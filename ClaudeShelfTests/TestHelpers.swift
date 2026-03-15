import Foundation
import XCTest
@testable import ClaudeShelf

// MARK: - FileEntry Factory

/// Shared helper for creating FileEntry instances in tests.
/// Avoids duplicating makeEntry/makeFileEntry helpers across test files.
enum TestFileEntryFactory {

    /// Creates a FileEntry with sensible defaults for testing.
    ///
    /// - Parameters:
    ///   - id: Unique identifier. Defaults to auto-generated from `path`.
    ///   - name: The filename. Defaults to "test.md".
    ///   - path: The absolute path. Defaults to "/Users/testuser/test.md".
    ///   - displayName: Display name. Defaults to `name`.
    ///   - category: File category. Defaults to `.other`.
    ///   - scope: File scope. Defaults to `.project`.
    ///   - project: Project name. Defaults to "TestProject".
    ///   - size: File size in bytes. Defaults to 100.
    ///   - modifiedDate: Modification date. Defaults to now.
    ///   - isReadOnly: Read-only flag. Defaults to false.
    static func make(
        id: String? = nil,
        name: String = "test.md",
        path: String = "/Users/testuser/test.md",
        displayName: String? = nil,
        category: ClaudeShelf.Category = .other,
        scope: Scope = .project,
        project: String? = "TestProject",
        size: Int64 = 100,
        modifiedDate: Date = Date(),
        isReadOnly: Bool = false
    ) -> FileEntry {
        FileEntry(
            id: id ?? FileEntry.generateID(from: path),
            name: name,
            path: path,
            displayName: displayName ?? name,
            category: category,
            scope: scope,
            project: project,
            size: size,
            modifiedDate: modifiedDate,
            isReadOnly: isReadOnly
        )
    }
}

// MARK: - Temporary Directory Test Case

/// Base class for tests that need a temporary directory.
/// Handles creation in setUp and cleanup in tearDown.
class TempDirectoryTestCase: XCTestCase {
    var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(type(of: self))-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    /// Creates a file at the given path relative to tempDir.
    func createFile(_ relativePath: String, content: String = "test") {
        let fileURL = tempDir.appendingPathComponent(relativePath)
        let dir = fileURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try? content.write(to: fileURL, atomically: true, encoding: .utf8)
    }
}

// MARK: - Mock ScanLocationStore

/// In-memory implementation of ScanLocationStoring for testing.
/// Marked @unchecked Sendable because mutable state is only accessed
/// from the @MainActor test context (single-threaded test execution).
final class MockScanLocationStore: ScanLocationStoring, @unchecked Sendable {
    private(set) var stored: [ScanLocation]?
    private(set) var saveCallCount = 0

    func load(defaults: [ScanLocation]) -> [ScanLocation] {
        stored ?? defaults
    }

    func save(_ locations: [ScanLocation]) {
        stored = locations
        saveCallCount += 1
    }
}
