import Foundation
import os

/// Analyzes files for cleanup candidates: empty, empty-content, and stale files.
enum CleanupAnalyzer {
    private static let logger = Logger(subsystem: "com.claudeshelf.app", category: "CleanupAnalyzer")

    /// Stale threshold: 30 days
    private static let staleThreshold: TimeInterval = 30 * 24 * 60 * 60

    /// Content patterns that count as "empty content"
    private static let emptyContentPatterns: Set<String> = ["[]", "{}", "null"]

    /// Analyzes files and returns cleanup candidates.
    static func analyze(files: [FileEntry]) -> [CleanupItem] {
        var items: [CleanupItem] = []
        let now = Date()

        for file in files {
            // Empty file (0 bytes)
            if file.size == 0 {
                items.append(CleanupItem(
                    id: "\(file.id)-empty",
                    file: file,
                    reason: .emptyFile,
                    detail: "File is empty (0 bytes)"
                ))
            }

            // Empty content check — only for small files
            if file.size > 0, file.size < 1024 {
                if let content = try? String(contentsOfFile: file.path, encoding: .utf8) {
                    let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
                    if trimmed.isEmpty || emptyContentPatterns.contains(trimmed) {
                        items.append(CleanupItem(
                            id: "\(file.id)-content",
                            file: file,
                            reason: .emptyContent,
                            detail: trimmed.isEmpty ? "File contains only whitespace" : "File contains only \"\(trimmed)\""
                        ))
                    }
                }
            }

            // Stale check (30+ days)
            if now.timeIntervalSince(file.modifiedDate) > staleThreshold {
                let days = Int(now.timeIntervalSince(file.modifiedDate) / (24 * 60 * 60))
                items.append(CleanupItem(
                    id: "\(file.id)-stale",
                    file: file,
                    reason: .stale,
                    detail: "Not modified in \(days) days"
                ))
            }
        }

        logger.info("Cleanup analysis found \(items.count) items from \(files.count) files")
        return items
    }

    /// Groups cleanup items by reason for sectioned display.
    static func grouped(_ items: [CleanupItem]) -> [(reason: CleanupReason, items: [CleanupItem])] {
        let order: [CleanupReason] = [.emptyFile, .emptyContent, .stale]
        return order.compactMap { reason in
            let matching = items.filter { $0.reason == reason }
            return matching.isEmpty ? nil : (reason: reason, items: matching)
        }
    }

    /// Returns unique files from cleanup items (a file may appear under multiple reasons).
    static func uniqueFiles(from items: [CleanupItem]) -> [FileEntry] {
        var seen = Set<String>()
        var result: [FileEntry] = []
        for item in items {
            if seen.insert(item.file.id).inserted {
                result.append(item.file)
            }
        }
        return result
    }
}
