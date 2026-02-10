import XCTest
@testable import ClaudeShelf

final class PathDecoderTests: XCTestCase {

    // MARK: - Project Name Decoding

    func testBasicProjectDecode() {
        let name = PathDecoder.decodeProjectName(from: "-home-user-Projects-MyApp")
        XCTAssertEqual(name, "MyApp")
    }

    func testUsersPath() {
        // "-Users-kevin-code-my-tool" splits as [Users, kevin, code, my, tool]
        // "Users" and "code" are common prefixes, "kevin" is not, "my" is not, "tool" is not.
        // Last meaningful segment is "tool".
        let name = PathDecoder.decodeProjectName(from: "-Users-kevin-code-my-tool")
        XCTAssertEqual(name, "tool")
    }

    func testSingleSegment() {
        // After stripping common prefixes, only "Projects" remains but it's
        // in commonPrefixes — so all segments are stripped, returns nil.
        let name = PathDecoder.decodeProjectName(from: "-home-user-Projects")
        XCTAssertNil(name)
    }

    func testMultipleMeaningfulSegments() {
        // Both "workspace-tools" and "MyProject" are meaningful; last wins.
        let name = PathDecoder.decodeProjectName(from: "-Users-kevin-workspace-tools-MyProject")
        XCTAssertEqual(name, "MyProject")
    }

    func testAllCommonPrefixesStripped() {
        // All segments are common prefixes or single chars — returns nil.
        let name = PathDecoder.decodeProjectName(from: "-home-user-src")
        XCTAssertNil(name)
    }

    func testGithubPath() {
        let name = PathDecoder.decodeProjectName(from: "-Users-kevin-Github-ClaudeShelf")
        XCTAssertEqual(name, "ClaudeShelf")
    }

    func testSingleCharSegmentsFiltered() {
        // "C" is a single char (drive letter), should be filtered out.
        let name = PathDecoder.decodeProjectName(from: "-C-Users-kevin-Projects-MyApp")
        XCTAssertEqual(name, "MyApp")
    }

    // MARK: - Scope Detection

    func testProjectScopeViaProjects() {
        let (scope, project) = PathDecoder.detectScope(
            for: "/Users/kevin/.claude/projects/-Users-kevin-code-MyApp/settings.json",
            homeDirectory: "/Users/kevin"
        )
        XCTAssertEqual(scope, .project)
        XCTAssertEqual(project, "MyApp")
    }

    func testGlobalScope() {
        let (scope, project) = PathDecoder.detectScope(
            for: "/Users/kevin/.claude/settings.json",
            homeDirectory: "/Users/kevin"
        )
        XCTAssertEqual(scope, .global)
        XCTAssertNil(project)
    }

    func testProjectScopeViaNestedClaude() {
        // .claude/ inside a project directory (not under ~/.claude)
        let (scope, project) = PathDecoder.detectScope(
            for: "/Users/kevin/projects/MyApp/.claude/settings.json",
            homeDirectory: "/Users/kevin"
        )
        XCTAssertEqual(scope, .project)
        XCTAssertEqual(project, "MyApp")
    }

    func testProjectScopeViaClaudeMd() {
        // CLAUDE.md at project root (not inside .claude/)
        let (scope, project) = PathDecoder.detectScope(
            for: "/Users/kevin/projects/MyApp/CLAUDE.md",
            homeDirectory: "/Users/kevin"
        )
        XCTAssertEqual(scope, .project)
        XCTAssertEqual(project, "MyApp")
    }

    func testGlobalScopeForNonClaudeMd() {
        // A random file not inside .claude and not CLAUDE.md
        let (scope, project) = PathDecoder.detectScope(
            for: "/Users/kevin/.clauderc",
            homeDirectory: "/Users/kevin"
        )
        XCTAssertEqual(scope, .global)
        XCTAssertNil(project)
    }

    func testHomeDirectoryWithTrailingSlash() {
        // Home directory with trailing slash should still work
        let (scope, project) = PathDecoder.detectScope(
            for: "/Users/kevin/.claude/settings.json",
            homeDirectory: "/Users/kevin/"
        )
        XCTAssertEqual(scope, .global)
        XCTAssertNil(project)
    }

    // MARK: - Display Name

    func testDisplayNameWithProject() {
        let name = PathDecoder.displayName(for: "CLAUDE.md", project: "MyApp")
        XCTAssertEqual(name, "MyApp/CLAUDE.md")
    }

    func testDisplayNameWithoutProject() {
        let name = PathDecoder.displayName(for: "settings.json", project: nil)
        XCTAssertEqual(name, "settings.json")
    }
}
