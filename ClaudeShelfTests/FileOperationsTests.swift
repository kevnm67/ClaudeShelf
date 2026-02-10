import XCTest
@testable import ClaudeShelf

final class FileOperationsTests: XCTestCase {

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

    // MARK: - Save

    func testSaveFilePreservesPermissions() throws {
        let path = tempDir.appendingPathComponent("test.md").path
        try "original".write(toFile: path, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: NSNumber(value: 0o644)], ofItemAtPath: path)

        try FileOperations.saveFile(at: path, content: "updated")

        let content = try String(contentsOfFile: path, encoding: .utf8)
        XCTAssertEqual(content, "updated")
        let perms = try FileOperations.filePermissions(at: path)
        XCTAssertEqual(perms, 0o644)
    }

    func testSaveFileRestoresRestrictivePermissions() throws {
        let path = tempDir.appendingPathComponent("secret.json").path
        try "{}".write(toFile: path, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: NSNumber(value: 0o600)], ofItemAtPath: path)

        try FileOperations.saveFile(at: path, content: "{\"key\": \"value\"}")

        let perms = try FileOperations.filePermissions(at: path)
        XCTAssertEqual(perms, 0o600)
    }

    func testSaveFileThrowsOnInvalidPath() {
        XCTAssertThrowsError(try FileOperations.saveFile(at: "/nonexistent/path/file.txt", content: "x"))
    }

    // MARK: - Create

    func testCreateFileWithDefaultPermissions() throws {
        let path = tempDir.appendingPathComponent("new-file.md").path
        try FileOperations.createFile(at: path, content: "hello")

        let content = try String(contentsOfFile: path, encoding: .utf8)
        XCTAssertEqual(content, "hello")
        let perms = try FileOperations.filePermissions(at: path)
        XCTAssertEqual(perms, 0o600)
    }

    func testCreateFileEmptyContent() throws {
        let path = tempDir.appendingPathComponent("empty.md").path
        try FileOperations.createFile(at: path)

        let content = try String(contentsOfFile: path, encoding: .utf8)
        XCTAssertEqual(content, "")
        let perms = try FileOperations.filePermissions(at: path)
        XCTAssertEqual(perms, 0o600)
    }

    func testCreateFileCreatesParentDirectories() throws {
        let path = tempDir.appendingPathComponent("deep/nested/dir/file.md").path
        try FileOperations.createFile(at: path, content: "test")

        let content = try String(contentsOfFile: path, encoding: .utf8)
        XCTAssertEqual(content, "test")
    }

    // MARK: - Permissions

    func testFilePermissions() throws {
        let path = tempDir.appendingPathComponent("perms.md").path
        try "test".write(toFile: path, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: NSNumber(value: 0o755)], ofItemAtPath: path)

        let perms = try FileOperations.filePermissions(at: path)
        XCTAssertEqual(perms, 0o755)
    }

    // MARK: - Trash

    func testTrashFileMovesToTrash() throws {
        let path = tempDir.appendingPathComponent("trash-me.md").path
        try "trash content".write(toFile: path, atomically: true, encoding: .utf8)
        XCTAssertTrue(FileManager.default.fileExists(atPath: path))

        let trashURL = try FileOperations.trashFile(at: path)

        XCTAssertFalse(FileManager.default.fileExists(atPath: path))
        // Clean up from Trash if we got a URL back
        if let url = trashURL {
            try? FileManager.default.removeItem(at: url)
        }
    }

    func testTrashFileThrowsOnInvalidPath() {
        XCTAssertThrowsError(try FileOperations.trashFile(at: "/nonexistent/path/no-such-file.md"))
    }

    // MARK: - Permanent Delete

    func testPermanentlyDeleteFileRemovesFile() throws {
        let path = tempDir.appendingPathComponent("delete-me.md").path
        try "delete content".write(toFile: path, atomically: true, encoding: .utf8)
        XCTAssertTrue(FileManager.default.fileExists(atPath: path))

        try FileOperations.permanentlyDeleteFile(at: path)

        XCTAssertFalse(FileManager.default.fileExists(atPath: path))
    }

    func testPermanentlyDeleteFileThrowsOnInvalidPath() {
        XCTAssertThrowsError(try FileOperations.permanentlyDeleteFile(at: "/nonexistent/path/no-such-file.md"))
    }

    // MARK: - Bulk Trash

    func testTrashFilesPartialFailure() throws {
        let path1 = tempDir.appendingPathComponent("bulk-trash-1.md").path
        let path2 = tempDir.appendingPathComponent("bulk-trash-2.md").path
        try "file 1".write(toFile: path1, atomically: true, encoding: .utf8)
        try "file 2".write(toFile: path2, atomically: true, encoding: .utf8)

        // Delete one file first to cause a failure during bulk trash
        try FileManager.default.removeItem(atPath: path2)

        do {
            try FileOperations.trashFiles(at: [path1, path2])
            XCTFail("Expected partialFailure error")
        } catch let error as FileOperationError {
            switch error {
            case .partialFailure(let succeeded, let failed, let errors):
                XCTAssertEqual(succeeded, 1)
                XCTAssertEqual(failed, 1)
                XCTAssertEqual(errors.count, 1)
            }
        }

        // First file should have been trashed successfully
        XCTAssertFalse(FileManager.default.fileExists(atPath: path1))
    }

    // MARK: - Bulk Permanent Delete

    func testPermanentlyDeleteFilesAllSucceed() throws {
        let path1 = tempDir.appendingPathComponent("bulk-delete-1.md").path
        let path2 = tempDir.appendingPathComponent("bulk-delete-2.md").path
        let path3 = tempDir.appendingPathComponent("bulk-delete-3.md").path
        try "file 1".write(toFile: path1, atomically: true, encoding: .utf8)
        try "file 2".write(toFile: path2, atomically: true, encoding: .utf8)
        try "file 3".write(toFile: path3, atomically: true, encoding: .utf8)

        try FileOperations.permanentlyDeleteFiles(at: [path1, path2, path3])

        XCTAssertFalse(FileManager.default.fileExists(atPath: path1))
        XCTAssertFalse(FileManager.default.fileExists(atPath: path2))
        XCTAssertFalse(FileManager.default.fileExists(atPath: path3))
    }
}
