import Foundation

/// A filesystem location to scan for Claude configuration files.
struct ScanLocation: Identifiable, Hashable, Sendable, Codable {
    /// Unique identifier for this scan location.
    let id: UUID

    /// Absolute filesystem path to scan.
    let path: String

    /// Whether this location is included in scans.
    var isEnabled: Bool

    /// Whether this is a built-in default location (true) or user-added (false).
    let isDefault: Bool

    /// A short display name for the location.
    ///
    /// Returns a tilde-abbreviated path for the home directory,
    /// or just the last path component for other paths.
    var displayName: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if path == home {
            return "~"
        }
        if path.hasPrefix(home) {
            return "~" + path.dropFirst(home.count)
        }
        return (path as NSString).lastPathComponent
    }

    /// Memberwise initializer.
    ///
    /// - Parameters:
    ///   - id: Unique identifier.
    ///   - path: Absolute filesystem path.
    ///   - isEnabled: Whether this location is included in scans.
    ///   - isDefault: Whether this is a built-in default location.
    init(id: UUID, path: String, isEnabled: Bool, isDefault: Bool) {
        self.id = id
        self.path = path
        self.isEnabled = isEnabled
        self.isDefault = isDefault
    }

    /// Creates a user-added scan location.
    ///
    /// - Parameter userPath: The absolute filesystem path to scan.
    init(userPath: String) {
        self.id = UUID()
        self.path = userPath
        self.isEnabled = true
        self.isDefault = false
    }

    /// The 8 default scan locations from the project specification.
    ///
    /// These correspond to the standard directories where Claude
    /// configuration files are typically found.
    static let defaultLocations: [ScanLocation] = {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let paths = [
            "\(home)/.claude",
            "\(home)/projects",
            "\(home)/src",
            "\(home)/dev",
            "\(home)/code",
            "\(home)/workspace",
            "\(home)/repos",
            home,
        ]
        return paths.map { path in
            ScanLocation(
                id: UUID(),
                path: path,
                isEnabled: true,
                isDefault: true
            )
        }
    }()
}
