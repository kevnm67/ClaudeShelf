import XCTest
@testable import ClaudeShelf

final class CategoryAssignerTests: XCTestCase {

    // MARK: - Rule 1: /agents/ + .md → Agents

    func testAgentsMdFile() {
        let cat = CategoryAssigner.assignCategory(
            fileName: "my-agent.md",
            path: "/Users/kevin/.claude/agents/my-agent.md",
            isInsideClaude: true
        )
        XCTAssertEqual(cat, .agents)
    }

    func testAgentsNonMdFile() {
        // /agents/ + .json should NOT match Rule 1 (requires .md)
        let cat = CategoryAssigner.assignCategory(
            fileName: "config.json",
            path: "/Users/kevin/.claude/agents/config.json",
            isInsideClaude: true
        )
        XCTAssertNotEqual(cat, .agents)
    }

    // MARK: - Rule 2: /debug/ → Debug

    func testDebugFile() {
        let cat = CategoryAssigner.assignCategory(
            fileName: "trace.log",
            path: "/Users/kevin/.claude/debug/trace.log",
            isInsideClaude: true
        )
        XCTAssertEqual(cat, .debug)
    }

    // MARK: - Rule 3: /memory/ or memory.md → Memory

    func testMemoryDir() {
        let cat = CategoryAssigner.assignCategory(
            fileName: "context.json",
            path: "/Users/kevin/.claude/memory/context.json",
            isInsideClaude: true
        )
        XCTAssertEqual(cat, .memory)
    }

    func testMemoryMdFile() {
        let cat = CategoryAssigner.assignCategory(
            fileName: "memory.md",
            path: "/Users/kevin/.claude/memory.md",
            isInsideClaude: true
        )
        XCTAssertEqual(cat, .memory)
    }

    // MARK: - Rule 4: CLAUDE.md outside .claude → Project Config

    func testClaudeMdOutside() {
        let cat = CategoryAssigner.assignCategory(
            fileName: "CLAUDE.md",
            path: "/Users/kevin/projects/MyApp/CLAUDE.md",
            isInsideClaude: false
        )
        XCTAssertEqual(cat, .projectConfig)
    }

    // MARK: - Rule 5: settings.json or .clauderc → Settings

    func testSettingsJson() {
        let cat = CategoryAssigner.assignCategory(
            fileName: "settings.json",
            path: "/Users/kevin/.claude/settings.json",
            isInsideClaude: true
        )
        XCTAssertEqual(cat, .settings)
    }

    func testClauderc() {
        let cat = CategoryAssigner.assignCategory(
            fileName: ".clauderc",
            path: "/Users/kevin/.clauderc",
            isInsideClaude: false
        )
        XCTAssertEqual(cat, .settings)
    }

    // MARK: - Rule 6: .sh inside .claude (not shell-snapshots) → Settings

    func testShellScript() {
        let cat = CategoryAssigner.assignCategory(
            fileName: "setup.sh",
            path: "/Users/kevin/.claude/setup.sh",
            isInsideClaude: true
        )
        XCTAssertEqual(cat, .settings)
    }

    func testShellSnapshot() {
        // .sh inside shell-snapshots should NOT match Rule 6
        let cat = CategoryAssigner.assignCategory(
            fileName: "snapshot.sh",
            path: "/Users/kevin/.claude/shell-snapshots/snapshot.sh",
            isInsideClaude: true
        )
        XCTAssertNotEqual(cat, .settings)
        // It should fall through to .other since no other rule matches
        XCTAssertEqual(cat, .other)
    }

    // MARK: - Rule 7: stats-cache.json → Settings

    func testStatsCache() {
        let cat = CategoryAssigner.assignCategory(
            fileName: "stats-cache.json",
            path: "/Users/kevin/.claude/stats-cache.json",
            isInsideClaude: true
        )
        XCTAssertEqual(cat, .settings)
    }

    // MARK: - Rule 8: /todos/ or /tasks/ → Todos

    func testTodos() {
        let cat = CategoryAssigner.assignCategory(
            fileName: "todo-1.md",
            path: "/Users/kevin/.claude/todos/todo-1.md",
            isInsideClaude: true
        )
        XCTAssertEqual(cat, .todos)
    }

    func testTasks() {
        let cat = CategoryAssigner.assignCategory(
            fileName: "task-1.json",
            path: "/Users/kevin/.claude/tasks/task-1.json",
            isInsideClaude: true
        )
        XCTAssertEqual(cat, .todos)
    }

    // MARK: - Rule 9: /plans/ → Plans

    func testPlans() {
        let cat = CategoryAssigner.assignCategory(
            fileName: "plan-1.md",
            path: "/Users/kevin/.claude/plans/plan-1.md",
            isInsideClaude: true
        )
        XCTAssertEqual(cat, .plans)
    }

    // MARK: - Rule 10: /skills/ → Skills

    func testSkills() {
        let cat = CategoryAssigner.assignCategory(
            fileName: "coding.md",
            path: "/Users/kevin/.claude/skills/coding.md",
            isInsideClaude: true
        )
        XCTAssertEqual(cat, .skills)
    }

    // MARK: - Rule 11: CLAUDE.md inside .claude → Project Config

    func testClaudeMdInside() {
        let cat = CategoryAssigner.assignCategory(
            fileName: "CLAUDE.md",
            path: "/Users/kevin/.claude/CLAUDE.md",
            isInsideClaude: true
        )
        XCTAssertEqual(cat, .projectConfig)
    }

    // MARK: - Rule 12: Everything else → Other

    func testOther() {
        let cat = CategoryAssigner.assignCategory(
            fileName: "random.yaml",
            path: "/Users/kevin/.claude/random.yaml",
            isInsideClaude: true
        )
        XCTAssertEqual(cat, .other)
    }

    // MARK: - Priority tests

    func testPriorityAgentsOverPlans() {
        // A file in /plans/agents/ with .md should match Rule 1 (agents) before Rule 9 (plans)
        let cat = CategoryAssigner.assignCategory(
            fileName: "agent.md",
            path: "/Users/kevin/.claude/plans/agents/agent.md",
            isInsideClaude: true
        )
        XCTAssertEqual(cat, .agents)
    }

    func testPriorityDebugOverMemory() {
        // A file in /debug/memory/ should match Rule 2 (debug) before Rule 3 (memory)
        let cat = CategoryAssigner.assignCategory(
            fileName: "data.json",
            path: "/Users/kevin/.claude/debug/memory/data.json",
            isInsideClaude: true
        )
        XCTAssertEqual(cat, .debug)
    }

    func testPriorityMemoryOverSettings() {
        // memory.md named "memory.md" should match Rule 3 (memory) not fall to settings
        let cat = CategoryAssigner.assignCategory(
            fileName: "memory.md",
            path: "/Users/kevin/.claude/projects/memory.md",
            isInsideClaude: true
        )
        XCTAssertEqual(cat, .memory)
    }
}
