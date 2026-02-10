import SwiftUI

/// A read-only viewer for a selected Claude configuration file.
///
/// Displays a metadata header (name, category, scope, lock status, size, date)
/// followed by the file's text content in a monospaced font. Content is loaded
/// asynchronously and reloads when the selected file changes.
struct FileDetailView: View {
    let file: FileEntry

    @State private var fileContent: String?
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
            fileContent = nil
            loadError = nil
            do {
                let url = URL(fileURLWithPath: file.path)
                fileContent = try String(contentsOf: url, encoding: .utf8)
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
        if let content = fileContent {
            ScrollView([.horizontal, .vertical]) {
                Text(content)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding()
            }
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
