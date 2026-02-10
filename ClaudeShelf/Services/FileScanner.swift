import Foundation
import os

/// A file discovered during scanning, before category assignment.
struct DiscoveredFile: Sendable {
    /// The absolute URL to the file.
    let url: URL
    /// The filename (e.g., "CLAUDE.md").
    let name: String
    /// File size in bytes.
    let size: Int64
    /// Last modification date.
    let modifiedDate: Date
    /// Whether the file is read-only (not writable by the current user).
    let isReadOnly: Bool
    /// Whether the file was found inside a `.claude/` directory.
    let isInsideClaude: Bool
    /// Path relative to the `.claude/` directory, for category assignment.
    /// Nil if the file is not inside a `.claude/` directory.
    let claudeRelativePath: String?
}

/// Core file discovery engine that walks directories, applies skip rules,
/// respects depth limits, and discovers files matching known Claude
/// configuration extensions.
actor FileScanner {

    // MARK: - Constants

    /// Known Claude config file extensions (without leading dot).
    static let knownExtensions: Set<String> = [
        "md", "json", "yaml", "yml", "txt", "toml", "log", "sh",
    ]

    /// Special filenames recognized anywhere (not just inside `.claude/`).
    static let specialFiles: Set<String> = ["CLAUDE.md", ".clauderc"]

    /// Directories to skip during scanning.
    static let skipDirectories: Set<String> = [
        ".git", "node_modules", ".venv", "__pycache__",
    ]

    /// Max depth for non-`.claude` directories.
    /// 0 = scan location itself, 1 = immediate children, 2 = grandchildren.
    static let maxDepth = 2

    // MARK: - Logging

    private static let logger = Logger(
        subsystem: "com.claudeshelf.app",
        category: "FileScanner"
    )

    // MARK: - Scanning

    /// Scans all enabled locations and returns discovered files with timing info.
    ///
    /// - Parameter locations: The scan locations to enumerate.
    /// - Returns: A list of discovered files, scan duration, and any non-fatal errors.
    func scanLocations(
        _ locations: [ScanLocation]
    ) async -> (files: [DiscoveredFile], duration: TimeInterval, errors: [String]) {
        let startTime = Date()
        var allFiles: [DiscoveredFile] = []
        var allErrors: [String] = []

        for location in locations {
            guard location.isEnabled else { continue }

            let expandedPath = (location.path as NSString)
                .expandingTildeInPath
            let directoryURL = URL(fileURLWithPath: expandedPath, isDirectory: true)

            // Verify the directory exists before scanning.
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(
                atPath: directoryURL.path,
                isDirectory: &isDirectory
            ), isDirectory.boolValue else {
                continue
            }

            let (files, errors) = scanDirectory(
                at: directoryURL,
                currentDepth: 0,
                isInsideClaude: false,
                claudeBaseURL: nil
            )
            allFiles.append(contentsOf: files)
            allErrors.append(contentsOf: errors)
        }

        let duration = Date().timeIntervalSince(startTime)
        return (allFiles, duration, allErrors)
    }

    // MARK: - Private

    /// Recursively scans a directory for Claude configuration files.
    ///
    /// - Parameters:
    ///   - url: The directory URL to scan.
    ///   - currentDepth: Current recursion depth (0-based).
    ///   - isInsideClaude: Whether we are inside a `.claude/` directory tree.
    ///   - claudeBaseURL: The URL of the `.claude/` directory ancestor, used to
    ///     compute relative paths. Nil if not inside `.claude/`.
    /// - Returns: A tuple of discovered files and non-fatal error messages.
    private func scanDirectory(
        at url: URL,
        currentDepth: Int,
        isInsideClaude: Bool,
        claudeBaseURL: URL?
    ) -> (files: [DiscoveredFile], errors: [String]) {
        var files: [DiscoveredFile] = []
        var errors: [String] = []

        let keys: [URLResourceKey] = [
            .isDirectoryKey,
            .fileSizeKey,
            .contentModificationDateKey,
            .isWritableKey,
        ]

        let contents: [URL]
        do {
            contents = try FileManager.default.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: keys,
                options: []
            )
        } catch {
            let message = "Failed to read directory \(url.path): \(error.localizedDescription)"
            Self.logger.error("\(message, privacy: .public)")
            return ([], [message])
        }

        for itemURL in contents {
            let itemName = itemURL.lastPathComponent

            let resourceValues: URLResourceValues
            do {
                resourceValues = try itemURL.resourceValues(
                    forKeys: Set(keys)
                )
            } catch {
                let message = "Failed to read attributes for \(itemURL.path): \(error.localizedDescription)"
                Self.logger.error("\(message, privacy: .public)")
                errors.append(message)
                continue
            }

            let isDirectory = resourceValues.isDirectory ?? false

            if isDirectory {
                // Skip known noise directories.
                if Self.skipDirectories.contains(itemName) {
                    continue
                }

                // Skip hidden directories except `.claude`.
                if itemName.hasPrefix(".") && itemName != ".claude" {
                    continue
                }

                if itemName == ".claude" {
                    // Enter .claude with unlimited depth.
                    let (subFiles, subErrors) = scanDirectory(
                        at: itemURL,
                        currentDepth: 0,
                        isInsideClaude: true,
                        claudeBaseURL: itemURL
                    )
                    files.append(contentsOf: subFiles)
                    errors.append(contentsOf: subErrors)
                } else if isInsideClaude {
                    // Inside .claude — no depth limit, recurse freely.
                    let (subFiles, subErrors) = scanDirectory(
                        at: itemURL,
                        currentDepth: currentDepth + 1,
                        isInsideClaude: true,
                        claudeBaseURL: claudeBaseURL
                    )
                    files.append(contentsOf: subFiles)
                    errors.append(contentsOf: subErrors)
                } else if currentDepth < Self.maxDepth {
                    // Outside .claude — respect depth limit.
                    let (subFiles, subErrors) = scanDirectory(
                        at: itemURL,
                        currentDepth: currentDepth + 1,
                        isInsideClaude: false,
                        claudeBaseURL: nil
                    )
                    files.append(contentsOf: subFiles)
                    errors.append(contentsOf: subErrors)
                }
            } else {
                // It's a file. Check if we should include it.
                let shouldInclude: Bool
                if isInsideClaude {
                    let ext = itemURL.pathExtension.lowercased()
                    shouldInclude = Self.knownExtensions.contains(ext)
                } else if Self.specialFiles.contains(itemName) {
                    shouldInclude = true
                } else {
                    shouldInclude = false
                }

                if shouldInclude {
                    let fileSize = Int64(resourceValues.fileSize ?? 0)
                    let modDate = resourceValues.contentModificationDate ?? Date.distantPast
                    let isReadOnly = !(resourceValues.isWritable ?? true)

                    var relativePath: String?
                    if let base = claudeBaseURL {
                        let basePath = base.path
                        let filePath = itemURL.path
                        if filePath.hasPrefix(basePath) {
                            var rel = String(filePath.dropFirst(basePath.count))
                            if rel.hasPrefix("/") {
                                rel = String(rel.dropFirst())
                            }
                            relativePath = rel
                        }
                    }

                    let discovered = DiscoveredFile(
                        url: itemURL,
                        name: itemName,
                        size: fileSize,
                        modifiedDate: modDate,
                        isReadOnly: isReadOnly,
                        isInsideClaude: isInsideClaude,
                        claudeRelativePath: relativePath
                    )
                    files.append(discovered)
                }
            }
        }

        return (files, errors)
    }
}
