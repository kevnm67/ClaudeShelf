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
        .commands {
            CommandGroup(after: .newItem) {
                Button("Rescan") {
                    Task { await appState.performScan() }
                }
                .keyboardShortcut("r", modifiers: .command)
            }
        }

        Settings {
            SettingsView()
                .environment(appState)
        }
    }
}
