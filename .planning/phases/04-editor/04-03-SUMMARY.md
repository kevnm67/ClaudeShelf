---
phase: 04-editor
plan: 03
subsystem: save-diff-readonly
tags: [save, permissions, dirty-tracking, diff-view, read-only, undo-redo, cmd-s]

requires:
  - phase: 04-editor (plan 01)
    provides: CodeEditorView NSViewRepresentable wrapping NSTextView with allowsUndo
  - phase: 04-editor (plan 02)
    provides: Syntax highlighting integrated into CodeEditorView
provides:
  - Cmd+S save with POSIX permission preservation
  - Dirty state tracking with visual accent dot indicator
  - Read-only detection with lock banner
  - DiffView showing line-by-line changes with color coding
  - Save error alerts with user-friendly messages
  - Undo/redo via NSTextView built-in undoManager
affects: []

tech-stack:
  added: [os.Logger, CollectionDifference, FileManager.attributesOfItem, POSIX permissions]
  patterns: [Permission-preserving save (read permissions, write, restore), computed isDirty from original vs current content, line-by-line diff via CollectionDifference]

key-files:
  created:
    - ClaudeShelf/Views/Editor/DiffView.swift
  modified:
    - ClaudeShelf/Views/Editor/FileDetailView.swift
    - ClaudeShelf.xcodeproj/project.pbxproj

key-decisions:
  - "Permission-preserving save: read POSIX permissions before write, restore after atomic write"
  - "isDirty as computed property comparing fileContent != originalContent"
  - "Accent-colored dot indicator for unsaved changes in header"
  - "Read-only banner with lock icon and secondary styling below header"
  - "Save button and Review Changes button only visible when isDirty && !isReadOnly"
  - "DiffView uses CollectionDifference for line-by-line diff computation"
  - "Color coding: red for removed lines (with strikethrough), green for added, normal for unchanged"
  - "User-friendly error messages in alerts, detailed errors logged via os.Logger"
  - "Undo/redo handled by NSTextView's built-in undoManager (no additional code)"

patterns-established:
  - "saveFile() pattern: read attributes -> write atomically -> restore permissions"
  - "isPresented binding from optional @State for error alert display"
  - "DiffLine enum with Identifiable conformance for diff output representation"
  - "buildDiffOutput() walking original and modified with removed/inserted offset sets"

issues-created: []

duration: 6min
completed: 2026-02-10
---

# Phase 4 Plan 3: Save, Diff, and Read-Only Summary

**Cmd+S save with permission preservation, dirty tracking, diff view, and read-only detection**

## Performance

- **Duration:** 6 min
- **Started:** 2026-02-10
- **Completed:** 2026-02-10
- **Tasks:** 2
- **Files created/modified:** 3

## Accomplishments

- Added `saveFile()` method to FileDetailView that preserves POSIX permissions:
  - Reads current permissions via `FileManager.attributesOfItem`
  - Writes content atomically via `String.write(toFile:atomically:encoding:)`
  - Restores original permissions after atomic write
  - Updates `originalContent` to clear dirty state on success
- Dirty state tracking via computed `isDirty` property comparing `fileContent != originalContent`
- Visual dirty indicator: accent-colored 8pt dot next to file name in header
- Cmd+S keyboard shortcut on Save button, only visible when `isDirty && !file.isReadOnly`
- Save error alert with user-friendly message ("Unable to save file. Please check permissions and try again.")
- Detailed error logging via `os.Logger` (never exposing raw paths to UI)
- Read-only banner below header with lock icon and "This file is read-only" text
- Created DiffView with line-by-line diff using Swift's `CollectionDifference`:
  - Red text with minus prefix and strikethrough for removed lines
  - Green text with plus prefix for added lines
  - Normal text for unchanged lines
  - "N lines changed" summary header
  - Save and Cancel buttons with keyboard shortcuts
  - Monospaced font in ScrollView
- "Review Changes" button in FileDetailView header opens DiffView as sheet
- Saving from DiffView calls `saveFile()` and dismisses the sheet
- Undo/redo works via NSTextView's built-in `allowsUndo` (Cmd+Z / Cmd+Shift+Z)
- Added two #Preview blocks: "Editable" and "Read-Only" variants
- All existing tests pass
- Build succeeds with zero errors and zero warnings

## Task Commits

1. **Task 1+2: Save with permission preservation, dirty tracking, diff view** - `a9256ef` (feat)

## Files Created/Modified

- `ClaudeShelf/Views/Editor/DiffView.swift` - New view showing line-by-line diff between original and modified text. Uses private `DiffLine` enum for unchanged/added/removed lines. `buildDiffOutput()` uses `CollectionDifference` to compute insertions and removals. Color-coded display with monospaced font, summary header, and Save/Cancel buttons.
- `ClaudeShelf/Views/Editor/FileDetailView.swift` - Added `import os` and Logger, `saveError` and `showDiff` state, `isDirty` computed property, `saveFile()` with permission preservation, dirty dot indicator, Save and Review Changes buttons with keyboard shortcuts, read-only banner, save error alert, DiffView sheet, and two #Preview blocks.
- `ClaudeShelf.xcodeproj/project.pbxproj` - Added DiffView.swift to Editor group and Sources build phase (F3 prefix IDs).

## Decisions Made

- Combined Tasks 1 and 2 into a single commit because FileDetailView references DiffView (interdependent files cannot be committed separately without breaking the build)
- Used `Color.accentColor` for the dirty indicator dot (`.accent` ShapeStyle is not available on macOS 15)
- Made `DiffLine` enum `private` and all methods using it `private` to satisfy Swift access control
- Used `isPresented` binding from optional `saveError` state for alert display pattern
- Chose simple `buildDiffOutput` algorithm walking both arrays with removed/inserted offset sets rather than full LCS visualization

## Deviations from Plan

- Tasks 1 and 2 committed together instead of separately due to file interdependency
- Simplified the DiffView diff algorithm to use a single clean `buildDiffOutput` method instead of the initial two-pass approach drafted in the plan

## Issues Encountered

- `.accent` is not a valid `ShapeStyle` member on macOS 15; used `Color.accentColor` instead
- `Category.globalSettings` does not exist in the Category enum; used `.settings` in the Read-Only preview
- `DiffLine` access control: `private` enum required all methods returning or accepting it to also be `private`

## Next Phase Readiness

- Phase 4 Editor is now complete with all three plans executed:
  - 04-01: CodeEditorView with NSTextView, line numbers, undo support
  - 04-02: Syntax highlighting for JSON, YAML, TOML, Markdown
  - 04-03: Save with permission preservation, dirty tracking, diff view, read-only detection
- Ready to proceed to Phase 5 or additional features

---
*Phase: 04-editor*
*Completed: 2026-02-10*
