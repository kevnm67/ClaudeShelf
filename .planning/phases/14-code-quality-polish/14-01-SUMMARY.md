# Phase 14-01 Summary: Code Quality Polish

## Duration
Single session, 3 tasks completed.

## Tasks Completed

### Task 1: Fix logger inconsistencies
- Converted 4 loggers to consistent `private static let` pattern
- FileWatcher.swift: instance `let` -> `static let`, references updated to `Self.logger`
- FileDetailView.swift: file-scope global -> `static let` inside struct
- FileListView.swift: file-scope global -> `static let` inside struct
- CleanupSheet.swift: instance `let` -> `static let`

### Task 2: Fix ByteCountFormatter + DiffLine.id
- FileRowView.swift: replaced per-row `ByteCountFormatter()` allocation with `ByteCountFormatter.string(fromByteCount:countStyle:)` static method
- DiffView.swift: replaced nondeterministic `text.hashValue` in `DiffLine.id` with lineNumber-only IDs
- No test changes needed (DiffViewTests do not assert on `.id` values)

### Task 3: Deterministic ScanLocation UUIDs
- Added `import CryptoKit` to ScanLocation.swift
- Added `stableUUID(for:)` private static helper using SHA256
- Default locations now produce the same UUIDs across app launches
- ScanLocationStore merge-by-path strategy unaffected

## Files Modified
- `ClaudeShelf/Services/FileWatcher.swift`
- `ClaudeShelf/Views/Editor/FileDetailView.swift`
- `ClaudeShelf/Views/Sidebar/FileListView.swift`
- `ClaudeShelf/Views/Cleanup/CleanupSheet.swift`
- `ClaudeShelf/Views/Sidebar/FileRowView.swift`
- `ClaudeShelf/Views/Editor/DiffView.swift`
- `ClaudeShelf/Models/ScanLocation.swift`

## Verification
- Build: SUCCEEDED
- Tests: 149 executed, 0 failures
- No new warnings

## Deviations from Plan
None.
