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
}
