import SwiftUI
import os

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

    /// The file scanner actor used to discover Claude configuration files.
    private let scanner = FileScanner()

    /// Logger for internal diagnostics.
    private static let logger = Logger(
        subsystem: "com.claudeshelf.app",
        category: "AppState"
    )

    /// Performs a full scan of all enabled locations.
    ///
    /// The scan runs on the ``FileScanner`` actor (off the main thread)
    /// and populates ``files`` on completion. Concurrent scans are
    /// prevented by checking ``isScanning``.
    func performScan() async {
        guard !isScanning else { return }
        isScanning = true
        errorMessage = nil

        let result = await scanner.scan(locations: scanLocations)

        files = result.files
        lastScanDate = result.scanDate
        isScanning = false

        Self.logger.info("Scan completed: \(result.files.count) files in \(String(format: "%.2f", result.duration))s")

        if !result.errors.isEmpty {
            Self.logger.warning("Scan encountered \(result.errors.count) error(s)")
            for error in result.errors {
                Self.logger.debug("Scan error: \(error, privacy: .private)")
            }
            // Show user-friendly message, don't expose raw paths
            errorMessage = "Some locations could not be scanned. \(result.errors.count) error(s) occurred."
        }
    }

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
