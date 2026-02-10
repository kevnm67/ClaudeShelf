import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @Environment(AppState.self) private var appState
    @State private var showCleanup = false
    @State private var exportError: String?

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
            ToolbarItem(placement: .automatic) {
                Button {
                    exportFiles()
                } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                .disabled(appState.filteredFiles.isEmpty)
                .help("Export filtered files as zip archive")
            }
        }
        .sheet(isPresented: $showCleanup) {
            CleanupSheet()
        }
        .alert("Export Error", isPresented: .init(
            get: { exportError != nil },
            set: { if !$0 { exportError = nil } }
        )) {
            Button("OK", role: .cancel) {
                exportError = nil
            }
        } message: {
            if let errorMessage = exportError {
                Text(errorMessage)
            }
        }
        .frame(minWidth: 800, minHeight: 500)
    }

    // MARK: - Export

    private func exportFiles() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = ExportService.defaultFilename()
        panel.allowedContentTypes = [.zip]

        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            do {
                try ExportService.exportAsZip(files: appState.filteredFiles, to: url.path)
            } catch {
                exportError = error.localizedDescription
            }
        }
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
