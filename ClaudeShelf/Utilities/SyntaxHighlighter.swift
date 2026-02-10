import AppKit

/// Detects the format of a Claude configuration file and applies regex-based
/// syntax coloring to produce a styled ``NSAttributedString``.
///
/// Supports Markdown, JSON, YAML, and TOML — the four formats used by
/// Claude config files. Uses ``NSRegularExpression`` for pattern matching
/// and semantic ``NSColor`` values that adapt to light and dark mode.
enum SyntaxHighlighter {

    // MARK: - File Type Detection

    /// The format of a configuration file, determined from its extension.
    enum FileType: Sendable {
        case markdown
        case json
        case yaml
        case toml
        case plainText
    }

    /// Determines the file type from a filename's extension.
    ///
    /// - Parameter filename: The file name (e.g. `"CLAUDE.md"`, `"settings.json"`).
    /// - Returns: The detected ``FileType``, or `.plainText` if the extension is unrecognized.
    static func detectFileType(from filename: String) -> FileType {
        let lowercased = filename.lowercased()

        if lowercased.hasSuffix(".md") || lowercased.hasSuffix(".markdown") {
            return .markdown
        } else if lowercased.hasSuffix(".json") {
            return .json
        } else if lowercased.hasSuffix(".yaml") || lowercased.hasSuffix(".yml") {
            return .yaml
        } else if lowercased.hasSuffix(".toml") {
            return .toml
        } else {
            return .plainText
        }
    }

    // MARK: - Theme Colors

    /// Semantic colors for syntax highlighting that adapt to light/dark mode.
    private enum Theme {
        static let keyword = NSColor.systemBlue
        static let string = NSColor.systemGreen
        static let number = NSColor.systemOrange
        static let comment = NSColor.systemGray
        static let key = NSColor.systemPurple
        static let heading = NSColor.systemBrown
        static let link = NSColor.systemCyan
        static let boolean = NSColor.systemPink
        static let base = NSColor.labelColor
        nonisolated(unsafe) static let baseFont = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        nonisolated(unsafe) static let boldFont = NSFont.monospacedSystemFont(ofSize: 13, weight: .bold)
    }

    // MARK: - Public API

    /// Applies syntax highlighting to the given text based on file type.
    ///
    /// Returns an ``NSAttributedString`` with colored ranges for recognized
    /// syntax elements. The base font is a 13pt monospaced system font with
    /// ``NSColor.labelColor`` that adapts to the current appearance.
    ///
    /// - Parameters:
    ///   - text: The raw file content.
    ///   - fileType: The format to highlight for.
    /// - Returns: An attributed string with syntax coloring applied.
    static func highlight(_ text: String, for fileType: FileType) -> NSAttributedString {
        let baseAttributes: [NSAttributedString.Key: Any] = [
            .font: Theme.baseFont,
            .foregroundColor: Theme.base,
        ]

        let attributed = NSMutableAttributedString(string: text, attributes: baseAttributes)
        let fullRange = NSRange(location: 0, length: attributed.length)

        guard fullRange.length > 0 else { return attributed }

        switch fileType {
        case .json:
            applyJSONHighlighting(to: attributed, in: fullRange)
        case .yaml:
            applyYAMLHighlighting(to: attributed, in: fullRange)
        case .toml:
            applyTOMLHighlighting(to: attributed, in: fullRange)
        case .markdown:
            applyMarkdownHighlighting(to: attributed, in: fullRange)
        case .plainText:
            break
        }

        return attributed
    }

    // MARK: - JSON Highlighting

    private static func applyJSONHighlighting(
        to attributed: NSMutableAttributedString,
        in range: NSRange
    ) {
        let text = attributed.string

        // Numbers (before strings so string values take precedence)
        applyPattern(#"\b-?\d+\.?\d*([eE][+-]?\d+)?\b"#, to: attributed, in: range, text: text,
                     attributes: [.foregroundColor: Theme.number])

        // Booleans and null
        applyPattern(#"\b(true|false|null)\b"#, to: attributed, in: range, text: text,
                     attributes: [.foregroundColor: Theme.boolean])

        // String values (all double-quoted strings first)
        applyPattern(#""[^"\\]*(?:\\.[^"\\]*)*""#, to: attributed, in: range, text: text,
                     attributes: [.foregroundColor: Theme.string])

        // Keys (quoted strings followed by colon) — override string color
        applyPattern(#""[^"\\]*(?:\\.[^"\\]*)*"\s*:"#, to: attributed, in: range, text: text,
                     attributes: [.foregroundColor: Theme.key])
    }

    // MARK: - YAML Highlighting

    private static func applyYAMLHighlighting(
        to attributed: NSMutableAttributedString,
        in range: NSRange
    ) {
        let text = attributed.string

        // String values (quoted)
        applyPattern(#""[^"\\]*(?:\\.[^"\\]*)*"|'[^']*'"#, to: attributed, in: range, text: text,
                     attributes: [.foregroundColor: Theme.string])

        // Numbers (value after colon)
        applyPattern(#":\s*-?\d+\.?\d*\s*$"#, to: attributed, in: range, text: text,
                     attributes: [.foregroundColor: Theme.number],
                     options: [.anchorsMatchLines])

        // Booleans and null
        applyPattern(#"\b(true|false|yes|no|null|~)\b"#, to: attributed, in: range, text: text,
                     attributes: [.foregroundColor: Theme.boolean])

        // Keys (word characters at start of line followed by colon)
        applyPattern(#"^[\w][\w.-]*\s*:"#, to: attributed, in: range, text: text,
                     attributes: [.foregroundColor: Theme.key],
                     options: [.anchorsMatchLines])

        // Nested keys (indented keys)
        applyPattern(#"^\s+[\w][\w.-]*\s*:"#, to: attributed, in: range, text: text,
                     attributes: [.foregroundColor: Theme.key],
                     options: [.anchorsMatchLines])

        // Comments (must be last to override other patterns)
        applyPattern(#"#.*$"#, to: attributed, in: range, text: text,
                     attributes: [.foregroundColor: Theme.comment],
                     options: [.anchorsMatchLines])
    }

    // MARK: - TOML Highlighting

    private static func applyTOMLHighlighting(
        to attributed: NSMutableAttributedString,
        in range: NSRange
    ) {
        let text = attributed.string

        // String values (quoted)
        applyPattern(#""[^"\\]*(?:\\.[^"\\]*)*"|'[^']*'"#, to: attributed, in: range, text: text,
                     attributes: [.foregroundColor: Theme.string])

        // Numbers (value after equals)
        applyPattern(#"=\s*-?\d+\.?\d*"#, to: attributed, in: range, text: text,
                     attributes: [.foregroundColor: Theme.number])

        // Booleans
        applyPattern(#"\b(true|false)\b"#, to: attributed, in: range, text: text,
                     attributes: [.foregroundColor: Theme.boolean])

        // Keys (word characters before equals)
        applyPattern(#"^[\w][\w.-]*\s*="#, to: attributed, in: range, text: text,
                     attributes: [.foregroundColor: Theme.key],
                     options: [.anchorsMatchLines])

        // Section headers [section] and [[array]]
        applyPattern(#"^\[[\w][\w.-]*\]"#, to: attributed, in: range, text: text,
                     attributes: [.foregroundColor: Theme.key, .font: Theme.boldFont],
                     options: [.anchorsMatchLines])
        applyPattern(#"^\[\[[\w][\w.-]*\]\]"#, to: attributed, in: range, text: text,
                     attributes: [.foregroundColor: Theme.key, .font: Theme.boldFont],
                     options: [.anchorsMatchLines])

        // Comments (must be last to override other patterns)
        applyPattern(#"#.*$"#, to: attributed, in: range, text: text,
                     attributes: [.foregroundColor: Theme.comment],
                     options: [.anchorsMatchLines])
    }

    // MARK: - Markdown Highlighting

    private static func applyMarkdownHighlighting(
        to attributed: NSMutableAttributedString,
        in range: NSRange
    ) {
        let text = attributed.string

        // Code blocks (fenced — must come before inline patterns)
        applyPattern(#"```[^\n]*\n[\s\S]*?```"#, to: attributed, in: range, text: text,
                     attributes: [.foregroundColor: Theme.string])

        // Inline code
        applyPattern(#"`[^`\n]+`"#, to: attributed, in: range, text: text,
                     attributes: [.foregroundColor: Theme.string])

        // Bold (** or __)
        applyPattern(#"\*\*[^*]+\*\*"#, to: attributed, in: range, text: text,
                     attributes: [.font: Theme.boldFont])
        applyPattern(#"__[^_]+__"#, to: attributed, in: range, text: text,
                     attributes: [.font: Theme.boldFont])

        // Italic (* or _ — single, not double)
        applyPattern(#"(?<!\*)\*(?!\*)[^*]+(?<!\*)\*(?!\*)"#, to: attributed, in: range, text: text,
                     attributes: [.obliqueness: NSNumber(value: 0.15)])
        applyPattern(#"(?<!_)_(?!_)[^_]+(?<!_)_(?!_)"#, to: attributed, in: range, text: text,
                     attributes: [.obliqueness: NSNumber(value: 0.15)])

        // Links [text](url)
        applyPattern(#"\[[^\]]+\]\([^)]+\)"#, to: attributed, in: range, text: text,
                     attributes: [.foregroundColor: Theme.link])

        // List markers
        applyPattern(#"^\s*[-*+]\s"#, to: attributed, in: range, text: text,
                     attributes: [.foregroundColor: Theme.keyword],
                     options: [.anchorsMatchLines])

        // Numbered lists
        applyPattern(#"^\s*\d+\.\s"#, to: attributed, in: range, text: text,
                     attributes: [.foregroundColor: Theme.keyword],
                     options: [.anchorsMatchLines])

        // Headings (must be last so they override other patterns on heading lines)
        applyPattern(#"^#{1,6}\s+.*$"#, to: attributed, in: range, text: text,
                     attributes: [.foregroundColor: Theme.heading, .font: Theme.boldFont],
                     options: [.anchorsMatchLines])
    }

    // MARK: - Pattern Matching

    /// Applies the given attributes to all matches of a regex pattern in the attributed string.
    ///
    /// - Parameters:
    ///   - pattern: A regular expression pattern.
    ///   - attributed: The mutable attributed string to modify.
    ///   - range: The range within the string to search.
    ///   - text: The plain text content (for efficient matching).
    ///   - attributes: The attributes to apply to each match.
    ///   - options: Regular expression options (e.g. `.anchorsMatchLines`).
    private static func applyPattern(
        _ pattern: String,
        to attributed: NSMutableAttributedString,
        in range: NSRange,
        text: String,
        attributes: [NSAttributedString.Key: Any],
        options: NSRegularExpression.Options = []
    ) {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else {
            return
        }

        let matches = regex.matches(in: text, options: [], range: range)
        for match in matches {
            attributed.addAttributes(attributes, range: match.range)
        }
    }
}
