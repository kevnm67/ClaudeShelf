---
phase: 04-editor
plan: 01
subsystem: code-editor
tags: [nstextview, nsviewrepresentable, line-numbers, code-editor, swiftui]

requires:
  - phase: 03-core-ui (plan 03)
    provides: FileDetailView with metadata header and .task(id:) content loading
provides:
  - CodeEditorView NSViewRepresentable wrapping NSTextView with line number gutter
  - Editable monospaced text with undo, horizontal/vertical scrolling
  - FileDetailView now uses CodeEditorView with originalContent for future dirty detection
affects: [04-02, 04-03]

tech-stack:
  added: [AppKit (NSTextView, NSScrollView, NSRulerView)]
  patterns: [NSViewRepresentable with @MainActor Coordinator, LineNumberRulerView using NSLayoutManager glyph enumeration, fileprivate access for file-scoped AppKit subclasses]

key-files:
  created:
    - ClaudeShelf/Views/Editor/CodeEditorView.swift
  modified:
    - ClaudeShelf/Views/Editor/FileDetailView.swift
    - ClaudeShelf.xcodeproj/project.pbxproj

key-decisions:
  - "Use NSTextView via NSViewRepresentable instead of SwiftUI TextEditor for line numbers and fine-grained control"
  - "LineNumberRulerView as fileprivate NSRulerView subclass within CodeEditorView.swift"
  - "Coordinator marked @MainActor for Swift 6 strict concurrency compliance"
  - "Store originalContent alongside fileContent in FileDetailView for future dirty detection in 04-03"
  - "Use NSRulerView as property type in Coordinator to avoid access level conflict with fileprivate LineNumberRulerView"

patterns-established:
  - "NSViewRepresentable + @MainActor Coordinator pattern for AppKit bridging under Swift 6 strict concurrency"
  - "isUpdating flag to prevent feedback loops between SwiftUI binding and NSTextViewDelegate"
  - "NSTextStorage.didProcessEditingNotification for ruler view updates on text changes"

issues-created: []

duration: 5min
completed: 2026-02-10
---

# Phase 4 Plan 1: Code Editor (NSTextView) Summary

**NSTextView-based code editor with line numbers replacing the read-only text display**

## Performance

- **Duration:** 5 min
- **Started:** 2026-02-10
- **Completed:** 2026-02-10
- **Tasks:** 2
- **Files created/modified:** 3

## Accomplishments

- Created CodeEditorView wrapping NSTextView in NSViewRepresentable
- Monospaced font (13pt), undo support, disabled all automatic text substitutions for code editing
- Horizontal and vertical scrolling with proper text container sizing
- LineNumberRulerView (NSRulerView subclass) showing right-aligned line numbers in gutter
- Gutter auto-sizes based on digit count of total lines
- Gutter has background fill and separator line for visual clarity
- Coordinator marked @MainActor for Swift 6 strict concurrency compliance
- Feedback loop prevention via isUpdating flag between binding updates and delegate callbacks
- Ruler redraws via NSTextStorage.didProcessEditingNotification
- FileDetailView now uses CodeEditorView instead of ScrollView+Text
- Read-only files render with isEditable=false
- originalContent state added for future dirty detection (04-03)
- isLoaded state for proper loading/error/content transitions
- All 42 existing tests pass
- Build succeeds with zero errors and zero warnings

## Task Commits

1. **Task 1: Create CodeEditorView NSViewRepresentable** - `3f325d9` (feat)
2. **Task 2: Integrate CodeEditorView into FileDetailView** - `9fc3b2e` (feat)

## Files Created/Modified

- `ClaudeShelf/Views/Editor/CodeEditorView.swift` - NSViewRepresentable wrapping NSTextView with @MainActor Coordinator, LineNumberRulerView with glyph-based line enumeration, horizontal scrolling, undo, and disabled auto-substitutions
- `ClaudeShelf/Views/Editor/FileDetailView.swift` - Replaced ScrollView+Text with CodeEditorView, added originalContent and isLoaded state, preserved metadata header
- `ClaudeShelf.xcodeproj/project.pbxproj` - Added CodeEditorView.swift to Editor group and Sources build phase (F1 prefix IDs)

## Decisions Made

- Used `NSTextView` via `NSViewRepresentable` instead of SwiftUI's `TextEditor` because TextEditor lacks line numbers, syntax highlighting hooks, and fine-grained undo control
- Defined `LineNumberRulerView` as `fileprivate` within `CodeEditorView.swift` to keep the AppKit implementation encapsulated
- Used `NSRulerView` as the property type in Coordinator instead of `LineNumberRulerView` to avoid access level conflicts between the `@MainActor` Coordinator (internal) and the `fileprivate` ruler class
- Renamed the notification handler from `textStorageDidProcessEditing` to `handleTextStorageDidProcessEditing` to avoid conflicting with the inherited NSObject method of the same name
- Stored `originalContent` in FileDetailView to prepare for dirty detection and Cmd+S save in plan 04-03

## Deviations from Plan

- Renamed notification handler to `handleTextStorageDidProcessEditing` to avoid override conflict with inherited NSObject method
- Used `NSRulerView` as the Coordinator property type instead of `LineNumberRulerView` to resolve Swift access level constraints

## Issues Encountered

- Swift 6 strict concurrency: The `fileprivate` access on `LineNumberRulerView` conflicted with the `@MainActor` Coordinator's internal access level. Resolved by using the public superclass `NSRulerView` as the property type.
- The `textStorageDidProcessEditing` method name conflicted with an inherited NSObject method, requiring an `override` keyword. Resolved by renaming to `handleTextStorageDidProcessEditing`.

## Next Phase Readiness

- CodeEditorView provides editable NSTextView with line numbers
- FileDetailView holds both fileContent and originalContent for dirty detection
- Ready for 04-02 (syntax highlighting) and 04-03 (save/dirty detection)

---
*Phase: 04-editor*
*Completed: 2026-02-10*
