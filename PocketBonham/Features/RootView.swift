import BonhamCore
import SwiftUI

struct RootView: View {
  @ObservedObject var store: AppStore
  @ObservedObject var audio: AudioHost
  @State private var settings = false
  var body: some View {
    TabView(selection: $store.tab) {
      NavigationStack {
        PatternView(store: store, audio: audio, onSettings: { settings = true })
      }.tabItem { Label("Pattern", systemImage: "square.grid.3x3.fill") }.tag("pattern")
      NavigationStack { LibraryView(store: store) }.tabItem {
        Label("Library", systemImage: "square.stack")
      }.tag("library")
      NavigationStack { ChainView(store: store, audio: audio) }.tabItem {
        Label("Chains", systemImage: "link")
      }.tag("chains")
    }.tint(.signal)
      .modifier(InstrumentChassis())
      .sheet(isPresented: $settings) { SettingsView(store: store, audio: audio) }
      .alert(
        "PocketBonham",
        isPresented: Binding(
          get: { store.message != nil || audio.error != nil },
          set: {
            if !$0 {
              store.message = nil
              audio.error = nil
            }
          })
      ) {
        Button("OK") {
          store.message = nil
          audio.error = nil
        }
      } message: {
        Text(store.message ?? audio.error ?? "")
      }
      .confirmationDialog(
        "Leave this unsaved draft?", isPresented: $store.showLeave, titleVisibility: .visible
      ) {
        Button("Save and Continue") { store.finishLeave("save") }
        Button("Keep Draft") { store.finishLeave("keep") }
        Button("Discard Draft", role: .destructive) { store.finishLeave("discard") }
        Button("Cancel", role: .cancel) { store.pendingAction = nil }
      }
      .confirmationDialog(
        store.recoveryConflict
          ? "Saved version has changed. Recover as a separate copy?"
          : "A recoverable draft is available.", isPresented: $store.showRecovery,
        titleVisibility: .visible
      ) {
        Button(store.recoveryConflict ? "Recover as Copy" : "Resume Draft") {
          store.recover(useDraft: true)
        }
        Button("Open Saved Version / Discard Draft") { store.recover(useDraft: false) }
        Button("Later", role: .cancel) {}
      }
      .confirmationDialog(
        "Changing kit removes notes on: \(store.kitChangeLoss.joined(separator:", "))",
        isPresented: Binding(
          get: { !store.kitChangeLoss.isEmpty }, set: { if !$0 { store.kitChangeLoss = [] } }),
        titleVisibility: .visible
      ) {
        Button("Change Kit and Remove Those Tracks", role: .destructive) { store.confirmKit() }
        Button("Cancel", role: .cancel) { store.pendingKit = nil }
      }
      .onChange(of: store.tab) { _, _ in Task { await store.flush() } }
  }
}
struct PatternView: View {
  var onSettings: () -> Void
  init(store: AppStore, audio: AudioHost, onSettings: @escaping () -> Void) {
    self.store = store
    self.audio = audio
    self.onSettings = onSettings
  }
  @ObservedObject var store: AppStore
  @ObservedObject var audio: AudioHost
  @State private var details = false
  @State private var instrumentMenu = false
  @State private var velocityEdit: VelocityEdit?
  @Environment(\.scenePhase) private var scenePhase
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  @State private var padPage = 0
  @State private var saveName = false
  @State private var name = ""
  @State private var clearScope: String?
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 10) {
        HStack(alignment: .top) {
          VStack(alignment: .leading, spacing: 4) {
            Text("PocketBonham").font(.system(.title2, design: .serif).weight(.black))
              .italic().tracking(-0.8).dynamicTypeSize(...DynamicTypeSize.xxxLarge).lineLimit(1).minimumScaleFactor(0.55)
            Text(store.pattern.name).font(.subheadline.weight(.medium)).lineLimit(2)
            Text(store.patternDirty ? "● UNSAVED DRAFT" : "✓ SAVED").font(
              .system(.caption2, design: .monospaced).weight(.bold)
            ).foregroundStyle(store.patternDirty ? Color.signal : Color.moss)
              .lineLimit(1).minimumScaleFactor(0.7)
          }
          Spacer()
          Menu {
            Button("Settings and Help", systemImage: "gearshape", action: onSettings)
            Button("New Pattern", systemImage: "plus") { store.newPattern() }
            Button("Copy Pattern", systemImage: "doc.on.doc") {
              store.duplicatePattern(store.pattern)
            }
            Button("Redo", systemImage: "arrow.uturn.forward") { store.redo() }.disabled(
              !store.canRedo)
            Button("Clear Track", role: .destructive) { clearScope = "track" }
            Button("Clear Pattern", role: .destructive) { clearScope = "pattern" }
            Button("Clear All Pattern Locks") { store.editPattern { $0.clearLocks() } }
          } label: {
            Image(systemName: "ellipsis.circle").font(.title2).frame(width: 44, height: 44)
          }.accessibilityLabel("Pattern actions")
          Button("Save") {
            name = store.pattern.name
            saveName = true
          }.fontWeight(.bold).frame(minHeight: 44).disabled(store.saving).accessibilityIdentifier(
            "savePattern")
        }
        display
        if store.kit?.developmentFixture == true {
          Label(
            "Synthetic development fixtures",
            systemImage: "waveform.badge.magnifyingglass"
          ).font(.caption2).foregroundStyle(Color.ink.opacity(0.75))
        }
        instrumentSelector
        HStack(spacing: 4) {
          Button {
            store.padsMode = false
          } label: {
            Text("Steps").font(.subheadline.weight(.semibold)).frame(
              maxWidth: .infinity, minHeight: 44
            ).background(
              !store.padsMode ? Color.ink : Color.clear, in: RoundedRectangle(cornerRadius: 10))
          }.buttonStyle(.plain).foregroundStyle(!store.padsMode ? Color.casing : Color.ink)
            .accessibilityAddTraits(!store.padsMode ? .isSelected : [])
          Button {
            store.padsMode = true
          } label: {
            Text("Play Pads").font(.subheadline.weight(.semibold)).frame(
              maxWidth: .infinity, minHeight: 44
            ).background(
              store.padsMode ? Color.ink : Color.clear, in: RoundedRectangle(cornerRadius: 10))
          }.buttonStyle(.plain).foregroundStyle(store.padsMode ? Color.casing : Color.ink)
            .accessibilityAddTraits(store.padsMode ? .isSelected : [])
        }.padding(3).background(Color.walnut.opacity(0.10), in: RoundedRectangle(cornerRadius: 13))
          .overlay { RoundedRectangle(cornerRadius: 13).strokeBorder(Color.brass.opacity(0.3)) }

        if store.padsMode {
          HStack {
            if store.pattern.tracks.count > 8 {
              Button {
                padPage = 0
              } label: {
                Image(systemName: "chevron.left").frame(width: 44, height: 44)
              }.disabled(padPage == 0).accessibilityLabel("Previous pad page")
              Text("\(padPage+1) / 2").font(.caption)
              Button {
                padPage = 1
              } label: {
                Image(systemName: "chevron.right").frame(width: 44, height: 44)
              }.disabled(padPage == 1).accessibilityLabel("Next pad page")
            } else {
              Text("PLAY ON TOUCH").font(.system(.caption, design: .monospaced))
            }
            Spacer()
            Toggle("Accent", isOn: $store.accent).fixedSize()
          }
          TouchPads(
            labels: Array(store.pattern.tracks.dropFirst(padPage * 8).prefix(8)).map { track in
              store.kit?.instruments.first { $0.id == track.id }?.name ?? track.id
            }
          ) { index, time in store.tap(padPage * 8 + index, timestamp: time) }.frame(
            height: CGFloat((min(8, store.pattern.tracks.count - padPage * 8) + 1) / 2) * (dynamicTypeSize.isAccessibilitySize ? 72 : 54))
          Text(
            store.recordArmed
              ? "Record armed · taps overdub after the four-count"
              : "Arm Record to capture pads into this pattern."
          ).font(.caption).foregroundStyle(Color.ink.opacity(0.7))
        } else {
          stepGrid
        }
        HStack {
          Text("16 STEPS / 4 BEATS").font(.system(.caption2, design: .monospaced))
          Spacer()
          Button("Step \(store.selectedStep+1) Details", systemImage: "slider.horizontal.3") {
            details = true
          }.font(.caption.weight(.bold)).frame(minHeight: 44)
        }
        Panel {
          ValueControl(
            title: "Tempo",
            value: Binding(
              get: { Double(store.pattern.bpm) },
              set: { v in store.editPattern { $0.bpm = Int(v) } }), range: 40...240, suffix: " BPM",
            editing: gesture
          ).disabled(audio.running && (audio.status.state == 1 || audio.chainMode))
          ValueControl(
            title: "Swing",
            value: Binding(
              get: { store.pattern.swing * 100 },
              set: { v in store.editPattern { $0.swing = v / 100 } }), range: 50...75, suffix: "%",
            editing: gesture
          ).disabled(audio.running && audio.chainMode)
          if audio.status.pending != 0 {
            Text("Tempo / swing pending · next bar").font(.caption.weight(.bold)).foregroundStyle(
              Color.signal)
          }
        }
        Text("A little machine. A big pocket.").font(.system(.subheadline, design: .serif).italic())
          .foregroundStyle(Color.ink.opacity(0.45)).padding(.bottom, 8)
      }.padding(14)
    }.scrollIndicators(.hidden)
      .scrollDisabled(velocityEdit != nil)
      .onDisappear { finishVelocity() }
      .onChange(of: scenePhase) { _, phase in if phase != .active { finishVelocity() } }
      .onChange(of: store.selectedTrack) { _, _ in finishVelocity() }
      .onChange(of: store.pattern.id) { _, _ in finishVelocity() }
      .onChange(of: store.pattern.kitID) { _, _ in padPage = 0 }.background { InstrumentBackground() }
      .foregroundStyle(Color.ink).navigationBarTitleDisplayMode(.inline)
      .toolbar(.hidden, for: .navigationBar)
      .safeAreaInset(edge: .bottom, spacing: 0) {
        TransportView(store: store, audio: audio, chain: false)
      }
      .sheet(isPresented: $details) { StepDetailView(store: store) }
      .alert("Save Pattern", isPresented: $saveName) {
        TextField("Pattern name", text: $name)
        Button("Save") {
          guard validName(name) else {
            store.message = "Use a name with 1–64 visible characters."
            return
          }
          store.editPattern { $0.name = name }
          Task { await store.save(isChain: false) }
        }
        Button("Cancel", role: .cancel) {}
      } message: {
        Text("Saved patterns become available to every chain.")
      }
      .confirmationDialog(
        "Clear \(clearScope ?? "")? This can be undone.",
        isPresented: Binding(get: { clearScope != nil }, set: { if !$0 { clearScope = nil } }),
        titleVisibility: .visible
      ) {
        Button("Clear Notes and Locks", role: .destructive) {
          let scope = clearScope
          store.editPattern { p in
            if scope == "track" {
              if p.tracks.indices.contains(store.selectedTrack) {
                p.tracks[store.selectedTrack].steps = Array(repeating: Step(), count: 16)
              }
            } else {
              for t in p.tracks.indices { p.tracks[t].steps = Array(repeating: Step(), count: 16) }
            }
          }
          clearScope = nil
        }
        Button("Cancel", role: .cancel) { clearScope = nil }
      }
  }
  func gesture(_ active: Bool) { if active { store.beginGesture() } else { store.endGesture() } }
  private func instrumentName(_ track: Track) -> String {
    store.kit?.instruments.first { $0.id == track.id }?.name ?? track.id
  }
  private func instrumentStatus(_ track: Track) -> String {
    let state = store.performance[store.pattern.kitID + "/" + track.id] ?? Performance()
    return [state.muted ? "Muted" : nil, state.solo ? "Solo" : nil].compactMap { $0 }.joined(separator: " · ")
  }
  var instrumentSelector: some View {
    HStack(spacing: 0) {
      Button { instrumentMenu.toggle() } label: {
        HStack(spacing: 10) {
          VStack(alignment: .leading, spacing: 2) {
            Text("INSTRUMENT").font(.system(size: 10, weight: .semibold, design: .monospaced))
              .tracking(1.5).foregroundStyle(Color.ink.opacity(0.65))
            if let track = store.track {
              Text(instrumentName(track)).font(.headline).lineLimit(2)
              if !instrumentStatus(track).isEmpty {
                Text(instrumentStatus(track)).font(.caption).foregroundStyle(Color.signal)
              }
            }
          }
          Spacer(minLength: 4)
          Image(systemName: "chevron.up.chevron.down").font(.system(size: 16, weight: .semibold))
        }.padding(.horizontal, 14).padding(.vertical, 9).frame(maxWidth: .infinity, minHeight: 52)
          .contentShape(Rectangle())
      }.buttonStyle(.plain).accessibilityIdentifier("instrumentSelector")
        .accessibilityLabel("Instrument")
        .accessibilityValue(store.track.map { [instrumentName($0), instrumentStatus($0)].filter { !$0.isEmpty }.joined(separator: ", ") } ?? "Unavailable")
        .accessibilityHint("Choose any drum in the kit.")
        .popover(isPresented: $instrumentMenu, arrowEdge: .top) {
          ScrollView {
            VStack(spacing: 0) {
              ForEach(Array(store.pattern.tracks.enumerated()), id: \.element.id) { index, track in
                Button {
                  finishVelocity()
                  store.selectedTrack = index
                  padPage = index / 8
                  instrumentMenu = false
                } label: {
                  HStack {
                    VStack(alignment: .leading) {
                      Text(instrumentName(track)).font(.body.weight(.medium))
                      if !instrumentStatus(track).isEmpty {
                        Text(instrumentStatus(track)).font(.caption)
                      }
                    }
                    Spacer()
                    if store.selectedTrack == index { Image(systemName: "checkmark") }
                  }.padding(.horizontal, 18).frame(minHeight: 44).contentShape(Rectangle())
                }.buttonStyle(.plain).accessibilityIdentifier("instrument-option-\(track.id)")
                if index < store.pattern.tracks.count - 1 { Divider().padding(.horizontal, 18) }
              }
            }.padding(.vertical, 8)
          }.frame(minWidth: 240, idealWidth: 280, maxHeight: 440)
            .foregroundStyle(Color.ink).background(Color.casing)
            .presentationCompactAdaptation(.popover)
        }
      Rectangle().fill(Color.brass.opacity(0.3)).frame(width: 1, height: 30).accessibilityHidden(true)
      Button {
        if let track = store.track { audio.audition(pattern: store.pattern, track: track, level: 100) }
      } label: {
        Image(systemName: "speaker.wave.2").font(.system(size: 20)).frame(width: 52, height: 52)
      }.buttonStyle(.plain).accessibilityLabel("Audition selected instrument")
        .disabled(audio.running && audio.chainMode)
    }.instrumentGlass()
  }
  var display: some View {
    VStack(alignment: .leading, spacing: 4) {
      HStack {
        Menu {
          ForEach(store.catalog.items) { item in Button(item.kit.name) { store.selectKit(item.kit) } }
        } label: {
          HStack(spacing: 5) {
            Image(systemName: "square.stack.3d.up")
            Text(store.kit?.name ?? "Kit unavailable").lineLimit(1).minimumScaleFactor(0.7)
            Image(systemName: "chevron.down").font(.caption2)
          }.font(.caption.weight(.semibold)).frame(minHeight: 40)
        }.disabled(audio.running || audio.preparing)
          .accessibilityLabel(store.kit?.name ?? "Kit unavailable")
        Spacer(minLength: 4)
        HStack(spacing: 5) {
          Circle().fill(audio.running ? Color.amber : Color.brass).frame(width: 5, height: 5)
            .accessibilityHidden(true)
          Text(audio.preparing ? "PREPARING" : audio.running
            ? audio.visualStatus.state == 1 ? "COUNT \(max(1,audio.visualStatus.count)) / 4"
              : "BEAT \(audio.visualStatus.step/4+1)" : "READY / 4:4")
            .font(.system(.caption2, design: .monospaced).weight(.medium))
            .lineLimit(1).minimumScaleFactor(0.7)
        }
      }.foregroundStyle(Color.casing)
      HStack(alignment: .center, spacing: 8) {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
          Text(String(store.pattern.bpm)).font(.system(size: 38, weight: .light, design: .monospaced))
            .shadow(color: Color.amber.opacity(0.25), radius: 5)
          Text("BPM").font(.system(.caption2, design: .monospaced))
        }.foregroundStyle(Color.amber)
        Spacer(minLength: 0)
        HStack(spacing: 3) {
          ForEach(0..<16, id: \.self) { index in
            RoundedRectangle(cornerRadius: 1).fill(
              audio.running && audio.visualStatus.state == 2 && Int(audio.visualStatus.step) == index
                ? Color.amber : Color.amber.opacity(index % 4 == 0 ? 0.35 : 0.12)
            ).frame(height: index % 4 == 0 ? 14 : 9)
          }
        }.frame(maxWidth: 150).accessibilityHidden(true)
      }
    }.dynamicTypeSize(...DynamicTypeSize.xxxLarge)
      .padding(.horizontal, 16).padding(.bottom, 12).padding(.top, 3)
      .background(LinearGradient(colors: [Color(red: 0.22, green: 0.22, blue: 0.18),
        Color(red: 0.10, green: 0.11, blue: 0.09)], startPoint: .topLeading, endPoint: .bottomTrailing),
        in: RoundedRectangle(cornerRadius: 13))
      .overlay { RoundedRectangle(cornerRadius: 13).strokeBorder(Color.brass.opacity(0.8), lineWidth: 1.5) }
      .overlay(alignment: .topLeading) { ScrewHead().padding(5) }
      .overlay(alignment: .bottomTrailing) { ScrewHead().padding(5) }
      .shadow(color: Color.walnut.opacity(0.25), radius: 2, y: 3)
  }

  var stepGrid: some View {
    VStack(spacing: 10) {
      ForEach(0..<4, id: \.self) { row in
        HStack(spacing: 8) {
          Text("\(row+1)").font(.system(.caption2, design: .monospaced)).foregroundStyle(
            Color.ink.opacity(0.5)
          ).frame(width: 10).accessibilityLabel("Beat \(row+1)")
          ForEach(0..<4, id: \.self) { col in stepButton(row * 4 + col) }
        }
      }
    }.padding(8)
      .background(Color.walnut.opacity(0.12), in: RoundedRectangle(cornerRadius: 15))
      .overlay { RoundedRectangle(cornerRadius: 15).strokeBorder(Color.walnut.opacity(0.25)) }
      .overlay {
        GeometryReader { geometry in
          if let edit = velocityEdit {
            VelocityFader(name: edit.name, step: edit.step + 1, level: edit.level)
              .frame(width: 94, height: 224)
              .position(x: edit.step % 4 < 2 ? geometry.size.width - 56 : 56,
                y: geometry.size.height / 2)
              .allowsHitTesting(false)
          }
        }
      }
  }
  func stepButton(_ index: Int) -> some View {
    let step = store.track?.steps[index] ?? Step()
    let playing = audio.running && !audio.chainMode && audio.visualStatus.state == 2
      && Int(audio.visualStatus.step) == index
    return VStack(alignment: .leading, spacing: 2) {
      HStack {
        Text(String(format: "%02d", index + 1)).font(.system(.headline, design: .monospaced))
        Spacer(minLength: 0)
        if step.enabled { Circle().fill(Color.casing).frame(width: 7, height: 7) }
      }
      HStack(spacing: 3) {
        if step.pitchLock != nil || step.decayLock != nil { Image(systemName: "lock.fill") }
        if step.retriggerCount > 1 { Text("×\(step.retriggerCount)") }
        Spacer()
        if playing { Image(systemName: "play.fill") }
      }.font(.system(size: 10, weight: .bold)).frame(height: 10)
      GeometryReader { proxy in
        Capsule().fill(step.enabled ? Color.casing.opacity(0.85) : Color.ink.opacity(0.12))
          .frame(width: proxy.size.width * (step.enabled ? CGFloat(step.level) / 127 : 1))
      }.frame(height: 2)
    }.padding(9).frame(maxWidth: .infinity, minHeight: 50)
      .foregroundStyle(step.enabled ? Color.white : Color.ink)
      .background { KeycapSurface(enabled: step.enabled, playing: playing,
        selected: store.selectedStep == index) }
      .accessibilityHidden(true)
      .overlay {
        StepTouchSurface(
          label: "\(store.track?.id ?? "Instrument"), step \(index+1), \(step.enabled ? "enabled":"disabled"), level \(step.level), \(step.retriggerCount) hits\(playing ? ", playing":"")",
          identifier: "step-\(index+1)",
          tap: {
            store.selectedStep = index
            store.editPattern { p in
              if p.tracks.indices.contains(store.selectedTrack) {
                p.tracks[store.selectedTrack].steps[index].enabled.toggle()
              }
            }
          },
          hold: { beginVelocity(index) },
          drag: { distance in updateVelocity(distance) },
          release: { finishVelocity() },
          adjust: { delta in
            guard step.enabled else { return }
            store.selectedStep = index
            store.editPattern { p in
              p.tracks[store.selectedTrack].steps[index].level = min(127, max(1, step.level + delta))
            }
          })
      }
  }
  private func beginVelocity(_ index: Int) {
    finishVelocity()
    store.selectedStep = index
    guard let track = store.track else { return }
    guard track.steps[index].enabled else { details = true; return }
    store.beginGesture()
    velocityEdit = VelocityEdit(patternID: store.pattern.id, trackID: track.id,
      step: index, name: instrumentName(track), startLevel: track.steps[index].level,
      level: track.steps[index].level)
  }
  private func updateVelocity(_ distance: CGFloat) {
    guard var edit = velocityEdit, edit.patternID == store.pattern.id,
      let trackIndex = store.pattern.tracks.firstIndex(where: { $0.id == edit.trackID }),
      store.pattern.tracks[trackIndex].steps[edit.step].enabled else { finishVelocity(); return }
    let level = min(127, max(1, edit.startLevel - Int((distance * 126 / 160).rounded())))
    guard level != edit.level else { return }
    edit.level = level
    velocityEdit = edit
    store.editPattern { $0.tracks[trackIndex].steps[edit.step].level = level }
  }
  private func finishVelocity() {
    guard velocityEdit != nil else { return }
    velocityEdit = nil
    store.endGesture()
  }
}

private struct VelocityEdit {
  let patternID: UUID
  let trackID: String
  let step: Int
  let name: String
  let startLevel: Int
  var level: Int
}
