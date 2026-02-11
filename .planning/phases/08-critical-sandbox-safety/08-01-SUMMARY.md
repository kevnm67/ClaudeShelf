---
phase: 08-critical-sandbox-safety
plan: 01
subsystem: infra
tags: [sandbox, entitlements, actor-isolation, swift-concurrency]

# Dependency graph
requires:
  - phase: 07-cleanup-export-polish
    provides: Complete v1.0 app with all features
provides:
  - Sandbox disabled for programmatic file access
  - Race-free FileWatcher lifecycle
affects: [09-security-hardening, 11-filewatcher-fsevents-rewrite]

# Tech tracking
tech-stack:
  added: []
  patterns: [remove-deinit-from-actors]

key-files:
  modified: [ClaudeShelf/ClaudeShelf.entitlements, ClaudeShelf/Services/FileWatcher.swift]

key-decisions:
  - "Disabled sandbox entirely rather than using temporary exceptions (deprecated, App Store rejected)"
  - "Removed deinit rather than using nonisolated(unsafe) — DispatchSource cancel handlers already clean up"

patterns-established:
  - "Actors should not have deinit blocks that access isolated state"

issues-created: []

# Metrics
duration: 1min
completed: 2026-02-10
---

# Phase 8 Plan 1: Critical Sandbox & Safety Summary

**Disabled app sandbox for programmatic file scanning and eliminated FileWatcher actor isolation data race by removing unsafe deinit**

## Performance

- **Duration:** 1 min
- **Started:** 2026-02-10T19:00:47Z
- **Completed:** 2026-02-10T19:01:50Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- Disabled app sandbox — app can now scan ~/.claude/, ~/projects/, and other directories on launch
- Eliminated data race in FileWatcher deinit that accessed actor-isolated state from arbitrary thread
- All 89 tests pass with no regressions

## Task Commits

Each task was committed atomically:

1. **Task 1: Disable app sandbox** - `a5b608f` (fix)
2. **Task 2: Remove FileWatcher deinit** - `e5db466` (fix)

## Files Created/Modified
- `ClaudeShelf/ClaudeShelf.entitlements` - Sandbox disabled, user-selected entitlement removed
- `ClaudeShelf/Services/FileWatcher.swift` - Removed unsafe deinit block (5 lines)

## Decisions Made
- Disabled sandbox entirely rather than using temporary exception entitlements — they are deprecated and rejected by App Store review. Standard approach for developer tools needing broad filesystem access.
- Removed deinit entirely rather than using `nonisolated(unsafe)` wrapper — the existing `setCancelHandler` on each DispatchSource already calls `close(fd)`, making the deinit redundant AND unsafe.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None

## Next Phase Readiness
- Phase 8 complete (single plan phase)
- Ready for Phase 9: Security Hardening (TOCTOU save race, symlink protection, error sanitization)

---
*Phase: 08-critical-sandbox-safety*
*Completed: 2026-02-10*
