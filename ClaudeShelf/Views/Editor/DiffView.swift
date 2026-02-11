import SwiftUI

/// Represents a single line in a diff output.
enum DiffLine: Identifiable {
    case unchanged(lineNumber: Int, text: String)
    case added(lineNumber: Int, text: String)
    case removed(lineNumber: Int, text: String)

    var id: String {
        switch self {
        case .unchanged(let lineNumber, _):
            return "u-\(lineNumber)"
        case .added(let lineNumber, _):
            return "a-\(lineNumber)"
        case .removed(let lineNumber, _):
            return "r-\(lineNumber)"
        }
    }

    var text: String {
        switch self {
        case .unchanged(_, let text): text
        case .added(_, let text): text
        case .removed(_, let text): text
        }
    }

    var prefix: String {
        switch self {
        case .unchanged: " "
        case .added: "+"
        case .removed: "\u{2212}" // minus sign
        }
    }
}

/// Shows a line-by-line diff between original and modified text.
///
/// Uses Swift's `CollectionDifference` to compute insertions and removals,
/// then displays them with color-coded lines: red for removed, green for added,
/// and normal for unchanged. Includes a summary header and Save/Cancel buttons.
struct DiffView: View {
    let original: String
    let modified: String
    var onSave: () -> Void
    var onCancel: () -> Void

    /// Computed diff lines between original and modified text.
    private var diffLines: [DiffLine] {
        Self.computeDiff(original: original, modified: modified)
    }

    /// Count of lines that changed (added + removed).
    private var changeCount: Int {
        diffLines.reduce(0) { count, line in
            switch line {
            case .unchanged: count
            case .added, .removed: count + 1
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Header
            headerView
            Divider()

            // MARK: - Diff Content
            ScrollView([.horizontal, .vertical]) {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(diffLines) { line in
                        diffLineView(for: line)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(.background)

            Divider()

            // MARK: - Footer Buttons
            footerView
        }
        .frame(minWidth: 500, idealWidth: 700, minHeight: 400, idealHeight: 600)
    }

    // MARK: - Subviews

    @ViewBuilder
    private var headerView: some View {
        HStack {
            Image(systemName: "doc.text.magnifyingglass")
                .foregroundStyle(.secondary)
            Text("Review Changes")
                .font(.headline)
            Spacer()
            Text("\(changeCount) line\(changeCount == 1 ? "" : "s") changed")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
    }

    @ViewBuilder
    private func diffLineView(for line: DiffLine) -> some View {
        HStack(spacing: 0) {
            Text(line.prefix)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(foregroundColor(for: line))
                .frame(width: 20, alignment: .center)

            Text(line.text.isEmpty ? " " : line.text)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(foregroundColor(for: line))
                .strikethrough(isRemoved(line), color: removedForeground)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 1)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(backgroundColor(for: line))
    }

    @ViewBuilder
    private var footerView: some View {
        HStack {
            Spacer()
            Button("Cancel", role: .cancel) {
                onCancel()
            }
            .keyboardShortcut(.cancelAction)

            Button("Save") {
                onSave()
            }
            .keyboardShortcut(.defaultAction)
        }
        .padding()
    }

    // MARK: - Styling

    private let addedForeground = Color.green
    private let addedBackground = Color.green.opacity(0.1)
    private let removedForeground = Color.red
    private let removedBackground = Color.red.opacity(0.1)

    private func foregroundColor(for line: DiffLine) -> Color {
        switch line {
        case .unchanged: .primary
        case .added: addedForeground
        case .removed: removedForeground
        }
    }

    private func backgroundColor(for line: DiffLine) -> Color {
        switch line {
        case .unchanged: .clear
        case .added: addedBackground
        case .removed: removedBackground
        }
    }

    private func isRemoved(_ line: DiffLine) -> Bool {
        if case .removed = line { return true }
        return false
    }

    // MARK: - Diff Algorithm

    /// Computes a line-by-line diff between two strings using `CollectionDifference`.
    ///
    /// Splits both strings into lines, computes the difference, then walks
    /// through the results to produce an ordered list of unchanged, added,
    /// and removed lines suitable for display.
    ///
    /// - Parameters:
    ///   - original: The original (saved) text.
    ///   - modified: The modified (current editor) text.
    /// - Returns: An array of ``DiffLine`` values representing the diff.
    static func computeDiff(original: String, modified: String) -> [DiffLine] {
        let originalLines = original.components(separatedBy: "\n")
        let modifiedLines = modified.components(separatedBy: "\n")
        return buildDiffOutput(originalLines: originalLines, modifiedLines: modifiedLines)
    }

    /// Builds diff output by walking both line arrays with the collection difference.
    private static func buildDiffOutput(originalLines: [String], modifiedLines: [String]) -> [DiffLine] {
        let diff = modifiedLines.difference(from: originalLines)

        var removedOffsets: Set<Int> = []
        var insertedOffsets: Set<Int> = []

        for change in diff {
            switch change {
            case .remove(let offset, _, _):
                removedOffsets.insert(offset)
            case .insert(let offset, _, _):
                insertedOffsets.insert(offset)
            }
        }

        var result: [DiffLine] = []
        var originalIndex = 0
        var modifiedIndex = 0
        var lineCounter = 0

        while originalIndex < originalLines.count || modifiedIndex < modifiedLines.count {
            // Emit removed lines from original
            if originalIndex < originalLines.count && removedOffsets.contains(originalIndex) {
                lineCounter += 1
                result.append(.removed(lineNumber: lineCounter, text: originalLines[originalIndex]))
                originalIndex += 1
                continue
            }

            // Emit inserted lines from modified
            if modifiedIndex < modifiedLines.count && insertedOffsets.contains(modifiedIndex) {
                lineCounter += 1
                result.append(.added(lineNumber: lineCounter, text: modifiedLines[modifiedIndex]))
                modifiedIndex += 1
                continue
            }

            // Unchanged line (present in both)
            if originalIndex < originalLines.count && modifiedIndex < modifiedLines.count {
                lineCounter += 1
                result.append(.unchanged(lineNumber: lineCounter, text: originalLines[originalIndex]))
                originalIndex += 1
                modifiedIndex += 1
            } else if originalIndex < originalLines.count {
                // Remaining original lines must be removed
                lineCounter += 1
                result.append(.removed(lineNumber: lineCounter, text: originalLines[originalIndex]))
                originalIndex += 1
            } else if modifiedIndex < modifiedLines.count {
                // Remaining modified lines must be added
                lineCounter += 1
                result.append(.added(lineNumber: lineCounter, text: modifiedLines[modifiedIndex]))
                modifiedIndex += 1
            }
        }

        return result
    }
}

#Preview {
    DiffView(
        original: """
        # CLAUDE.md

        This is a sample file.
        It has some content.
        This line stays the same.
        This line will be removed.
        End of file.
        """,
        modified: """
        # CLAUDE.md

        This is a modified file.
        It has some content.
        This line stays the same.
        A new line was added here.
        End of file.
        """,
        onSave: {},
        onCancel: {}
    )
    .frame(width: 600, height: 400)
}
