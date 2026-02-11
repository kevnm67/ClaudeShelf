import Foundation
import os

/// Errors that can occur during bulk file operations.
enum FileOperationError: LocalizedError {
    /// Some files in a bulk operation failed while others succeeded.
    case partialFailure(succeeded: Int, failed: Int, errors: [String])

    var errorDescription: String? {
        switch self {
        case .partialFailure(let succeeded, let failed, _):
            return "\(succeeded) file(s) processed, \(failed) file(s) failed"
        }
    }
}

/// Provides safe file operations with permission preservation and secure defaults.
///
/// All write operations preserve existing POSIX permissions. New files
/// default to `0600` (owner read/write only) per security policy.
enum FileOperations {
    private static let logger = Logger(subsystem: "com.claudeshelf.app", category: "FileOperations")

    /// Saves content to an existing file, preserving its POSIX permissions.
    ///
    /// Writes to a temporary file first, sets correct permissions on it,
    /// then atomically replaces the original — eliminating the TOCTOU window
    /// where the file could be world-readable.
    static func saveFile(at path: String, content: String) throws {
        let fm = FileManager.default
        let url = URL(fileURLWithPath: path)
        let parentDir = url.deletingLastPathComponent()

        // Read current permissions before writing
        let attributes = try fm.attributesOfItem(atPath: path)
        let posixPermissions = attributes[.posixPermissions] as? NSNumber

        // Write content to a temp file in the same directory
        let tempURL = parentDir.appendingPathComponent(".\(UUID().uuidString).tmp")
        guard let data = content.data(using: .utf8) else {
            throw CocoaError(.fileWriteInapplicableStringEncoding)
        }
        try data.write(to: tempURL)

        // Set correct permissions on temp file BEFORE it replaces the original
        if let permissions = posixPermissions {
            try fm.setAttributes([.posixPermissions: permissions], ofItemAtPath: tempURL.path)
        }

        // Atomically replace — file is never visible with wrong permissions
        _ = try fm.replaceItemAt(url, withItemAt: tempURL)

        logger.info("File saved successfully")
    }

    /// Creates a new file with content and secure default permissions (0600).
    ///
    /// Writes to a temporary file first, sets 0600 permissions on it,
    /// then moves to the final path — file is never visible with wrong permissions.
    static func createFile(at path: String, content: String = "") throws {
        let fm = FileManager.default
        let url = URL(fileURLWithPath: path)
        let parentDir = url.deletingLastPathComponent()

        // Create parent directories if needed
        if !fm.fileExists(atPath: parentDir.path) {
            try fm.createDirectory(at: parentDir, withIntermediateDirectories: true)
        }

        // Write to temp file, set secure permissions, then move to final path
        let tempURL = parentDir.appendingPathComponent(".\(UUID().uuidString).tmp")
        guard let data = content.data(using: .utf8) else {
            throw CocoaError(.fileWriteInapplicableStringEncoding)
        }
        try data.write(to: tempURL)

        // Set secure permissions on temp file BEFORE it becomes visible
        try fm.setAttributes([.posixPermissions: NSNumber(value: 0o600)], ofItemAtPath: tempURL.path)

        // Move to final path
        try fm.moveItem(at: tempURL, to: url)

        logger.info("File created with 0600 permissions")
    }

    /// Returns the POSIX permissions for a file, or nil if unavailable.
    static func filePermissions(at path: String) throws -> Int? {
        let attributes = try FileManager.default.attributesOfItem(atPath: path)
        return (attributes[.posixPermissions] as? NSNumber)?.intValue
    }

    // MARK: - Trash

    /// Moves a file to the macOS Trash.
    ///
    /// Uses `FileManager.trashItem(at:resultingItemURL:)` which is reversible
    /// via the Finder. Returns the URL of the item in the Trash.
    ///
    /// - Parameter path: Absolute path to the file to trash.
    /// - Returns: The URL of the trashed item, or nil if the system doesn't report one.
    @discardableResult
    static func trashFile(at path: String) throws -> URL? {
        let url = URL(fileURLWithPath: path)
        var resultingURL: NSURL?
        try FileManager.default.trashItem(at: url, resultingItemURL: &resultingURL)
        logger.info("File moved to Trash")
        return resultingURL as URL?
    }

    // MARK: - Permanent Delete

    /// Permanently deletes a file from the filesystem.
    ///
    /// This operation is irreversible. Callers should confirm with the user
    /// before invoking this method.
    ///
    /// - Parameter path: Absolute path to the file to delete.
    static func permanentlyDeleteFile(at path: String) throws {
        let url = URL(fileURLWithPath: path)
        try FileManager.default.removeItem(at: url)
        logger.info("File permanently deleted")
    }

    // MARK: - Bulk Trash

    /// Moves multiple files to the macOS Trash using best-effort semantics.
    ///
    /// Processes all files regardless of individual failures. If any files
    /// fail, throws ``FileOperationError/partialFailure`` with details.
    ///
    /// - Parameter paths: Array of absolute paths to trash.
    /// - Returns: A dictionary mapping each path to its resulting Trash URL (or nil).
    @discardableResult
    static func trashFiles(at paths: [String]) throws -> [String: URL?] {
        var results: [String: URL?] = [:]
        var errors: [String] = []
        var succeeded = 0

        for path in paths {
            do {
                let trashURL = try trashFile(at: path)
                results[path] = trashURL
                succeeded += 1
            } catch {
                errors.append(error.localizedDescription)
                logger.error("Failed to trash file: \(error.localizedDescription, privacy: .public)")
            }
        }

        if !errors.isEmpty {
            throw FileOperationError.partialFailure(
                succeeded: succeeded,
                failed: errors.count,
                errors: errors
            )
        }

        return results
    }

    // MARK: - Bulk Permanent Delete

    /// Permanently deletes multiple files using best-effort semantics.
    ///
    /// Processes all files regardless of individual failures. If any files
    /// fail, throws ``FileOperationError/partialFailure`` with details.
    ///
    /// - Parameter paths: Array of absolute paths to permanently delete.
    static func permanentlyDeleteFiles(at paths: [String]) throws {
        var errors: [String] = []
        var succeeded = 0

        for path in paths {
            do {
                try permanentlyDeleteFile(at: path)
                succeeded += 1
            } catch {
                errors.append(error.localizedDescription)
                logger.error("Failed to permanently delete file: \(error.localizedDescription, privacy: .public)")
            }
        }

        if !errors.isEmpty {
            throw FileOperationError.partialFailure(
                succeeded: succeeded,
                failed: errors.count,
                errors: errors
            )
        }
    }
}
