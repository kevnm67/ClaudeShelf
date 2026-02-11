import XCTest
@testable import ClaudeShelf

final class FileScannerTests: XCTestCase {

    private var tempDir: URL!
    private var scanner: FileScanner!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FileScannerTests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        scanner = FileScanner()
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    // MARK: - Helpers

    /// Creates a file at the given path relative to tempDir.
    private func createFile(_ relativePath: String, content: String = "test") {
        let fileURL = tempDir.appendingPathComponent(relativePath)
        let dir = fileURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try? content.write(to: fileURL, atomically: true, encoding: .utf8)
    }

    /// Returns an enabled ScanLocation pointing at tempDir.
    private func scanLocation() -> ScanLocation {
        ScanLocation(id: UUID(), path: tempDir.path, isEnabled: true, isDefault: false)
    }

    /// Returns a disabled ScanLocation pointing at tempDir.
    private func disabledScanLocation() -> ScanLocation {
        ScanLocation(id: UUID(), path: tempDir.path, isEnabled: false, isDefault: false)
    }

    // MARK: - Special File Discovery

    func testDiscoversCLAUDEMDAtRoot() async {
        createFile("CLAUDE.md")
        let result = await scanner.scanLocations([scanLocation()])
        XCTAssertEqual(result.files.count, 1)
        XCTAssertEqual(result.files.first?.name, "CLAUDE.md")
    }

    func testDiscoversClaudercAtRoot() async {
        createFile(".clauderc")
        let result = await scanner.scanLocations([scanLocation()])
        XCTAssertEqual(result.files.count, 1)
        XCTAssertEqual(result.files.first?.name, ".clauderc")
    }

    func testIgnoresNonSpecialFilesOutsideClaude() async {
        createFile("random.txt")
        let result = await scanner.scanLocations([scanLocation()])
        XCTAssertEqual(result.files.count, 0)
    }

    // MARK: - .claude Directory Handling

    func testDiscoversFilesInsideClaudeDir() async {
        createFile(".claude/settings.json")
        createFile(".claude/commands/test.md")
        let result = await scanner.scanLocations([scanLocation()])
        XCTAssertEqual(result.files.count, 2)
    }

    func testFiltersExtensionsInsideClaude() async {
        createFile(".claude/image.png")
        let result = await scanner.scanLocations([scanLocation()])
        XCTAssertEqual(result.files.count, 0, "Files with unrecognized extensions inside .claude should be skipped")
    }

    func testNoDepthLimitInsideClaude() async {
        createFile(".claude/deep/nested/sub/settings.json")
        let result = await scanner.scanLocations([scanLocation()])
        XCTAssertEqual(result.files.count, 1, "Files deep inside .claude should be found regardless of depth")
    }

    // MARK: - Depth Limits

    func testDepthLimitOutsideClaude() async {
        // depth 1 (within limit)
        createFile("level1/CLAUDE.md")
        // depth 2 (within limit)
        createFile("level1/level2/CLAUDE.md")
        // depth 3 (beyond maxDepth=2)
        createFile("level1/level2/level3/CLAUDE.md")

        let result = await scanner.scanLocations([scanLocation()])
        XCTAssertEqual(result.files.count, 2, "Should find depth 1 and 2, but not depth 3")
    }

    // MARK: - Skip Rules

    func testSkipsGitDirectory() async {
        createFile(".git/config.json")
        createFile(".claude/settings.json")
        let result = await scanner.scanLocations([scanLocation()])
        XCTAssertEqual(result.files.count, 1)
        XCTAssertEqual(result.files.first?.name, "settings.json")
    }

    func testSkipsNodeModules() async {
        createFile("node_modules/CLAUDE.md")
        let result = await scanner.scanLocations([scanLocation()])
        XCTAssertEqual(result.files.count, 0)
    }

    func testSkipsHiddenDirectoriesExceptClaude() async {
        createFile(".hidden/CLAUDE.md")
        createFile(".claude/settings.md")
        let result = await scanner.scanLocations([scanLocation()])
        XCTAssertEqual(result.files.count, 1, "Only .claude contents should be found, not .hidden")
        XCTAssertEqual(result.files.first?.name, "settings.md")
    }

    // MARK: - Location Handling

    func testDisabledLocationSkipped() async {
        createFile("CLAUDE.md")
        let result = await scanner.scanLocations([disabledScanLocation()])
        XCTAssertEqual(result.files.count, 0, "Disabled scan locations should be skipped entirely")
    }

    func testNonexistentLocationDoesNotError() async {
        let bogus = ScanLocation(
            id: UUID(),
            path: "/nonexistent/path/\(UUID().uuidString)",
            isEnabled: true,
            isDefault: false
        )
        let result = await scanner.scanLocations([bogus])
        XCTAssertEqual(result.files.count, 0)
        XCTAssertTrue(result.errors.isEmpty, "Nonexistent location should be silently skipped, not produce errors")
    }

    // MARK: - Full Scan with FileEntry

    func testScanReturnsFileEntries() async {
        createFile(".claude/settings.json", content: "{}")
        let scanResult = await scanner.scan(locations: [scanLocation()])

        XCTAssertEqual(scanResult.files.count, 1)
        let entry = scanResult.files[0]
        XCTAssertEqual(entry.name, "settings.json")
        XCTAssertTrue(entry.path.hasSuffix(".claude/settings.json"))
        XCTAssertEqual(entry.category, .settings)
    }
}
