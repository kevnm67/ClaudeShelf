import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var appState
    @State private var showCleanup = false

    var body: some View {
        @Bindable var appState = appState

        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 200, ideal: 220)
        } content: {
            Group {
                if appState.isScanning {
                    ProgressView("Scanning...")
                } else {
                    FileListView()
                }
            }
            .navigationSplitViewColumnWidth(min: 250, ideal: 300)
        } detail: {
            detailColumn
        }
        .searchable(text: $appState.searchText, prompt: "Search files...")
        .toolbar {
            ToolbarItem(placement: .automatic) {
                if appState.isScanning {
                    ProgressView()
                        .controlSize(.small)
                        .help("Scanning for files...")
                } else {
                    Button {
                        Task {
                            await appState.performScan()
                        }
                    } label: {
                        Label("Rescan", systemImage: "arrow.clockwise")
                    }
                    .keyboardShortcut("r", modifiers: .command)
                    .help("Rescan for Claude configuration files")
                }
            }
            ToolbarItem(placement: .automatic) {
                Button {
                    showCleanup = true
                } label: {
                    Label("Cleanup", systemImage: "wand.and.stars")
                }
                .help("Analyze files for cleanup")
            }
        }
        .sheet(isPresented: $showCleanup) {
            CleanupSheet()
        }
        .frame(minWidth: 800, minHeight: 500)
    }

    // MARK: - Detail Column

    @ViewBuilder
    private var detailColumn: some View {
        if let selectedFile = appState.selectedFile {
            FileDetailView(file: selectedFile)
        } else if let errorMessage = appState.errorMessage {
            ContentUnavailableView {
                Label("Scan Error", systemImage: "exclamationmark.triangle")
            } description: {
                Text(errorMessage)
                    .foregroundStyle(.red)
            }
        } else {
            ContentUnavailableView {
                Label("No Selection", systemImage: "doc.text")
            } description: {
                Text("Select a file to view")
            }
        }
    }
}

#Preview {
    ContentView()
        .environment(AppState())
}
