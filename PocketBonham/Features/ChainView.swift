import BonhamCore
import SwiftUI

struct ChainView: View {
  @ObservedObject var store: AppStore
  @ObservedObject var audio: AudioHost
  @State private var add = false
  @State private var saveName = false
  @State private var name = ""
  @State private var allTempo = false
  @State private var tempo = "120"
  @State private var query = ""
  var resolved: [ResolvedEntry] {
    (try? store.chain.resolve(patterns: store.library.patterns)) ?? []
  }
  var body: some View {
    List {
      Section {
        HStack {
          VStack(alignment: .leading, spacing: 5) {
            Text(store.chain.name).font(.title2.bold())
            Text(store.chainDirty ? "● UNSAVED DRAFT" : "✓ SAVED").font(
              .system(.caption2, design: .monospaced)
            ).foregroundStyle(store.chainDirty ? Color.signal : Color.moss)
          }
          Spacer()
          Button("Save") {
            name = store.chain.name
            saveName = true
          }.frame(minHeight: 44).disabled(store.saving).accessibilityIdentifier("saveChain")
        }
        HStack {
          Text("\(store.chain.entries.reduce(0){$0+$1.repeatCount}) bars")
          Spacer()
          Text(String(format: "%.2f seconds", resolved.reduce(0) { $0 + $1.duration }))
        }.font(.system(.subheadline, design: .monospaced))
        if audio.running && audio.chainMode {
          Text(
            audio.status.state == 1
              ? "Count-in \(max(1,audio.status.count)) / 4"
              : "Entry \(audio.status.entry+1)/\(audio.currentEntries.count) · Repeat \(audio.status.repeat+1) · Beat \(audio.status.step/4+1)"
          ).font(.headline).foregroundStyle(Color.moss)
          Text("Arrangement and saved-pattern changes apply next playback.").font(.caption)
        }
        if !store.chain.entries.isEmpty, let issue = store.chainPlaybackIssue {
          Label(issue, systemImage: "exclamationmark.triangle").font(.caption).foregroundStyle(
            Color.signal)
        }
        Menu {
          Button("Set All Entry Tempos") { allTempo = true }
          Button("Reset All to Pattern BPMs") {
            store.editChain { c in for i in c.entries.indices { c.entries[i].bpmOverride = nil } }
          }
        } label: {
          Label("Tempo Actions", systemImage: "metronome").frame(minHeight: 44)
        }
      }
      Section {
        ForEach(Array(store.chain.entries.enumerated()), id: \.element.id) { index, entry in
          entryCard(index, entry)
        }
        .onMove { indices, destination in
          store.editChain { $0.entries.move(fromOffsets: indices, toOffset: destination) }
        }
        Button {
          query = ""
          add = true
        } label: {
          Label("Add Pattern", systemImage: "plus.circle.fill").frame(minHeight: 44)
        }.disabled(store.chain.entries.count >= 64).accessibilityIdentifier("addPattern")
        if store.chain.entries.isEmpty {
          Text(
            "Choose any saved pattern. Add it more than once, arrange repeats, and give each entry its own tempo."
          ).font(.subheadline).foregroundStyle(.secondary)
        }
      } header: {
        Text("Arrangement · \(store.chain.entries.count) / 64 entries")
      }
    }.scrollContentBackground(.hidden).background(Color.casing).navigationTitle("Chains").toolbar {
      ToolbarItem(placement: .topBarLeading) {
        Menu {
          Button("New Chain") { store.newChain() }
          Button("Copy Chain") { store.duplicateChain(store.chain) }
          Button("Redo") { store.redo() }.disabled(!store.canRedo)
        } label: {
          Image(systemName: "ellipsis.circle").frame(width: 44, height: 44)
        }.accessibilityLabel("Chain actions")
      }
      ToolbarItem(placement: .topBarTrailing) { EditButton() }
    }.safeAreaInset(edge: .bottom, spacing: 0) {
      TransportView(store: store, audio: audio, chain: true)
    }
    .sheet(isPresented: $add) {
      NavigationStack {
        List(
          store.library.patterns.filter {
            query.isEmpty || $0.name.localizedCaseInsensitiveContains(query)
          }
        ) { p in
          Button {
            store.editChain { $0.entries.append(ChainEntry(patternID: p.id)) }
            add = false
          } label: {
            VStack(alignment: .leading) {
              Text(p.name).font(.headline)
              Text(
                "\(p.bpm) BPM · \(store.catalog.items.first {$0.id==p.kitID}?.kit.name ?? p.kitID)"
              ).font(.caption)
            }
          }.frame(minHeight: 44)
        }.overlay {
          if store.library.patterns.isEmpty {
            ContentUnavailableView(
              "Save a pattern first", systemImage: "square.stack",
              description: Text("Chains use your saved pattern library."))
          }
        }.navigationTitle("Add Saved Pattern").searchable(text: $query).toolbar {
          ToolbarItem(placement: .cancellationAction) { Button("Cancel") { add = false } }
        }
      }
    }
    .alert("Save Chain", isPresented: $saveName) {
      TextField("Chain name", text: $name)
      Button("Save") {
        guard validName(name) else {
          store.message = "Use a name with 1–64 visible characters."
          return
        }
        store.editChain { $0.name = name }
        Task { await store.save(isChain: true) }
      }
      Button("Cancel", role: .cancel) {}
    }
    .alert("Set All Current Entry Tempos", isPresented: $allTempo) {
      TextField("BPM (40–240)", text: $tempo).keyboardType(.numberPad)
      Button("Apply") {
        if let bpm = Int(tempo), (40...240).contains(bpm) {
          store.editChain { c in for i in c.entries.indices { c.entries[i].bpmOverride = bpm } }
        } else {
          store.message = "Tempo must be 40–240 BPM."
        }
      }
      Button("Cancel", role: .cancel) {}
    } message: {
      Text("One-time override for existing entries. New entries still inherit their pattern BPM.")
    }
  }
  func entryCard(_ index: Int, _ entry: ChainEntry) -> some View {
    let pattern = store.library.patterns.first { $0.id == entry.patternID }
    let active = audio.running && audio.chainMode && Int(audio.status.entry) == index
    return VStack(alignment: .leading, spacing: 10) {
      HStack {
        Text(String(format: "%02d", index + 1)).font(.system(.title3, design: .monospaced).bold())
          .foregroundStyle(active ? Color.signal : Color.secondary)
        VStack(alignment: .leading) {
          Text(pattern?.name ?? "Missing Pattern").font(.headline)
          Text(store.catalog.items.first { $0.id == pattern?.kitID }?.kit.name ?? "Kit unavailable")
            .font(.caption).foregroundStyle(.secondary)
        }
        Spacer()
        if active { Image(systemName: "play.fill").foregroundStyle(Color.signal) }
      }
      Stepper(
        "Repeat \(entry.repeatCount) \(entry.repeatCount==1 ? "bar":"bars")",
        value: Binding(
          get: { entry.repeatCount },
          set: { v in store.editChain { $0.entries[index].repeatCount = v } }), in: 1...16)
      Toggle(
        "Use Pattern BPM (\(pattern?.bpm ?? 120))",
        isOn: Binding(
          get: { entry.bpmOverride == nil },
          set: { v in
            store.editChain { $0.entries[index].bpmOverride = v ? nil : pattern?.bpm ?? 120 }
          }))
      if entry.bpmOverride != nil {
        ValueControl(
          title: "Play At",
          value: Binding(
            get: { Double(entry.bpmOverride ?? 120) },
            set: { v in store.editChain { $0.entries[index].bpmOverride = Int(v) } }),
          range: 40...240, suffix: " BPM",
          editing: { if $0 { store.beginChainGesture() } else { store.endChainGesture() } })
      }
      HStack {
        Button("Move Up", systemImage: "arrow.up") {
          store.editChain { $0.entries.swapAt(index, index - 1) }
        }.disabled(index == 0)
        Button("Move Down", systemImage: "arrow.down") {
          store.editChain { $0.entries.swapAt(index, index + 1) }
        }.disabled(index == store.chain.entries.count - 1)
        Spacer()
        Button(role: .destructive) {
          store.editChain { $0.entries.remove(at: index) }
        } label: {
          Image(systemName: "trash").frame(width: 44, height: 44)
        }.accessibilityLabel("Remove \(pattern?.name ?? "entry")")
      }.font(.caption).buttonStyle(.borderless).frame(minHeight: 44)
    }.padding(.vertical, 8)
  }
}
