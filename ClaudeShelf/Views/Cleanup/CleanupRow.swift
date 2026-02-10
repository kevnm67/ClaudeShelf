import SwiftUI

struct CleanupRow: View {
    let item: CleanupItem
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isSelected ? Color.accentColor : .secondary)

            Image(systemName: item.file.category.sfSymbol)
                .foregroundStyle(.secondary)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.file.displayName)
                    .font(.body)
                    .lineLimit(1)
                Text(item.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(ByteCountFormatter.string(fromByteCount: item.file.size, countStyle: .file))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
        .onTapGesture { onToggle() }
    }
}

#Preview {
    let file = FileEntry(
        id: "preview-1",
        name: "CLAUDE.md",
        path: "/Users/test/.claude/CLAUDE.md",
        displayName: "CLAUDE.md",
        category: .projectConfig,
        scope: .global,
        project: nil,
        size: 0,
        modifiedDate: Date(),
        isReadOnly: false
    )
    let item = CleanupItem(
        id: "preview-1-empty",
        file: file,
        reason: .emptyFile,
        detail: "File is empty (0 bytes)"
    )
    VStack {
        CleanupRow(item: item, isSelected: false, onToggle: {})
        CleanupRow(item: item, isSelected: true, onToggle: {})
    }
    .padding()
    .frame(width: 400)
}
