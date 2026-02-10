import Foundation

/// Assigns categories to discovered files based on 12 priority rules.
///
/// Rules are evaluated in priority order; the first match wins.
/// This maps directly to the category assignment specification in PROJECT.md.
struct CategoryAssigner: Sendable {

    /// Assigns a category to a file based on 12 priority rules.
    /// First matching rule wins (priority order).
    ///
    /// - Parameters:
    ///   - fileName: The file's name (e.g., "CLAUDE.md", "settings.json").
    ///   - path: The absolute file path.
    ///   - isInsideClaude: Whether the file is inside a `.claude/` directory.
    /// - Returns: The assigned ``Category``.
    static func assignCategory(
        fileName: String,
        path: String,
        isInsideClaude: Bool
    ) -> Category {
        let lowercasePath = path.lowercased()
        let fileExtension = (fileName as NSString).pathExtension.lowercased()

        // Rule 1: /agents/ + .md extension -> Agents
        if lowercasePath.contains("/agents/") && fileExtension == "md" {
            return .agents
        }

        // Rule 2: /debug/ -> Debug
        if lowercasePath.contains("/debug/") {
            return .debug
        }

        // Rule 3: /memory/ or file is memory.md -> Memory
        if lowercasePath.contains("/memory/") || fileName.lowercased() == "memory.md" {
            return .memory
        }

        // Rule 4: CLAUDE.md outside .claude/ -> Project Config
        if fileName == "CLAUDE.md" && !isInsideClaude {
            return .projectConfig
        }

        // Rule 5: settings.json or .clauderc -> Settings
        if fileName == "settings.json" || fileName == ".clauderc" {
            return .settings
        }

        // Rule 6: .sh files inside .claude/ (not shell-snapshots) -> Settings
        if isInsideClaude && fileExtension == "sh"
            && !lowercasePath.contains("/shell-snapshots/")
        {
            return .settings
        }

        // Rule 7: stats-cache.json -> Settings
        if fileName == "stats-cache.json" {
            return .settings
        }

        // Rule 8: /todos/ or /tasks/ -> Todos
        if lowercasePath.contains("/todos/") || lowercasePath.contains("/tasks/") {
            return .todos
        }

        // Rule 9: /plans/ -> Plans
        if lowercasePath.contains("/plans/") {
            return .plans
        }

        // Rule 10: /skills/ -> Skills
        if lowercasePath.contains("/skills/") {
            return .skills
        }

        // Rule 11: CLAUDE.md or .clauderc (catch-all for inside .claude) -> Project Config
        if fileName == "CLAUDE.md" || fileName == ".clauderc" {
            return .projectConfig
        }

        // Rule 12: Everything else -> Other
        return .other
    }
}
