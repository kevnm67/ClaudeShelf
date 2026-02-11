import Foundation
import os

/// Protocol for persistence of scan location configuration.
protocol ScanLocationStoring: Sendable {
    func load(defaults: [ScanLocation]) -> [ScanLocation]
    func save(_ locations: [ScanLocation])
}

/// Persists scan location configuration to UserDefaults.
///
/// Uses a merge-with-defaults strategy: default locations always appear,
/// user customizations (enabled/disabled state, custom locations) are preserved.
struct ScanLocationStore: ScanLocationStoring, @unchecked Sendable {
    private let userDefaults: UserDefaults
    private let key = "scanLocations"
    private static let logger = Logger(
        subsystem: "com.claudeshelf.app",
        category: "ScanLocationStore"
    )

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

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
    func load(defaults: [ScanLocation]) -> [ScanLocation] {
        guard let data = userDefaults.data(forKey: key),
              let saved = try? JSONDecoder().decode([ScanLocation].self, from: data) else {
            Self.logger.debug("No saved scan locations found, returning defaults")
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

        Self.logger.debug("Loaded \(result.count) scan locations (\(defaults.count) defaults + \(result.count - defaults.count) custom)")
        return result
    }

    /// Saves scan locations to UserDefaults.
    ///
    /// - Parameter locations: The complete list of scan locations to persist.
    func save(_ locations: [ScanLocation]) {
        guard let data = try? JSONEncoder().encode(locations) else {
            Self.logger.error("Failed to encode scan locations")
            return
        }
        userDefaults.set(data, forKey: key)
        Self.logger.debug("Saved \(locations.count) scan locations")
    }
}
