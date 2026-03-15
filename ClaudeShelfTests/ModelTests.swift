import XCTest
@testable import ClaudeShelf

// MARK: - Category Tests

final class CategoryTests: XCTestCase {

    func testAllCasesCount() {
        XCTAssertEqual(Category.allCases.count, 9, "Should have exactly 9 categories")
    }

    func testIdentifiableID() {
        for category in Category.allCases {
            XCTAssertEqual(category.id, category.rawValue)
        }
    }

    func testDisplayNames() {
        XCTAssertEqual(Category.agents.displayName, "Agents")
        XCTAssertEqual(Category.debug.displayName, "Debug")
        XCTAssertEqual(Category.memory.displayName, "Memory")
        XCTAssertEqual(Category.projectConfig.displayName, "Project Config")
        XCTAssertEqual(Category.settings.displayName, "Settings")
        XCTAssertEqual(Category.todos.displayName, "Todos")
        XCTAssertEqual(Category.plans.displayName, "Plans")
        XCTAssertEqual(Category.skills.displayName, "Skills")
        XCTAssertEqual(Category.other.displayName, "Other")
    }

    func testSFSymbols() {
        // Verify all categories have non-empty SF Symbol names
        for category in Category.allCases {
            XCTAssertFalse(category.sfSymbol.isEmpty, "\(category) should have an SF Symbol")
        }
    }

    func testPrioritiesAreUnique() {
        let priorities = Category.allCases.map(\.priority)
        XCTAssertEqual(Set(priorities).count, priorities.count, "All category priorities should be unique")
    }

    func testPrioritiesAreOrdered() {
        // Agents (1) should have highest priority, Other (9) lowest
        XCTAssertEqual(Category.agents.priority, 1)
        XCTAssertEqual(Category.other.priority, 9)
    }

    func testCodableRoundTrip() throws {
        for category in Category.allCases {
            let data = try JSONEncoder().encode(category)
            let decoded = try JSONDecoder().decode(Category.self, from: data)
            XCTAssertEqual(decoded, category)
        }
    }
}

// MARK: - Scope Tests

final class ScopeTests: XCTestCase {

    func testRawValues() {
        XCTAssertEqual(Scope.global.rawValue, "global")
        XCTAssertEqual(Scope.project.rawValue, "project")
    }

    func testCodableRoundTrip() throws {
        for scope in [Scope.global, Scope.project] {
            let data = try JSONEncoder().encode(scope)
            let decoded = try JSONDecoder().decode(Scope.self, from: data)
            XCTAssertEqual(decoded, scope)
        }
    }
}

// MARK: - CleanupReason Tests

final class CleanupReasonTests: XCTestCase {

    func testRawValues() {
        XCTAssertEqual(CleanupReason.emptyFile.rawValue, "emptyFile")
        XCTAssertEqual(CleanupReason.emptyContent.rawValue, "emptyContent")
        XCTAssertEqual(CleanupReason.stale.rawValue, "stale")
    }

    func testCodableRoundTrip() throws {
        for reason in [CleanupReason.emptyFile, .emptyContent, .stale] {
            let data = try JSONEncoder().encode(reason)
            let decoded = try JSONDecoder().decode(CleanupReason.self, from: data)
            XCTAssertEqual(decoded, reason)
        }
    }
}

// MARK: - CleanupItem Tests

final class CleanupItemTests: XCTestCase {

    func testIdentifiable() {
        let file = TestFileEntryFactory.make()
        let item = CleanupItem(id: "test-empty", file: file, reason: .emptyFile, detail: "test detail")
        XCTAssertEqual(item.id, "test-empty")
    }

    func testPropertiesStored() {
        let file = TestFileEntryFactory.make(name: "config.json")
        let item = CleanupItem(id: "item-1", file: file, reason: .stale, detail: "Not modified in 45 days")

        XCTAssertEqual(item.file.name, "config.json")
        XCTAssertEqual(item.reason, .stale)
        XCTAssertEqual(item.detail, "Not modified in 45 days")
    }
}

// MARK: - ScanResult Tests

final class ScanResultTests: XCTestCase {

    func testPropertiesStored() {
        let file = TestFileEntryFactory.make()
        let date = Date()
        let result = ScanResult(files: [file], scanDate: date, duration: 1.5, errors: ["test error"])

        XCTAssertEqual(result.files.count, 1)
        XCTAssertEqual(result.scanDate, date)
        XCTAssertEqual(result.duration, 1.5, accuracy: 0.001)
        XCTAssertEqual(result.errors, ["test error"])
    }

    func testEmptyResult() {
        let result = ScanResult(files: [], scanDate: Date(), duration: 0.0, errors: [])
        XCTAssertTrue(result.files.isEmpty)
        XCTAssertTrue(result.errors.isEmpty)
    }
}

// MARK: - FileOperationError Tests

final class FileOperationErrorTests: XCTestCase {

    func testPartialFailureDescription() {
        let error = FileOperationError.partialFailure(succeeded: 3, failed: 2, errors: ["err1", "err2"])
        XCTAssertEqual(error.errorDescription, "3 file(s) processed, 2 file(s) failed")
    }

    func testPartialFailureZeroSucceeded() {
        let error = FileOperationError.partialFailure(succeeded: 0, failed: 5, errors: [])
        XCTAssertEqual(error.errorDescription, "0 file(s) processed, 5 file(s) failed")
    }
}

// MARK: - ScanLocation Tests

final class ScanLocationTests: XCTestCase {

    func testStableUUIDDeterminism() {
        // Default locations should produce the same UUIDs every time
        let locations1 = ScanLocation.defaultLocations
        let locations2 = ScanLocation.defaultLocations
        XCTAssertEqual(locations1.map(\.id), locations2.map(\.id))
    }

    func testDefaultLocationsCount() {
        XCTAssertEqual(ScanLocation.defaultLocations.count, 8, "Should have exactly 8 default scan locations")
    }

    func testDefaultLocationsAllEnabled() {
        for location in ScanLocation.defaultLocations {
            XCTAssertTrue(location.isEnabled, "\(location.path) should be enabled by default")
            XCTAssertTrue(location.isDefault, "\(location.path) should be marked as default")
        }
    }

    func testDefaultLocationsContainExpectedPaths() {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let paths = Set(ScanLocation.defaultLocations.map(\.path))

        XCTAssertTrue(paths.contains("\(home)/.claude"))
        XCTAssertTrue(paths.contains("\(home)/projects"))
        XCTAssertTrue(paths.contains("\(home)/src"))
        XCTAssertTrue(paths.contains(home))
    }

    func testHashable() {
        let loc1 = ScanLocation(userPath: "/tmp/a")
        let loc2 = ScanLocation(userPath: "/tmp/b")
        var set = Set<ScanLocation>()
        set.insert(loc1)
        set.insert(loc2)
        XCTAssertEqual(set.count, 2)
    }

    func testCodableRoundTrip() throws {
        let location = ScanLocation(id: UUID(), path: "/tmp/test", isEnabled: false, isDefault: true)
        let data = try JSONEncoder().encode(location)
        let decoded = try JSONDecoder().decode(ScanLocation.self, from: data)

        XCTAssertEqual(decoded.id, location.id)
        XCTAssertEqual(decoded.path, location.path)
        XCTAssertEqual(decoded.isEnabled, location.isEnabled)
        XCTAssertEqual(decoded.isDefault, location.isDefault)
    }
}

// MARK: - FileEntry Hashable Tests

final class FileEntryHashableTests: XCTestCase {

    func testHashableUsedInSets() {
        // FileEntry uses auto-synthesized Hashable (all properties),
        // so two entries with identical properties are considered equal.
        let fixedDate = Date(timeIntervalSince1970: 1_000_000)
        let entry1 = TestFileEntryFactory.make(path: "/Users/testuser/a.md", modifiedDate: fixedDate)
        let entry2 = TestFileEntryFactory.make(path: "/Users/testuser/b.md", modifiedDate: fixedDate)
        let entry3 = TestFileEntryFactory.make(path: "/Users/testuser/a.md", modifiedDate: fixedDate) // identical to entry1

        var set = Set<FileEntry>()
        set.insert(entry1)
        set.insert(entry2)
        set.insert(entry3)

        XCTAssertEqual(set.count, 2, "Identical entries should deduplicate in a Set")
    }

    func testEqualityByAllProperties() {
        let date = Date(timeIntervalSince1970: 1_000_000)
        let entry1 = TestFileEntryFactory.make(path: "/Users/testuser/a.md", modifiedDate: date)
        let entry2 = TestFileEntryFactory.make(path: "/Users/testuser/a.md", modifiedDate: date)

        XCTAssertEqual(entry1, entry2, "Entries with same properties should be equal")
    }

    func testInequalityByDifferentSize() {
        let date = Date(timeIntervalSince1970: 1_000_000)
        let entry1 = TestFileEntryFactory.make(path: "/Users/testuser/a.md", size: 100, modifiedDate: date)
        let entry2 = TestFileEntryFactory.make(path: "/Users/testuser/a.md", size: 200, modifiedDate: date)

        XCTAssertNotEqual(entry1, entry2, "Entries with different sizes should not be equal")
    }
}
