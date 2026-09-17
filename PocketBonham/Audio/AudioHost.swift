import AVFoundation
import BonhamCore
import BonhamRender
import CryptoKit
import Foundation
import QuartzCore

struct CatalogItem: Identifiable, Sendable {
  var kit: Kit
  var directory: URL
  var id: String { kit.id }
}
struct KitCatalog: Sendable {
  var items: [CatalogItem] = []
  var issues: [String] = []
  static func bundled() -> KitCatalog {
    var result = KitCatalog()
    guard let base = Bundle.main.resourceURL?.appendingPathComponent("Kits"),
      let files = FileManager.default.enumerator(at: base, includingPropertiesForKeys: nil)
    else {
      result.issues = ["Bundled Kits folder is missing."]
      return result
    }
    for case let url as URL in files where url.lastPathComponent == "manifest.json" {
      do {
        let kit = try JSONDecoder().decode(Kit.self, from: Data(contentsOf: url))
        try kit.validate()
        try require(
          !result.items.contains(where: { $0.id == kit.id }), "Duplicate kit ID \(kit.id).")
        for i in kit.instruments {
          try require(
            FileManager.default.fileExists(
              atPath: url.deletingLastPathComponent().appendingPathComponent(i.file).path),
            "\(kit.name) / \(i.name): missing \(i.file).")
        }
        result.items.append(CatalogItem(kit: kit, directory: url.deletingLastPathComponent()))
      } catch {
        result.issues.append(
          "\(url.deletingLastPathComponent().lastPathComponent): \(error.localizedDescription)")
      }
    }
    result.items.sort {
      let a = $0.kit.developmentFixture == true
      let b = $1.kit.developmentFixture == true
      return a == b ? $0.kit.name < $1.kit.name : !a
    }
    return result
  }
}
final class AudioRig: @unchecked Sendable {
  let engine = AVAudioEngine()
  let kernel: OpaquePointer
  let rate: Double
  var mapping: [String: Int32] = [:]
  var hatKinds: [String: Int32] = [:]
  var decodedBytes = 0
  let source: AVAudioSourceNode
  init(items: [CatalogItem], rate: Double) throws {
    self.rate = rate
    guard let kernel = pb_create(rate) else { throw BonhamError("Could not allocate sampler.") }
    self.kernel = kernel
    let format = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 2)!
    source = AVAudioSourceNode(format: format) { _, timestamp, count, buffers in
      let list = UnsafeMutableAudioBufferListPointer(buffers)
      guard list.count >= 2, let l = list[0].mData, let r = list[1].mData else { return -1 }
      let host = AVAudioTime.seconds(forHostTime: timestamp.pointee.mHostTime)
      pb_render(
        kernel, l.assumingMemoryBound(to: Float.self), r.assumingMemoryBound(to: Float.self), count,
        host)
      return noErr
    }
    do {
      var slot: Int32 = 0
      for item in items {
        for instrument in item.kit.instruments.sorted(by: { $0.order < $1.order }) {
          let path = item.directory.appendingPathComponent(instrument.file)
          do {
            let decoded = try SampleDecoder.decode(
              path: path, instrument: instrument, rate: rate,
              remainingBytes: 192 * 1024 * 1024 - decodedBytes)
            let stereo = decoded.stereo
            try require(slot < 256, "This playback requires more than 256 distinct samples.")
            stereo.withUnsafeBufferPointer {
              _ = pb_set_sample(kernel, slot, $0.baseAddress, Int32(decoded.frames))
            }
            mapping[item.id + "/" + instrument.id] = slot
            hatKinds[item.id + "/" + instrument.id] = instrument.renderHatKind
            decodedBytes += stereo.count * 4
            slot += 1
          } catch {
            throw BonhamError(
              "\(item.kit.name) / \(instrument.name) / \(instrument.file): \(error.localizedDescription)"
            )
          }
        }
      }
      engine.attach(source)
      engine.connect(source, to: engine.mainMixerNode, format: format)
      engine.prepare()
    } catch {
      throw error
    }
  }
  deinit {
    engine.stop()
    pb_destroy(kernel)
  }
}
@MainActor final class AudioHost: ObservableObject {
  @Published var status = PBStatus()
  @Published var visualStatus = PBStatus()
  private var positionHistory: [PBStatus] = []
  @Published var preparing = false
  @Published var running = false
  @Published var chainMode = false
  @Published var error: String?
  @Published var route = "Not active"
  @Published var latency = 0.0
  @Published var bufferDuration = 0.0
  @Published var decodedBytes = 0
  var rig: AudioRig?
  private var generation = 0
  private var observers: [NSObjectProtocol] = []
  private var displayLink: CADisplayLink?
  var onTick: (() -> Void)?
  var onExternalStop: (() -> Void)?
  var currentKitIDs: Set<String> = []
  var currentEntries: [ResolvedEntry] = []
  var preferences = Preferences()
  var eligibility: [String: Int64] = [:]
  init() {
    let nc = NotificationCenter.default
    for name in [
      AVAudioSession.interruptionNotification, AVAudioSession.routeChangeNotification,
      AVAudioSession.mediaServicesWereResetNotification, .AVAudioEngineConfigurationChange,
    ] {
      observers.append(
        nc.addObserver(forName: name, object: nil, queue: .main) { [weak self] note in
          Task { @MainActor in
            guard let self else { return }
            if note.name == .AVAudioEngineConfigurationChange,
              (note.object as? AVAudioEngine) !== self.rig?.engine
            {
              return
            }
            if note.name == AVAudioSession.routeChangeNotification,
              let raw = note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
              raw == AVAudioSession.RouteChangeReason.categoryChange.rawValue
            {
              return
            }
            self.stop()
            self.rig?.engine.stop()
            self.onTick?()
            self.rig = nil
            self.currentKitIDs = []
            self.onExternalStop?()
          }
        })
    }
    let link = CADisplayLink(target: self, selector: #selector(tick))
    link.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 60, preferred: 60)
    link.add(to: .main, forMode: .common)
    displayLink = link
  }
  @objc private func tick() {
    if let rig {
      status = pb_status(rig.kernel)
      var visual = status
      if status.state == 2 {
        if positionHistory.last?.bar != status.bar {
          positionHistory.append(status)
          if positionHistory.count > 4 { positionHistory.removeFirst() }
        }
        let presentationFrame =
          Double(status.frame) + (CACurrentMediaTime() - status.hostSeconds - latency)
          * status.sampleRate
        if let earlier = positionHistory.last(where: { $0.barStartFrame <= presentationFrame }) {
          visual = earlier
        }
        if presentationFrame < visual.barStartFrame {
          visual.state = 1
          visual.count = 4
        } else {
          let seconds = (presentationFrame - visual.barStartFrame) / status.sampleRate
          visual.step = Int32(
            (0..<16).last(where: {
              MusicalClock.onset(step: $0, bpm: Int(visual.bpm), swing: visual.swing) <= seconds
            }) ?? 0)
        }
      }
      visualStatus = visual
    }
    onTick?()
  }
  func configureSession() throws -> Double {
    let session = AVAudioSession.sharedInstance()
    try session.setCategory(.playback, mode: .default, options: [])
    try session.setPreferredSampleRate(48000)
    try session.setPreferredIOBufferDuration(0.005)
    try session.setActive(true)
    route = session.currentRoute.outputs.map(\.portName).joined(separator: ", ")
    latency = session.outputLatency
    bufferDuration = session.ioBufferDuration
    return session.sampleRate
  }
  func prepare(items: [CatalogItem]) async throws {
    let ids = Set(items.map(\.id))
    if let rig, ids.isSubset(of: currentKitIDs), rig.engine.isRunning { return }
    let token = generation
    rig?.engine.stop()
    rig = nil
    currentKitIDs = []
    let rate = try configureSession()
    let next = try await Task.detached(priority: .userInitiated) {
      try AudioRig(items: items, rate: rate)
    }.value
    try require(token == generation, "Audio preparation cancelled.")
    try next.engine.start()
    rig = next
    currentKitIDs = ids
    decodedBytes = next.decodedBytes
    applyPreferences()
  }
  func start(entries: [ResolvedEntry], catalog: KitCatalog, chain: Bool) async {
    guard !preparing else { return }
    stop()
    preparing = true
    chainMode = chain
    let token = generation
    do {
      let ids = Set(entries.map { $0.pattern.kitID })
      let kits = ids.compactMap { id in catalog.items.first { $0.id == id } }
      try require(
        kits.count == ids.count, "A required kit is unavailable. Restore its bundled assets.")
      for entry in entries {
        try entry.pattern.validate(kit: kits.first { $0.id == entry.pattern.kitID }!.kit)
      }
      try await prepare(items: kits)
      guard token == generation else { return }
      currentEntries = entries
      eligibility = [:]
      for slot in rig!.mapping.values { pb_audible(rig!.kernel, slot, 1) }
      publish(entries: entries, start: true)
      running = true
      preparing = false
    } catch {
      if token == generation {
        self.error = error.localizedDescription
        preparing = false
        running = false
      }
    }
  }
  func publish(entries: [ResolvedEntry], start: Bool) {
    guard let rig, let plan = pb_plan_create(Int32(entries.count), chainMode ? 1 : 0) else {
      return
    }
    defer { pb_plan_destroy(plan) }
    for (ei, entry) in entries.enumerated() {
      let p = entry.pattern
      pb_plan_entry(
        plan, Int32(ei), Int32(entry.bpm), p.swing, Int32(entry.repeats),
        p.room.enabled ? Float(p.room.amount) : 0)
      for (ti, track) in p.tracks.enumerated() {
        guard let sample = rig.mapping[p.kitID + "/" + track.id] else { continue }
        let hat = rig.hatKinds[p.kitID + "/" + track.id] ?? 0
        pb_plan_track(
          plan, Int32(ei), Int32(ti), sample, hat, Float(track.baseLevel),
          Float(track.basePitchSemitones), Float(track.baseDecay))
        for (si, step) in track.steps.enumerated() {
          pb_plan_step(
            plan, Int32(ei), Int32(ti), Int32(si), step.enabled ? 1 : 0, Int32(step.level),
            Int32(step.retriggerCount), Float(step.pitchLock ?? track.basePitchSemitones),
            Float(step.decayLock ?? track.baseDecay), eligibility[track.id + "/" + String(si)] ?? 0)
        }
      }
    }
    if pb_publish(rig.kernel, plan, start ? 1 : 0) == 0 {
      error = "Audio edit queue is full. Retry the edit."
    }
  }
  func update(_ pattern: Pattern) {
    guard running && !chainMode else { return }
    publish(entries: [ResolvedEntry(pattern: pattern, repeats: 1, bpm: pattern.bpm)], start: false)
  }
  func stop() {
    generation += 1
    if let rig { pb_stop(rig.kernel) }
    running = false
    preparing = false
    status = PBStatus()
    visualStatus = PBStatus()
    positionHistory = []
    eligibility = [:]
  }
  func deactivate() {
    stop()
    rig?.engine.stop()
    onTick?()
    rig = nil
    currentKitIDs = []
    try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
  }
  func applyPreferences() {
    if let rig {
      pb_preferences(
        rig.kernel, Float(preferences.masterLevel), Float(preferences.clickLevel),
        preferences.metronomeEnabled ? 1 : 0)
    }
  }
  func setMotion(pattern: Pattern, track: Track, parameter: String, value: Double) {
    guard let rig, let slot = rig.mapping[pattern.kitID + "/" + track.id] else { return }
    if pb_motion(rig.kernel, slot, parameter == "pitch" ? 1 : 2, Float(value)) == 0 {
      error = "Motion queue is full."
    }
  }
  func endMotion() -> UInt64 {
    guard let rig else { return 0 }
    return pb_motion(rig.kernel, -1, 0, 0)
  }
  var motionAcknowledged: UInt64 { rig.map { pb_motion_ack($0.kernel) } ?? UInt64.max }
  func drainMotion() -> [(String, Int, Int, Double)] {
    guard let rig else { return [] }
    var events = [PBMotionEvent](repeating: PBMotionEvent(), count: 1024)
    let count = Int(pb_motion_read(rig.kernel, &events, 1024))
    return events.prefix(count).compactMap { event in
      guard let key = rig.mapping.first(where: { $0.value == event.sample })?.key else {
        return nil
      }
      return (key, Int(event.step), Int(event.parameter), Double(event.value))
    }
  }
  func audition(pattern: Pattern, track: Track, level: Int) {
    guard let rig, let slot = rig.mapping[pattern.kitID + "/" + track.id], rig.engine.isRunning
    else { return }
    if pb_live(
      rig.kernel, slot, rig.hatKinds[pattern.kitID + "/" + track.id] ?? 0,
      Float(track.baseLevel * Double(level) / 127), Float(track.basePitchSemitones),
      Float(track.baseDecay)) == 0
    {
      error = "Pad queue is full."
    }
  }
}
