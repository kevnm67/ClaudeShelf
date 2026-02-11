# Roadmap: ClaudeShelf

## Overview

Build a native macOS SwiftUI app from the ground up that replaces the Go-based ClaudeShelf web app. Start with project foundation and data models, then port the file scanning engine from Go, build the three-column UI, add a syntax-highlighted editor, implement safe file operations, wire up live file watching, and finish with cleanup tools, export, and platform polish. Then harden the app with security fixes, async correctness, test coverage, and accessibility.

## Domain Expertise

None

## Milestones

- ✅ **v1.0 MVP** - Phases 1-7 (shipped 2026-02-10)
- 🚧 **v1.1 Audit Fixes & Hardening** - Phases 8-14 (in progress)

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

<details>
<summary>✅ v1.0 MVP (Phases 1-7) — SHIPPED 2026-02-10</summary>

- [x] **Phase 1: Foundation** - Xcode project, app architecture, data models, MVVM scaffolding
- [x] **Phase 2: File Scanner** - Core scanning engine ported from Go: locations, categories, path decoding, skip rules, depth limits
- [x] **Phase 3: Core UI** - Three-column NavigationSplitView, sidebar with categories, file list, search, keyboard navigation
- [x] **Phase 4: Editor** - Syntax-highlighted editor, undo/redo, line numbers, Cmd+S save, diff view, read-only detection
- [x] **Phase 5: File Operations** - Permission-preserving save, trash/delete, bulk operations, confirmation dialogs
- [x] **Phase 6: File Watching** - FSEvents-based watching, auto-refresh, manual rescan, configurable scan locations
- [x] **Phase 7: Cleanup, Export & Polish** - Cleanup analysis & modal, zip export, multiple windows, Quick Look, menu bar, dark/light mode

</details>

### 🚧 v1.1 Audit Fixes & Hardening (Phases 8-14)

- [x] **Phase 8: Critical Sandbox & Safety** - Fix sandbox entitlements blocking scanning, FileWatcher actor isolation
- [x] **Phase 9: Security Hardening** - TOCTOU save race, symlink protection, error sanitization
- [x] **Phase 10: Async & Main Thread Safety** - Async export, async cleanup analysis, NSSavePanel modernization
- [ ] **Phase 11: FileWatcher FSEvents Rewrite** - Replace DispatchSource with recursive FSEvents watching
- [ ] **Phase 12: Error Handling & Accessibility** - Silent trash fix, stale metadata, VoiceOver labels
- [ ] **Phase 13: Testability & Test Coverage** - Protocol boundaries, DI, FileScanner/AppState/SyntaxHighlighter tests
- [ ] **Phase 14: Code Quality Polish** - Logger consistency, ByteCountFormatter, placeholder test, DiffLine IDs

## Phase Details

<details>
<summary>✅ v1.0 MVP Phase Details</summary>

### Phase 1: Foundation
**Goal**: Xcode project with app shell, MVVM architecture, all core data models, and the basic app entry point running
**Depends on**: Nothing (first phase)
**Research**: Unlikely (standard Swift/SwiftUI project setup)
**Plans**: TBD

Plans:
- [x] 01-01: Xcode project setup, targets, build settings, Swift 6 strict concurrency
- [x] 01-02: Core data models (FileEntry, Category, Scope, ScanLocation) and app architecture scaffolding

### Phase 2: File Scanner
**Goal**: Fully functional file scanner that discovers Claude config files across all scan locations with correct category assignment, path decoding, skip rules, and depth limits — faithfully ported from the Go implementation
**Depends on**: Phase 1
**Research**: Unlikely (porting existing Go logic to Swift, standard FileManager APIs)
**Plans**: TBD

Plans:
- [x] 02-01: Scanner core — scan locations, directory walking, skip rules, depth limits
- [x] 02-02: File recognition, category assignment (9 categories with priority rules), path decoding, ID generation
- [x] 02-03: Scanner integration — AppState wiring, async scanning, error handling

### Phase 3: Core UI
**Goal**: Three-column NavigationSplitView with category sidebar (icons, counts, sizes), filterable file list, basic file content viewer, real-time search, and keyboard navigation
**Depends on**: Phase 2
**Research**: Unlikely (standard SwiftUI NavigationSplitView patterns on macOS)
**Plans**: TBD

Plans:
- [x] 03-01: Three-column NavigationSplitView layout, sidebar with categories, SF Symbols icons, file counts
- [x] 03-02: File list view with sorting, visual grouping by scope (global vs project)
- [x] 03-03: Search (Cmd+F), keyboard shortcuts, basic file content display

### Phase 4: Editor
**Goal**: Full-featured text editor with syntax highlighting for Markdown/JSON/YAML/TOML, undo/redo, line numbers, Cmd+S save, diff view for unsaved changes, and read-only detection with lock icon
**Depends on**: Phase 3
**Research**: Likely (syntax highlighting in SwiftUI is non-trivial)
**Research topics**: TextKit2 vs NSTextView bridging via NSViewRepresentable for syntax highlighting, SwiftUI text editor capabilities on macOS 15, diff view approaches (inline vs side-by-side), language grammar detection
**Plans**: TBD

Plans:
- [x] 04-01: Text editor foundation — NSTextView bridge or TextKit2 approach, line numbers
- [x] 04-02: Syntax highlighting for Markdown, JSON, YAML, TOML
- [x] 04-03: Undo/redo, Cmd+S save, diff view, read-only detection

### Phase 5: File Operations
**Goal**: Safe file operations — permission-preserving save (read POSIX before write, restore after), trash as default delete, permanent delete with explicit confirmation, single and bulk delete with confirmation dialogs, new files default to 0600
**Depends on**: Phase 4
**Research**: Unlikely (standard FileManager APIs, POSIX permission handling)
**Plans**: TBD

Plans:
- [x] 05-01: Permission-preserving save, new file creation with 0600 default
- [x] 05-02: Trash delete, permanent delete with confirmation, bulk operations

### Phase 6: File Watching
**Goal**: FSEvents-based file watcher that auto-refreshes the file list on disk changes, manual rescan button, and configurable scan locations in Settings
**Depends on**: Phase 5
**Research**: Likely (FSEvents integration patterns in Swift)
**Research topics**: DispatchSource.makeFileSystemObjectSource vs FSEvents C API, actor-safe file watching patterns in Swift 6 structured concurrency, debouncing/coalescing rapid file system events
**Plans**: TBD

Plans:
- [x] 06-01: FSEvents file watcher actor with debouncing
- [x] 06-02: Settings view with configurable scan locations, manual rescan

### Phase 7: Cleanup, Export & Polish
**Goal**: Cleanup tool (empty files, empty content, stale files with modal), zip export, multiple windows, Quick Look integration, complete menu bar, dark/light mode, final polish
**Depends on**: Phase 6
**Research**: Unlikely (standard macOS patterns, minor Quick Look investigation)
**Plans**: TBD

Plans:
- [x] 07-01: Cleanup analyzer (empty, empty-content, stale) and cleanup modal UI
- [x] 07-02: Zip export of selected files
- [x] 07-03: Multiple windows, Quick Look (spacebar preview), menu bar, dark/light mode, final polish


</details>

### Phase 8: Critical Sandbox & Safety
**Goal**: Fix the two critical blockers — sandbox entitlements that prevent the app from scanning any directories, and FileWatcher actor isolation violation in deinit that causes a data race
**Depends on**: v1.0 complete
**Research**: Unlikely (entitlements documentation, Swift actor isolation rules)
**Plans**: 1

Plans:
- [x] 08-01: Disable sandbox, fix FileWatcher deinit actor isolation

### Phase 9: Security Hardening
**Goal**: Eliminate TOCTOU race in file save (files briefly world-readable), add symlink loop protection in scanner, sanitize error messages to prevent raw path leakage
**Depends on**: Phase 8
**Research**: Unlikely (POSIX file permission APIs, FileManager symlink detection)
**Plans**: 1

Plans:
- [x] 09-01: TOCTOU fix, symlink protection, error sanitization

### Phase 10: Async & Main Thread Safety
**Goal**: Make ExportService.exportAsZip and CleanupAnalyzer.analyze async to prevent main thread blocking, modernize NSSavePanel to async pattern
**Depends on**: Phase 9
**Research**: Unlikely (Swift concurrency patterns, Process terminationHandler)
**Plans**: 1

Plans:
- [x] 10-01: Async ExportService, async CleanupAnalyzer, async UI callers

### Phase 11: FileWatcher FSEvents Rewrite
**Goal**: Replace per-directory DispatchSource watching with FSEvents-based recursive watching so subdirectory file changes are detected (current watcher misses most changes)
**Depends on**: Phase 10
**Research**: Likely (FSEvents C API from Swift, recursive monitoring patterns)
**Research topics**: FSEventStreamCreate vs DispatchSource for recursive watching, FSEventStreamEventFlags interpretation, actor-safe callback patterns for FSEvents in Swift 6
**Plans**: TBD

Plans:
- [ ] 11-01: TBD

### Phase 12: Error Handling & Accessibility
**Goal**: Fix silent trash failure in FileRowView (user gets no feedback), handle stale FileEntry metadata between scans, add VoiceOver accessibility labels and button traits to interactive elements
**Depends on**: Phase 11
**Research**: Unlikely (SwiftUI accessibility modifiers, standard patterns)
**Plans**: TBD

Plans:
- [ ] 12-01: TBD

### Phase 13: Testability & Test Coverage
**Goal**: Add protocol boundaries on services for dependency injection, make ScanLocationStore injectable (fix UserDefaults pollution in tests), add missing tests for FileScanner, AppState, SyntaxHighlighter, and DiffView
**Depends on**: Phase 12
**Research**: Unlikely (standard Swift protocol/DI patterns, XCTest)
**Plans**: TBD

Plans:
- [ ] 13-01: TBD

### Phase 14: Code Quality Polish
**Goal**: Fix logger inconsistencies (static, matching bundle ID subsystem), ByteCountFormatter per-row allocation, remove placeholder test, fix DiffLine.id nondeterminism, deterministic ScanLocation UUIDs
**Depends on**: Phase 13
**Research**: Unlikely (internal code quality, no new APIs)
**Plans**: TBD

Plans:
- [ ] 14-01: TBD

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3 → 4 → 5 → 6 → 7 → 8 → 9 → 10 → 11 → 12 → 13 → 14

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|---------------|--------|-----------|
| 1. Foundation | v1.0 | 2/2 | Complete | 2026-02-10 |
| 2. File Scanner | v1.0 | 3/3 | Complete | 2026-02-10 |
| 3. Core UI | v1.0 | 3/3 | Complete | 2026-02-10 |
| 4. Editor | v1.0 | 3/3 | Complete | 2026-02-10 |
| 5. File Operations | v1.0 | 2/2 | Complete | 2026-02-10 |
| 6. File Watching | v1.0 | 2/2 | Complete | 2026-02-10 |
| 7. Cleanup, Export & Polish | v1.0 | 3/3 | Complete | 2026-02-10 |
| 8. Critical Sandbox & Safety | v1.1 | 1/1 | Complete | 2026-02-10 |
| 9. Security Hardening | v1.1 | 1/1 | Complete | 2026-02-10 |
| 10. Async & Main Thread Safety | v1.1 | 1/1 | Complete | 2026-02-11 |
| 11. FileWatcher FSEvents Rewrite | v1.1 | 0/? | Not started | - |
| 12. Error Handling & Accessibility | v1.1 | 0/? | Not started | - |
| 13. Testability & Test Coverage | v1.1 | 0/? | Not started | - |
| 14. Code Quality Polish | v1.1 | 0/? | Not started | - |
