import XCTest
@testable import ClaudeShelf

final class SyntaxHighlighterTests: XCTestCase {

    // MARK: - File Type Detection

    func testDetectMarkdownExtension() {
        XCTAssertEqual(SyntaxHighlighter.detectFileType(from: "CLAUDE.md"), .markdown)
    }

    func testDetectMarkdownFullExtension() {
        XCTAssertEqual(SyntaxHighlighter.detectFileType(from: "README.markdown"), .markdown)
    }

    func testDetectJSON() {
        XCTAssertEqual(SyntaxHighlighter.detectFileType(from: "settings.json"), .json)
    }

    func testDetectYAML() {
        XCTAssertEqual(SyntaxHighlighter.detectFileType(from: "config.yaml"), .yaml)
    }

    func testDetectYML() {
        XCTAssertEqual(SyntaxHighlighter.detectFileType(from: "config.yml"), .yaml)
    }

    func testDetectTOML() {
        XCTAssertEqual(SyntaxHighlighter.detectFileType(from: "settings.toml"), .toml)
    }

    func testDetectPlainText() {
        XCTAssertEqual(SyntaxHighlighter.detectFileType(from: "notes.txt"), .plainText)
    }

    func testDetectCaseInsensitive() {
        XCTAssertEqual(SyntaxHighlighter.detectFileType(from: "FILE.JSON"), .json)
        XCTAssertEqual(SyntaxHighlighter.detectFileType(from: "README.MD"), .markdown)
    }

    func testDetectNoExtension() {
        XCTAssertEqual(SyntaxHighlighter.detectFileType(from: ".clauderc"), .plainText)
    }

    // MARK: - Highlight Returns Attributed String

    func testHighlightEmptyString() {
        let result = SyntaxHighlighter.highlight("", for: .json)
        XCTAssertEqual(result.length, 0)
    }

    func testHighlightPlainTextNoColoring() {
        let text = "Hello world"
        let result = SyntaxHighlighter.highlight(text, for: .plainText)
        XCTAssertEqual(result.string, text)
    }

    // MARK: - JSON Highlighting

    func testJSONKeysColored() {
        let json = #"{"name": "value"}"#
        let result = SyntaxHighlighter.highlight(json, for: .json)
        // "name": is a key — should be purple
        var range = NSRange()
        let attrs = result.attributes(at: 1, effectiveRange: &range)
        let color = attrs[.foregroundColor] as? NSColor
        XCTAssertNotNil(color)
        XCTAssertEqual(color, NSColor.systemPurple)
    }

    func testJSONStringValuesColored() {
        let json = #"{"key": "hello"}"#
        let result = SyntaxHighlighter.highlight(json, for: .json)
        // "hello" is a string value, should be green
        let valueStart = (json as NSString).range(of: "\"hello\"")
        var effectiveRange = NSRange()
        let attrs = result.attributes(at: valueStart.location + 1, effectiveRange: &effectiveRange)
        let color = attrs[.foregroundColor] as? NSColor
        XCTAssertEqual(color, NSColor.systemGreen)
    }

    func testJSONBooleansColored() {
        let json = #"{"flag": true}"#
        let result = SyntaxHighlighter.highlight(json, for: .json)
        let trueRange = (json as NSString).range(of: "true")
        var effectiveRange = NSRange()
        let attrs = result.attributes(at: trueRange.location, effectiveRange: &effectiveRange)
        let color = attrs[.foregroundColor] as? NSColor
        XCTAssertEqual(color, NSColor.systemPink)
    }

    func testJSONNumbersColored() {
        let json = #"{"count": 42}"#
        let result = SyntaxHighlighter.highlight(json, for: .json)
        let numberRange = (json as NSString).range(of: "42")
        var effectiveRange = NSRange()
        let attrs = result.attributes(at: numberRange.location, effectiveRange: &effectiveRange)
        let color = attrs[.foregroundColor] as? NSColor
        // Numbers get colored first but may be overridden by subsequent patterns.
        // In this case 42 is not inside quotes and not a boolean, so it stays as number color.
        XCTAssertEqual(color, NSColor.systemOrange)
    }

    // MARK: - Markdown Highlighting

    func testMarkdownHeadingColored() {
        let md = "# Heading\nSome text"
        let result = SyntaxHighlighter.highlight(md, for: .markdown)
        var effectiveRange = NSRange()
        let attrs = result.attributes(at: 0, effectiveRange: &effectiveRange)
        let color = attrs[.foregroundColor] as? NSColor
        XCTAssertEqual(color, NSColor.systemBrown)
    }

    func testMarkdownCodeBlockColored() {
        let md = "```\ncode here\n```"
        let result = SyntaxHighlighter.highlight(md, for: .markdown)
        var effectiveRange = NSRange()
        let attrs = result.attributes(at: 4, effectiveRange: &effectiveRange)
        let color = attrs[.foregroundColor] as? NSColor
        XCTAssertEqual(color, NSColor.systemGreen)
    }

    func testMarkdownInlineCodeColored() {
        let md = "Use `inline` here"
        let result = SyntaxHighlighter.highlight(md, for: .markdown)
        // The backtick-enclosed text starts at index 4
        let codeRange = (md as NSString).range(of: "`inline`")
        var effectiveRange = NSRange()
        let attrs = result.attributes(at: codeRange.location, effectiveRange: &effectiveRange)
        let color = attrs[.foregroundColor] as? NSColor
        XCTAssertEqual(color, NSColor.systemGreen)
    }

    func testMarkdownLinkColored() {
        let md = "See [docs](https://example.com) for details"
        let result = SyntaxHighlighter.highlight(md, for: .markdown)
        let linkRange = (md as NSString).range(of: "[docs](https://example.com)")
        var effectiveRange = NSRange()
        let attrs = result.attributes(at: linkRange.location, effectiveRange: &effectiveRange)
        let color = attrs[.foregroundColor] as? NSColor
        XCTAssertEqual(color, NSColor.systemCyan)
    }

    // MARK: - YAML Highlighting

    func testYAMLKeyColored() {
        let yaml = "name: value"
        let result = SyntaxHighlighter.highlight(yaml, for: .yaml)
        var effectiveRange = NSRange()
        let attrs = result.attributes(at: 0, effectiveRange: &effectiveRange)
        let color = attrs[.foregroundColor] as? NSColor
        XCTAssertEqual(color, NSColor.systemPurple)
    }

    func testYAMLCommentColored() {
        let yaml = "key: value # comment"
        let result = SyntaxHighlighter.highlight(yaml, for: .yaml)
        let commentStart = (yaml as NSString).range(of: "#")
        var effectiveRange = NSRange()
        let attrs = result.attributes(at: commentStart.location, effectiveRange: &effectiveRange)
        let color = attrs[.foregroundColor] as? NSColor
        XCTAssertEqual(color, NSColor.systemGray)
    }

    func testYAMLBooleanColored() {
        let yaml = "enabled: true"
        let result = SyntaxHighlighter.highlight(yaml, for: .yaml)
        let boolRange = (yaml as NSString).range(of: "true")
        var effectiveRange = NSRange()
        let attrs = result.attributes(at: boolRange.location, effectiveRange: &effectiveRange)
        let color = attrs[.foregroundColor] as? NSColor
        XCTAssertEqual(color, NSColor.systemPink)
    }

    // MARK: - TOML Highlighting

    func testTOMLSectionHeaderColored() {
        let toml = "[section]\nkey = \"value\""
        let result = SyntaxHighlighter.highlight(toml, for: .toml)
        var effectiveRange = NSRange()
        let attrs = result.attributes(at: 0, effectiveRange: &effectiveRange)
        let color = attrs[.foregroundColor] as? NSColor
        XCTAssertEqual(color, NSColor.systemPurple)
    }

    func testTOMLCommentColored() {
        let toml = "# This is a comment"
        let result = SyntaxHighlighter.highlight(toml, for: .toml)
        var effectiveRange = NSRange()
        let attrs = result.attributes(at: 0, effectiveRange: &effectiveRange)
        let color = attrs[.foregroundColor] as? NSColor
        XCTAssertEqual(color, NSColor.systemGray)
    }

    func testTOMLStringValuesColored() {
        let toml = "name = \"hello\""
        let result = SyntaxHighlighter.highlight(toml, for: .toml)
        let stringRange = (toml as NSString).range(of: "\"hello\"")
        var effectiveRange = NSRange()
        let attrs = result.attributes(at: stringRange.location + 1, effectiveRange: &effectiveRange)
        let color = attrs[.foregroundColor] as? NSColor
        XCTAssertEqual(color, NSColor.systemGreen)
    }
}
