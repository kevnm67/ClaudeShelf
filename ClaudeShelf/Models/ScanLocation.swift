import Foundation

/// A filesystem location to scan for Claude configuration files.
struct ScanLocation: Identifiable, Hashable, Sendable, Codable {
    /// Unique identifier for this scan location.
    let id: UUID

    /// Absolute filesystem path to scan.
    let path: String

    /// Whether this location is included in scans.
    let isEnabled: Bool

    /// Whether this is a built-in default location (true) or user-added (false).
    let isDefault: Bool

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
