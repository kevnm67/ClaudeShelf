import SwiftUI

/// The content column of the NavigationSplitView showing filtered files
/// grouped by scope (global first, then project) with sorting controls.
///
/// Selection drives ``AppState/selectedFile`` which populates the
/// detail column.
struct FileListView: View {
    @Environment(AppState.self) private var appState

    /// The current sort order for files within each scope group.
    @State private var sortOrder: SortOrder = .name

    var body: some View {
        @Bindable var appState = appState

        Group {
            if appState.filteredFiles.isEmpty {
                ContentUnavailableView {
                    Label("No Files", systemImage: "doc.questionmark")
                } description: {
                    Text("No files match the current filter.")
                }
            } else {
                List(selection: $appState.selectedFile) {
                    let grouped = groupedAndSortedFiles

                    if !grouped.global.isEmpty {
                        Section("Global") {
                            ForEach(grouped.global) { file in
                                FileRowView(file: file)
                                    .tag(Optional(file))
                            }
                        }
                    }

                    if !grouped.project.isEmpty {
                        Section("Project") {
                            ForEach(grouped.project) { file in
                                FileRowView(file: file)
                                    .tag(Optional(file))
                            }
                        }
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Picker("Sort", selection: $sortOrder) {
                    ForEach(SortOrder.allCases) { order in
                        Label(order.label, systemImage: order.sfSymbol)
                            .tag(order)
                    }
                }
                .pickerStyle(.segmented)
                .help("Sort files by name, date, or size")
            }
        }
        .navigationTitle("Files")
    }

    // MARK: - Grouping & Sorting

    /// Files split by scope and sorted by the current sort order.
    private var groupedAndSortedFiles: (global: [FileEntry], project: [FileEntry]) {
        let files = appState.filteredFiles
        let globalFiles = sortFiles(files.filter { $0.scope == .global })
        let projectFiles = sortFiles(files.filter { $0.scope == .project })
        return (global: globalFiles, project: projectFiles)
    }

    /// Sorts an array of files by the current sort order.
    private func sortFiles(_ files: [FileEntry]) -> [FileEntry] {
        switch sortOrder {
        case .name:
            return files.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
        case .date:
            return files.sorted { $0.modifiedDate > $1.modifiedDate }
        case .size:
            return files.sorted { $0.size > $1.size }
        }
    }
}

// MARK: - SortOrder

/// Sort order options for the file list.
enum SortOrder: String, CaseIterable, Identifiable {
    case name
    case date
    case size

    var id: String { rawValue }

    /// Human-readable label for the sort option.
    var label: String {
        switch self {
        case .name: "Name"
        case .date: "Date"
        case .size: "Size"
        }
    }

    /// SF Symbol for the sort option picker.
    var sfSymbol: String {
        switch self {
        case .name: "textformat.abc"
        case .date: "calendar"
        case .size: "externaldrive"
        }
    }
}

#Preview {
    NavigationSplitView {
        Text("Sidebar")
    } content: {
        FileListView()
    } detail: {
        Text("Detail")
    }
    .environment({
        let state = AppState()
        return state
    }())
}
