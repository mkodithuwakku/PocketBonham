import BonhamRender
import XCTest

@testable import BonhamCore

typealias Pattern = BonhamCore.Pattern

final class ModelTests: XCTestCase {
  func kit(_ id: String = "test") -> Kit {
    Kit(
      id: id, name: "Test Kit",
      instruments: [
        Instrument(id: "kick", name: "Kick", file: "kick.wav", order: 0),
        Instrument(id: "snare", name: "Snare", file: "snare.wav", order: 1),
      ])
  }
  func testExplicitHatVariantsAndLegacyManifestCompatibility() throws {
    let legacy = Data(#"{"id":"closedHat","name":"Closed Hat","file":"hat.wav","order":0}"#.utf8)
    XCTAssertEqual(try JSONDecoder().decode(Instrument.self, from: legacy).renderHatKind, 1)
    var variant = Instrument(id: "closedHat2", name: "Closed Hat 2", file: "hat2.wav", order: 1,
      chokeGroup: "hats")
    variant.hatType = .closed
    var k = Kit(id: "variants", name: "Variants", instruments: [variant])
    try k.validate()
    let roundTrip = try JSONDecoder().decode(Kit.self, from: JSONEncoder().encode(k))
    XCTAssertEqual(roundTrip.instruments[0].renderHatKind, 1)
    k.instruments[0].chokeGroup = nil
    XCTAssertThrowsError(try k.validate())
  }
  func testOwnerKitDecodesEveryOriginalAndRetainsNineRoles() throws {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
      .deletingLastPathComponent().deletingLastPathComponent()
      .appendingPathComponent("PocketBonham/Resources/Kits/kit-1")
    let kit = try JSONDecoder().decode(Kit.self,
      from: Data(contentsOf: root.appendingPathComponent("manifest.json")))
    try kit.validate()
    XCTAssertEqual(kit.instruments.map(\.id),
      ["kick", "snare", "closedHat", "closedHat2", "openHat", "tomExtra1", "tomExtra2", "tomExtra3", "ride"])
    XCTAssertEqual(kit.instruments.map(\.renderHatKind), [0, 0, 1, 1, 2, 0, 0, 0, 0])
    let pattern = Pattern(kit: kit)
    try pattern.validate(kit: kit)
    XCTAssertEqual(pattern.tracks.count, 9)
    for rate in [44100.0, 48000.0] {
      for instrument in kit.instruments {
        let sample = try SampleDecoder.decode(path: root.appendingPathComponent(instrument.file),
          instrument: instrument, rate: rate, remainingBytes: 192 * 1024 * 1024)
        XCTAssertGreaterThan(sample.frames, 0)
        XCTAssertTrue(sample.stereo.contains { abs($0) > 0.001 })
      }
    }
  }
  func testTimingSwingQuantizationAndDrift() {
    for swing in [0.5, 2.0 / 3, 0.75] {
      XCTAssertEqual(MusicalClock.onset(step: 4, bpm: 120, swing: swing), 0.5, accuracy: 1e-12)
      XCTAssertEqual(
        MusicalClock.onset(step: 1, bpm: 120, swing: swing), 0.25 * swing, accuracy: 1e-12)
    }
    XCTAssertEqual(MusicalClock.nearest(time: 0.0625, bpm: 120, swing: 0.5).step, 1)
    let wrap = MusicalClock.nearest(time: 1.99, bpm: 120, swing: 0.75)
    XCTAssertEqual(wrap.bar, 1)
    XCTAssertEqual(wrap.step, 0)
    for bar in 0..<400 {
      let f = MusicalClock.frame(seconds: Double(bar) * 240 / 137, rate: 48000)
      XCTAssertLessThanOrEqual(abs(Double(f) - Double(bar) * 240 / 137 * 48000), 0.5)
    }
  }
  func testValidationLocksAndDuplicate() throws {
    var p = Pattern(kit: kit())
    p.tracks[0].steps[0].enabled = true
    p.tracks[0].steps[0].pitchLock = 7
    p.tracks[0].steps[0].decayLock = 0.2
    p.tracks[0].steps[0].retriggerCount = 16
    try p.validate(kit: kit())
    let copy = p.copy()
    XCTAssertNotEqual(p.id, copy.id)
    XCTAssertEqual(p.tracks, copy.tracks)
    p.tracks[0].steps.removeLast()
    XCTAssertThrowsError(try p.validate())
    var k = kit()
    k.instruments[0].file = "../kick.wav"
    XCTAssertThrowsError(try k.validate())
    k = kit()
    k.instruments[1].id = "kick"
    XCTAssertThrowsError(try k.validate())
    XCTAssertFalse(validName(" \n\t "))
    XCTAssertTrue(validName("Gâteau 🥁"))
  }
  func testChainsOverridesAndDuration() throws {
    var a = Pattern(kit: kit())
    var b = Pattern(kit: kit("other"))
    a.bpm = 100
    b.bpm = 140
    var c = Chain()
    c.entries = [ChainEntry(patternID: a.id), ChainEntry(patternID: b.id)]
    c.entries[0].repeatCount = 2
    XCTAssertEqual(
      try c.resolve(patterns: [a, b]).reduce(0) { $0 + $1.duration }, 6.514285714285714,
      accuracy: 1e-9)
    c.entries[0].bpmOverride = 120
    c.entries[1].bpmOverride = 120
    XCTAssertEqual(
      try c.resolve(patterns: [a, b]).reduce(0) { $0 + $1.duration }, 6, accuracy: 1e-9)
    XCTAssertEqual(a.bpm, 100)
    XCTAssertThrowsError(try c.resolve(patterns: [a]))
  }
  func testUndoGroupsAndRedo() {
    var h = EditHistory<Int>()
    for n in 0..<120 { h.record(n, n + 1) }
    var value = 120
    for _ in 0..<100 { value = h.undo(value)! }
    XCTAssertEqual(value, 20)
    XCTAssertEqual(h.redo(value), 21)
    h.record(21, 42)
    XCTAssertNil(h.redo(42))
  }
}
final class RepositoryTests: XCTestCase {
  func directory() throws -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    addTeardownBlock { try? FileManager.default.removeItem(at: url) }
    return url
  }
  func pattern() -> Pattern {
    Pattern(
      kit: Kit(
        id: "test", name: "Test",
        instruments: [Instrument(id: "kick", name: "Kick", file: "kick.wav", order: 0)]))
  }
  func testRoundTripReferenceIntegrityRecoveryAndRevision() async throws {
    let root = try directory()
    let repo = Repository(root: root)
    var p = pattern()
    p.tracks[0].steps[3].enabled = true
    p.tracks[0].steps[3].pitchLock = -4
    p = try await repo.save(p)
    XCTAssertEqual(p.revision, 1)
    var c = Chain()
    c.entries = [ChainEntry(patternID: p.id)]
    c.entries[0].bpmOverride = 137
    c = try await repo.save(c)
    do {
      try await repo.deletePattern(p.id)
      XCTFail("Referenced deletion allowed")
    } catch { XCTAssertTrue(error.localizedDescription.contains(c.name)) }
    var draft = p
    draft.bpm = 180
    try await repo.recover(draft, type: "pattern")
    let loaded = await repo.load()
    XCTAssertEqual(loaded.patterns[0].bpm, 120)
    XCTAssertEqual(loaded.patternDrafts[0].model.bpm, 180)
    p.name = "Renamed"
    p = try await repo.save(p)
    do {
      _ = try await repo.save(draft)
      XCTFail("Stale revision accepted")
    } catch {}
    let relaunch = Repository(root: root)
    let next = await relaunch.load()
    XCTAssertEqual(next.patterns[0].name, "Renamed")
    XCTAssertEqual(next.chains[0].entries[0].patternID, p.id)
    try await repo.deleteChain(c.id)
    try await repo.deletePattern(p.id)
  }
  func testCorruptFutureSchemaAndRestoreBackup() async throws {
    let root = try directory()
    let repo = Repository(root: root)
    var p = try await repo.save(pattern())
    p.bpm = 137
    p = try await repo.save(p)
    let file = root.appendingPathComponent("patterns/\(p.id.uuidString).json")
    try Data("broken".utf8).write(to: file)
    var state = await repo.load()
    XCTAssertEqual(state.issues.count, 1)
    XCTAssertTrue(state.patterns.isEmpty)
    _ = await repo.restoreBackups()
    state = await repo.load()
    XCTAssertEqual(state.patterns.first?.bpm, 120)
    let data = try Data(contentsOf: file)
    let text = String(decoding: data, as: UTF8.self).replacingOccurrences(
      of: "\"schemaVersion\" : 1", with: "\"schemaVersion\" : 99")
    try Data(text.utf8).write(to: file)
    state = await repo.load()
    XCTAssertTrue(state.patterns.isEmpty)
    _ = await repo.restoreBackups()
    XCTAssertEqual(try String(contentsOf: file, encoding: .utf8), text)
  }
  func testFailedSavePreservesPreviousAndDraft() async throws {
    let root = try directory()
    let repo = Repository(root: root)
    let p = try await repo.save(pattern())
    var invalid = p
    invalid.bpm = 999
    try await repo.recover(p, type: "pattern")
    do {
      _ = try await repo.save(invalid)
      XCTFail("Invalid saved")
    } catch {}
    let loaded = await repo.load()
    XCTAssertEqual(loaded.patterns[0].bpm, 120)
    XCTAssertEqual(loaded.patternDrafts.count, 1)
    // Force same-volume atomic replacement to fail without changing the prior canonical file.
    let backups = root.appendingPathComponent("backups")
    try FileManager.default.removeItem(at: backups)
    try Data("not a directory".utf8).write(to: backups)
    var next = p
    next.bpm = 140
    do {
      _ = try await repo.save(next)
      XCTFail("Fault injection did not fail")
    } catch {}
    let after = await repo.load()
    XCTAssertEqual(after.patterns[0], loaded.patterns[0])
    XCTAssertEqual(after.patternDrafts.count, 1)
  }
}
final class RenderTests: XCTestCase {
  func engine() -> OpaquePointer {
    let e = pb_create(48000)!
    let impulse: [Float] = [1, 1, 0, 0]
    impulse.withUnsafeBufferPointer {
      _ = pb_set_sample(e, 0, $0.baseAddress, 2)
      _ = pb_set_sample(e, 1, $0.baseAddress, 2)
    }
    pb_trace_enable(e, 1)
    let address = UInt(bitPattern: e)
    addTeardownBlock { pb_destroy(OpaquePointer(bitPattern: address)) }
    return e
  }
  func plan(bpm: Int32 = 120, swing: Double = 0.5, retriggers: Int32 = 1, steps: Bool = true)
    -> OpaquePointer
  {
    let p = pb_plan_create(1, 0)!
    pb_plan_entry(p, 0, bpm, swing, 1, 0)
    pb_plan_track(p, 0, 0, 0, 0, 0.8, 0, 1)
    for s in 0..<16 { pb_plan_step(p, 0, 0, Int32(s), steps ? 1 : 0, 100, retriggers, 0, 1, 0) }
    let address = UInt(bitPattern: p)
    addTeardownBlock { pb_plan_destroy(OpaquePointer(bitPattern: address)) }
    return p
  }
  @discardableResult func render(_ e: OpaquePointer, _ frames: Int) -> [PBEvent] {
    var left = [Float](repeating: 0, count: 4096)
    var right = left
    var remaining = frames
    while remaining > 0 {
      let count = min(4096, remaining)
      left.withUnsafeMutableBufferPointer { l in
        right.withUnsafeMutableBufferPointer { r in
          pb_render(e, l.baseAddress, r.baseAddress, UInt32(count), 0)
        }
      }
      XCTAssertTrue(left.prefix(count).allSatisfy { $0.isFinite && abs($0) <= 0.980001 })
      remaining -= count
    }
    var events = [PBEvent](repeating: PBEvent(), count: 65536)
    let n = pb_trace_read(e, &events, Int32(events.count))
    return Array(events.prefix(Int(n)))
  }
  func testFourCountStraightAndNoExtraBoundary() {
    let e = engine()
    let p = plan()
    XCTAssertEqual(pb_publish(e, p, 1), 1)
    let events = render(e, 288001)
    let clicks = events.filter { $0.click == 1 }
    let hits = events.filter { $0.click == 0 }
    XCTAssertEqual(clicks.map(\.frame), [0, 24000, 48000, 72000])
    XCTAssertEqual(hits.count, 33)
    for (index, event) in hits.enumerated() {
      XCTAssertEqual(event.frame, 96000 + Int64(index) * 6000)
    }
  }
  func testCountInAtTempoExtremes() {
    for bpm: Int32 in [40, 240] {
      let e = engine()
      let p = plan(bpm: bpm)
      _ = pb_publish(e, p, 1)
      let q = 48000 * 60 / Double(bpm)
      let events = render(e, Int(q * 4) + 1)
      XCTAssertEqual(
        events.filter { $0.click == 1 }.map(\.frame),
        (0..<4).map { Int64((Double($0) * q).rounded()) })
      XCTAssertEqual(events.last?.frame, Int64(q * 4))
    }
  }
  func testSwingAndRetriggersAtAbsoluteFrames() {
    for swing in [0.5, 2.0 / 3, 0.75] {
      for r: Int32 in [1, 2, 4, 8, 16] {
        let e = engine()
        let p = plan(swing: swing, retriggers: r)
        _ = pb_publish(e, p, 1)
        let hits = render(e, 192000).filter { $0.click == 0 }
        XCTAssertEqual(hits.count, 16 * Int(r))
        for s in 0..<16 {
          let start = MusicalClock.onset(step: s, bpm: 120, swing: swing)
          let end = s == 15 ? 2 : MusicalClock.onset(step: s + 1, bpm: 120, swing: swing)
          for j in 0..<Int(r) {
            XCTAssertEqual(
              hits[s * Int(r) + j].frame,
              Int64(((2 + start + (end - start) * Double(j) / Double(r)) * 48000).rounded()))
          }
        }
      }
    }
  }
  func testTenMinute137BPMHasNoCumulativeDrift() {
    let e = engine()
    let p = plan(bpm: 137)
    _ = pb_publish(e, p, 1)
    let events = render(e, 48000 * 600).filter { $0.click == 0 }
    XCTAssertGreaterThan(events.count, 5400)
    let quarter = 60.0 / 137
    for (n, event) in events.enumerated() {
      let expected = Int64(((4 * quarter + Double(n) * quarter / 4) * 48000).rounded())
      XCTAssertLessThanOrEqual(abs(event.frame - expected), 1)
    }
  }
  func testStopCancelsPendingStartAndClicks() {
    let e = engine()
    let p = plan()
    _ = pb_publish(e, p, 1)
    pb_stop(e)
    XCTAssertTrue(render(e, 100000).isEmpty)
    _ = pb_publish(e, p, 1)
    _ = render(e, 100)
    pb_stop(e)
    XCTAssertTrue(render(e, 200000).isEmpty)
    XCTAssertEqual(pb_status(e).state, 0)
  }
  func testChainTempoRepeatsAndSampleIdentity() {
    let e = engine()
    let p = pb_plan_create(2, 1)!
    defer { pb_plan_destroy(p) }
    for en: Int32 in 0..<2 {
      pb_plan_entry(p, en, en == 0 ? 100 : 140, 0.5, en == 0 ? 2 : 1, 0)
      pb_plan_track(p, en, 0, en, 0, 0.8, 0, 1)
      pb_plan_step(p, en, 0, 0, 1, 100, 1, 0, 1, 0)
    }
    _ = pb_publish(e, p, 1)
    let hits = render(e, 48000 * 12).filter { $0.click == 0 }
    XCTAssertEqual(hits.prefix(4).map(\.sample), [0, 0, 1, 0])
    let expected = [2.4, 4.8, 7.2, 2.4 + 6.514285714285714]
    for (hit, time) in zip(hits, expected) {
      XCTAssertEqual(hit.frame, Int64((time * 48000).rounded()))
    }
  }
  func testTempoEditWaitsForBarAndLiveStepUpdate() {
    let e = engine()
    let p = plan(steps: false)
    _ = pb_publish(e, p, 1)
    _ = render(e, 100000)
    pb_plan_entry(p, 0, 240, 0.75, 1, 0)
    pb_plan_step(p, 0, 0, 4, 1, 100, 1, 0, 1, 0)
    _ = pb_publish(e, p, 0)
    var hits = render(e, 30000).filter { $0.click == 0 }
    XCTAssertEqual(hits.first?.frame, 120000)
    XCTAssertEqual(pb_status(e).bpm, 120)
    XCTAssertEqual(pb_status(e).pending, 1)
    hits = render(e, 100000).filter { $0.click == 0 }
    XCTAssertEqual(hits.first?.frame, 204000)
    XCTAssertEqual(pb_status(e).bpm, 240)
  }
  func testHatChordAndNewRecordedHitEligibility() {
    let e = engine()
    let p = plan(steps: false)
    pb_plan_track(p, 0, 0, 0, 2, 0.8, 0, 1)
    pb_plan_track(p, 0, 1, 1, 1, 0.8, 0, 1)
    pb_plan_step(p, 0, 0, 0, 1, 100, 1, 0, 1, 0)
    pb_plan_step(p, 0, 1, 0, 1, 100, 1, 0, 1, 0)
    pb_plan_step(p, 0, 1, 4, 1, 100, 1, 0, 1, 1)
    _ = pb_publish(e, p, 1)
    let hits = render(e, 240001).filter { $0.click == 0 }
    XCTAssertEqual(hits.filter { $0.frame == 96000 }.map(\.sample), [0, 1])
    XCTAssertEqual(hits.filter { $0.step == 4 }.map(\.frame), [216000])
  }
  func testMutedVoicesAndSaturatedStressStayBounded() {
    let e = engine()
    let p = plan(bpm: 240, swing: 0.75, retriggers: 16)
    let sample = [Float](repeating: 0.1, count: 48000 * 2)
    sample.withUnsafeBufferPointer { _ = pb_set_sample(e, 0, $0.baseAddress, 48000) }
    for t: Int32 in 0..<16 {
      pb_plan_track(p, 0, t, 0, 0, 0.8, 0, 1)
      for s: Int32 in 0..<16 { pb_plan_step(p, 0, t, s, 1, 127, 16, 0, 1, 0) }
    }
    pb_plan_entry(p, 0, 240, 0.75, 1, 0.3)
    _ = pb_publish(e, p, 1)
    _ = render(e, 48000 * 3)
    XCTAssertLessThanOrEqual(pb_status(e).voices, 64)
    XCTAssertGreaterThan(pb_status(e).stolenVoices, 0)
    pb_audible(e, 0, 0)
    XCTAssertTrue(render(e, 48000).filter { $0.click == 0 }.isEmpty)
  }
}

final class DecoderTests: XCTestCase {
  func testRequiredPCMAndMP3Matrix() throws {
    let root = Bundle.module.resourceURL!.appendingPathComponent("Fixtures")
    let files = try FileManager.default.contentsOfDirectory(
      at: root, includingPropertiesForKeys: nil)
    XCTAssertEqual(files.count, 16)
    for file in files {
      let instrument = Instrument(
        id: "test", name: "Codec Fixture", file: file.lastPathComponent, order: 0)
      for rate in [44100.0, 48000.0] {
        let sample = try SampleDecoder.decode(path: file, instrument: instrument, rate: rate)
        XCTAssertEqual(sample.stereo.count, sample.frames * 2)
        XCTAssertTrue(sample.stereo.allSatisfy(\.isFinite))
        // MP3 encoder priming is preserved, never automatically trimmed.
        let seconds = Double(sample.frames) / rate
        if file.pathExtension == "wav" {
          XCTAssertEqual(seconds, 0.1, accuracy: 2 / rate)
        } else {
          XCTAssertGreaterThanOrEqual(seconds, 0.099)
          XCTAssertLessThan(seconds, 0.17)
        }
        let left = stride(from: 0, to: sample.stereo.count, by: 2).map { sample.stereo[$0] }
        let right = stride(from: 1, to: sample.stereo.count, by: 2).map { sample.stereo[$0] }
        XCTAssertGreaterThan(left.map { abs($0) }.max() ?? 0, 0.1)
        if file.lastPathComponent.contains("-1.") {
          XCTAssertEqual(left, right)
        } else {
          XCTAssertNotEqual(left, right)
        }
      }
    }
  }
  func testBudgetCorruptionAndExplicitTrim() throws {
    let file = Bundle.module.resourceURL!.appendingPathComponent("Fixtures/pcm16-48000-1.wav")
    var instrument = Instrument(id: "test", name: "Test", file: file.lastPathComponent, order: 0)
    XCTAssertThrowsError(
      try SampleDecoder.decode(path: file, instrument: instrument, rate: 48000, remainingBytes: 16))
    instrument.startFrame = 480
    instrument.endFrame = 960
    let sample = try SampleDecoder.decode(path: file, instrument: instrument, rate: 48000)
    XCTAssertEqual(sample.frames, 480)
    instrument.endFrame = 999999
    XCTAssertThrowsError(try SampleDecoder.decode(path: file, instrument: instrument, rate: 48000))
    let corrupt = FileManager.default.temporaryDirectory.appendingPathComponent(
      UUID().uuidString + ".wav")
    defer { try? FileManager.default.removeItem(at: corrupt) }
    try Data("not an audio file".utf8).write(to: corrupt)
    XCTAssertThrowsError(
      try SampleDecoder.decode(path: corrupt, instrument: instrument, rate: 48000))
  }
}
extension RenderTests {
  func capture(_ e: OpaquePointer, frames: Int) -> [Float] {
    var l = [Float](repeating: 0, count: frames)
    var r = l
    l.withUnsafeMutableBufferPointer { left in
      r.withUnsafeMutableBufferPointer { right in
        pb_render(e, left.baseAddress, right.baseAddress, UInt32(frames), 0)
      }
    }
    return l
  }
  func testSimultaneousDrumsMixWithoutDroppingVoices() {
    let e = engine()
    let p = plan(steps: false)
    let pcm = [Float](repeating: 0.2, count: 4800 * 2)
    for slot: Int32 in 0..<16 {
      pcm.withUnsafeBufferPointer { _ = pb_set_sample(e, slot, $0.baseAddress, 4800) }
      pb_plan_track(p, 0, slot, slot, 0, 0.1, 0, 1)
      pb_plan_step(p, 0, slot, 0, 1, 127, 1, 0, 1, 0)
    }
    _ = pb_publish(e, p, 1)
    let output = capture(e, frames: 97000)
    XCTAssertEqual(output[96500], 16 * 0.2 * 0.1 * 0.7, accuracy: 0.00001)
    XCTAssertEqual(pb_status(e).voices, 16)
    let hits = render(e, 1).filter { $0.click == 0 }
    XCTAssertEqual(Set(hits.map(\.sample)), Set((0..<16).map { Int32($0) }))
    XCTAssertTrue(hits.allSatisfy { $0.frame == 96000 })
  }
  func testSimultaneousHatPairsKeepBothTails() {
    for hats: [Int32] in [[1, 1], [1, 2], [2, 1]] {
      for live in [false, true] {
        let e = engine()
        let p = plan(steps: false)
        let pcm = [Float](repeating: 0.2, count: 4800 * 2)
        for slot: Int32 in 0..<2 {
          pcm.withUnsafeBufferPointer { _ = pb_set_sample(e, slot, $0.baseAddress, 4800) }
          pb_plan_track(p, 0, slot, slot, hats[Int(slot)], 0.1, 0, 1)
          pb_plan_step(p, 0, slot, 0, 1, 127, 1, 0, 1, 0)
        }
        if live {
          _ = pb_live(e, 0, hats[0], 0.1, 0, 1)
          _ = pb_live(e, 1, hats[1], 0.1, 0, 1)
        } else { _ = pb_publish(e, p, 1) }
        let onset = live ? 0 : 96000
        let output = capture(e, frames: onset + 1000)
        XCTAssertEqual(output[onset + 500], 2 * 0.2 * 0.1 * 0.7, accuracy: 0.00001,
          "Both same-frame hats must survive beyond the choke ramp; live=\(live)")
        XCTAssertEqual(pb_status(e).voices, 2)
        // A later hat still releases both older tails.
        _ = pb_live(e, 0, 1, 0.1, 0, 1)
        let later = capture(e, frames: 500)
        XCTAssertEqual(later[499], 0.2 * 0.1 * 0.7, accuracy: 0.00001)
        XCTAssertEqual(pb_status(e).voices, 1)
      }
    }
  }
  func testMutedClosedHatDoesNotSuppressLiveOpenHat() {
    let e = engine()
    pb_audible(e, 0, 0)
    _ = pb_live(e, 0, 1, 0.1, 0, 1)
    _ = pb_live(e, 1, 2, 0.1, 0, 1)
    XCTAssertEqual(render(e, 1).map(\.sample), [1])
  }
  func testPitchDecayLocksDoNotLeakAndStopRamps() {
    let e = engine()
    let p = plan(steps: false)
    let pcm = [Float](repeating: 0.3, count: 4800 * 2)
    pcm.withUnsafeBufferPointer { _ = pb_set_sample(e, 0, $0.baseAddress, 4800) }
    pb_plan_step(p, 0, 0, 0, 1, 127, 1, 12, 0.5, 0)
    pb_plan_step(p, 0, 0, 1, 1, 127, 1, 0, 1, 0)
    _ = pb_publish(e, p, 1)
    let output = capture(e, frames: 108000)
    XCTAssertGreaterThan(abs(output[96010]), 0.1)
    XCTAssertEqual(output[98000], 0, accuracy: 0.00001)
    XCTAssertGreaterThan(abs(output[105000]), 0.1)
    _ = pb_live(e, 0, 0, 0.5, 0, 1)
    _ = capture(e, frames: 256)
    pb_stop(e)
    let stopped = capture(e, frames: 512)
    XCTAssertGreaterThan(abs(stopped[0]), 0)
    XCTAssertTrue(stopped.dropFirst(144).allSatisfy { $0 == 0 })
  }
  func testUnequalHatRollsLayerAtSharedOnsets() {
    let e = engine()
    let p = plan(steps: false)
    pb_plan_track(p, 0, 0, 0, 2, 0.8, 0, 1)
    pb_plan_track(p, 0, 1, 1, 1, 0.8, 0, 1)
    pb_plan_step(p, 0, 0, 0, 1, 100, 4, 0, 1, 0)
    pb_plan_step(p, 0, 1, 0, 1, 100, 2, 0, 1, 0)
    _ = pb_publish(e, p, 1)
    let hits = render(e, 102000).filter { $0.click == 0 }
    XCTAssertEqual(hits.map(\.frame), [96000, 96000, 97500, 99000, 99000, 100500])
    XCTAssertEqual(hits.map(\.sample), [0, 1, 0, 0, 1, 0])
  }
  func testPitchResamplingRejectsAboveNyquistEnergy() {
    func rms(_ frequency: Double) -> Double {
      let e = engine()
      let count = 4800
      var pcm = [Float]()
      pcm.reserveCapacity(count * 2)
      for n in 0..<count {
        let value = Float(sin(2 * .pi * frequency * Double(n) / 48000)) * 0.2
        pcm.append(value)
        pcm.append(value)
      }
      pcm.withUnsafeBufferPointer { _ = pb_set_sample(e, 0, $0.baseAddress, Int32(count)) }
      _ = pb_live(e, 0, 0, 1, 12, 1)
      let output = capture(e, frames: 2000).dropFirst(32)
      return sqrt(output.reduce(0) { $0 + Double($1 * $1) } / Double(output.count))
    }
    let audible = rms(2000)
    let rejected = rms(16000)
    XCTAssertGreaterThan(audible, 0.08)
    XCTAssertLessThan(rejected / audible, 0.025)
  }
}
extension RepositoryTests {
  func testLibraryScaleAndUnsupportedRecordIsolation() async throws {
    let root = try directory()
    let repo = Repository(root: root)
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    var first: Pattern?
    for n in 0..<1000 {
      var p = pattern()
      p.name = "Pattern \(n)"
      p.revision = 1
      if n == 0 { first = p }
      try encoder.encode(p).write(
        to: root.appendingPathComponent("patterns/\(p.id.uuidString).json"))
    }
    for n in 0..<200 {
      var c = Chain()
      c.name = "Chain \(n)"
      c.revision = 1
      c.entries = [ChainEntry(patternID: first!.id)]
      try encoder.encode(c).write(to: root.appendingPathComponent("chains/\(c.id.uuidString).json"))
    }
    try Data("corrupt".utf8).write(to: root.appendingPathComponent("patterns/bad.json"))
    let start = ContinuousClock.now
    let state = await repo.load()
    let duration = start.duration(to: .now)
    XCTAssertEqual(state.patterns.count, 1000)
    XCTAssertEqual(state.chains.count, 200)
    XCTAssertEqual(state.issues.count, 1)
    print("Library scale: 1,000 patterns / 200 chains read in \(duration)")
    XCTAssertLessThan(duration, .seconds(3))  // Host regression guard; device target still requires measurement.
  }
}

extension RenderTests {
  func testMotionIsCapturedOnTheAudioClockOnlyForEnabledSteps() {
    let e = engine()
    let p = plan(steps: false)
    pb_plan_step(p, 0, 0, 1, 1, 100, 4, 0, 1, 0)
    pb_plan_step(p, 0, 0, 3, 1, 100, 1, 0, 1, 0)
    _ = pb_publish(e, p, 1)
    _ = render(e, 97000)
    let start = pb_motion(e, 0, 1, 7)
    _ = render(e, 18000)
    var events = [PBMotionEvent](repeating: PBMotionEvent(), count: 32)
    let count = pb_motion_read(e, &events, 32)
    XCTAssertEqual(count, 2)
    XCTAssertEqual(events.prefix(Int(count)).map(\.step), [1, 3])
    XCTAssertTrue(events.prefix(Int(count)).allSatisfy { $0.parameter == 1 && $0.value == 7 })
    let end = pb_motion(e, -1, 0, 0)
    XCTAssertGreaterThan(end, start)
    _ = render(e, 96000)
    XCTAssertEqual(pb_motion_ack(e), end)
    XCTAssertEqual(pb_motion_read(e, &events, 32), 0)
  }
  func testOneHourOfflineClock() throws {
    guard ProcessInfo.processInfo.environment["PB_LONG_TESTS"] == "1" else {
      throw XCTSkip("Run PB_LONG_TESTS=1 swift test -c release for the one-hour offline timeline.")
    }
    let e = engine()
    let p = plan(bpm: 137, swing: 0.75)
    _ = pb_publish(e, p, 1)
    let hits = render(e, 48000 * 3600).filter { $0.click == 0 }
    XCTAssertGreaterThan(hits.count, 32000)
    for (index, event) in hits.enumerated() {
      let countIn = 240.0 / 137
      let barDuration = 240.0 / 137
      let approximateBar = index / 16
      let expected = Int64(
        ((countIn + Double(approximateBar) * barDuration
          + MusicalClock.onset(step: Int(event.step), bpm: 137, swing: 0.75)) * 48000).rounded())
      XCTAssertLessThanOrEqual(abs(event.frame - expected), 1)
    }
  }
}
