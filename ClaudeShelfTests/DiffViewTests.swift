import XCTest
@testable import ClaudeShelf

final class DiffViewTests: XCTestCase {

    // MARK: - No Changes

    func testNoDifference() {
        let text = "line one\nline two"
        let result = DiffView.computeDiff(original: text, modified: text)
        XCTAssertEqual(result.count, 2)
        for line in result {
            if case .unchanged = line { } else {
                XCTFail("Expected all lines unchanged, got \(line)")
            }
        }
    }

    // MARK: - Additions

    func testSingleLineAdded() {
        let original = "line one\nline two"
        let modified = "line one\ninserted\nline two"
        let result = DiffView.computeDiff(original: original, modified: modified)
        let addedLines = result.filter { if case .added = $0 { return true }; return false }
        XCTAssertEqual(addedLines.count, 1)
        XCTAssertEqual(addedLines.first?.text, "inserted")
    }

    // MARK: - Removals

    func testSingleLineRemoved() {
        let original = "line one\nline two\nline three"
        let modified = "line one\nline three"
        let result = DiffView.computeDiff(original: original, modified: modified)
        let removedLines = result.filter { if case .removed = $0 { return true }; return false }
        XCTAssertEqual(removedLines.count, 1)
        XCTAssertEqual(removedLines.first?.text, "line two")
    }

    // MARK: - Mixed Changes

    func testAddAndRemove() {
        let original = "aaa\nbbb\nccc"
        let modified = "aaa\nxxx\nccc"
        let result = DiffView.computeDiff(original: original, modified: modified)
        let removed = result.filter { if case .removed = $0 { return true }; return false }
        let added = result.filter { if case .added = $0 { return true }; return false }
        XCTAssertEqual(removed.count, 1)
        XCTAssertEqual(removed.first?.text, "bbb")
        XCTAssertEqual(added.count, 1)
        XCTAssertEqual(added.first?.text, "xxx")
    }

    // MARK: - Edge Cases

    func testEmptyOriginal() {
        let result = DiffView.computeDiff(original: "", modified: "new line")
        let added = result.filter { if case .added = $0 { return true }; return false }
        XCTAssertGreaterThanOrEqual(added.count, 1)
    }

    func testEmptyModified() {
        let result = DiffView.computeDiff(original: "old line", modified: "")
        let removed = result.filter { if case .removed = $0 { return true }; return false }
        XCTAssertGreaterThanOrEqual(removed.count, 1)
    }

    func testBothEmpty() {
        let result = DiffView.computeDiff(original: "", modified: "")
        // Single empty line, unchanged
        XCTAssertEqual(result.count, 1)
    }

    func testAllLinesChanged() {
        let original = "aaa\nbbb"
        let modified = "xxx\nyyy"
        let result = DiffView.computeDiff(original: original, modified: modified)
        let removed = result.filter { if case .removed = $0 { return true }; return false }
        let added = result.filter { if case .added = $0 { return true }; return false }
        XCTAssertEqual(removed.count, 2)
        XCTAssertEqual(added.count, 2)
    }

    // MARK: - DiffLine Properties

    func testDiffLinePrefix() {
        let lines = DiffView.computeDiff(original: "old", modified: "new")
        for line in lines {
            switch line {
            case .unchanged:
                XCTAssertEqual(line.prefix, " ")
            case .added:
                XCTAssertEqual(line.prefix, "+")
            case .removed:
                XCTAssertEqual(line.prefix, "\u{2212}")
            }
        }
    }
}
