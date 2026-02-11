import XCTest
@testable import ClaudeShelf

/// In-memory implementation of ScanLocationStoring for testing.
/// Avoids polluting UserDefaults.
///
/// Marked @unchecked Sendable because mutable state is only accessed
/// from the @MainActor test context (single-threaded test execution).
private final class MockScanLocationStore: ScanLocationStoring, @unchecked Sendable {
    private var stored: [ScanLocation]?

    func load(defaults: [ScanLocation]) -> [ScanLocation] {
        stored ?? defaults
    }

    func save(_ locations: [ScanLocation]) {
        stored = locations
    }
}

/// Alias to disambiguate ClaudeShelf.Category from ObjC Category typedef.
private typealias FileCategory = ClaudeShelf.Category

@MainActor
final class AppStateTests: XCTestCase {

    private var store: MockScanLocationStore!
    private var appState: AppState!

    override func setUp() {
        super.setUp()
        store = MockScanLocationStore()
        appState = AppState(store: store)
    }

    // MARK: - Helpers

    private func makeEntry(
        name: String = "test.md",
        path: String = "/tmp/test.md",
        category: FileCategory = .projectConfig,
        scope: Scope = .global
    ) -> FileEntry {
        FileEntry(
            id: FileEntry.generateID(from: path),
            name: name,
            path: path,
            displayName: name,
            category: category,
            scope: scope,
            project: nil,
            size: 100,
            modifiedDate: Date(),
            isReadOnly: false
        )
    }

    // MARK: - Scan Location Initialization

    func testInitLoadsDefaultScanLocations() {
        XCTAssertEqual(appState.scanLocations.count, ScanLocation.defaultLocations.count)
        let defaultPaths = Set(ScanLocation.defaultLocations.map(\.path))
        let loadedPaths = Set(appState.scanLocations.map(\.path))
        XCTAssertEqual(defaultPaths, loadedPaths)
    }

    // MARK: - Add / Remove / Toggle Scan Locations

    func testAddScanLocationAppendsAndSaves() {
        let initialCount = appState.scanLocations.count
        appState.addScanLocation(path: "/tmp/custom-scan-\(UUID().uuidString)")
        XCTAssertEqual(appState.scanLocations.count, initialCount + 1)
    }

    func testAddDuplicateScanLocationIgnored() {
        let path = "/tmp/custom-scan-\(UUID().uuidString)"
        appState.addScanLocation(path: path)
        let countAfterFirst = appState.scanLocations.count
        appState.addScanLocation(path: path)
        XCTAssertEqual(appState.scanLocations.count, countAfterFirst, "Adding duplicate path should be silently ignored")
    }

    func testRemoveScanLocationOnlyCustom() {
        let path = "/tmp/custom-scan-\(UUID().uuidString)"
        appState.addScanLocation(path: path)
        let defaultCount = ScanLocation.defaultLocations.count

        guard let customLocation = appState.scanLocations.first(where: { $0.path == path }) else {
            XCTFail("Custom location not found after adding")
            return
        }

        appState.removeScanLocation(id: customLocation.id)
        XCTAssertEqual(appState.scanLocations.count, defaultCount, "After removing custom location, only defaults should remain")
    }

    func testRemoveDefaultLocationIgnored() {
        let initialCount = appState.scanLocations.count
        guard let defaultLocation = appState.scanLocations.first(where: { $0.isDefault }) else {
            XCTFail("No default location found")
            return
        }
        appState.removeScanLocation(id: defaultLocation.id)
        XCTAssertEqual(appState.scanLocations.count, initialCount, "Removing a default location should be a no-op")
    }

    func testToggleScanLocationFlipsEnabled() {
        guard let firstLocation = appState.scanLocations.first else {
            XCTFail("No scan locations found")
            return
        }
        let wasEnabled = firstLocation.isEnabled
        appState.toggleScanLocation(id: firstLocation.id)
        let toggled = appState.scanLocations.first(where: { $0.id == firstLocation.id })
        XCTAssertEqual(toggled?.isEnabled, !wasEnabled)
    }

    // MARK: - Filtering

    func testFilteredFilesByCategory() {
        let settingsEntry = makeEntry(name: "settings.json", path: "/tmp/a.json", category: .settings)
        let memoryEntry = makeEntry(name: "memory.md", path: "/tmp/b.md", category: .memory)
        let agentsEntry = makeEntry(name: "agent.yml", path: "/tmp/c.yml", category: .agents)
        appState.files = [settingsEntry, memoryEntry, agentsEntry]

        appState.selectedCategory = .settings
        let filtered = appState.filteredFiles
        XCTAssertEqual(filtered.count, 1)
        XCTAssertEqual(filtered.first?.category, .settings)
    }

    func testFilteredFilesBySearchText() {
        let claudeEntry = makeEntry(name: "CLAUDE.md", path: "/tmp/claude.md", category: .projectConfig)
        let settingsEntry = makeEntry(name: "settings.json", path: "/tmp/settings.json", category: .settings)
        appState.files = [claudeEntry, settingsEntry]

        appState.searchText = "claude"
        let filtered = appState.filteredFiles
        XCTAssertEqual(filtered.count, 1)
        XCTAssertEqual(filtered.first?.name, "CLAUDE.md")
    }

    func testCategoryCountsComputed() {
        let entry1 = makeEntry(name: "a.json", path: "/tmp/a.json", category: .settings)
        let entry2 = makeEntry(name: "b.json", path: "/tmp/b.json", category: .settings)
        let entry3 = makeEntry(name: "c.md", path: "/tmp/c.md", category: .memory)
        appState.files = [entry1, entry2, entry3]

        let counts = appState.categoryCounts
        XCTAssertEqual(counts[.settings], 2)
        XCTAssertEqual(counts[.memory], 1)
        XCTAssertNil(counts[.agents], "Categories with 0 files should not appear in counts")
    }

    // MARK: - Bulk Selection

    func testBulkSelectionToggle() {
        let entry = makeEntry()
        appState.files = [entry]

        appState.toggleFileSelection(entry.id)
        XCTAssertTrue(appState.selectedFileIDs.contains(entry.id))

        appState.toggleFileSelection(entry.id)
        XCTAssertFalse(appState.selectedFileIDs.contains(entry.id))
    }

    func testSelectAllFiltered() {
        let entry1 = makeEntry(name: "a.md", path: "/tmp/a.md", category: .settings)
        let entry2 = makeEntry(name: "b.md", path: "/tmp/b.md", category: .settings)
        let entry3 = makeEntry(name: "c.md", path: "/tmp/c.md", category: .memory)
        appState.files = [entry1, entry2, entry3]

        appState.selectedCategory = .settings
        appState.selectAllFiltered()

        XCTAssertEqual(appState.selectedFileIDs.count, 2)
        XCTAssertTrue(appState.selectedFileIDs.contains(entry1.id))
        XCTAssertTrue(appState.selectedFileIDs.contains(entry2.id))
        XCTAssertFalse(appState.selectedFileIDs.contains(entry3.id))
    }

    func testClearSelectionResetsMode() {
        let entry = makeEntry()
        appState.files = [entry]
        appState.isBulkSelectionMode = true
        appState.toggleFileSelection(entry.id)

        appState.clearSelection()

        XCTAssertTrue(appState.selectedFileIDs.isEmpty)
        XCTAssertFalse(appState.isBulkSelectionMode)
    }

    func testRemoveFilesClearsFromSelection() {
        let entry1 = makeEntry(name: "a.md", path: "/tmp/a.md")
        let entry2 = makeEntry(name: "b.md", path: "/tmp/b.md")
        appState.files = [entry1, entry2]
        appState.toggleFileSelection(entry1.id)
        appState.toggleFileSelection(entry2.id)

        appState.removeFiles([entry1])

        XCTAssertEqual(appState.files.count, 1)
        XCTAssertEqual(appState.files.first?.id, entry2.id)
        XCTAssertFalse(appState.selectedFileIDs.contains(entry1.id), "Removed file should be cleared from selection")
        XCTAssertTrue(appState.selectedFileIDs.contains(entry2.id), "Non-removed file should remain selected")
    }
}
