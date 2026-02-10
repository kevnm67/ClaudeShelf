import Foundation

/// Decodes Claude-encoded project paths and determines file scope.
///
/// Claude encodes project paths as directory names under `~/.claude/projects/`.
/// For example, `~/.claude/projects/-home-user-Projects-MyApp/` encodes the
/// project path `/home/user/Projects/MyApp`, and the project name is "MyApp".
struct PathDecoder: Sendable {

    // MARK: - Constants

    /// Common path segments that are stripped when decoding project names.
    /// These are directory names that typically appear in filesystem paths
    /// but do not represent meaningful project names.
    private static let commonPrefixes: Set<String> = [
        "home", "Users", "user", "Documents", "Desktop",
        "Projects", "projects", "src", "dev", "code",
        "workspace", "repos", "Github", "github", "Repos",
    ]

    // MARK: - Project Name Decoding

    /// Extracts a human-readable project name from a Claude-encoded path segment.
    ///
    /// Claude encodes absolute paths by replacing `/` with `-`. This method
    /// splits on `-`, strips common path prefixes and single-character segments
    /// (like drive letters), and returns the last meaningful segment.
    ///
    /// - Parameter encodedPath: The encoded directory name
    ///   (e.g., "-home-user-Projects-MyApp").
    /// - Returns: The decoded project name (e.g., "MyApp"), or nil if no
    ///   meaningful name can be extracted.
    static func decodeProjectName(from encodedPath: String) -> String? {
        // Split on "-" which Claude uses as the path separator.
        let segments = encodedPath.split(separator: "-", omittingEmptySubsequences: true)

        // Filter out common prefixes and single-character segments (drive letters).
        let meaningful = segments.filter { segment in
            let s = String(segment)
            if s.count <= 1 { return false }
            if commonPrefixes.contains(s) { return false }
            return true
        }

        // Return the last meaningful segment as the project name.
        guard let last = meaningful.last else { return nil }
        return String(last)
    }

    // MARK: - Scope Detection

    /// Determines whether a file is global or project-scoped and extracts
    /// the project name if applicable.
    ///
    /// - Parameters:
    ///   - path: The absolute path of the file.
    ///   - homeDirectory: The user's home directory path (without trailing slash).
    /// - Returns: A tuple of the detected scope and optional project name.
    static func detectScope(
        for path: String,
        homeDirectory: String
    ) -> (scope: Scope, project: String?) {
        let home = homeDirectory.hasSuffix("/")
            ? String(homeDirectory.dropLast())
            : homeDirectory

        let claudeBase = "\(home)/.claude/"
        let projectsBase = "\(home)/.claude/projects/"

        // Case 1: Inside ~/.claude/projects/ — project scope with encoded name.
        if path.hasPrefix(projectsBase) {
            let afterProjects = String(path.dropFirst(projectsBase.count))
            // The encoded directory name is the first path component.
            let components = afterProjects.split(
                separator: "/",
                omittingEmptySubsequences: true
            )
            if let encodedDir = components.first {
                let projectName = decodeProjectName(from: String(encodedDir))
                return (.project, projectName)
            }
            return (.project, nil)
        }

        // Case 2: Inside ~/.claude/ (but not projects/) — global scope.
        if path.hasPrefix(claudeBase) {
            return (.global, nil)
        }

        // Case 3: Contains /.claude/ elsewhere — project scope,
        //         extract project name from the parent of .claude.
        if let claudeRange = path.range(of: "/.claude/") {
            let parentPath = String(path[..<claudeRange.lowerBound])
            let parentName = (parentPath as NSString).lastPathComponent
            if !parentName.isEmpty {
                return (.project, parentName)
            }
            return (.project, nil)
        }

        // Case 4: CLAUDE.md not inside .claude — project scope,
        //         extract project name from parent directory.
        let fileName = (path as NSString).lastPathComponent
        if fileName == "CLAUDE.md" {
            let parentDir = (path as NSString).deletingLastPathComponent
            let projectName = (parentDir as NSString).lastPathComponent
            if !projectName.isEmpty && projectName != "/" {
                return (.project, projectName)
            }
        }

        // Default: global scope.
        return (.global, nil)
    }

    // MARK: - Display Name

    /// Creates a display name for a file, optionally prefixed with the project name.
    ///
    /// - Parameters:
    ///   - file: The filename (e.g., "CLAUDE.md").
    ///   - project: The decoded project name, or nil for global files.
    /// - Returns: A display string (e.g., "MyApp/CLAUDE.md" or "CLAUDE.md").
    static func displayName(for file: String, project: String?) -> String {
        if let project {
            return "\(project)/\(file)"
        }
        return file
    }
}
