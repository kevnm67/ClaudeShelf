import SwiftUI

/// Displays a selected Claude configuration file with a metadata header
/// and an editable code editor.
///
/// The metadata header shows the file's name, category, scope, lock status,
/// size, and modification date. Below the header, a ``CodeEditorView`` provides
/// an NSTextView-based editor with line numbers and monospaced font.
/// Content is loaded asynchronously and reloads when the selected file changes.
struct FileDetailView: View {
    let file: FileEntry

    @State private var fileContent: String = ""
    @State private var originalContent: String = ""
    @State private var isLoaded: Bool = false
    @State private var loadError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // MARK: - Metadata Header
            headerView
            Divider()

            // MARK: - File Content
            contentView
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .task(id: file.id) {
            isLoaded = false
            loadError = nil
            fileContent = ""
            originalContent = ""
            do {
                let url = URL(fileURLWithPath: file.path)
                let content = try String(contentsOf: url, encoding: .utf8)
                fileContent = content
                originalContent = content
                isLoaded = true
            } catch {
                loadError = "Unable to read file contents"
            }
        }
    }

    // MARK: - Header

    @ViewBuilder
    private var headerView: some View {
        VStack(alignment: .leading, spacing: 8) {
            // File name and lock icon
            HStack(spacing: 6) {
                Text(file.displayName)
                    .font(.headline)
                    .lineLimit(1)

                if file.isReadOnly {
                    Image(systemName: "lock.fill")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                        .help("This file is read-only")
                }
            }

            // Badges and metadata row
            HStack(spacing: 12) {
                // Category badge
                Label(file.category.displayName, systemImage: file.category.sfSymbol)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.fill.tertiary, in: Capsule())

                // Scope badge
                Text(scopeLabel)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.fill.tertiary, in: Capsule())

                Spacer()

                // File size
                Text(formattedSize)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                // Last modified date
                Text(file.modifiedDate, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
    }

    // MARK: - Content

    @ViewBuilder
    private var contentView: some View {
        if isLoaded {
            CodeEditorView(text: $fileContent, isEditable: !file.isReadOnly, filename: file.name)
        } else if let error = loadError {
            ContentUnavailableView {
                Label("Cannot Read File", systemImage: "exclamationmark.triangle")
            } description: {
                Text(error)
            }
        } else {
            VStack {
                Spacer()
                ProgressView("Loading...")
                Spacer()
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Computed Properties

    /// Human-readable scope label showing "Global" or the project name.
    private var scopeLabel: String {
        if let project = file.project {
            return project
        }
        return file.scope == .global ? "Global" : "Project"
    }

    /// File size formatted with ByteCountFormatter.
    private var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: file.size, countStyle: .file)
    }
}

#Preview {
    FileDetailView(
        file: FileEntry(
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
    )
    .frame(width: 600, height: 500)
}
