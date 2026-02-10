import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        NavigationSplitView {
            Text("Categories")
                .navigationTitle("ClaudeShelf")
        } content: {
            Text("\(appState.filteredFiles.count) files")
        } detail: {
            Text("Select a file to edit")
                .foregroundStyle(.secondary)
        }
        .frame(minWidth: 800, minHeight: 500)
    }
}

#Preview {
    ContentView()
        .environment(AppState())
}
