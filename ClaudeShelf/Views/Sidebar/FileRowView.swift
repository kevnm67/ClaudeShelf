import SwiftUI

/// A single row in the file list showing a file's category icon,
/// display name, filename, size, modification date, and read-only status.
struct FileRowView: View {
    let file: FileEntry

    var body: some View {
        HStack(spacing: 8) {
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
    }

    /// File size formatted using ByteCountFormatter with file count style.
    private var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: file.size)
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
}
