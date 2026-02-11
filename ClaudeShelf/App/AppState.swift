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

    /// Backing storage for the currently selected file.
    private var _selectedFile: FileEntry? = nil

    /// The currently selected file for editing, or nil.
    ///
    /// When set, refreshes the file's metadata (size, modification date,
    /// read-only status) from disk to prevent showing stale information.
    var selectedFile: FileEntry? {
        get { _selectedFile }
        set {
            if let file = newValue {
                let refreshed = refreshFileMetadata(for: file)
                _selectedFile = refreshed
                // Update the corresponding entry in the files array if metadata changed
                if refreshed != file, let index = files.firstIndex(where: { $0.id == file.id }) {
                    files[index] = refreshed
                }
            } else {
                _selectedFile = nil
            }
        }
    }

    /// The current search query text.
    var searchText: String = ""

    /// Whether a scan is currently in progress.
    var isScanning: Bool = false

    /// The configured scan locations (loaded from persisted state on init).
    var scanLocations: [ScanLocation]

    /// When the last scan completed, or nil if no scan has run.
    var lastScanDate: Date? = nil

    /// An error message to display to the user, or nil.
    var errorMessage: String? = nil

    // MARK: - Bulk Selection

    /// The IDs of files currently selected for bulk operations.
    var selectedFileIDs: Set<String> = []

    /// Whether the user is in bulk selection mode.
    var isBulkSelectionMode: Bool = false

    /// The file scanner actor used to discover Claude configuration files.
    private let scanner = FileScanner()

    /// The file watcher actor that monitors directories for changes.
    private let fileWatcher = FileWatcher()

    /// Logger for internal diagnostics.
    private static let logger = Logger(
        subsystem: "com.claudeshelf.app",
        category: "AppState"
    )

    /// The store used to persist scan location configuration.
    private let store: ScanLocationStoring

    // MARK: - Initialization

    init(store: ScanLocationStoring = ScanLocationStore()) {
        self.store = store
        self.scanLocations = store.load(defaults: ScanLocation.defaultLocations)
    }

    // MARK: - Scan Location Management

    /// Adds a user-specified directory as a new scan location.
    ///
    /// Duplicate paths are silently ignored.
    ///
    /// - Parameter path: Absolute filesystem path to add.
    func addScanLocation(path: String) {
        guard !scanLocations.contains(where: { $0.path == path }) else { return }
        let location = ScanLocation(userPath: path)
        scanLocations.append(location)
        saveScanLocations()
    }

    /// Removes a user-added scan location by ID.
    ///
    /// Default (built-in) locations cannot be removed; they can only be disabled.
    ///
    /// - Parameter id: The UUID of the location to remove.
    func removeScanLocation(id: UUID) {
        guard let loc = scanLocations.first(where: { $0.id == id }),
              !loc.isDefault else { return }
        scanLocations.removeAll { $0.id == id }
        saveScanLocations()
    }

    /// Toggles the enabled state of a scan location.
    ///
    /// - Parameter id: The UUID of the location to toggle.
    func toggleScanLocation(id: UUID) {
        guard let index = scanLocations.firstIndex(where: { $0.id == id }) else { return }
        scanLocations[index].isEnabled.toggle()
        saveScanLocations()
    }

    /// Persists current scan locations to UserDefaults.
    private func saveScanLocations() {
        store.save(scanLocations)
    }

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

    /// Starts file watching on all enabled scan locations.
    func startFileWatching() async {
        let directories = scanLocations
            .filter(\.isEnabled)
            .map(\.path)
        await fileWatcher.start(directories: directories) { [weak self] in
            await self?.performScan()
        }
    }

    /// Stops file watching.
    func stopFileWatching() async {
        await fileWatcher.stop()
    }

    /// Restarts file watching (e.g., after scan locations change).
    func restartFileWatching() async {
        await stopFileWatching()
        await startFileWatching()
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

    // MARK: - Bulk Selection

    /// Toggles selection state for a file ID in bulk mode.
    func toggleFileSelection(_ fileID: String) {
        if selectedFileIDs.contains(fileID) {
            selectedFileIDs.remove(fileID)
        } else {
            selectedFileIDs.insert(fileID)
        }
    }

    /// Selects all files that match the current filter.
    func selectAllFiltered() {
        selectedFileIDs = Set(filteredFiles.map(\.id))
    }

    /// Clears all selected IDs and exits bulk selection mode.
    func clearSelection() {
        selectedFileIDs.removeAll()
        isBulkSelectionMode = false
    }

    /// The FileEntry objects corresponding to the currently selected IDs.
    var selectedFiles: [FileEntry] {
        files.filter { selectedFileIDs.contains($0.id) }
    }

    // MARK: - Metadata Refresh

    /// Refreshes a file entry's metadata from disk.
    ///
    /// Performs a lightweight stat() call to re-read size, modification date,
    /// and read-only status. Returns the original entry unchanged if the file
    /// cannot be accessed or if no metadata changed.
    ///
    /// - Parameter file: The file entry to refresh.
    /// - Returns: A new FileEntry with updated metadata, or the original if unchanged.
    private func refreshFileMetadata(for file: FileEntry) -> FileEntry {
        let fm = FileManager.default
        guard let attrs = try? fm.attributesOfItem(atPath: file.path) else { return file }
        let size = attrs[.size] as? Int64 ?? file.size
        let modDate = attrs[.modificationDate] as? Date ?? file.modifiedDate
        let isReadOnly = !fm.isWritableFile(atPath: file.path)
        guard size != file.size || modDate != file.modifiedDate || isReadOnly != file.isReadOnly else {
            return file
        }
        return FileEntry(
            id: file.id,
            name: file.name,
            path: file.path,
            displayName: file.displayName,
            category: file.category,
            scope: file.scope,
            project: file.project,
            size: size,
            modifiedDate: modDate,
            isReadOnly: isReadOnly
        )
    }

    /// Removes entries from the files array, clears them from the selection,
    /// and clears the selected file if it was among the removed entries.
    ///
    /// - Parameter entries: The file entries to remove.
    func removeFiles(_ entries: [FileEntry]) {
        let idsToRemove = Set(entries.map(\.id))
        files.removeAll { idsToRemove.contains($0.id) }
        selectedFileIDs.subtract(idsToRemove)

        if let selected = selectedFile, idsToRemove.contains(selected.id) {
            selectedFile = nil
        }
    }
}
