import XCTest
@testable import ClaudeShelf

final class FileEntryTests: XCTestCase {

    // MARK: - ID Generation

    func testIDLength() {
        let id = FileEntry.generateID(from: "/Users/testuser/.claude/settings.json")
        XCTAssertEqual(id.count, 16, "ID should be 16 hex characters (8 bytes)")
    }

    func testIDConsistency() {
        let id1 = FileEntry.generateID(from: "/some/path/file.md")
        let id2 = FileEntry.generateID(from: "/some/path/file.md")
        XCTAssertEqual(id1, id2, "Same path must produce the same ID")
    }

    func testIDUniqueness() {
        let id1 = FileEntry.generateID(from: "/path/a")
        let id2 = FileEntry.generateID(from: "/path/b")
        XCTAssertNotEqual(id1, id2, "Different paths must produce different IDs")
    }

    func testIDHexFormat() {
        let id = FileEntry.generateID(from: "/any/path")
        let hexCharSet = CharacterSet(charactersIn: "0123456789abcdef")
        for char in id.unicodeScalars {
            XCTAssertTrue(hexCharSet.contains(char), "ID should only contain lowercase hex characters, found: \(char)")
        }
    }

    func testIDDifferentPathsSamePrefix() {
        // Paths that share a long prefix should still produce different IDs
        let id1 = FileEntry.generateID(from: "/Users/testuser/.claude/projects/-Users-testuser-code-MyApp/settings.json")
        let id2 = FileEntry.generateID(from: "/Users/testuser/.claude/projects/-Users-testuser-code-MyApp/config.json")
        XCTAssertNotEqual(id1, id2)
    }

    func testIDEmptyPath() {
        // Even an empty path should produce a valid 16-char hex ID
        let id = FileEntry.generateID(from: "")
        XCTAssertEqual(id.count, 16)
    }
}
