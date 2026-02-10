# ClaudeShelf

A native macOS SwiftUI app for browsing, searching, editing, and managing Claude Code configuration files.

ClaudeShelf automatically discovers Claude config files across your filesystem — `CLAUDE.md` instructions, project settings, memory files, todos, and more — and presents them in an organized, searchable interface with syntax-highlighted editing.

## Features

- **Automatic file discovery** — Scans `~/.claude/`, common project directories, and home directory for Claude config files
- **9 categories** — Memory, Settings, Todos, Plans, Skills, Agents, Debug, Project Config, Other
- **Syntax-highlighted editor** — Markdown, JSON, YAML, TOML highlighting with line numbers
- **Three-column layout** — Category sidebar, file list with sorting/grouping, and editor pane
- **Real-time search** — Filter across file names, paths, and display names
- **Read-only detection** — Lock icon for non-writable files
- **Global and project scope** — Visual grouping by scope with decoded project names

## Screenshots

*Coming soon*

## Requirements

- macOS 15+ (Sequoia)
- Xcode 16+ (to build from source)

## Building

```bash
git clone https://github.com/kevnm67/ClaudeShelf.git
cd ClaudeShelf
open ClaudeShelf.xcodeproj
```

Build and run with Cmd+R in Xcode.

## Architecture

- **Swift 6** with strict concurrency
- **SwiftUI** with `NavigationSplitView` three-column layout
- **MVVM** — Views observe `@Observable` state objects; business logic in Services
- **Actor isolation** — File scanner uses Swift actors for thread-safe I/O
- **Zero external dependencies** — Apple frameworks only
- **NSViewRepresentable** — Code editor bridges `NSTextView` for full editor capabilities

## Project Structure

```
ClaudeShelf/
├── App/              # @main entry point, AppState
├── Models/           # FileEntry, Category, Scope, ScanLocation
├── Services/         # FileScanner, CategoryAssigner
├── Views/
│   ├── Sidebar/      # SidebarView, FileListView, FileRowView
│   ├── Editor/       # FileDetailView, CodeEditorView
│   └── Components/   # Shared UI components
└── Utilities/        # PathDecoder, SyntaxHighlighter
```

## Origin

This is a greenfield rewrite of [MojtabaTajik/ClaudeShelf](https://github.com/MojtabaTajik/ClaudeShelf), originally a Go HTTP server with an embedded web UI. The native app eliminates the HTTP server entirely — no network attack surface, proper file permission handling, and a native macOS experience.

## License

MIT
