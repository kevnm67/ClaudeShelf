# ClaudeShelf

## What This Is

A native macOS SwiftUI app that browses, searches, edits, and manages Claude Code configuration files. A greenfield rewrite of the Go-based ClaudeShelf web app, eliminating its HTTP server architecture in favor of direct filesystem access for security.

## Core Value

Reliable discovery, safe editing, and native-quality management of Claude Code config files — with zero network exposure.

## Requirements

### Validated

(None yet — ship to validate)

### Active

**File Discovery & Scanning**
- [ ] Scan `~/.claude/`, common project dirs (`~/projects/`, `~/src/`, `~/dev/`, `~/code/`, `~/workspace/`, `~/repos/`), and home dir
- [ ] Recognize files inside `.claude/` dirs with known extensions (`.md`, `.json`, `.yaml`, `.yml`, `.txt`, `.toml`, `.log`, `.sh`) plus `CLAUDE.md` and `.clauderc` anywhere
- [ ] Skip `.git`, `node_modules`, `.venv`, `__pycache__`, hidden dirs (except `.claude`)
- [ ] Depth limit: max 2 levels for non-`.claude` directories
- [ ] Assign files to 9 categories with priority-based rules (Agents, Debug, Memory, Project Config, Settings, Todos, Plans, Skills, Other)
- [ ] Decode Claude's encoded project paths (e.g., `-home-user-Projects-MyApp` → `MyApp`)
- [ ] Generate file IDs via truncated SHA256 of absolute path
- [ ] FSEvents-based file watching with auto-refresh on disk changes
- [ ] Manual rescan button
- [ ] Configurable scan locations in Settings

**Editor**
- [ ] Syntax-highlighted editor for Markdown, JSON, YAML, TOML
- [ ] Undo/redo via native `UndoManager`
- [ ] Line numbers
- [ ] Cmd+S to save
- [ ] Diff view showing unsaved changes before saving
- [ ] Read-only detection with lock icon

**File Operations**
- [ ] Preserve original POSIX permissions on save
- [ ] Default new files to `0600` (owner read/write only)
- [ ] Move to Trash as default delete action (`FileManager.trashItem`)
- [ ] Permanent delete with explicit confirmation and distinct button
- [ ] Single and bulk delete with confirmation dialogs

**UI & Navigation**
- [ ] Three-column NavigationSplitView: categories | file list | editor
- [ ] Sidebar with SF Symbols icons, file counts, and sizes per category
- [ ] Real-time search across name, path, display name, project (Cmd+F)
- [ ] Visual grouping by project scope (global vs project-scoped)
- [ ] Dark/Light mode following system appearance
- [ ] Standard macOS menu bar with all actions
- [ ] Keyboard shortcuts: Cmd+S (save), Cmd+Delete (trash), Cmd+F (search), Cmd+R (rescan), arrow key navigation
- [ ] Multiple windows — open files in separate windows
- [ ] Quick Look integration (spacebar to preview)

**Cleanup Tool**
- [ ] Identify empty files (0 bytes)
- [ ] Identify empty content files (`[]`, `{}`, `null`, whitespace-only)
- [ ] Identify stale files (30+ days since last modified/accessed)
- [ ] Cleanup modal with selectable items for batch operations

**Export**
- [ ] Export selected files as a zip archive

### Out of Scope

- Touch Bar support — discontinued hardware since 2021, not worth supporting
- Network communication of any kind — no HTTP server, no sockets, no API calls
- Third-party dependencies — Apple frameworks only, no SPM packages without explicit approval
- Analytics, telemetry, or crash reporting — not without explicit approval
- Keychain storage — not needed for v1 (no secrets to store beyond file content)

## Context

- **Origin:** Rewrite of [MojtabaTajik/ClaudeShelf](https://github.com/MojtabaTajik/ClaudeShelf) (Go 1.21, ~2,845 lines, embedded web UI)
- **Security audit:** 9 issues found in original (see SECURITY_AUDIT.md). 5 eliminated by removing the HTTP server. Remaining 4 (file permissions, error messages, CI pinning, race conditions) addressed in the architecture.
- **File scanner logic:** The Go scanner is the source of truth for discovery behavior. All scan locations, category rules, skip dirs, depth limits, and path decoding must be faithfully ported.
- **Target users:** Claude Code users who want to browse and manage their config files visually instead of via terminal.

## Constraints

- **Platform:** macOS 15+ (Sequoia) only — no iOS, no cross-platform
- **Language:** Swift 6 with strict concurrency checking
- **UI framework:** SwiftUI only — no AppKit unless SwiftUI has a gap
- **Dependencies:** Zero external dependencies — Apple frameworks only
- **Architecture:** MVVM with actors for shared state, no network layer
- **File safety:** Preserve permissions on save, `0600` default, trash over delete

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Native macOS app over web app | Eliminates 5 of 9 security issues from original; native UX | — Pending |
| Swift 6 + SwiftUI | Latest stable toolchain, structured concurrency for safe state management | — Pending |
| No external dependencies | Reduces supply chain risk, simplifies builds | — Pending |
| Trash over permanent delete | Reversible by default, safer for config files | — Pending |
| FSEvents over polling | Efficient, native file watching instead of manual rescan | — Pending |
| Three-column NavigationSplitView | Standard macOS pattern for browse/detail apps | — Pending |

---
*Last updated: 2026-02-10 after initialization*
