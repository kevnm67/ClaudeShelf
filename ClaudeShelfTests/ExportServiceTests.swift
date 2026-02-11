import XCTest
@testable import ClaudeShelf

final class ExportServiceTests: XCTestCase {

    private var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    func testExportCreatesZipFile() async throws {
        // Create temp source files
        let file1Path = tempDir.appendingPathComponent("test1.md").path
        try "# Test 1".write(toFile: file1Path, atomically: true, encoding: .utf8)
        let file2Path = tempDir.appendingPathComponent("test2.json").path
        try "{}".write(toFile: file2Path, atomically: true, encoding: .utf8)

        let entries = [
            makeEntry(name: "test1.md", path: file1Path),
            makeEntry(name: "test2.json", path: file2Path)
        ]

        let zipPath = tempDir.appendingPathComponent("export.zip").path
        try await ExportService.exportAsZip(files: entries, to: zipPath)

        XCTAssertTrue(FileManager.default.fileExists(atPath: zipPath))
        // Verify it's non-empty
        let attrs = try FileManager.default.attributesOfItem(atPath: zipPath)
        let size = attrs[.size] as? Int ?? 0
        XCTAssertGreaterThan(size, 0)
    }

    func testExportThrowsOnEmptyFiles() async {
        let zipPath = tempDir.appendingPathComponent("empty.zip").path
        do {
            try await ExportService.exportAsZip(files: [], to: zipPath)
            XCTFail("Expected error for empty files")
        } catch {
            // Expected
        }
    }

    func testDefaultFilenameFormat() {
        let name = ExportService.defaultFilename()
        XCTAssertTrue(name.hasPrefix("ClaudeShelf-export-"))
        XCTAssertTrue(name.hasSuffix(".zip"))
    }

    func testExportHandlesNameCollisions() async throws {
        let file1Path = tempDir.appendingPathComponent("config1.json").path
        try "{}".write(toFile: file1Path, atomically: true, encoding: .utf8)
        let file2Path = tempDir.appendingPathComponent("config2.json").path
        try "[]".write(toFile: file2Path, atomically: true, encoding: .utf8)

        // Two entries with the same name but different paths
        let entries = [
            makeEntry(name: "settings.json", path: file1Path),
            makeEntry(name: "settings.json", path: file2Path, project: "ProjectB")
        ]

        let zipPath = tempDir.appendingPathComponent("collisions.zip").path
        try await ExportService.exportAsZip(files: entries, to: zipPath)
        XCTAssertTrue(FileManager.default.fileExists(atPath: zipPath))
    }

    private func makeEntry(name: String, path: String, project: String? = nil) -> FileEntry {
        FileEntry(
            id: FileEntry.generateID(from: path),
            name: name,
            path: path,
            displayName: name,
            category: .other,
            scope: .global,
            project: project,
            size: 100,
            modifiedDate: Date(),
            isReadOnly: false
        )
    }
}
