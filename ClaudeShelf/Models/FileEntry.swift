import Foundation
import CryptoKit

/// Represents a single Claude configuration file discovered during scanning.
struct FileEntry: Identifiable, Hashable, Sendable {
    /// Unique identifier derived from SHA256 of the absolute path,
    /// truncated to 16 hex characters.
    let id: String

    /// The filename (e.g., "CLAUDE.md").
    let name: String

    /// The absolute filesystem path.
    let path: String

    /// Decoded display name for the UI (e.g., project name extracted
    /// from encoded path segments).
    let displayName: String

    /// Which category this file belongs to.
    let category: Category

    /// Whether this is a global or project-scoped file.
    let scope: Scope

    /// The decoded project name, or nil for global-scope files.
    let project: String?

    /// File size in bytes.
    let size: Int64

    /// Last modification date.
    let modifiedDate: Date

    /// Whether the file is read-only (not writable by the current user).
    let isReadOnly: Bool

    /// Generates a stable, unique identifier from an absolute file path.
    ///
    /// Computes SHA256 of the UTF-8 encoded path and returns the first
    /// 16 hexadecimal characters (8 bytes).
    ///
    /// - Parameter path: The absolute filesystem path.
    /// - Returns: A 16-character lowercase hex string.
    static func generateID(from path: String) -> String {
        let data = Data(path.utf8)
        let digest = SHA256.hash(data: data)
        return digest.prefix(8)
            .map { String(format: "%02x", $0) }
            .joined()
    }
}
