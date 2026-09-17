import Darwin
import Foundation

public struct LibrarySnapshot: Sendable {
  public init() {}
  public var patterns: [Pattern] = []
  public var chains: [Chain] = []
  public var patternDrafts: [RecoveryDraft<Pattern>] = []
  public var chainDrafts: [RecoveryDraft<Chain>] = []
  public var issues: [String] = []
  public var preferences = Preferences()
}
public actor Repository {
  public let root: URL
  private let encoder: JSONEncoder
  private let decoder: JSONDecoder
  private var storageIssue: String?
  public init(root: URL) {
    self.root = root
    encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    encoder.dateEncodingStrategy = .iso8601
    decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    do {
      for dir in ["patterns", "chains", "recovery", "backups", "quarantine"] {
        try FileManager.default.createDirectory(
          at: root.appendingPathComponent(dir), withIntermediateDirectories: true)
      }
    } catch { storageIssue = "Local storage unavailable: " + error.localizedDescription }
  }
  private func ensureStorage() throws {
    for dir in ["patterns", "chains", "recovery", "backups", "quarantine"] {
      try FileManager.default.createDirectory(
        at: root.appendingPathComponent(dir), withIntermediateDirectories: true)
    }
    storageIssue = nil
  }
  private func url(_ folder: String, _ id: UUID) -> URL {
    root.appendingPathComponent(folder).appendingPathComponent(id.uuidString + ".json")
  }
  private func read<T: Decodable>(_ type: T.Type, _ path: URL) throws -> T {
    try decoder.decode(type, from: Data(contentsOf: path))
  }
  private func files(_ folder: String) -> [URL] {
    ((try? FileManager.default.contentsOfDirectory(
      at: root.appendingPathComponent(folder), includingPropertiesForKeys: nil)) ?? []).filter {
        $0.pathExtension == "json"
      }.sorted { $0.lastPathComponent < $1.lastPathComponent }
  }
  private func durableReplace(_ data: Data, at destination: URL) throws {
    let temporary = destination.deletingLastPathComponent().appendingPathComponent(
      "." + UUID().uuidString + ".tmp")
    defer { try? FileManager.default.removeItem(at: temporary) }
    try data.write(to: temporary, options: [.completeFileProtectionUnlessOpen])
    let handle = try FileHandle(forWritingTo: temporary)
    do {
      try handle.synchronize()
      try handle.close()
    } catch {
      try? handle.close()
      throw error
    }
    let result = temporary.path.withCString { source in
      destination.path.withCString { target in Darwin.rename(source, target) }
    }
    guard result == 0 else {
      throw BonhamError(
        "Could not commit " + destination.lastPathComponent + ": "
          + String(cString: strerror(errno)))
    }
    // APFS journals the atomic rename. Also request a directory flush where supported.
    let directory = Darwin.open(destination.deletingLastPathComponent().path, O_RDONLY)
    if directory >= 0 {
      _ = Darwin.fsync(directory)
      _ = Darwin.close(directory)
    }
  }
  private func write<T: Codable>(_ value: T, to path: URL, backup: Bool = false) throws {
    try ensureStorage()
    let data = try encoder.encode(value)
    _ = try decoder.decode(T.self, from: data)
    if backup && FileManager.default.fileExists(atPath: path.path) {
      let old = try Data(contentsOf: path)
      try durableReplace(
        old,
        at: root.appendingPathComponent("backups").appendingPathComponent(
          path.deletingLastPathComponent().lastPathComponent + "-" + path.lastPathComponent))
    }
    try durableReplace(data, at: path)
  }
  public func load() -> LibrarySnapshot {
    var result = LibrarySnapshot()
    if let storageIssue { result.issues.append(storageIssue) }
    for path in files("patterns") {
      do {
        let p = try read(Pattern.self, path)
        try p.validate()
        try require(
          path.deletingPathExtension().lastPathComponent == p.id.uuidString,
          "Pattern filename/identity mismatch.")
        result.patterns.append(p)
      } catch { result.issues.append("\(path.lastPathComponent): \(error.localizedDescription)") }
    }
    for path in files("chains") {
      do {
        let c = try read(Chain.self, path)
        try c.validate()
        try require(
          path.deletingPathExtension().lastPathComponent == c.id.uuidString,
          "Chain filename/identity mismatch.")
        result.chains.append(c)
      } catch { result.issues.append("\(path.lastPathComponent): \(error.localizedDescription)") }
    }
    for path in files("recovery") {
      do {
        let data = try Data(contentsOf: path)
        let header = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        try require(
          header?["schemaVersion"] as? Int == 1, "Unsupported recovery schema; retained untouched.")
        if header?["entityType"] as? String == "pattern" {
          let d = try decoder.decode(RecoveryDraft<Pattern>.self, from: data)
          try d.model.validate()
          result.patternDrafts.append(d)
        } else if header?["entityType"] as? String == "chain" {
          let d = try decoder.decode(RecoveryDraft<Chain>.self, from: data)
          try d.model.validateDraft()
          result.chainDrafts.append(d)
        } else {
          throw BonhamError("Unknown recovery type.")
        }
      } catch {
        result.issues.append("Recovery \(path.lastPathComponent): \(error.localizedDescription)")
      }
    }
    let pref = root.appendingPathComponent("preferences.json")
    if FileManager.default.fileExists(atPath: pref.path) {
      do {
        let p = try read(Preferences.self, pref)
        try require(
          p.schemaVersion == 1 && p.masterLevel.isFinite && (0...1).contains(p.masterLevel)
            && p.clickLevel.isFinite && (0.01...1).contains(p.clickLevel),
          "Invalid preferences; defaults used.")
        result.preferences = p
      } catch { result.issues.append(error.localizedDescription) }
    }
    return result
  }
  private func commit<T: LibraryEntity>(_ model: T, folder: String) throws -> T {
    try model.validate()
    let dest = url(folder, model.id)
    if FileManager.default.fileExists(atPath: dest.path) {
      let previous = try read(T.self, dest)
      try previous.validate()
      try require(
        previous.revision == model.revision,
        "This item changed since this draft was opened. Recover the draft as a copy.")
    } else {
      try require(model.revision == 0, "The original saved item is missing. Save a copy instead.")
    }
    var saved = model
    saved.name = saved.name.trimmingCharacters(in: .whitespacesAndNewlines)
    saved.revision += 1
    saved.updatedAt = Date()
    try write(saved, to: dest, backup: true)
    return saved
  }
  public func save(_ pattern: Pattern) throws -> Pattern { try commit(pattern, folder: "patterns") }
  public func save(_ chain: Chain) throws -> Chain {
    try chain.validate()
    for e in chain.entries {
      let p = try read(Pattern.self, url("patterns", e.patternID))
      try p.validate()
    }
    return try commit(chain, folder: "chains")
  }
  public func recover<T: LibraryEntity>(_ model: T, type: String) throws {
    try write(RecoveryDraft(model, type: type), to: url("recovery", model.id))
  }
  public func discardDraft(_ id: UUID) throws {
    let p = url("recovery", id)
    if FileManager.default.fileExists(atPath: p.path) { try FileManager.default.removeItem(at: p) }
  }
  public func savePreferences(_ preferences: Preferences) throws {
    try write(preferences, to: root.appendingPathComponent("preferences.json"))
  }
  public func deletePattern(_ id: UUID, additionalChains: [Chain] = []) throws {
    let snapshot = load()
    try require(
      !snapshot.issues.contains(where: { $0.contains("Recovery") }),
      "Resolve unreadable recovery records before deleting patterns; they may contain chain references."
    )
    // An unreadable saved chain could also reference this pattern. Preserve integrity conservatively.
    for path in files("chains") { try read(Chain.self, path).validate() }
    let owners = (snapshot.chains + snapshot.chainDrafts.map(\.model) + additionalChains).filter {
      $0.entries.contains { $0.patternID == id }
    }
    try require(
      owners.isEmpty,
      "Used by: \(Set(owners.map(\.name)).sorted().joined(separator: ", ")). Remove those entries from saved chains and drafts first."
    )
    try FileManager.default.removeItem(at: url("patterns", id))
    try? FileManager.default.removeItem(
      at: root.appendingPathComponent("backups/patterns-" + id.uuidString + ".json"))
    try discardDraft(id)
  }
  public func deleteChain(_ id: UUID) throws {
    try FileManager.default.removeItem(at: url("chains", id))
    try? FileManager.default.removeItem(
      at: root.appendingPathComponent("backups/chains-" + id.uuidString + ".json"))
    try discardDraft(id)
  }
  public func restoreBackups() -> [String] {
    var results: [String] = []
    for path in files("backups") {
      do {
        let name = path.lastPathComponent
        let folder = name.hasPrefix("patterns-") ? "patterns" : "chains"
        let original = String(name.dropFirst(folder.count + 1))
        let dest = root.appendingPathComponent(folder).appendingPathComponent(original)
        let data = try Data(contentsOf: path)
        if folder == "patterns" {
          try decoder.decode(Pattern.self, from: data).validate()
        } else {
          try decoder.decode(Chain.self, from: data).validate()
        }
        // Restore only damaged/missing canonical files; never roll back a healthy library item.
        if let current = try? Data(contentsOf: dest) {
          let valid: Bool
          if folder == "patterns" {
            valid = (try? decoder.decode(Pattern.self, from: current).validate()) != nil
          } else {
            valid = (try? decoder.decode(Chain.self, from: current).validate()) != nil
          }
          if valid { continue }
          let header = try? JSONSerialization.jsonObject(with: current) as? [String: Any]
          if let version = header?["schemaVersion"] as? Int, version > 1 { continue }
          try current.write(
            to: root.appendingPathComponent("quarantine").appendingPathComponent(
              UUID().uuidString + "-" + original), options: .atomic)
        }
        try durableReplace(data, at: dest)
        results.append("Restored \(original)")
      } catch { results.append(error.localizedDescription) }
    }
    return results
  }
}
