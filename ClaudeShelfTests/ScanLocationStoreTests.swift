import XCTest
@testable import ClaudeShelf

final class ScanLocationStoreTests: XCTestCase {

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: "scanLocations")
        super.tearDown()
    }

    // MARK: - Load

    func testLoadReturnsDefaultsWhenNoSavedData() {
        UserDefaults.standard.removeObject(forKey: "scanLocations")
        let defaults = [
            ScanLocation(id: UUID(), path: "/tmp/default-a", isEnabled: true, isDefault: true),
            ScanLocation(id: UUID(), path: "/tmp/default-b", isEnabled: true, isDefault: true),
        ]
        let result = ScanLocationStore.load(defaults: defaults)

        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0].path, "/tmp/default-a")
        XCTAssertEqual(result[1].path, "/tmp/default-b")
        XCTAssertTrue(result[0].isEnabled)
        XCTAssertTrue(result[1].isEnabled)
    }

    // MARK: - Save and Load Round Trip

    func testSaveAndLoadRoundTrip() {
        let locations = [ScanLocation(userPath: "/tmp/test-scan")]
        ScanLocationStore.save(locations)

        let loaded = ScanLocationStore.load(defaults: [])
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.path, "/tmp/test-scan")
        XCTAssertFalse(loaded.first?.isDefault ?? true)
        XCTAssertTrue(loaded.first?.isEnabled ?? false)
    }

    // MARK: - Merge Behavior

    func testMergePreservesDisabledState() {
        // Save a default location as disabled
        var location = ScanLocation(id: UUID(), path: "/tmp/default-a", isEnabled: false, isDefault: true)
        location.isEnabled = false
        ScanLocationStore.save([location])

        // Load with merge — the default should stay disabled
        let defaults = [
            ScanLocation(id: UUID(), path: "/tmp/default-a", isEnabled: true, isDefault: true),
        ]
        let loaded = ScanLocationStore.load(defaults: defaults)

        XCTAssertEqual(loaded.count, 1)
        XCTAssertFalse(loaded[0].isEnabled, "User's disabled state should be preserved after merge")
    }

    func testMergeAddsNewDefaults() {
        // Save one default
        let saved = [
            ScanLocation(id: UUID(), path: "/tmp/default-a", isEnabled: true, isDefault: true),
        ]
        ScanLocationStore.save(saved)

        // Load with two defaults — new one should appear
        let defaults = [
            ScanLocation(id: UUID(), path: "/tmp/default-a", isEnabled: true, isDefault: true),
            ScanLocation(id: UUID(), path: "/tmp/default-b", isEnabled: true, isDefault: true),
        ]
        let loaded = ScanLocationStore.load(defaults: defaults)

        XCTAssertEqual(loaded.count, 2)
        XCTAssertEqual(loaded[1].path, "/tmp/default-b")
        XCTAssertTrue(loaded[1].isEnabled, "New default should be enabled")
    }

    func testMergeRetainsCustomLocations() {
        // Save a default + a custom location
        let saved = [
            ScanLocation(id: UUID(), path: "/tmp/default-a", isEnabled: true, isDefault: true),
            ScanLocation(userPath: "/tmp/custom-user-dir"),
        ]
        ScanLocationStore.save(saved)

        // Load with only the default
        let defaults = [
            ScanLocation(id: UUID(), path: "/tmp/default-a", isEnabled: true, isDefault: true),
        ]
        let loaded = ScanLocationStore.load(defaults: defaults)

        XCTAssertEqual(loaded.count, 2)
        XCTAssertEqual(loaded[1].path, "/tmp/custom-user-dir")
        XCTAssertFalse(loaded[1].isDefault)
    }

    // MARK: - ScanLocation Model

    func testUserPathInitializer() {
        let location = ScanLocation(userPath: "/Users/someone/myproject")
        XCTAssertEqual(location.path, "/Users/someone/myproject")
        XCTAssertTrue(location.isEnabled)
        XCTAssertFalse(location.isDefault)
    }

    func testDisplayNameLastComponent() {
        let location = ScanLocation(userPath: "/some/other/directory")
        XCTAssertEqual(location.displayName, "directory")
    }

    func testDisplayNameTildeAbbreviation() {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let location = ScanLocation(userPath: "\(home)/projects")
        XCTAssertEqual(location.displayName, "~/projects")
    }

    func testDisplayNameHomeDirectoryItself() {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let location = ScanLocation(userPath: home)
        XCTAssertEqual(location.displayName, "~")
    }
}
