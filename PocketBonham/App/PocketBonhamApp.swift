import SwiftUI

@main struct PocketBonhamApp: App {
  @StateObject private var store = AppStore()
  @Environment(\.scenePhase) private var phase
  var body: some Scene {
    WindowGroup {
      RootView(store: store, audio: store.audio)
        .preferredColorScheme(.light)
        .onChange(of: phase) { _, phase in
          UIApplication.shared.isIdleTimerDisabled = phase == .active
          if phase != .active {
            store.stop()
            store.audio.deactivate()
            Task { await store.flush() }
          } else {
            Task { await store.preparePads() }
          }
        }
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
    }
  }
}
