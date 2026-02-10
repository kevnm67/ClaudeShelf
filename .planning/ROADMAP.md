# Roadmap: ClaudeShelf

## Overview

Build a native macOS SwiftUI app from the ground up that replaces the Go-based ClaudeShelf web app. Start with project foundation and data models, then port the file scanning engine from Go, build the three-column UI, add a syntax-highlighted editor, implement safe file operations, wire up live file watching, and finish with cleanup tools, export, and platform polish.

## Domain Expertise

None

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [ ] **Phase 1: Foundation** - Xcode project, app architecture, data models, MVVM scaffolding
- [ ] **Phase 2: File Scanner** - Core scanning engine ported from Go: locations, categories, path decoding, skip rules, depth limits
- [ ] **Phase 3: Core UI** - Three-column NavigationSplitView, sidebar with categories, file list, search, keyboard navigation
- [ ] **Phase 4: Editor** - Syntax-highlighted editor, undo/redo, line numbers, Cmd+S save, diff view, read-only detection
- [ ] **Phase 5: File Operations** - Permission-preserving save, trash/delete, bulk operations, confirmation dialogs
- [ ] **Phase 6: File Watching** - FSEvents-based watching, auto-refresh, manual rescan, configurable scan locations
- [ ] **Phase 7: Cleanup, Export & Polish** - Cleanup analysis & modal, zip export, multiple windows, Quick Look, menu bar, dark/light mode

## Phase Details

### Phase 1: Foundation
**Goal**: Xcode project with app shell, MVVM architecture, all core data models, and the basic app entry point running
**Depends on**: Nothing (first phase)
**Research**: Unlikely (standard Swift/SwiftUI project setup)
**Plans**: TBD

Plans:
- [ ] 01-01: Xcode project setup, targets, build settings, Swift 6 strict concurrency
- [ ] 01-02: Core data models (FileEntry, Category, Scope, ScanLocation) and app architecture scaffolding

### Phase 2: File Scanner
**Goal**: Fully functional file scanner that discovers Claude config files across all scan locations with correct category assignment, path decoding, skip rules, and depth limits — faithfully ported from the Go implementation
**Depends on**: Phase 1
**Research**: Unlikely (porting existing Go logic to Swift, standard FileManager APIs)
**Plans**: TBD

Plans:
- [ ] 02-01: Scanner core — scan locations, directory walking, skip rules, depth limits
- [ ] 02-02: File recognition, category assignment (9 categories with priority rules), path decoding, ID generation
- [ ] 02-03: Scanner integration — AppState wiring, async scanning, error handling

### Phase 3: Core UI
**Goal**: Three-column NavigationSplitView with category sidebar (icons, counts, sizes), filterable file list, basic file content viewer, real-time search, and keyboard navigation
**Depends on**: Phase 2
**Research**: Unlikely (standard SwiftUI NavigationSplitView patterns on macOS)
**Plans**: TBD

Plans:
- [ ] 03-01: Three-column NavigationSplitView layout, sidebar with categories, SF Symbols icons, file counts
- [ ] 03-02: File list view with sorting, visual grouping by scope (global vs project)
- [ ] 03-03: Search (Cmd+F), keyboard shortcuts, basic file content display

### Phase 4: Editor
**Goal**: Full-featured text editor with syntax highlighting for Markdown/JSON/YAML/TOML, undo/redo, line numbers, Cmd+S save, diff view for unsaved changes, and read-only detection with lock icon
**Depends on**: Phase 3
**Research**: Likely (syntax highlighting in SwiftUI is non-trivial)
**Research topics**: TextKit2 vs NSTextView bridging via NSViewRepresentable for syntax highlighting, SwiftUI text editor capabilities on macOS 15, diff view approaches (inline vs side-by-side), language grammar detection
**Plans**: TBD

Plans:
- [ ] 04-01: Text editor foundation — NSTextView bridge or TextKit2 approach, line numbers
- [ ] 04-02: Syntax highlighting for Markdown, JSON, YAML, TOML
- [ ] 04-03: Undo/redo, Cmd+S save, diff view, read-only detection

### Phase 5: File Operations
**Goal**: Safe file operations — permission-preserving save (read POSIX before write, restore after), trash as default delete, permanent delete with explicit confirmation, single and bulk delete with confirmation dialogs, new files default to 0600
**Depends on**: Phase 4
**Research**: Unlikely (standard FileManager APIs, POSIX permission handling)
**Plans**: TBD

Plans:
- [ ] 05-01: Permission-preserving save, new file creation with 0600 default
- [ ] 05-02: Trash delete, permanent delete with confirmation, bulk operations

### Phase 6: File Watching
**Goal**: FSEvents-based file watcher that auto-refreshes the file list on disk changes, manual rescan button, and configurable scan locations in Settings
**Depends on**: Phase 5
**Research**: Likely (FSEvents integration patterns in Swift)
**Research topics**: DispatchSource.makeFileSystemObjectSource vs FSEvents C API, actor-safe file watching patterns in Swift 6 structured concurrency, debouncing/coalescing rapid file system events
**Plans**: TBD

Plans:
- [ ] 06-01: FSEvents file watcher actor with debouncing
- [ ] 06-02: Settings view with configurable scan locations, manual rescan

### Phase 7: Cleanup, Export & Polish
**Goal**: Cleanup tool (empty files, empty content, stale files with modal), zip export, multiple windows, Quick Look integration, complete menu bar, dark/light mode, final polish
**Depends on**: Phase 6
**Research**: Unlikely (standard macOS patterns, minor Quick Look investigation)
**Plans**: TBD

Plans:
- [ ] 07-01: Cleanup analyzer (empty, empty-content, stale) and cleanup modal UI
- [ ] 07-02: Zip export of selected files
- [ ] 07-03: Multiple windows, Quick Look (spacebar preview), menu bar, dark/light mode, final polish

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3 → 4 → 5 → 6 → 7

| Phase | Plans Complete | Status | Completed |
|-------|---------------|--------|-----------|
| 1. Foundation | 0/2 | Not started | - |
| 2. File Scanner | 0/3 | Not started | - |
| 3. Core UI | 0/3 | Not started | - |
| 4. Editor | 0/3 | Not started | - |
| 5. File Operations | 0/2 | Not started | - |
| 6. File Watching | 0/2 | Not started | - |
| 7. Cleanup, Export & Polish | 0/3 | Not started | - |
