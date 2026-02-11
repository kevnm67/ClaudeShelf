---
phase: 11-filewatcher-fsevents-rewrite
plan: 01
subsystem: file-watching
tags: [fsevents, recursive-watching, dispatch-queue, c-callback-bridge]

requires:
  - phase: 08-critical-sandbox-safety
    provides: Sandbox disabled, FileWatcher actor safe
provides:
  - Recursive FSEvents-based file watching
  - Subdirectory change detection
affects: [13-testability-coverage]

tech-stack:
  added: [CoreServices/FSEvents]
  patterns: [FileWatcherContext-bridge-class, Unmanaged-passUnretained-for-C-callback]

key-files:
  modified: [ClaudeShelf/Services/FileWatcher.swift, ClaudeShelfTests/FileWatcherTests.swift]

key-decisions:
  - "FileWatcherContext bridging class (@unchecked Sendable) to pass actor context through C callback"
  - "Unmanaged.passUnretained (not passRetained) to avoid retain cycle"
  - "kFSEventStreamCreateFlagFileEvents for per-file recursive events"
  - "Increased debounce test interval to 0.8s for FSEvents file-level event coalescing"

patterns-established:
  - "C callback to actor bridge via helper class + Unmanaged pointer"
  - "FSEventStream lifecycle: Create → SetDispatchQueue → Start → Stop → Invalidate → Release"

issues-created: []

duration: 4min
completed: 2026-02-11
---

# Phase 11 Plan 1: FileWatcher FSEvents Rewrite Summary

**FSEvents recursive file watching replacing per-directory DispatchSource, with C-callback-to-actor bridge and subdirectory detection**

## Performance

- **Duration:** 4 min
- **Started:** 2026-02-11T00:22:23Z
- **Completed:** 2026-02-11T00:25:55Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- Replaced DispatchSource per-directory watching with FSEvents recursive watching
- Subdirectory changes now detected (fixes audit finding H-3)
- Bridged C function pointer callback to actor isolation via FileWatcherContext helper class
- Added recursive subdirectory test proving the new capability
- All 90 tests pass (89 existing + 1 new)

## Task Commits

1. **Task 1: Rewrite FileWatcher with FSEvents recursive watching** - `0bf7cb3` (feat)
2. **Task 2: Add recursive subdirectory watching test** - `0d419b8` (test)

## Files Created/Modified
- `ClaudeShelf/Services/FileWatcher.swift` - Complete rewrite: FSEventStream, FileWatcherContext bridge, Unmanaged pointer
- `ClaudeShelfTests/FileWatcherTests.swift` - New testWatcherDetectsSubdirectoryFileCreation, adjusted debounce timing

## Decisions Made
- Used `FileWatcherContext` (`@unchecked Sendable`) to bridge C callback to actor — only way to pass context through FSEvents C function pointer
- Used `Unmanaged.passUnretained` (not `passRetained`) — avoids retain cycle, context kept alive via stored property
- Used `kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagNoDefer` — per-file events with low latency
- Adjusted debounce test from 0.3s to 0.8s — FSEvents fires individual file-level events that can span multiple debounce windows

## Deviations from Plan
- Debounce test timing adjustment (plan anticipated this): increased debounce interval and reduced inter-write sleep for reliable coalescing with FSEvents file-level events

## Issues Encountered
None

## Next Phase Readiness
- Phase 11 complete
- Ready for Phase 12: Error Handling & Accessibility

---
*Phase: 11-filewatcher-fsevents-rewrite*
*Completed: 2026-02-11*
