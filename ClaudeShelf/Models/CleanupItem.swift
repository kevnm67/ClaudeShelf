import Foundation

/// The reason a file was flagged for cleanup.
enum CleanupReason: String, Sendable, Codable {
    /// File is 0 bytes.
    case emptyFile

    /// File contains only empty content: `[]`, `{}`, `null`, or whitespace.
    case emptyContent

    /// File has not been modified in 30 or more days.
    case stale
}

/// A file flagged for potential cleanup, with the reason and a
/// human-readable explanation.
struct CleanupItem: Identifiable, Sendable {
    /// Same identifier as the associated FileEntry.
    let id: String

    /// The file that was flagged.
    let file: FileEntry

    /// Why this file was flagged.
    let reason: CleanupReason

    /// Human-readable description of why the file was flagged
    /// (e.g., "File is empty (0 bytes)").
    let detail: String
}
