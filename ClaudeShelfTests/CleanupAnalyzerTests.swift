import XCTest
@testable import ClaudeShelf

final class CleanupAnalyzerTests: XCTestCase {

    // MARK: - Helpers

    /// Creates a FileEntry with test data. Uses generic paths to avoid filesystem access.
    private func makeFileEntry(
        id: String = "test-id",
        name: String = "test.md",
        path: String = "/tmp/test.md",
        size: Int64 = 100,
        modifiedDate: Date = Date(),
        category: ClaudeShelf.Category = .other
    ) -> FileEntry {
        FileEntry(
            id: id,
            name: name,
            path: path,
            displayName: name,
            category: category,
            scope: .project,
            project: "TestProject",
            size: size,
            modifiedDate: modifiedDate,
            isReadOnly: false
        )
    }

    // MARK: - Empty File Detection

    func testEmptyFileDetected() {
        let file = makeFileEntry(id: "f1", size: 0)
        let items = CleanupAnalyzer.analyze(files: [file])

        let emptyItems = items.filter { $0.reason == .emptyFile }
        XCTAssertEqual(emptyItems.count, 1)
        XCTAssertEqual(emptyItems.first?.id, "f1-empty")
        XCTAssertEqual(emptyItems.first?.detail, "File is empty (0 bytes)")
    }

    func testNonEmptyFileNotFlaggedAsEmpty() {
        let file = makeFileEntry(id: "f2", size: 512)
        let items = CleanupAnalyzer.analyze(files: [file])

        let emptyItems = items.filter { $0.reason == .emptyFile }
        XCTAssertTrue(emptyItems.isEmpty)
    }

    // MARK: - Empty Content Detection

    func testEmptyContentWhitespace() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let path = tempDir.appendingPathComponent("whitespace.md").path
        try "   \n  \t  ".write(toFile: path, atomically: true, encoding: .utf8)
        let size = try FileManager.default.attributesOfItem(atPath: path)[.size] as! Int64

        let file = makeFileEntry(id: "ws1", path: path, size: size)
        let items = CleanupAnalyzer.analyze(files: [file])

        let contentItems = items.filter { $0.reason == .emptyContent }
        XCTAssertEqual(contentItems.count, 1)
        XCTAssertEqual(contentItems.first?.detail, "File contains only whitespace")
    }

    func testEmptyContentEmptyArray() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let path = tempDir.appendingPathComponent("array.json").path
        try "[]".write(toFile: path, atomically: true, encoding: .utf8)
        let size = try FileManager.default.attributesOfItem(atPath: path)[.size] as! Int64

        let file = makeFileEntry(id: "arr1", path: path, size: size)
        let items = CleanupAnalyzer.analyze(files: [file])

        let contentItems = items.filter { $0.reason == .emptyContent }
        XCTAssertEqual(contentItems.count, 1)
        XCTAssertEqual(contentItems.first?.detail, "File contains only \"[]\"")
    }

    func testEmptyContentEmptyObject() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let path = tempDir.appendingPathComponent("object.json").path
        try "{}".write(toFile: path, atomically: true, encoding: .utf8)
        let size = try FileManager.default.attributesOfItem(atPath: path)[.size] as! Int64

        let file = makeFileEntry(id: "obj1", path: path, size: size)
        let items = CleanupAnalyzer.analyze(files: [file])

        let contentItems = items.filter { $0.reason == .emptyContent }
        XCTAssertEqual(contentItems.count, 1)
        XCTAssertEqual(contentItems.first?.detail, "File contains only \"{}\"")
    }

    func testEmptyContentNull() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let path = tempDir.appendingPathComponent("null.json").path
        try "null".write(toFile: path, atomically: true, encoding: .utf8)
        let size = try FileManager.default.attributesOfItem(atPath: path)[.size] as! Int64

        let file = makeFileEntry(id: "null1", path: path, size: size)
        let items = CleanupAnalyzer.analyze(files: [file])

        let contentItems = items.filter { $0.reason == .emptyContent }
        XCTAssertEqual(contentItems.count, 1)
        XCTAssertEqual(contentItems.first?.detail, "File contains only \"null\"")
    }

    func testNonEmptyContentNotFlagged() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let path = tempDir.appendingPathComponent("real.md").path
        try "# Real content here".write(toFile: path, atomically: true, encoding: .utf8)
        let size = try FileManager.default.attributesOfItem(atPath: path)[.size] as! Int64

        let file = makeFileEntry(id: "real1", path: path, size: size)
        let items = CleanupAnalyzer.analyze(files: [file])

        let contentItems = items.filter { $0.reason == .emptyContent }
        XCTAssertTrue(contentItems.isEmpty)
    }

    // MARK: - Large File Skips Content Check

    func testLargeFileSkipsContentCheck() {
        // File size >= 1024 should not be checked for empty content
        let file = makeFileEntry(id: "big1", path: "/tmp/nonexistent-big-file.md", size: 1024)
        let items = CleanupAnalyzer.analyze(files: [file])

        let contentItems = items.filter { $0.reason == .emptyContent }
        XCTAssertTrue(contentItems.isEmpty, "Files >= 1024 bytes should not be checked for empty content")
    }

    // MARK: - Stale File Detection

    func testStaleFileDetected() {
        let staleDate = Date().addingTimeInterval(-(31 * 24 * 60 * 60)) // 31 days ago
        let file = makeFileEntry(id: "stale1", size: 100, modifiedDate: staleDate)
        let items = CleanupAnalyzer.analyze(files: [file])

        let staleItems = items.filter { $0.reason == .stale }
        XCTAssertEqual(staleItems.count, 1)
        XCTAssertTrue(staleItems.first?.detail.contains("31") ?? false)
    }

    func testRecentFileNotFlaggedAsStale() {
        let recentDate = Date().addingTimeInterval(-(5 * 24 * 60 * 60)) // 5 days ago
        let file = makeFileEntry(id: "recent1", size: 100, modifiedDate: recentDate)
        let items = CleanupAnalyzer.analyze(files: [file])

        let staleItems = items.filter { $0.reason == .stale }
        XCTAssertTrue(staleItems.isEmpty)
    }

    func testJustUnder30DaysNotStale() {
        // 29 days should NOT be flagged (threshold is > 30 days)
        let borderDate = Date().addingTimeInterval(-(29 * 24 * 60 * 60))
        let file = makeFileEntry(id: "border1", size: 100, modifiedDate: borderDate)
        let items = CleanupAnalyzer.analyze(files: [file])

        let staleItems = items.filter { $0.reason == .stale }
        XCTAssertTrue(staleItems.isEmpty)
    }

    // MARK: - Multiple Categories

    func testFileAppearsInMultipleCategories() {
        // A file that is both empty (0 bytes) and stale (31+ days)
        let staleDate = Date().addingTimeInterval(-(31 * 24 * 60 * 60))
        let file = makeFileEntry(id: "multi1", size: 0, modifiedDate: staleDate)
        let items = CleanupAnalyzer.analyze(files: [file])

        let emptyItems = items.filter { $0.reason == .emptyFile }
        let staleItems = items.filter { $0.reason == .stale }
        XCTAssertEqual(emptyItems.count, 1)
        XCTAssertEqual(staleItems.count, 1)
        XCTAssertEqual(items.count, 2) // Two separate items for the same file
    }

    // MARK: - Grouping

    func testGroupedByReason() {
        let staleDate = Date().addingTimeInterval(-(31 * 24 * 60 * 60))
        let emptyFile = makeFileEntry(id: "g1", name: "empty.md", size: 0)
        let staleFile = makeFileEntry(id: "g2", name: "old.md", size: 100, modifiedDate: staleDate)

        let items = CleanupAnalyzer.analyze(files: [emptyFile, staleFile])
        let grouped = CleanupAnalyzer.grouped(items)

        // emptyFile produces .emptyFile and possibly .stale depending on date
        // staleFile produces .stale
        // We know emptyFile is recent, so only .emptyFile
        let reasons = grouped.map(\.reason)
        XCTAssertTrue(reasons.contains(.emptyFile))
        XCTAssertTrue(reasons.contains(.stale))

        // Empty files group should come first in the order
        XCTAssertEqual(grouped.first?.reason, .emptyFile)
    }

    func testGroupedExcludesEmptyReasons() {
        // Only recent, non-empty files — should produce no groups
        let file = makeFileEntry(id: "clean1", size: 100)
        let items = CleanupAnalyzer.analyze(files: [file])
        let grouped = CleanupAnalyzer.grouped(items)

        XCTAssertTrue(grouped.isEmpty)
    }

    // MARK: - Unique Files Deduplication

    func testUniqueFilesDeduplication() {
        let staleDate = Date().addingTimeInterval(-(31 * 24 * 60 * 60))
        // File that is both empty and stale -> two CleanupItems, one unique file
        let file = makeFileEntry(id: "dedup1", size: 0, modifiedDate: staleDate)
        let items = CleanupAnalyzer.analyze(files: [file])

        XCTAssertGreaterThan(items.count, 1, "Should have multiple cleanup items for same file")

        let unique = CleanupAnalyzer.uniqueFiles(from: items)
        XCTAssertEqual(unique.count, 1)
        XCTAssertEqual(unique.first?.id, "dedup1")
    }

    func testUniqueFilesMultipleDistinctFiles() {
        let file1 = makeFileEntry(id: "u1", name: "file1.md", size: 0)
        let file2 = makeFileEntry(id: "u2", name: "file2.md", size: 0)
        let items = CleanupAnalyzer.analyze(files: [file1, file2])

        let emptyItems = items.filter { $0.reason == .emptyFile }
        let unique = CleanupAnalyzer.uniqueFiles(from: emptyItems)
        XCTAssertEqual(unique.count, 2)
    }

    // MARK: - No Files

    func testAnalyzeEmptyInput() {
        let items = CleanupAnalyzer.analyze(files: [])
        XCTAssertTrue(items.isEmpty)
    }
}
