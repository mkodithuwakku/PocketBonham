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
  @State private var longPressedStep: Int?
  @State private var padPage = 0
  @State private var saveName = false
  @State private var name = ""
  @State private var clearScope: String?
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 10) {
        HStack(alignment: .top) {
          VStack(alignment: .leading, spacing: 4) {
            Text("POCKET / BONHAM").font(.system(.caption, design: .monospaced).weight(.bold))
              .tracking(2)
            Text(store.pattern.name).font(.headline).lineLimit(2)
            Text(store.patternDirty ? "● UNSAVED DRAFT" : "✓ SAVED").font(
              .system(.caption2, design: .monospaced).weight(.bold)
            ).foregroundStyle(store.patternDirty ? Color.signal : Color.moss)
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
        ScrollView(.horizontal, showsIndicators: false) {
          HStack(spacing: 8) {
            Button {
              if let t = store.track {
                audio.audition(pattern: store.pattern, track: t, level: 100)
              }
            } label: {
              Image(systemName: "speaker.wave.2").frame(width: 44, height: 48)
            }
            .accessibilityLabel("Audition selected instrument").disabled(
              audio.running && audio.chainMode)
            ForEach(Array(store.pattern.tracks.enumerated()), id: \.element.id) { index, track in
              let state = store.performance[store.pattern.kitID + "/" + track.id] ?? Performance()
              Button {
                store.endGesture()
                store.selectedTrack = index
              } label: {
                VStack(spacing: 3) {
                  Text(store.kit?.instruments.first { $0.id == track.id }?.name ?? track.id).font(
                    .subheadline.weight(.bold))
                  if state.muted || state.solo {
                    Text((state.muted ? "Muted " : "") + (state.solo ? "Solo" : "")).font(.caption2)
                  }
                }.padding(.horizontal, 14).frame(minHeight: 48).background(
                  store.selectedTrack == index ? Color.ink : Color.white.opacity(0.6),
                  in: RoundedRectangle(cornerRadius: 12)
                ).foregroundStyle(store.selectedTrack == index ? Color.casing : Color.ink)
              }.accessibilityLabel(
                "\(track.id)\(store.selectedTrack==index ? ", selected":"")\(state.muted ? ", muted":"")\(state.solo ? ", solo":"")"
              )
            }
          }
        }
        HStack(spacing: 4) {
          Button {
            store.padsMode = false
          } label: {
            Text("Steps").font(.subheadline.weight(.semibold)).frame(
              maxWidth: .infinity, minHeight: 44
            ).background(
              !store.padsMode ? Color.white : Color.clear, in: RoundedRectangle(cornerRadius: 10))
          }.buttonStyle(.plain).accessibilityAddTraits(!store.padsMode ? .isSelected : [])
          Button {
            store.padsMode = true
          } label: {
            Text("Play Pads").font(.subheadline.weight(.semibold)).frame(
              maxWidth: .infinity, minHeight: 44
            ).background(
              store.padsMode ? Color.white : Color.clear, in: RoundedRectangle(cornerRadius: 10))
          }.buttonStyle(.plain).accessibilityAddTraits(store.padsMode ? .isSelected : [])
        }.padding(3).background(Color.ink.opacity(0.08), in: RoundedRectangle(cornerRadius: 13))

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
            height: CGFloat((min(8, store.pattern.tracks.count - padPage * 8) + 1) / 2) * 64)
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
        Text("A little machine. A big pocket.").font(.system(.caption, design: .monospaced))
          .foregroundStyle(Color.ink.opacity(0.45)).padding(.bottom, 8)
      }.padding(14)
    }.onChange(of: store.pattern.kitID) { _, _ in padPage = 0 }.background(Color.casing)
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
  var display: some View {
    VStack(alignment: .leading, spacing: 4) {
      HStack {
        Menu {
          ForEach(store.catalog.items) { item in Button(item.kit.name) { store.selectKit(item.kit) }
          }
        } label: {
          Label(store.kit?.name ?? "Kit unavailable", systemImage: "square.stack.3d.up").font(
            .caption.weight(.semibold)
          ).frame(minHeight: 44)
        }.disabled(audio.running || audio.preparing)
        Spacer()
        Text(
          audio.preparing
            ? "PREPARING"
            : audio.running
              ? audio.visualStatus.state == 1
                ? "COUNT \(max(1,audio.visualStatus.count)) / 4"
                : "BEAT \(audio.visualStatus.step/4+1)" : "READY / 4:4"
        ).font(.system(.caption, design: .monospaced).weight(.bold))
      }
      HStack(alignment: .firstTextBaseline) {
        Text(String(store.pattern.bpm)).font(
          .system(size: 36, weight: .medium, design: .monospaced))
        Text("BPM").font(.system(.caption2, design: .monospaced))
        Spacer()
        HStack(spacing: 3) {
          ForEach(0..<16, id: \.self) { index in
            RoundedRectangle(cornerRadius: 2).fill(
              audio.running && audio.visualStatus.state == 2
                && Int(audio.visualStatus.step) == index
                ? Color.orange : Color.casing.opacity(index % 4 == 0 ? 0.5 : 0.2)
            ).frame(height: 8)
          }
        }.frame(maxWidth: 160).accessibilityHidden(true)
      }
    }.padding(.horizontal, 14).padding(.bottom, 12).foregroundStyle(Color.casing).background(
      Color.ink, in: RoundedRectangle(cornerRadius: 16))
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
    }
  }
  func stepButton(_ index: Int) -> some View {
    let step = store.track?.steps[index] ?? Step()
    let playing =
      audio.running && !audio.chainMode && audio.visualStatus.state == 2
      && Int(audio.visualStatus.step) == index
    return Button {
      if longPressedStep == index {
        longPressedStep = nil
        return
      }
      store.selectedStep = index
      store.editPattern { p in
        if p.tracks.indices.contains(store.selectedTrack) {
          p.tracks[store.selectedTrack].steps[index].enabled.toggle()
        }
      }
    } label: {
      VStack(alignment: .leading, spacing: 2) {
        HStack {
          Text(String(format: "%02d", index + 1)).font(.system(.headline, design: .monospaced))
          Spacer()
          if step.enabled { Circle().fill(Color.casing).frame(width: 7, height: 7) }
        }
        HStack(spacing: 3) {
          if step.pitchLock != nil || step.decayLock != nil { Image(systemName: "lock.fill") }
          if step.retriggerCount > 1 { Text("×\(step.retriggerCount)") }
          Spacer()
          if playing { Image(systemName: "play.fill") }
        }.font(.system(size: 10, weight: .bold)).frame(height: 12)
      }.padding(8).frame(maxWidth: .infinity, minHeight: 50).background(
        step.enabled ? Color.signal : Color.white.opacity(0.65),
        in: RoundedRectangle(cornerRadius: 12)
      ).foregroundStyle(step.enabled ? Color.white : Color.ink).overlay(
        RoundedRectangle(cornerRadius: 12).stroke(
          playing ? Color.ink : store.selectedStep == index ? Color.ink.opacity(0.35) : .clear,
          lineWidth: playing ? 3 : 1))
    }.buttonStyle(.plain).accessibilityLabel(
      "\(store.track?.id ?? "Instrument"), step \(index+1), \(step.enabled ? "enabled":"disabled"), level \(step.level), \(step.retriggerCount) hits\(playing ? ", playing":"")"
    ).accessibilityIdentifier("step-\(index+1)").simultaneousGesture(
      LongPressGesture(minimumDuration: 0.5).onEnded { _ in
        longPressedStep = index
        store.selectedStep = index
        details = true
      }
    ).onChange(of: details) { _, open in if !open { longPressedStep = nil } }
  }
}
