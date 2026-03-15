import XCTest
@testable import ClaudeShelf

final class ExportServiceTests: TempDirectoryTestCase {

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

    func testExportThrowsNoFilesError() async {
        let zipPath = tempDir.appendingPathComponent("empty.zip").path
        do {
            try await ExportService.exportAsZip(files: [], to: zipPath)
            XCTFail("Expected ExportError.noFiles")
        } catch let error as ExportService.ExportError {
            XCTAssertEqual(error, .noFiles)
            XCTAssertNotNil(error.errorDescription)
            XCTAssertTrue(error.errorDescription?.contains("No files") ?? false)
        } catch {
            XCTFail("Expected ExportError.noFiles, got \(error)")
        }
    }

    func testExportErrorDescriptions() {
        let noFiles = ExportService.ExportError.noFiles
        XCTAssertEqual(noFiles.errorDescription, "No files selected for export.")

        let zipFailed = ExportService.ExportError.zipCreationFailed
        XCTAssertEqual(zipFailed.errorDescription, "Failed to create the zip archive. Please try again.")
    }

    func testDefaultFilenameContainsCurrentDate() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let todayString = formatter.string(from: Date())
        let name = ExportService.defaultFilename()
        XCTAssertTrue(name.contains(todayString), "Default filename should contain today's date")
    }

    private func makeEntry(name: String, path: String, project: String? = nil) -> FileEntry {
        TestFileEntryFactory.make(
            name: name,
            path: path,
            scope: .global,
            project: project
        )
    }
}
