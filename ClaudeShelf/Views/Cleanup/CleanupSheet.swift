import SwiftUI
import os

struct CleanupSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var items: [CleanupItem] = []
    @State private var selectedIDs: Set<String> = []
    @State private var isAnalyzing = true
    @State private var trashError: String?

    private static let logger = Logger(subsystem: "com.claudeshelf.app", category: "CleanupSheet")

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Cleanup")
                    .font(.headline)
                Spacer()
                if !items.isEmpty {
                    Button("Select All") { selectedIDs = Set(items.map(\.id)) }
                    Button("Deselect All") { selectedIDs.removeAll() }
                }
            }
            .padding()

            Divider()

            if isAnalyzing {
                VStack { Spacer(); ProgressView("Analyzing..."); Spacer() }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if items.isEmpty {
                ContentUnavailableView {
                    Label("All Clean", systemImage: "checkmark.circle")
                } description: {
                    Text("No cleanup candidates found.")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Grouped list
                List {
                    let grouped = CleanupAnalyzer.grouped(items)
                    ForEach(grouped, id: \.reason) { group in
                        Section(sectionTitle(for: group.reason)) {
                            ForEach(group.items) { item in
                                CleanupRow(
                                    item: item,
                                    isSelected: selectedIDs.contains(item.id),
                                    onToggle: { toggleSelection(item.id) }
                                )
                            }
                        }
                    }
                }
            }

            Divider()

            // Footer with actions
            HStack {
                if !items.isEmpty {
                    Text("\(selectedIDs.count) of \(items.count) selected")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Close") { dismiss() }
                    .keyboardShortcut(.escape)
                if !items.isEmpty {
                    Button {
                        trashSelected()
                    } label: {
                        Label("Move to Trash", systemImage: "trash")
                    }
                    .disabled(selectedIDs.isEmpty)
                    .keyboardShortcut(.return)
                }
            }
            .padding()
        }
        .frame(width: 550, height: 450)
        .task { await analyze() }
        .alert("Cleanup Error", isPresented: .init(
            get: { trashError != nil },
            set: { if !$0 { trashError = nil } }
        )) {
            Button("OK", role: .cancel) { trashError = nil }
        } message: {
            if let error = trashError { Text(error) }
        }
    }

    private func sectionTitle(for reason: CleanupReason) -> String {
        switch reason {
        case .emptyFile: return "Empty Files"
        case .emptyContent: return "Empty Content"
        case .stale: return "Stale Files (30+ days)"
        }
    }

    private func toggleSelection(_ id: String) {
        if selectedIDs.contains(id) {
            selectedIDs.remove(id)
        } else {
            selectedIDs.insert(id)
        }
    }

    private func analyze() async {
        items = await CleanupAnalyzer.analyze(files: appState.files)
        isAnalyzing = false
    }

    private func trashSelected() {
        let selectedItems = items.filter { selectedIDs.contains($0.id) }
        let filesToTrash = CleanupAnalyzer.uniqueFiles(from: selectedItems)
        let paths = filesToTrash.map(\.path)

        do {
            _ = try FileOperations.trashFiles(at: paths)
            appState.removeFiles(filesToTrash)
            // Remove trashed items from the list
            items.removeAll { selectedIDs.contains($0.id) }
            selectedIDs.removeAll()
            if items.isEmpty { dismiss() }
        } catch {
            trashError = "Some files could not be moved to Trash."
            Self.logger.error("Cleanup trash failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}

#Preview {
    CleanupSheet()
        .environment(AppState())
}
