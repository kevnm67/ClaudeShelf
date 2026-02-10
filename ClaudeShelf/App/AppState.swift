import SwiftUI

/// Central MVVM state container for the ClaudeShelf app.
///
/// AppState holds all shared application state and exposes computed
/// properties for filtered/aggregated views of that state. It uses
/// the Observation framework (@Observable) for efficient SwiftUI
/// updates and is confined to the main actor for thread safety.
@Observable
@MainActor
final class AppState {
    /// All Claude configuration files discovered by the scanner.
    var files: [FileEntry] = []

    /// The currently selected category filter, or nil for "all".
    var selectedCategory: Category? = nil

    /// The currently selected file for editing, or nil.
    var selectedFile: FileEntry? = nil

    /// The current search query text.
    var searchText: String = ""

    /// Whether a scan is currently in progress.
    var isScanning: Bool = false

    /// The configured scan locations.
    var scanLocations: [ScanLocation] = ScanLocation.defaultLocations

    /// When the last scan completed, or nil if no scan has run.
    var lastScanDate: Date? = nil

    /// An error message to display to the user, or nil.
    var errorMessage: String? = nil

    /// Files filtered by the current category selection and search text.
    var filteredFiles: [FileEntry] {
        var result = files
        if let category = selectedCategory {
            result = result.filter { $0.category == category }
        }
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter {
                $0.name.lowercased().contains(query) ||
                $0.displayName.lowercased().contains(query) ||
                $0.path.lowercased().contains(query) ||
                ($0.project?.lowercased().contains(query) ?? false)
            }
        }
        return result
    }

    /// Number of files in each category.
    var categoryCounts: [Category: Int] {
        Dictionary(grouping: files, by: \.category).mapValues(\.count)
    }

    /// Total file size (in bytes) per category.
    var categorySizes: [Category: Int64] {
        Dictionary(grouping: files, by: \.category).mapValues { entries in
            entries.reduce(0) { $0 + $1.size }
        }
    }
}
