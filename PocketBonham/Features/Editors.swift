import BonhamCore
import SwiftUI

struct StepDetailView: View {
  @ObservedObject var store: AppStore
  @Environment(\.dismiss) private var dismiss
  var step: Step { store.track?.steps[store.selectedStep] ?? Step() }
  func change(_ body: (inout Step) -> Void) {
    store.editPattern { p in
      guard p.tracks.indices.contains(store.selectedTrack) else { return }
      body(&p.tracks[store.selectedTrack].steps[store.selectedStep])
    }
  }
  func gesture(_ active: Bool) { if active { store.beginGesture() } else { store.endGesture() } }
  var body: some View {
    NavigationStack {
      Form {
        Section {
          Stepper("Step \(store.selectedStep+1)", value: $store.selectedStep, in: 0...15)
          Toggle(
            "Enabled", isOn: Binding(get: { step.enabled }, set: { v in change { $0.enabled = v } })
          )
          ValueControl(
            title: "Hit Level",
            value: Binding(get: { Double(step.level) }, set: { v in change { $0.level = Int(v) } }),
            range: 1...127, editing: gesture)
          Picker(
            "Retriggers",
            selection: Binding(
              get: { step.retriggerCount }, set: { v in change { $0.retriggerCount = v } })
          ) { ForEach([1, 2, 4, 8, 16], id: \.self) { Text("\($0) hits").tag($0) } }
        } header: {
          Text(store.track?.id ?? "Instrument")
        }
        Section("Parameter Locks") {
          Toggle(
            "Override Pitch",
            isOn: Binding(
              get: { step.pitchLock != nil },
              set: { v in change { $0.pitchLock = v ? store.track?.basePitchSemitones ?? 0 : nil } }
            ))
          if step.pitchLock != nil {
            ValueControl(
              title: "Pitch Lock",
              value: Binding(
                get: { step.pitchLock ?? 0 }, set: { v in change { $0.pitchLock = v } }),
              range: -12...12, step: 0.1, suffix: " st", editing: gesture)
          }
          Toggle(
            "Override Decay",
            isOn: Binding(
              get: { step.decayLock != nil },
              set: { v in change { $0.decayLock = v ? store.track?.baseDecay ?? 1 : nil } }))
          if step.decayLock != nil {
            ValueControl(
              title: "Decay Lock",
              value: Binding(
                get: { step.decayLock ?? 1 }, set: { v in change { $0.decayLock = v } }),
              range: 0.05...1, step: 0.01, editing: gesture)
          }
          Text(
            "Locks apply only to this step and its retriggers. Disabling a step keeps its settings."
          ).font(.caption)
        }
        Section {
          Button("Reset Step", role: .destructive) { change { $0 = Step() } }
          Button("Clear Locks on This Track") {
            store.editPattern { p in
              guard p.tracks.indices.contains(store.selectedTrack) else { return }
              for s in 0..<16 {
                p.tracks[store.selectedTrack].steps[s].pitchLock = nil
                p.tracks[store.selectedTrack].steps[s].decayLock = nil
              }
            }
          }
        }
      }.navigationTitle("Step Details").toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Done") {
            store.endGesture()
            dismiss()
          }
        }
      }
    }.tint(.signal).onDisappear { store.endGesture() }
  }
}
struct MixerView: View {
  @ObservedObject var store: AppStore
  @ObservedObject var audio: AudioHost
  @Environment(\.dismiss) private var dismiss
  var pattern: Pattern { store.activePattern }
  var body: some View {
    NavigationStack {
      Form {
        Section {
          ForEach(pattern.tracks) { track in
            let key = pattern.kitID + "/" + track.id
            let p = store.performance[key] ?? Performance()
            HStack {
              Button {
                if let index = store.pattern.tracks.firstIndex(where: { $0.id == track.id }) {
                  store.endGesture()
                  store.selectedTrack = index
                }
              } label: {
                Text(
                  store.catalog.items.first { $0.id == pattern.kitID }?.kit.instruments.first {
                    $0.id == track.id
                  }?.name ?? track.id
                ).fontWeight(store.track?.id == track.id ? .bold : .regular).frame(
                  maxWidth: .infinity, minHeight: 44, alignment: .leading)
              }.buttonStyle(.plain)
              Button(p.muted ? "Muted" : "Mute") {
                store.togglePerformance(kitID: pattern.kitID, instrumentID: track.id, solo: false)
              }.buttonStyle(.bordered).tint(p.muted ? .signal : .gray).frame(minHeight: 44)
                .accessibilityLabel("\(track.id), \(p.muted ? "unmute":"mute")")
              Button(p.solo ? "Solo ✓" : "Solo") {
                store.togglePerformance(kitID: pattern.kitID, instrumentID: track.id, solo: true)
              }.buttonStyle(.bordered).tint(p.solo ? .moss : .gray).frame(minHeight: 44)
                .accessibilityLabel("\(track.id), \(p.solo ? "unsolo":"solo")")
            }
          }
          Button("Clear Mutes / Solos") { store.clearPerformance() }
        } header: {
          Text(
            "\(store.catalog.items.first {$0.id==pattern.kitID}?.kit.name ?? pattern.kitID) · performance"
          )
        }
        if !(audio.running && audio.chainMode), let track = store.track {
          Section("\(track.id) · Base Sound") {
            Toggle("Record Motion", isOn: $store.recordMotion).onChange(of: store.recordMotion) {
              _, _ in
              store.endGesture()
              store.lastMotionStep = -1
            }
            Text(
              store.recordMotion
                ? "While playing, drag pitch or decay to write locks on existing hits. Each gesture can be undone."
                : "Existing step locks take priority over these base controls."
            ).font(.caption)
            ValueControl(
              title: "Level", value: trackBinding("level"), range: 0...1, step: 0.01,
              editing: gesture)
            ValueControl(
              title: "Pitch", value: trackBinding("pitch"), range: -12...12, step: 0.1,
              suffix: " st", editing: gesture)
            ValueControl(
              title: "Decay", value: trackBinding("decay"), range: 0.05...1, step: 0.01,
              editing: gesture)
            Button("Clear Track Locks") {
              store.editPattern { p in
                for s in 0..<16 {
                  p.tracks[store.selectedTrack].steps[s].pitchLock = nil
                  p.tracks[store.selectedTrack].steps[s].decayLock = nil
                }
              }
            }
          }
          Section("Drum Room") {
            Toggle(
              "Room On",
              isOn: Binding(
                get: { store.pattern.room.enabled },
                set: { v in
                  store.editPattern {
                    $0.room.enabled = v
                    if v && $0.room.amount == 0 { $0.room.amount = 0.15 }
                  }
                }))
            ValueControl(
              title: "Amount",
              value: Binding(
                get: { store.pattern.room.amount * 100 },
                set: { v in store.editPattern { $0.room.amount = v / 100 } }), range: 0...30,
              suffix: "%", editing: gesture
            ).disabled(!store.pattern.room.enabled)
          }
        } else {
          Text(
            "Chain sound settings come from saved patterns. Performance mutes and solos remain live."
          ).font(.caption)
        }
      }.navigationTitle("Mixer").toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Done") {
            store.endGesture()
            dismiss()
          }
        }
      }
    }.tint(.signal).onDisappear { store.endGesture() }
  }
  func gesture(_ active: Bool) {
    if active {
      store.beginGesture()
      store.lastMotionStep = -1
    } else {
      store.endGesture()
    }
  }
  func trackBinding(_ field: String) -> Binding<Double> {
    Binding(
      get: {
        if store.motionParameter == field { return store.motionValue }
        guard let t = store.track else { return 0 }
        return field == "pitch"
          ? t.basePitchSemitones : field == "decay" ? t.baseDecay : t.baseLevel
      }, set: { store.setTrackValue(field, value: $0) })
  }
}
struct SettingsView: View {
  @ObservedObject var store: AppStore
  @ObservedObject var audio: AudioHost
  @Environment(\.dismiss) private var dismiss
  var body: some View {
    NavigationStack {
      Form {
        Section("Listening") {
          ValueControl(
            title: "Master",
            value: Binding(
              get: { audio.preferences.masterLevel },
              set: {
                audio.preferences.masterLevel = $0
                audio.applyPreferences()
              }), range: 0...1, step: 0.01)
          ValueControl(
            title: "Click",
            value: Binding(
              get: { audio.preferences.clickLevel },
              set: {
                audio.preferences.clickLevel = $0
                audio.applyPreferences()
              }), range: 0.01...1, step: 0.01)
          Toggle(
            "Metronome After Count-in",
            isOn: Binding(
              get: { audio.preferences.metronomeEnabled },
              set: {
                audio.preferences.metronomeEnabled = $0
                audio.applyPreferences()
              }))
          Text(
            "Every Play starts with four clicks. The metronome setting affects only the music that follows."
          ).font(.caption)
        }
        Section("Audio Status") {
          LabeledContent("Route", value: audio.route)
          LabeledContent("Sample rate", value: "\(Int(audio.rig?.rate ?? 0)) Hz")
          LabeledContent(
            "I/O buffer", value: String(format: "%.2f ms", audio.bufferDuration * 1000))
          LabeledContent(
            "Reported output latency", value: String(format: "%.2f ms", audio.latency * 1000))
          LabeledContent(
            "Decoded samples",
            value: String(format: "%.1f / 192 MiB", Double(audio.decodedBytes) / 1_048_576))
          LabeledContent("Active voices", value: "\(audio.status.voices) / 64")
          LabeledContent("Voice steals", value: "\(audio.status.stolenVoices)")
          Text(
            "Bluetooth may add substantial pad response delay. Reported route latency is not a measured touch-to-sound result."
          ).font(.caption)
        }
        Section("Quick Guide") {
          Text(
            "1. Select a drum and tap any of the 16 steps. Tap Audition to hear the selected drum. Long-press a step, or use Details, for level, rolls and locks."
          )
          Text(
            "2. Play counts four beats, then loops. Tempo and swing edits wait for the next bar. Stop resets the transport and disarms Record."
          )
          Text(
            "3. Select Play Pads, arm Record, and play. Taps overdub to the nearest swung step; each bar is one Undo. An existing programmed hit may still sound alongside a live tap. A newly recorded hit waits until its following pass."
          )
          Text(
            "4. Save by name. Saved patterns and chains are separate from recovery drafts. Chains always use saved patterns and resolve a fresh snapshot at Play."
          )
          Text(
            "5. Add patterns in Chains, reorder them, set repeats or override individual tempos. Arrangement edits take effect on the next Play."
          )
          Text(
            "Mutes and solos are temporary. Mute wins over Solo; multiple solos are allowed. They suppress pads as well as programmed notes. Shared room tails may finish ringing."
          )
          Text(
            "Leaving the app stops sound. Returning never restarts playback. The screen remains awake while the app is active."
          )
        }.font(.subheadline)
        Section("Recovery and Assets") {
          ForEach(store.catalog.items) { item in
            LabeledContent(
              item.kit.name,
              value: "\(item.kit.instruments.count) drums · v\(item.kit.assetVersion)")
          }
          if store.catalog.items.contains(where: { $0.kit.developmentFixture == true }) {
            Text(
              "Development Sounds contains synthetic test samples. Owner kits are listed separately above."
            ).foregroundStyle(Color.signal)
          }
          ForEach(store.library.issues + store.catalog.issues, id: \.self) {
            Text($0).font(.caption)
          }
          Button("Restore Damaged Items from Backups") {
            Task {
              let results = await store.repository.restoreBackups()
              await store.refresh()
              store.message =
                results.isEmpty
                ? "No damaged item with a valid backup was found." : results.joined(separator: "\n")
            }
          }
        }
      }.navigationTitle("Settings & Help").toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Done") {
            Task { await store.flush() }
            dismiss()
          }
        }
      }
    }.tint(.signal).onDisappear { Task { await store.flush() } }
  }
}
