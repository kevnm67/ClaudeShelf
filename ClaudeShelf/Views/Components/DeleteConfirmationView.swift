import SwiftUI

/// A confirmation dialog for trashing or permanently deleting one or more files.
///
/// Displays the affected file names, a warning about irreversibility,
/// and three action buttons: Cancel, Move to Trash, and Delete Permanently.
struct DeleteConfirmationView: View {
    /// The files targeted for deletion.
    let files: [FileEntry]

    /// Called when the user chooses to move files to Trash.
    let onTrash: () -> Void

    /// Called when the user chooses to permanently delete files.
    let onPermanentDelete: () -> Void

    /// Called when the user cancels the operation.
    let onCancel: () -> Void

    /// The title adapts to single-file vs. bulk operations.
    private var title: String {
        files.count == 1 ? "Delete File?" : "Delete \(files.count) Files?"
    }

    var body: some View {
        VStack(spacing: 16) {
            // Header icon and title
            VStack(spacing: 8) {
                Image(systemName: "trash")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)

                Text(title)
                    .font(.headline)
            }
            .padding(.top, 8)

            // File list (scrollable for bulk)
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(files) { file in
                        HStack(spacing: 6) {
                            Image(systemName: file.category.sfSymbol)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(width: 16, alignment: .center)
                            Text(file.displayName)
                                .font(.body)
                                .lineLimit(1)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 150)
            .padding(.horizontal)

            // Warning text
            Text("Move to Trash is reversible. Permanent delete cannot be undone.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Divider()

            // Action buttons
            HStack(spacing: 12) {
                Button("Cancel", role: .cancel) {
                    onCancel()
                }
                .keyboardShortcut(.escape, modifiers: [])

                Spacer()

                Button {
                    onTrash()
                } label: {
                    Label("Move to Trash", systemImage: "trash")
                }
                .keyboardShortcut(.return, modifiers: [])
                .buttonStyle(.borderedProminent)

                Button(role: .destructive) {
                    onPermanentDelete()
                } label: {
                    Label("Delete Permanently", systemImage: "xmark.bin")
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
        .padding()
        .frame(width: 400, idealHeight: 350)
    }
}

// MARK: - Previews

#Preview("Single File") {
    DeleteConfirmationView(
        files: [
            FileEntry(
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
            )
        ],
        onTrash: {},
        onPermanentDelete: {},
        onCancel: {}
    )
}

#Preview("Multiple Files") {
    DeleteConfirmationView(
        files: [
            FileEntry(
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
            ),
            FileEntry(
                id: FileEntry.generateID(from: "/Users/demo/.claude/settings.json"),
                name: "settings.json",
                path: "/Users/demo/.claude/settings.json",
                displayName: "Global Settings",
                category: .settings,
                scope: .global,
                project: nil,
                size: 512,
                modifiedDate: Date().addingTimeInterval(-7200),
                isReadOnly: false
            ),
            FileEntry(
                id: FileEntry.generateID(from: "/Users/demo/Projects/MyApp/.claude/CLAUDE.md"),
                name: "CLAUDE.md",
                path: "/Users/demo/Projects/MyApp/.claude/CLAUDE.md",
                displayName: "MyApp Config",
                category: .projectConfig,
                scope: .project,
                project: "MyApp",
                size: 1024,
                modifiedDate: Date().addingTimeInterval(-86400),
                isReadOnly: false
            )
        ],
        onTrash: {},
        onPermanentDelete: {},
        onCancel: {}
    )
}
