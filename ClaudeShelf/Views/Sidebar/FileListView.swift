import SwiftUI
import os

/// Logger for bulk file operations.
private let logger = Logger(subsystem: "com.claudeshelf.app", category: "FileListView")

/// The content column of the NavigationSplitView showing filtered files
/// grouped by scope (global first, then project) with sorting controls.
///
/// Selection drives ``AppState/selectedFile`` which populates the
/// detail column. Supports bulk selection mode for multi-file
/// trash and delete operations.
struct FileListView: View {
    @Environment(AppState.self) private var appState

    /// The current sort order for files within each scope group.
    @State private var sortOrder: SortOrder = .name

    /// Whether the bulk delete confirmation sheet is showing.
    @State private var showBulkDeleteConfirmation: Bool = false

    /// Error message from a failed bulk delete operation.
    @State private var bulkDeleteError: String?

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
                VStack(spacing: 0) {
                    // Bulk selection toolbar
                    if appState.isBulkSelectionMode {
                        bulkSelectionBar
                        Divider()
                    }

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
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    if appState.isBulkSelectionMode {
                        appState.clearSelection()
                    } else {
                        appState.isBulkSelectionMode = true
                    }
                } label: {
                    Text(appState.isBulkSelectionMode ? "Done" : "Select")
                }
                .help(appState.isBulkSelectionMode ? "Exit selection mode" : "Enter selection mode")
            }

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
        .sheet(isPresented: $showBulkDeleteConfirmation) {
            DeleteConfirmationView(
                files: appState.selectedFiles,
                onTrash: {
                    bulkTrash()
                    showBulkDeleteConfirmation = false
                },
                onPermanentDelete: {
                    bulkPermanentDelete()
                    showBulkDeleteConfirmation = false
                },
                onCancel: {
                    showBulkDeleteConfirmation = false
                }
            )
        }
        .alert("Delete Error", isPresented: .init(
            get: { bulkDeleteError != nil },
            set: { if !$0 { bulkDeleteError = nil } }
        )) {
            Button("OK", role: .cancel) {
                bulkDeleteError = nil
            }
        } message: {
            if let errorMessage = bulkDeleteError {
                Text(errorMessage)
            }
        }
    }

    // MARK: - Bulk Selection Bar

    @ViewBuilder
    private var bulkSelectionBar: some View {
        HStack(spacing: 12) {
            Button {
                appState.selectAllFiltered()
            } label: {
                Text("Select All")
                    .font(.caption)
            }

            Text("\(appState.selectedFileIDs.count) selected")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            Button(role: .destructive) {
                showBulkDeleteConfirmation = true
            } label: {
                Label("Delete", systemImage: "trash")
                    .font(.caption)
            }
            .disabled(appState.selectedFileIDs.isEmpty)
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
        .background(.fill.quaternary)
    }

    // MARK: - Bulk Operations

    /// Moves all selected files to Trash.
    private func bulkTrash() {
        let filesToTrash = appState.selectedFiles
        let paths = filesToTrash.map(\.path)
        do {
            try FileOperations.trashFiles(at: paths)
            appState.removeFiles(filesToTrash)
            appState.clearSelection()
        } catch let error as FileOperationError {
            appState.removeFiles(appState.selectedFiles.filter { file in
                !FileManager.default.fileExists(atPath: file.path)
            })
            bulkDeleteError = error.errorDescription
            logger.error("Bulk trash partial failure: \(error.localizedDescription, privacy: .public)")
        } catch {
            bulkDeleteError = "Unable to move files to Trash. Please check permissions and try again."
            logger.error("Bulk trash failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Permanently deletes all selected files.
    private func bulkPermanentDelete() {
        let filesToDelete = appState.selectedFiles
        let paths = filesToDelete.map(\.path)
        do {
            try FileOperations.permanentlyDeleteFiles(at: paths)
            appState.removeFiles(filesToDelete)
            appState.clearSelection()
        } catch let error as FileOperationError {
            appState.removeFiles(appState.selectedFiles.filter { file in
                !FileManager.default.fileExists(atPath: file.path)
            })
            bulkDeleteError = error.errorDescription
            logger.error("Bulk delete partial failure: \(error.localizedDescription, privacy: .public)")
        } catch {
            bulkDeleteError = "Unable to delete files. Please check permissions and try again."
            logger.error("Bulk delete failed: \(error.localizedDescription, privacy: .public)")
        }
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
