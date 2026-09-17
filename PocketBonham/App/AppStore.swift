import BonhamCore
import BonhamRender
import SwiftUI

struct Performance: Equatable {
  var muted = false
  var solo = false
}
struct PatternEdit: Equatable {
  var pattern: Pattern
  var performance: [String: Performance]
}
struct ChainEdit: Equatable {
  var chain: Chain
  var performance: [String: Performance]
}
@MainActor final class AppStore: ObservableObject {
  let catalog: KitCatalog
  let repository: Repository
  let audio = AudioHost()
  @Published var pattern: Pattern
  @Published var chain = Chain()
  @Published var library = LibrarySnapshot()
  @Published var tab = "pattern"
  @Published var selectedTrack = 0
  @Published var selectedStep = 0
  @Published var padsMode = false
  @Published var recordArmed = false
  @Published var recordMotion = false
  @Published var accent = false
  @Published var performance: [String: Performance] = [:]
  @Published var message: String?
  @Published var saving = false
  @Published var historyVersion = 0
  @Published var showLeave = false
  @Published var showRecovery = false
  @Published var recoveryConflict = false
  @Published var kitChangeLoss: [String] = []
  @Published var pendingKit: Kit?
  var pendingAction: (() -> Void)?
  var leavingChain = false
  var recoveryPattern: RecoveryDraft<Pattern>?
  var recoveryChain: RecoveryDraft<Chain>?
  var patternHistory = EditHistory<PatternEdit>()
  var chainHistory = EditHistory<ChainEdit>()
  var patternGesture: PatternEdit?
  var recordingBefore: PatternEdit?
  var chainGesture: ChainEdit?
  var motionParameter: String?
  var motionEndSerial: UInt64?
  var motionPatternID: UUID?
  var motionValue: Double = 0
  var lastMotionStep = -1
  var lastRecordingBar: Int64 = -1
  var recoveryTask: Task<Void, Never>?
  var savedPattern: Pattern?
  var savedChain: Chain?
  var startup = true
  private var patternTouched = false
  private var chainTouched = false
  private var recoverablePattern: Bool { patternDirty && (patternTouched || pattern.revision > 0) }
  private var recoverableChain: Bool { chainDirty && (chainTouched || chain.revision > 0) }
  init() {
    catalog = KitCatalog.bundled()
    pattern = Pattern(
      kit: catalog.items.first?.kit
        ?? Kit(id: "unavailable", name: "No usable kits", instruments: []))
    var path = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("PocketBonham")
    #if DEBUG
      if let session = ProcessInfo.processInfo.environment["PB_TEST_SESSION"],
        UUID(uuidString: session) != nil
      {
        path = path.deletingLastPathComponent().appendingPathComponent("PocketBonham-UI-" + session)
      }
    #endif
    repository = Repository(root: path)
    audio.onTick = { [weak self] in self?.audioTick() }
    audio.onExternalStop = { [weak self] in
      self?.endGesture(force: true)
      self?.endRecording()
      self?.recordArmed = false
    }
    Task { await bootstrap() }
  }
  var kit: Kit? { catalog.items.first { $0.id == pattern.kitID }?.kit }
  var track: Track? {
    pattern.tracks.indices.contains(selectedTrack) ? pattern.tracks[selectedTrack] : nil
  }
  var patternDirty: Bool { savedPattern != pattern }
  var chainDirty: Bool { savedChain != chain }
  var activeDirty: Bool { tab == "chains" ? chainDirty : patternDirty }
  var pState: PatternEdit { PatternEdit(pattern: pattern, performance: performance) }
  var cState: ChainEdit { ChainEdit(chain: chain, performance: performance) }
  var canUndo: Bool {
    tab == "chains" ? chainHistory.canUndo : patternHistory.canUndo || recordingBefore != nil
  }
  var canRedo: Bool { tab == "chains" ? chainHistory.canRedo : patternHistory.canRedo }
  var chainPlaybackIssue: String? {
    do {
      let entries = try chain.resolve(patterns: library.patterns)
      for entry in entries {
        guard let kit = catalog.items.first(where: { $0.id == entry.pattern.kitID })?.kit else {
          return "\(entry.pattern.name) requires unavailable kit \(entry.pattern.kitID)."
        }
        try entry.pattern.validate(kit: kit)
      }
      return nil
    } catch { return error.localizedDescription }
  }
  var activePattern: Pattern {
    if audio.running && audio.chainMode
      && audio.currentEntries.indices.contains(Int(audio.status.entry))
    {
      return audio.currentEntries[Int(audio.status.entry)].pattern
    }
    return pattern
  }
  func bootstrap() async {
    library = await repository.load()
    audio.preferences = library.preferences
    tab = library.preferences.lastWorkspace
    if let id = library.preferences.lastKitID, let k = catalog.items.first(where: { $0.id == id }) {
      pattern = Pattern(kit: k.kit)
    }
    startup = false
    if !library.issues.isEmpty || !catalog.issues.isEmpty {
      message = (catalog.issues + library.issues).joined(separator: "\n")
    }
    if let d = library.patternDrafts.sorted(by: { $0.updatedAt > $1.updatedAt }).first {
      recoveryPattern = d
      recoveryConflict =
        library.patterns.first { $0.id == d.model.id }.map { $0.revision != d.baseRevision }
        ?? false
      showRecovery = true
    } else if let d = library.chainDrafts.sorted(by: { $0.updatedAt > $1.updatedAt }).first {
      recoveryChain = d
      recoveryConflict =
        library.chains.first { $0.id == d.model.id }.map { $0.revision != d.baseRevision } ?? false
      showRecovery = true
    }
    await preparePads()
  }
  func refresh() async { library = await repository.load() }
  func preparePads() async {
    guard !audio.running && !audio.preparing,
      let item = catalog.items.first(where: { $0.id == pattern.kitID })
    else { return }
    do {
      try await audio.prepare(items: [item])
      applyPerformance()
    } catch {
      if !error.localizedDescription.contains("cancelled") { message = error.localizedDescription }
    }
  }
  func changed() {
    historyVersion += 1
    audio.update(pattern)
    scheduleRecovery()
  }
  func editPattern(_ change: (inout Pattern) -> Void) {
    patternTouched = true
    let before = pState
    change(&pattern)
    if patternGesture == nil && recordingBefore == nil { patternHistory.record(before, pState) }
    changed()
  }
  func editChain(_ change: (inout Chain) -> Void) {
    chainTouched = true
    let before = cState
    change(&chain)
    if chainGesture == nil { chainHistory.record(before, cState) }
    changed()
  }
  func beginGesture() {
    if motionEndSerial != nil {
      drainMotion()
      finishGesture()
    }
    endRecording()
    if patternGesture == nil { patternGesture = pState }
  }
  func endGesture(force: Bool = false) {
    if let serial = motionEndSerial {
      drainMotion()
      if force || audio.motionAcknowledged >= serial { finishGesture() }
      return
    }
    if motionParameter != nil {
      motionEndSerial = audio.endMotion()
      motionParameter = nil
      drainMotion()
      if !force && audio.rig?.engine.isRunning == true { return }
    }
    finishGesture()
  }
  private func finishGesture() {
    if let before = patternGesture, before.pattern.id == pattern.id {
      patternHistory.record(before, pState)
    }
    patternGesture = nil
    motionParameter = nil
    motionEndSerial = nil
    motionPatternID = nil
    historyVersion += 1
  }
  private func drainMotion() {
    var modified = false
    for (key, step, parameter, value) in audio.drainMotion() {
      guard motionPatternID == pattern.id,
        let t = pattern.tracks.firstIndex(where: { pattern.kitID + "/" + $0.id == key })
      else { continue }
      if parameter == 1 {
        pattern.tracks[t].steps[step].pitchLock = value
      } else {
        pattern.tracks[t].steps[step].decayLock = value
      }
      modified = true
    }
    if modified { changed() }
  }
  func beginChainGesture() { if chainGesture == nil { chainGesture = cState } }
  func endChainGesture() {
    if let before = chainGesture { chainHistory.record(before, cState) }
    chainGesture = nil
    historyVersion += 1
  }
  func undo() {
    endGesture(force: true)
    endRecording()
    recordArmed = false
    if tab == "chains" {
      if let state = chainHistory.undo(cState) {
        let rev = chain.revision
        chain = state.chain
        chain.revision = rev
        if let savedChain { chain.updatedAt = savedChain.updatedAt }
        performance = state.performance
      }
    } else if let state = patternHistory.undo(pState) {
      let rev = pattern.revision
      pattern = state.pattern
      pattern.revision = rev
      if let savedPattern { pattern.updatedAt = savedPattern.updatedAt }
      performance = state.performance
      selectedTrack = min(selectedTrack, max(0, pattern.tracks.count - 1))
    }
    applyPerformance()
    changed()
    if !audio.running { Task { await preparePads() } }
  }
  func redo() {
    if tab == "chains" {
      if let state = chainHistory.redo(cState) {
        let rev = chain.revision
        chain = state.chain
        chain.revision = rev
        if let savedChain { chain.updatedAt = savedChain.updatedAt }
        performance = state.performance
      }
    } else if let state = patternHistory.redo(pState) {
      let rev = pattern.revision
      pattern = state.pattern
      pattern.revision = rev
      if let savedPattern { pattern.updatedAt = savedPattern.updatedAt }
      performance = state.performance
    }
    selectedTrack = min(selectedTrack, max(0, pattern.tracks.count - 1))
    applyPerformance()
    changed()
    if !audio.running { Task { await preparePads() } }
  }
  func scheduleRecovery() {
    guard !startup else { return }
    recoveryTask?.cancel()
    let p = pattern
    let c = chain
    let pd = recoverablePattern
    let cd = recoverableChain
    recoveryTask = Task { [weak self] in
      try? await Task.sleep(for: .milliseconds(300))
      guard !Task.isCancelled, let self else { return }
      do {
        if pd { try await repository.recover(p, type: "pattern") }
        if cd { try await repository.recover(c, type: "chain") }
      } catch { message = "Draft recovery failed: \(error.localizedDescription)" }
    }
  }
  private func settleMotion() async {
    endGesture()
    for _ in 0..<20 {
      drainMotion()
      guard let serial = motionEndSerial else { return }
      if audio.motionAcknowledged >= serial || audio.rig?.engine.isRunning != true {
        finishGesture()
        return
      }
      try? await Task.sleep(for: .milliseconds(5))
    }
    drainMotion()
    finishGesture()
  }
  @discardableResult func flush() async -> Bool {
    await settleMotion()
    recoveryTask?.cancel()
    do {
      if recoverablePattern { try await repository.recover(pattern, type: "pattern") }
      if recoverableChain { try await repository.recover(chain, type: "chain") }
      var prefs = audio.preferences
      prefs.lastWorkspace = tab
      prefs.lastKitID = pattern.kitID
      try await repository.savePreferences(prefs)
      return true
    } catch {
      message = error.localizedDescription
      return false
    }
  }
  @discardableResult func save(isChain: Bool) async -> Bool {
    guard !saving else { return false }
    saving = true
    await settleMotion()
    endRecording()
    recoveryTask?.cancel()
    defer { saving = false }
    do {
      if isChain {
        let captured = chain
        let saved = try await repository.save(captured)
        savedChain = saved
        if chain == captured {
          chain = saved
          try await repository.discardDraft(saved.id)
        } else {
          chain.revision = saved.revision
          scheduleRecovery()
        }
      } else {
        let captured = pattern
        let saved = try await repository.save(captured)
        savedPattern = saved
        if pattern == captured {
          pattern = saved
          try await repository.discardDraft(saved.id)
        } else {
          pattern.revision = saved.revision
          scheduleRecovery()
        }
      }
      await refresh()
      return true
    } catch {
      message = error.localizedDescription
      scheduleRecovery()
      return false
    }
  }
  func leave(isChain: Bool? = nil, _ action: @escaping () -> Void) {
    stop()
    leavingChain = isChain ?? (tab == "chains")
    if leavingChain ? recoverableChain : recoverablePattern {
      pendingAction = action
      showLeave = true
    } else {
      action()
    }
  }
  func finishLeave(_ choice: String) {
    let isChain = leavingChain
    Task {
      if choice == "save" {
        guard await save(isChain: isChain) else { return }
      } else if choice == "keep" {
        guard await flush() else { return }
      } else {
        recoveryTask?.cancel()
        do { try await repository.discardDraft(isChain ? chain.id : pattern.id) } catch {
          message = error.localizedDescription
          return
        }
        if isChain {
          chain = savedChain ?? Chain()
          chainTouched = false
          chainHistory = EditHistory()
        } else {
          pattern =
            savedPattern
            ?? Pattern(
              kit: kit ?? catalog.items.first?.kit
                ?? Kit(id: "unavailable", name: "No usable kits", instruments: []))
          patternTouched = false
          patternHistory = EditHistory()
          selectedTrack = 0
        }
      }
      let action = pendingAction
      pendingAction = nil
      action?()
      await refresh()
    }
  }
  func newPattern() {
    leave {
      self.pattern = Pattern(
        kit: self.kit ?? self.catalog.items.first?.kit
          ?? Kit(id: "unavailable", name: "No usable kits", instruments: []))
      self.savedPattern = nil
      self.patternTouched = true
      self.patternHistory = EditHistory()
      self.performance = [:]
      self.selectedTrack = 0
      self.tab = "pattern"
      self.changed()
    }
  }
  func newChain() {
    leave {
      self.chain = Chain()
      self.savedChain = nil
      self.chainTouched = true
      self.chainHistory = EditHistory()
      self.performance = [:]
      self.tab = "chains"
      self.changed()
    }
  }
  func open(_ p: Pattern) {
    leave(isChain: false) {
      if let d = self.library.patternDrafts.first(where: { $0.model.id == p.id }) {
        self.recoveryPattern = d
        self.recoveryChain = nil
        self.recoveryConflict = d.baseRevision != p.revision
        self.showRecovery = true
      } else {
        self.loadPattern(p)
      }
    }
  }
  func open(_ c: Chain) {
    leave(isChain: true) {
      if let d = self.library.chainDrafts.first(where: { $0.model.id == c.id }) {
        self.recoveryChain = d
        self.recoveryPattern = nil
        self.recoveryConflict = d.baseRevision != c.revision
        self.showRecovery = true
      } else {
        self.loadChain(c)
      }
    }
  }
  func loadPattern(_ p: Pattern, saved: Pattern? = nil) {
    stop()
    pattern = p
    patternTouched = p.revision == 0
    savedPattern = saved ?? library.patterns.first { $0.id == p.id }
    patternHistory = EditHistory()
    selectedTrack = 0
    performance = [:]
    tab = "pattern"
    Task { await preparePads() }
  }
  func loadChain(_ c: Chain, saved: Chain? = nil) {
    stop()
    chain = c
    chainTouched = c.revision == 0
    savedChain = saved ?? library.chains.first { $0.id == c.id }
    chainHistory = EditHistory()
    performance = [:]
    tab = "chains"
  }
  func recover(useDraft: Bool) {
    if let d = recoveryPattern {
      if useDraft {
        loadPattern(recoveryConflict ? d.model.copy() : d.model)
        scheduleRecovery()
      } else if let saved = library.patterns.first(where: { $0.id == d.model.id }) {
        loadPattern(saved)
      }
      if !useDraft {
        Task {
          try? await repository.discardDraft(d.id)
          await refresh()
        }
      }
    } else if let d = recoveryChain {
      if useDraft {
        loadChain(recoveryConflict ? d.model.copy() : d.model)
        scheduleRecovery()
      } else if let saved = library.chains.first(where: { $0.id == d.model.id }) {
        loadChain(saved)
      }
      if !useDraft {
        Task {
          try? await repository.discardDraft(d.id)
          await refresh()
        }
      }
    }
    recoveryPattern = nil
    recoveryChain = nil
    showRecovery = false
  }
  func duplicatePattern(_ p: Pattern) {
    leave(isChain: false) {
      self.loadPattern(p.copy())
      self.savedPattern = nil
      self.patternTouched = true
      self.changed()
    }
  }
  func duplicateChain(_ c: Chain) {
    leave(isChain: true) {
      self.loadChain(c.copy())
      self.savedChain = nil
      self.chainTouched = true
      self.changed()
    }
  }
  func deletePattern(_ p: Pattern) async {
    stop()
    do {
      try await repository.deletePattern(p.id, additionalChains: [chain])
      if pattern.id == p.id {
        pattern = Pattern(
          kit: kit ?? catalog.items.first?.kit
            ?? Kit(id: "unavailable", name: "No usable kits", instruments: []))
        savedPattern = nil
      }
      await refresh()
    } catch { message = error.localizedDescription }
  }
  func deleteChain(_ c: Chain) async {
    stop()
    do {
      try await repository.deleteChain(c.id)
      if chain.id == c.id {
        chain = Chain()
        savedChain = nil
      }
      await refresh()
    } catch { message = error.localizedDescription }
  }
  func selectKit(_ next: Kit) {
    guard !audio.running && !audio.preparing else { return }
    let roles = Set(next.instruments.map(\.id))
    kitChangeLoss = pattern.tracks.filter {
      !roles.contains($0.id) && $0.steps.contains(where: \.enabled)
    }.map(\.id)
    pendingKit = next
    if kitChangeLoss.isEmpty { confirmKit() }
  }
  func confirmKit() {
    guard let next = pendingKit else { return }
    editPattern { p in
      let old = p.tracks
      p.kitID = next.id
      p.kitAssetVersion = next.assetVersion
      p.tracks = next.instruments.sorted { $0.order < $1.order }.map { instrument in
        old.first { $0.id == instrument.id } ?? Track(instrumentID: instrument.id)
      }
    }
    selectedTrack = 0
    pendingKit = nil
    kitChangeLoss = []
    performance = [:]
    Task { await preparePads() }
  }
  func play(chainMode: Bool) {
    endRecording()
    performance = [:]
    Task {
      do {
        let entries =
          try chainMode
          ? chain.resolve(patterns: library.patterns)
          : [ResolvedEntry(pattern: pattern, repeats: 1, bpm: pattern.bpm)]
        await audio.start(entries: entries, catalog: catalog, chain: chainMode)
        if chainMode {
          recordArmed = false
          recordMotion = false
        }
      } catch { message = error.localizedDescription }
    }
  }
  func stop() {
    endGesture()
    endRecording()
    audio.stop()
    recordArmed = false
    lastRecordingBar = -1
  }
  func toggleRecord() {
    if recordArmed { endRecording() }
    recordArmed.toggle()
  }
  func endRecording() {
    if let before = recordingBefore {
      patternHistory.record(before, pState)
      historyVersion += 1
    }
    recordingBefore = nil
  }
  func tap(_ index: Int, timestamp: Double) {
    guard pattern.tracks.indices.contains(index), !audio.chainMode || !audio.running else { return }
    let track = pattern.tracks[index]
    let level = accent ? 127 : 100
    audio.audition(pattern: pattern, track: track, level: level)
    guard recordArmed && audio.running && audio.status.state == 2 else { return }
    let status = audio.status
    if lastRecordingBar != status.bar {
      endRecording()
      lastRecordingBar = status.bar
    }
    if recordingBefore == nil && patternGesture == nil { recordingBefore = pState }
    let delta = min(0.2, max(-0.2, timestamp - status.hostSeconds))
    let position = (Double(status.frame) - status.barStartFrame) / status.sampleRate + delta
    let target = MusicalClock.nearest(time: position, bpm: Int(status.bpm), swing: status.swing)
    patternTouched = true
    let wasEnabled = pattern.tracks[index].steps[target.step].enabled
    pattern.tracks[index].steps[target.step].enabled = true
    pattern.tracks[index].steps[target.step].level = level
    if !wasEnabled {
      audio.eligibility[track.id + "/" + String(target.step)] = status.bar + Int64(target.bar) + 1
    }
    changed()
  }
  func audioTick() {
    drainMotion()
    if let serial = motionEndSerial, audio.motionAcknowledged >= serial {
      drainMotion()
      finishGesture()
    }
    guard audio.running && audio.status.state == 2 else { return }
    if lastRecordingBar != audio.status.bar {
      endRecording()
      lastRecordingBar = audio.status.bar
    }
  }
  func setTrackValue(_ parameter: String, value: Double) {
    guard pattern.tracks.indices.contains(selectedTrack) else { return }
    if recordMotion && audio.running && !audio.chainMode
      && (parameter == "pitch" || parameter == "decay")
    {
      motionParameter = parameter
      motionValue = value
      motionPatternID = pattern.id
      if patternGesture == nil { patternGesture = pState }
      audio.setMotion(
        pattern: pattern, track: pattern.tracks[selectedTrack], parameter: parameter, value: value)
    } else {
      editPattern { p in
        if parameter == "pitch" {
          p.tracks[selectedTrack].basePitchSemitones = value
        } else if parameter == "decay" {
          p.tracks[selectedTrack].baseDecay = value
        } else {
          p.tracks[selectedTrack].baseLevel = value
        }
      }
    }
  }
  func togglePerformance(kitID: String, instrumentID: String, solo: Bool) {
    let beforeP = pState
    let beforeC = cState
    let key = kitID + "/" + instrumentID
    var value = performance[key] ?? Performance()
    if solo { value.solo.toggle() } else { value.muted.toggle() }
    performance[key] = value
    if tab == "chains" {
      chainHistory.record(beforeC, cState)
    } else {
      patternHistory.record(beforeP, pState)
    }
    historyVersion += 1
    applyPerformance()
  }
  func clearPerformance() {
    let p = pState
    let c = cState
    performance = [:]
    if tab == "chains" { chainHistory.record(c, cState) } else { patternHistory.record(p, pState) }
    historyVersion += 1
    applyPerformance()
  }
  func applyPerformance() {
    guard let rig = audio.rig else { return }
    for item in catalog.items {
      let anySolo = item.kit.instruments.contains {
        performance[item.id + "/" + $0.id]?.solo == true
      }
      for i in item.kit.instruments {
        let key = item.id + "/" + i.id
        let p = performance[key] ?? Performance()
        if let slot = rig.mapping[key] {
          pb_audible(rig.kernel, slot, !p.muted && (!anySolo || p.solo) ? 1 : 0)
        }
      }
    }
  }
}
