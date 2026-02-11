import CryptoKit
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
                id: stableUUID(for: path),
                path: path,
                isEnabled: true,
                isDefault: true
            )
        }
    }()

    /// Generates a stable UUID from a string by hashing it with SHA256.
    ///
    /// Uses the first 16 bytes of the SHA256 digest to construct a UUID,
    /// ensuring the same input always produces the same UUID across launches.
    private static func stableUUID(for string: String) -> UUID {
        let data = Data(string.utf8)
        let hash = SHA256.hash(data: data)
        var bytes = Array(hash.prefix(16))
        // Set version 4 (random) and variant 1 bits for RFC 4122 compliance
        bytes[6] = (bytes[6] & 0x0F) | 0x40 // version 4
        bytes[8] = (bytes[8] & 0x3F) | 0x80 // variant 1
        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }
}
