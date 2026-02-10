import Foundation
import os

/// Persists scan location configuration to UserDefaults.
///
/// Uses a merge-with-defaults strategy: default locations always appear,
/// user customizations (enabled/disabled state, custom locations) are preserved.
enum ScanLocationStore {
    private static let logger = Logger(
        subsystem: "com.claudeshelf.app",
        category: "ScanLocationStore"
    )
    private static let key = "scanLocations"

    /// Loads scan locations, merging saved state with current defaults.
    ///
    /// The merge strategy ensures that:
    /// - All default locations are always present
    /// - The user's enabled/disabled preferences for defaults are preserved
    /// - Any new default locations added in an app update appear automatically
    /// - User-added custom locations are retained
    ///
    /// - Parameter defaults: The current set of default scan locations.
    /// - Returns: Merged scan locations combining defaults with saved state.
    static func load(defaults: [ScanLocation]) -> [ScanLocation] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let saved = try? JSONDecoder().decode([ScanLocation].self, from: data) else {
            logger.debug("No saved scan locations found, returning defaults")
            return defaults
        }

        // Build a lookup from saved locations by path
        let savedByPath = Dictionary(
            saved.map { ($0.path, $0) },
            uniquingKeysWith: { _, last in last }
        )

        // Merge: keep user's enabled/disabled state for defaults, include new defaults
        var result: [ScanLocation] = []
        for var defaultLoc in defaults {
            if let savedLoc = savedByPath[defaultLoc.path] {
                defaultLoc.isEnabled = savedLoc.isEnabled
            }
            result.append(defaultLoc)
        }

        // Add user-added (non-default) locations
        let defaultPaths = Set(defaults.map(\.path))
        for savedLoc in saved where !defaultPaths.contains(savedLoc.path) {
            result.append(savedLoc)
        }

        logger.debug("Loaded \(result.count) scan locations (\(defaults.count) defaults + \(result.count - defaults.count) custom)")
        return result
    }

    /// Saves scan locations to UserDefaults.
    ///
    /// - Parameter locations: The complete list of scan locations to persist.
    static func save(_ locations: [ScanLocation]) {
        guard let data = try? JSONEncoder().encode(locations) else {
            logger.error("Failed to encode scan locations")
            return
        }
        UserDefaults.standard.set(data, forKey: key)
        logger.debug("Saved \(locations.count) scan locations")
    }
}
