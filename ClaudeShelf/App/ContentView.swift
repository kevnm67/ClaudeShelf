import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        NavigationSplitView {
            Text("Categories")
                .navigationTitle("ClaudeShelf")
        } content: {
            if appState.isScanning {
                ProgressView("Scanning...")
            } else {
                Text("\(appState.filteredFiles.count) files found")
            }
        } detail: {
            if let errorMessage = appState.errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
            } else {
                Text("Select a file to edit")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(minWidth: 800, minHeight: 500)
    }
}

#Preview {
    ContentView()
        .environment(AppState())
}
