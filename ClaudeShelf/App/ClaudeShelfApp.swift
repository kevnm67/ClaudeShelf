import SwiftUI

@main
struct ClaudeShelfApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .task {
                    await appState.performScan()
                    await appState.startFileWatching()
                }
        }

        Settings {
            SettingsView()
                .environment(appState)
        }
    }
}
