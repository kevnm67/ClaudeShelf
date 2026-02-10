import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 200, ideal: 220)
        } content: {
            Group {
                if appState.isScanning {
                    ProgressView("Scanning...")
                } else if appState.filteredFiles.isEmpty {
                    ContentUnavailableView {
                        Label("No Files Found", systemImage: "doc.questionmark")
                    } description: {
                        Text("Select a category or adjust your search.")
                    }
                } else {
                    Text("\(appState.filteredFiles.count) files found")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationSplitViewColumnWidth(min: 250, ideal: 300)
        } detail: {
            if let errorMessage = appState.errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
            } else {
                ContentUnavailableView {
                    Label("No Selection", systemImage: "doc.text")
                } description: {
                    Text("Select a file to edit")
                }
            }
        }
        .frame(minWidth: 800, minHeight: 500)
    }
}

#Preview {
    ContentView()
        .environment(AppState())
}
