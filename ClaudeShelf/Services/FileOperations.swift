import Foundation
import os

/// Provides safe file operations with permission preservation and secure defaults.
///
/// All write operations preserve existing POSIX permissions. New files
/// default to `0600` (owner read/write only) per security policy.
enum FileOperations {
    private static let logger = Logger(subsystem: "com.claudeshelf.app", category: "FileOperations")

    /// Saves content to an existing file, preserving its POSIX permissions.
    static func saveFile(at path: String, content: String) throws {
        let fm = FileManager.default
        // Read current permissions before writing
        let attributes = try fm.attributesOfItem(atPath: path)
        let posixPermissions = attributes[.posixPermissions] as? NSNumber

        // Write content atomically
        try content.write(toFile: path, atomically: true, encoding: .utf8)

        // Restore original permissions
        if let permissions = posixPermissions {
            try fm.setAttributes([.posixPermissions: permissions], ofItemAtPath: path)
        }

        logger.info("File saved successfully")
    }

    /// Creates a new file with content and secure default permissions (0600).
    static func createFile(at path: String, content: String = "") throws {
        let fm = FileManager.default
        let url = URL(fileURLWithPath: path)
        let parentDir = url.deletingLastPathComponent()

        // Create parent directories if needed
        if !fm.fileExists(atPath: parentDir.path) {
            try fm.createDirectory(at: parentDir, withIntermediateDirectories: true)
        }

        // Write content
        try content.write(toFile: path, atomically: true, encoding: .utf8)

        // Set secure permissions (owner read/write only)
        try fm.setAttributes([.posixPermissions: NSNumber(value: 0o600)], ofItemAtPath: path)

        logger.info("File created with 0600 permissions")
    }

    /// Returns the POSIX permissions for a file, or nil if unavailable.
    static func filePermissions(at path: String) throws -> Int? {
        let attributes = try FileManager.default.attributesOfItem(atPath: path)
        return (attributes[.posixPermissions] as? NSNumber)?.intValue
    }
}
