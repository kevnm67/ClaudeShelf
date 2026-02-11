import SwiftUI

/// A single row in the file list showing a file's category icon,
/// display name, filename, size, modification date, and read-only status.
///
/// In bulk selection mode, displays a checkbox at the leading edge.
/// Provides a context menu for quick trash and selection actions.
struct FileRowView: View {
    let file: FileEntry

    @Environment(AppState.self) private var appState
    @State private var trashError: String?

    /// Whether this file is currently selected in bulk mode.
    private var isSelected: Bool {
        appState.selectedFileIDs.contains(file.id)
    }

    var body: some View {
        HStack(spacing: 8) {
            // Bulk selection checkbox
            if appState.isBulkSelectionMode {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.body)
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                    .frame(width: 20, alignment: .center)
                    .onTapGesture {
                        appState.toggleFileSelection(file.id)
                    }
                    .accessibilityLabel(isSelected ? "Selected" : "Not selected")
                    .accessibilityAddTraits(.isButton)
            }

            Image(systemName: file.category.sfSymbol)
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(width: 20, alignment: .center)

            VStack(alignment: .leading, spacing: 2) {
                Text(file.displayName)
                    .font(.body)
                    .lineLimit(1)

                if file.name != file.displayName {
                    Text(file.name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                HStack(spacing: 4) {
                    if file.isReadOnly {
                        Image(systemName: "lock.fill")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .accessibilityLabel("Read-only")
                    }

                    Text(formattedSize)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                Text(file.modifiedDate, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
        .contextMenu {
            Button {
                if !appState.isBulkSelectionMode {
                    appState.isBulkSelectionMode = true
                }
                appState.toggleFileSelection(file.id)
            } label: {
                Label("Select", systemImage: "checkmark.circle")
            }

            Divider()

            if !file.isReadOnly {
                Button(role: .destructive) {
                    trashFile()
                } label: {
                    Label("Move to Trash", systemImage: "trash")
                }
            }
        }
        .alert("Trash Error", isPresented: .init(
            get: { trashError != nil },
            set: { if !$0 { trashError = nil } }
        )) {
            Button("OK", role: .cancel) { trashError = nil }
        } message: {
            if let error = trashError { Text(error) }
        }
    }

    /// File size formatted using ByteCountFormatter with file count style.
    private var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: file.size, countStyle: .file)
    }

    /// Moves this file to the Trash via context menu.
    private func trashFile() {
        do {
            try FileOperations.trashFile(at: file.path)
            appState.removeFiles([file])
        } catch {
            trashError = "Unable to move file to Trash. Please check permissions and try again."
        }
    }
}

#Preview {
    List {
        FileRowView(file: FileEntry(
            id: FileEntry.generateID(from: "/Users/demo/.claude/CLAUDE.md"),
            name: "CLAUDE.md",
            path: "/Users/demo/.claude/CLAUDE.md",
            displayName: "Global Instructions",
            category: .projectConfig,
            scope: .global,
            project: nil,
            size: 2048,
            modifiedDate: Date().addingTimeInterval(-3600),
            isReadOnly: false
        ))

        FileRowView(file: FileEntry(
            id: FileEntry.generateID(from: "/Users/demo/Projects/MyApp/.claude/CLAUDE.md"),
            name: "CLAUDE.md",
            path: "/Users/demo/Projects/MyApp/.claude/CLAUDE.md",
            displayName: "MyApp",
            category: .projectConfig,
            scope: .project,
            project: "MyApp",
            size: 512,
            modifiedDate: Date().addingTimeInterval(-86400 * 7),
            isReadOnly: true
        ))
    }
    .frame(width: 300)
    .environment(AppState())
}
