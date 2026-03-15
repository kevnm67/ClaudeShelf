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

/// Result of scanning locations for discovered files.
struct ScanLocationResult: Sendable {
    let files: [DiscoveredFile]
    let duration: TimeInterval
    let errors: [String]
}

/// Accumulator for files and errors discovered during a directory scan.
private struct DirectoryScanResult {
    var files: [DiscoveredFile] = []
    var errors: [String] = []
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
        "Library", "Applications", "Pictures", "Music", "Movies",
        "Public", "Downloads", ".Trash",
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
    /// - Returns: A ``ScanLocationResult`` with discovered files, duration, and errors.
    func scanLocations(
        _ locations: [ScanLocation]
    ) async -> ScanLocationResult {
        let startTime = Date()
        var allFiles: [DiscoveredFile] = []
        var allErrors: [String] = []
        var visited = Set<String>()

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

            // Track the scan root to prevent cycles
            let canonicalRoot = directoryURL.resolvingSymlinksInPath().path
            visited.insert(canonicalRoot)

            var dirResult = DirectoryScanResult()
            scanDirectory(
                at: directoryURL,
                currentDepth: 0,
                isInsideClaude: false,
                claudeBaseURL: nil,
                visited: &visited,
                result: &dirResult
            )
            allFiles.append(contentsOf: dirResult.files)
            allErrors.append(contentsOf: dirResult.errors)
        }

        let duration = Date().timeIntervalSince(startTime)
        return ScanLocationResult(files: allFiles, duration: duration, errors: allErrors)
    }

    /// Performs a full scan across all enabled locations and returns categorized
    /// ``FileEntry`` objects with category, scope, and project name assigned.
    ///
    /// This wraps ``scanLocations(_:)`` and converts each ``DiscoveredFile``
    /// into a ``FileEntry`` using ``CategoryAssigner`` and ``PathDecoder``.
    /// Duplicate files (same path found via multiple scan locations) are removed.
    ///
    /// - Parameter locations: The scan locations to enumerate.
    /// - Returns: A ``ScanResult`` containing the discovered file entries.
    func scan(locations: [ScanLocation]) async -> ScanResult {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path

        let scanResult = await scanLocations(locations)

        var entries: [FileEntry] = []
        entries.reserveCapacity(scanResult.files.count)

        for file in scanResult.files {
            let entry = buildFileEntry(from: file, homeDirectory: homeDir)
            entries.append(entry)
        }

        // Deduplicate by path — same file could be found via multiple scan locations.
        var seen = Set<String>()
        entries = entries.filter { seen.insert($0.path).inserted }

        return ScanResult(
            files: entries,
            scanDate: Date(),
            duration: scanResult.duration,
            errors: scanResult.errors
        )
    }

    /// Converts a discovered file into a categorized ``FileEntry``.
    private func buildFileEntry(
        from file: DiscoveredFile,
        homeDirectory: String
    ) -> FileEntry {
        let category = CategoryAssigner.assignCategory(
            fileName: file.name,
            path: file.url.path,
            isInsideClaude: file.isInsideClaude
        )

        let (scope, project) = PathDecoder.detectScope(
            for: file.url.path,
            homeDirectory: homeDirectory
        )

        let displayName = PathDecoder.displayName(
            for: file.name,
            project: project
        )

        return FileEntry(
            id: FileEntry.generateID(from: file.url.path),
            name: file.name,
            path: file.url.path,
            displayName: displayName,
            category: category,
            scope: scope,
            project: project,
            size: file.size,
            modifiedDate: file.modifiedDate,
            isReadOnly: file.isReadOnly
        )
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
    ///   - visited: Set of resolved canonical directory paths to detect symlink cycles.
    ///   - result: Accumulator for discovered files and errors.
    private func scanDirectory(
        at url: URL,
        currentDepth: Int,
        isInsideClaude: Bool,
        claudeBaseURL: URL?,
        visited: inout Set<String>,
        result: inout DirectoryScanResult
    ) {
        let keys: Set<URLResourceKey> = [
            .isDirectoryKey,
            .isSymbolicLinkKey,
            .fileSizeKey,
            .contentModificationDateKey,
            .isWritableKey,
        ]

        let contents: [URL]
        do {
            contents = try FileManager.default.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: Array(keys),
                options: []
            )
        } catch {
            let message = "Failed to read directory \(url.path): \(error.localizedDescription)"
            Self.logger.error("\(message, privacy: .public)")
            result.errors.append(message)
            return
        }

        for itemURL in contents {
            let resourceValues: URLResourceValues
            do {
                resourceValues = try itemURL.resourceValues(forKeys: keys)
            } catch {
                let message = "Failed to read attributes for \(itemURL.path): \(error.localizedDescription)"
                Self.logger.error("\(message, privacy: .public)")
                result.errors.append(message)
                continue
            }

            // Skip symlinks to prevent loops and boundary escape
            if resourceValues.isSymbolicLink ?? false {
                continue
            }

            if resourceValues.isDirectory ?? false {
                recurseIntoDirectory(
                    itemURL,
                    currentDepth: currentDepth,
                    isInsideClaude: isInsideClaude,
                    claudeBaseURL: claudeBaseURL,
                    visited: &visited,
                    result: &result
                )
            } else {
                collectFileIfRecognized(
                    itemURL,
                    resourceValues: resourceValues,
                    isInsideClaude: isInsideClaude,
                    claudeBaseURL: claudeBaseURL,
                    result: &result
                )
            }
        }
    }

    /// Handles recursion into a subdirectory, applying skip and depth rules.
    private func recurseIntoDirectory(
        _ itemURL: URL,
        currentDepth: Int,
        isInsideClaude: Bool,
        claudeBaseURL: URL?,
        visited: inout Set<String>,
        result: inout DirectoryScanResult
    ) {
        let itemName = itemURL.lastPathComponent

        // Skip known noise directories.
        guard !Self.skipDirectories.contains(itemName) else { return }

        // Skip hidden directories except `.claude`.
        guard !itemName.hasPrefix(".") || itemName == ".claude" else { return }

        // Cycle detection: resolve canonical path and skip if already visited
        let canonicalPath = itemURL.resolvingSymlinksInPath().path
        guard !visited.contains(canonicalPath) else {
            return
        }
        visited.insert(canonicalPath)

        if itemName == ".claude" {
            scanDirectory(
                at: itemURL, currentDepth: 0, isInsideClaude: true,
                claudeBaseURL: itemURL, visited: &visited, result: &result
            )
        } else if isInsideClaude {
            scanDirectory(
                at: itemURL, currentDepth: currentDepth + 1, isInsideClaude: true,
                claudeBaseURL: claudeBaseURL, visited: &visited, result: &result
            )
        } else if currentDepth < Self.maxDepth {
            scanDirectory(
                at: itemURL, currentDepth: currentDepth + 1, isInsideClaude: false,
                claudeBaseURL: nil, visited: &visited, result: &result
            )
        }
    }

    /// Checks if a file matches recognition rules and adds it to the result.
    private func collectFileIfRecognized(
        _ itemURL: URL,
        resourceValues: URLResourceValues,
        isInsideClaude: Bool,
        claudeBaseURL: URL?,
        result: inout DirectoryScanResult
    ) {
        let itemName = itemURL.lastPathComponent

        let shouldInclude: Bool = if isInsideClaude {
            Self.knownExtensions.contains(itemURL.pathExtension.lowercased())
        } else {
            Self.specialFiles.contains(itemName)
        }

        guard shouldInclude else { return }

        let relativePath = claudeRelativePath(for: itemURL, claudeBaseURL: claudeBaseURL)

        let discovered = DiscoveredFile(
            url: itemURL,
            name: itemName,
            size: Int64(resourceValues.fileSize ?? 0),
            modifiedDate: resourceValues.contentModificationDate ?? Date.distantPast,
            isReadOnly: !(resourceValues.isWritable ?? true),
            isInsideClaude: isInsideClaude,
            claudeRelativePath: relativePath
        )
        result.files.append(discovered)
    }

    /// Computes the path relative to the `.claude/` base directory.
    private func claudeRelativePath(for itemURL: URL, claudeBaseURL: URL?) -> String? {
        guard let base = claudeBaseURL else { return nil }
        let basePath = base.path
        let filePath = itemURL.path
        guard filePath.hasPrefix(basePath) else { return nil }
        var rel = String(filePath.dropFirst(basePath.count))
        if rel.hasPrefix("/") {
            rel = String(rel.dropFirst())
        }
        return rel
    }
}
