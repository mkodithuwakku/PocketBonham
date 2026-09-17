import BonhamCore
import SwiftUI

struct LibraryView: View {
  @ObservedObject var store: AppStore
  @State private var search = ""
  @State private var sortRecent = true
  @State private var chains = false
  @State private var deletingPattern: Pattern?
  @State private var deletingChain: Chain?
  @State private var renameID: UUID?
  @State private var renameIsChain = false
  @State private var name = ""
  var patterns: [Pattern] {
    store.library.patterns.filter {
      search.isEmpty || $0.name.localizedCaseInsensitiveContains(search)
    }.sorted {
      sortRecent
        ? $0.updatedAt > $1.updatedAt
        : $0.name.localizedStandardCompare($1.name) == .orderedAscending
    }
  }
  var chainList: [Chain] {
    store.library.chains.filter {
      search.isEmpty || $0.name.localizedCaseInsensitiveContains(search)
    }.sorted {
      sortRecent
        ? $0.updatedAt > $1.updatedAt
        : $0.name.localizedStandardCompare($1.name) == .orderedAscending
    }
  }
  var body: some View {
    List {
      Section {
        Picker("Library", selection: $chains) {
          Text("Patterns").tag(false)
          Text("Chains").tag(true)
        }.pickerStyle(.segmented)
        Toggle("Most Recent First", isOn: $sortRecent)
      }
      if chains {
        if chainList.isEmpty {
          ContentUnavailableView(
            "No saved chains", systemImage: "link",
            description: Text("Build an arrangement in Chains, then save it."))
        }
        ForEach(chainList) { c in
          HStack {
            Button {
              store.open(c)
            } label: {
              VStack(alignment: .leading, spacing: 6) {
                Text(c.name).font(.headline).foregroundStyle(Color.ink)
                Text(chainSummary(c)).font(.caption).foregroundStyle(.secondary)
                Text(c.updatedAt, style: .date).font(.caption2).foregroundStyle(.secondary)
              }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 8)
            }.buttonStyle(.plain)
            Menu {
              Button("Open") { store.open(c) }
              Button("Rename") {
                renameID = c.id
                renameIsChain = true
                name = c.name
              }
              Button("Duplicate") { store.duplicateChain(c) }
              Button("Delete", role: .destructive) { deletingChain = c }
            } label: {
              Image(systemName: "ellipsis.circle").frame(width: 44, height: 44)
            }.accessibilityLabel("Actions for \(c.name)")
          }
        }
      } else {
        if patterns.isEmpty {
          ContentUnavailableView(
            "Your groove starts here", systemImage: "square.grid.3x3",
            description: Text("Make a pattern, give it a name, and save it here."))
        }
        ForEach(patterns) { p in
          HStack {
            Button {
              store.open(p)
            } label: {
              VStack(alignment: .leading, spacing: 6) {
                Text(p.name).font(.headline).foregroundStyle(Color.ink)
                Text(
                  "\(store.catalog.items.first {$0.id==p.kitID}?.kit.name ?? p.kitID) · \(p.bpm) BPM"
                ).font(.caption).foregroundStyle(.secondary)
                Text(p.updatedAt, style: .date).font(.caption2).foregroundStyle(.secondary)
              }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 8)
            }.buttonStyle(.plain)
            Menu {
              Button("Open") { store.open(p) }
              Button("Rename") {
                renameID = p.id
                renameIsChain = false
                name = p.name
              }
              Button("Duplicate") { store.duplicatePattern(p) }
              Button("Delete", role: .destructive) { deletingPattern = p }
            } label: {
              Image(systemName: "ellipsis.circle").frame(width: 44, height: 44)
            }.accessibilityLabel("Actions for \(p.name)")
          }
        }
      }
      if !store.library.patternDrafts.isEmpty || !store.library.chainDrafts.isEmpty {
        Section("Recoverable Drafts") {
          ForEach(store.library.patternDrafts) { d in
            Button {
              store.leave(isChain: false) {
                store.recoveryPattern = d
                store.recoveryChain = nil
                store.recoveryConflict =
                  store.library.patterns.first { $0.id == d.model.id }.map {
                    $0.revision != d.baseRevision
                  } ?? false
                store.showRecovery = true
              }
            } label: {
              Label(d.model.name, systemImage: "pencil.and.outline")
            }
          }
          ForEach(store.library.chainDrafts) { d in
            Button {
              store.leave(isChain: true) {
                store.recoveryChain = d
                store.recoveryPattern = nil
                store.recoveryConflict =
                  store.library.chains.first { $0.id == d.model.id }.map {
                    $0.revision != d.baseRevision
                  } ?? false
                store.showRecovery = true
              }
            } label: {
              Label(d.model.name, systemImage: "link")
            }
          }
        }
      }
    }.scrollContentBackground(.hidden).background { InstrumentBackground() }.navigationTitle("Library")
      .searchable(text: $search, prompt: "Find a saved groove")
      .task { await store.refresh() }
      .alert(
        "Delete \(deletingPattern?.name ?? deletingChain?.name ?? "item")?",
        isPresented: Binding(
          get: { deletingPattern != nil || deletingChain != nil },
          set: {
            if !$0 {
              deletingPattern = nil
              deletingChain = nil
            }
          })
      ) {
        Button("Delete", role: .destructive) {
          let p = deletingPattern
          let c = deletingChain
          deletingPattern = nil
          deletingChain = nil
          Task {
            if let p { await store.deletePattern(p) }
            if let c { await store.deleteChain(c) }
          }
        }
        Button("Cancel", role: .cancel) {
          deletingPattern = nil
          deletingChain = nil
        }
      } message: {
        Text("Library deletion cannot be undone. Patterns referenced by chains are protected.")
      }
      .alert(
        "Rename", isPresented: Binding(get: { renameID != nil }, set: { if !$0 { renameID = nil } })
      ) {
        TextField("Name", text: $name)
        Button("Save") {
          let id = renameID
          renameID = nil
          Task {
            do {
              if renameIsChain, var c = store.library.chains.first(where: { $0.id == id }) {
                c.name = name
                let saved = try await store.repository.save(c)
                if store.chain.id == id && !store.chainDirty {
                  store.chain = saved
                  store.savedChain = saved
                }
              } else if var p = store.library.patterns.first(where: { $0.id == id }) {
                p.name = name
                let saved = try await store.repository.save(p)
                if store.pattern.id == id && !store.patternDirty {
                  store.pattern = saved
                  store.savedPattern = saved
                }
              }
              await store.refresh()
            } catch { store.message = error.localizedDescription }
          }
        }
        Button("Cancel", role: .cancel) { renameID = nil }
      }
  }
  func chainSummary(_ c: Chain) -> String {
    guard let entries = try? c.resolve(patterns: store.library.patterns) else {
      return "Missing pattern reference"
    }
    let bpms = Set(entries.map(\.bpm))
    return
      "\(c.entries.count) entries · \(entries.reduce(0){$0+$1.repeats}) bars · \(bpms.count==1 ? "\(bpms.first!) BPM":"Mixed tempo")"
  }
}
