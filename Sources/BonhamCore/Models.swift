import Foundation

public struct BonhamError: Error, LocalizedError, Sendable {
  public let message: String
  public init(_ message: String) { self.message = message }
  public var errorDescription: String? { message }
}
public func require(_ condition: Bool, _ message: String) throws {
  if !condition { throw BonhamError(message) }
}
public func validName(_ name: String) -> Bool {
  let s = name.trimmingCharacters(in: .whitespacesAndNewlines)
  return (1...64).contains(s.count)
    && s.unicodeScalars.contains {
      !CharacterSet.whitespacesAndNewlines.contains($0)
        && !CharacterSet.controlCharacters.contains($0)
    }
}
public struct Step: Codable, Equatable, Sendable {
  public var enabled = false
  public var level = 100
  public var retriggerCount = 1
  public var pitchLock: Double?
  public var decayLock: Double?
  public init() {}
  public func validate() throws {
    try require((1...127).contains(level), "Hit level must be 1–127.")
    try require([1, 2, 4, 8, 16].contains(retriggerCount), "Invalid retrigger count.")
    if let p = pitchLock {
      try require(p.isFinite && (-12...12).contains(p), "Invalid pitch lock.")
    }
    if let d = decayLock {
      try require(d.isFinite && (0.05...1).contains(d), "Invalid decay lock.")
    }
  }
}
public struct Track: Codable, Equatable, Sendable, Identifiable {
  public var instrumentID: String
  public var id: String { instrumentID }
  public var baseLevel = 0.8
  public var basePitchSemitones = 0.0
  public var baseDecay = 1.0
  public var steps = Array(repeating: Step(), count: 16)
  public init(instrumentID: String) { self.instrumentID = instrumentID }
  public func validate() throws {
    try require(
      !instrumentID.isEmpty && steps.count == 16, "Every instrument must have exactly 16 steps.")
    try require(baseLevel.isFinite && (0...1).contains(baseLevel), "Invalid track level.")
    try require(
      basePitchSemitones.isFinite && (-12...12).contains(basePitchSemitones), "Invalid track pitch."
    )
    try require(baseDecay.isFinite && (0.05...1).contains(baseDecay), "Invalid track decay.")
    for step in steps { try step.validate() }
  }
}
public struct Room: Codable, Equatable, Sendable {
  public var enabled = false
  public var amount = 0.0
  public var preset = "smallRoom-v1"
  public init() {}
}
public protocol LibraryEntity: Codable, Equatable, Sendable, Identifiable where ID == UUID {
  var schemaVersion: Int { get }
  var id: UUID { get set }
  var revision: Int { get set }
  var name: String { get set }
  var createdAt: Date { get set }
  var updatedAt: Date { get set }
  func validate() throws
}
public struct Pattern: LibraryEntity {
  public var schemaVersion = 1
  public var id = UUID()
  public var revision = 0
  public var name = "Untitled Pattern"
  public var createdAt = Date()
  public var updatedAt = Date()
  public var kitID: String
  public var kitAssetVersion: Int
  public var bpm = 120
  public var swing = 0.5
  public var tracks: [Track]
  public var room = Room()
  public init(kit: Kit) {
    kitID = kit.id
    kitAssetVersion = kit.assetVersion
    tracks = kit.instruments.sorted { $0.order < $1.order }.map { Track(instrumentID: $0.id) }
  }
  public func validate() throws {
    try require(
      schemaVersion == 1, "Unsupported pattern schema \(schemaVersion); original preserved.")
    try require(validName(name), "Use a name with 1–64 visible characters.")
    try require(
      revision >= 0 && kitAssetVersion > 0 && !kitID.isEmpty, "Invalid pattern identity/version.")
    try require(
      (40...240).contains(bpm) && swing.isFinite && (0.5...0.75).contains(swing),
      "Invalid tempo or swing.")
    try require(
      (1...16).contains(tracks.count) && Set(tracks.map(\.id)).count == tracks.count,
      "Invalid or duplicate tracks.")
    try require(
      room.amount.isFinite && (0...0.3).contains(room.amount) && room.preset == "smallRoom-v1",
      "Invalid room setting.")
    for t in tracks { try t.validate() }
  }
  public func validate(kit: Kit) throws {
    try validate()
    try require(
      kitID == kit.id && kitAssetVersion == kit.assetVersion,
      "Kit version has changed. Restore the matching assets for \(name).")
    try require(
      Set(tracks.map(\.id)) == Set(kit.instruments.map(\.id)),
      "Pattern instruments do not match kit \(kit.name).")
  }
  public func copy() -> Pattern {
    var p = self
    p.id = UUID()
    p.revision = 0
    p.name = String(name.prefix(59)) + " Copy"
    p.createdAt = Date()
    p.updatedAt = Date()
    return p
  }
  public mutating func clearLocks() {
    for t in tracks.indices {
      for s in 0..<16 {
        tracks[t].steps[s].pitchLock = nil
        tracks[t].steps[s].decayLock = nil
      }
    }
  }
}
public struct ChainEntry: Codable, Equatable, Sendable, Identifiable {
  public var id = UUID()
  public var patternID: UUID
  public var repeatCount = 1
  public var bpmOverride: Int?
  public init(patternID: UUID) { self.patternID = patternID }
}
public struct Chain: LibraryEntity {
  public var schemaVersion = 1
  public var id = UUID()
  public var revision = 0
  public var name = "Untitled Chain"
  public var createdAt = Date()
  public var updatedAt = Date()
  public var entries: [ChainEntry] = []
  public init() {}
  public func validate() throws { try validateDraft(allowEmpty: false) }
  public func validateDraft(allowEmpty: Bool = true) throws {
    try require(
      schemaVersion == 1, "Unsupported chain schema \(schemaVersion); original preserved.")
    try require(validName(name) && revision >= 0, "Invalid chain name or revision.")
    try require(
      (allowEmpty ? 0...64 : 1...64).contains(entries.count), "A saved chain needs 1–64 entries.")
    try require(Set(entries.map(\.id)).count == entries.count, "Duplicate chain entry IDs.")
    for e in entries {
      try require((1...16).contains(e.repeatCount), "Repeats must be 1–16.")
      if let b = e.bpmOverride { try require((40...240).contains(b), "Tempo must be 40–240.") }
    }
  }
  public func resolve(patterns: [Pattern]) throws -> [ResolvedEntry] {
    try validate()
    return try entries.map { e in
      guard let p = patterns.first(where: { $0.id == e.patternID }) else {
        throw BonhamError(
          "Missing pattern \(e.patternID). Edit this chain to replace its reference.")
      }
      try p.validate()
      return ResolvedEntry(pattern: p, repeats: e.repeatCount, bpm: e.bpmOverride ?? p.bpm)
    }
  }
  public func copy() -> Chain {
    var c = self
    c.id = UUID()
    c.revision = 0
    c.name = String(name.prefix(59)) + " Copy"
    c.createdAt = Date()
    c.updatedAt = Date()
    c.entries = entries.map {
      var e = $0
      e.id = UUID()
      return e
    }
    return c
  }
}
public struct ResolvedEntry: Sendable {
  public init(pattern: Pattern, repeats: Int, bpm: Int) {
    self.pattern = pattern
    self.repeats = repeats
    self.bpm = bpm
  }
  public var pattern: Pattern
  public var repeats: Int
  public var bpm: Int
  public var duration: Double { Double(repeats) * 240 / Double(bpm) }
}
public enum HatType: String, Codable, Sendable {
  case closed, open
}
public struct Instrument: Codable, Equatable, Sendable, Identifiable {
  public var id: String
  public var name: String
  public var file: String
  public var order: Int
  public var chokeGroup: String?
  public var hatType: HatType?
  /// Standard role IDs remain compatible with existing version-one manifests.
  public var renderHatKind: Int32 {
    switch hatType {
    case .closed: return 1
    case .open: return 2
    case nil: return id == "closedHat" ? 1 : id == "openHat" ? 2 : 0
    }
  }
  public var sha256: String?
  public var startFrame: Int?
  public var endFrame: Int?
  public init(id: String, name: String, file: String, order: Int, chokeGroup: String? = nil) {
    self.id = id
    self.name = name
    self.file = file
    self.order = order
    self.chokeGroup = chokeGroup
  }
}
public struct Kit: Codable, Equatable, Sendable, Identifiable {
  public var schemaVersion = 1
  public var id: String
  public var name: String
  public var assetVersion = 1
  public var developmentFixture: Bool? = nil
  public var instruments: [Instrument]
  public init(id: String, name: String, instruments: [Instrument]) {
    self.id = id
    self.name = name
    self.instruments = instruments
  }
  public func validate() throws {
    try require(
      schemaVersion == 1 && assetVersion > 0 && !id.isEmpty && validName(name),
      "Invalid kit manifest.")
    try require((1...16).contains(instruments.count), "\(name) must contain 1–16 instruments.")
    try require(
      Set(instruments.map(\.id)).count == instruments.count
        && Set(instruments.map(\.order)).count == instruments.count,
      "Duplicate instrument IDs/order in \(name).")
    for i in instruments {
      try require(i.hatType == nil || i.chokeGroup == "hats",
        "Explicit hat types must use the hats choke group: \(i.name).")
      try require(!i.id.isEmpty && validName(i.name), "Invalid instrument in \(name).")
      try require(
        !i.file.hasPrefix("/") && !i.file.split(separator: "/").contains("..")
          && !i.file.contains("\\")
          && ["wav", "mp3"].contains((i.file as NSString).pathExtension.lowercased()),
        "Unsafe or unsupported sample path: \(i.file).")
      try require(
        (i.startFrame ?? 0) >= 0 && (i.endFrame == nil || i.endFrame! > (i.startFrame ?? 0)),
        "Invalid sample trim for \(i.name).")
    }
  }
}
public struct Preferences: Codable, Equatable, Sendable {
  public var schemaVersion = 1
  public var masterLevel = 0.7
  public var clickLevel = 0.35
  public var metronomeEnabled = false
  public var lastKitID: String?
  public var lastWorkspace = "pattern"
  public init() {}
}
public struct RecoveryDraft<T: LibraryEntity>: Codable, Sendable, Identifiable {
  public var schemaVersion = 1
  public var entityType: String
  public var draftID: UUID
  public var savedEntityID: UUID?
  public var baseRevision: Int
  public var updatedAt = Date()
  public var model: T
  public var id: UUID { draftID }
  public init(_ model: T, type: String) {
    entityType = type
    draftID = model.id
    savedEntityID = model.revision > 0 ? model.id : nil
    baseRevision = model.revision
    self.model = model
  }
}
public enum MusicalClock {
  public static func bar(bpm: Int) -> Double { 240 / Double(bpm) }
  public static func onset(step: Int, bpm: Int, swing: Double) -> Double {
    (Double(step / 2) + (step % 2 == 1 ? swing : 0)) * 30 / Double(bpm)
  }
  public static func frame(seconds: Double, rate: Double) -> Int64 {
    Int64((seconds * rate).rounded())
  }
  public static func nearest(time: Double, bpm: Int, swing: Double) -> (bar: Int, step: Int) {
    let length = bar(bpm: bpm)
    let b = Int(floor(time / length))
    var best = (bar: b, step: 0)
    var distance = Double.infinity
    for n in (b - 1)...(b + 1) {
      for s in 0..<16 {
        let d = abs(time - (Double(n) * length + onset(step: s, bpm: bpm, swing: swing)))
        if d <= distance + 1e-12 {
          distance = d
          best = (n, s)
        }
      }
    }
    return best
  }
}
public struct EditHistory<T: Equatable> {
  private var past: [T] = []
  private var future: [T] = []
  public init() {}
  public var canUndo: Bool { !past.isEmpty }
  public var canRedo: Bool { !future.isEmpty }
  public mutating func record(_ before: T, _ after: T) {
    guard before != after else { return }
    past.append(before)
    if past.count > 150 { past.removeFirst() }
    future.removeAll()
  }
  public mutating func undo(_ current: T) -> T? {
    guard let previous = past.popLast() else { return nil }
    future.append(current)
    return previous
  }
  public mutating func redo(_ current: T) -> T? {
    guard let next = future.popLast() else { return nil }
    past.append(current)
    return next
  }
}
