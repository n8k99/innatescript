---
phase: 09-repl-and-integration
plan: 02
subsystem: repl
tags: [common-lisp, shell, sbcl, asdf, repl, file-runner, integration]

# Dependency graph
requires:
  - phase: 09-repl-and-integration/09-01
    provides: innate.repl:repl, innate.repl:run-file, innate.repl:print-result
  - phase: 06-stub-resolver
    provides: make-stub-resolver, make-eval-env
provides:
  - run-repl.sh shell entry point for interactive REPL and batch file evaluation
  - End-to-end pipeline verified: tokenize->parse->evaluate on burg_pipeline.dpn
  - rlwrap compatibility (no terminal manipulation in Lisp)
affects: [any future CLI phase, noosphere resolver integration, user-facing docs]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - sbcl --non-interactive for file mode, plain sbcl for interactive mode — --non-interactive disables stdin read-line
    - make-broadcast-stream to silence ASDF compilation noise without suppressing REPL output
    - --noinform flag to suppress SBCL banner on startup
    - Single-line --eval args in shell script avoid heredoc/multiline parsing issues

key-files:
  created:
    - run-repl.sh
  modified:
    - src/packages.lisp

key-decisions:
  - "Interactive mode uses sbcl without --non-interactive — that flag disables stdin read-line; file mode uses --non-interactive to force exit after eval"
  - "ASDF noise suppressed with make-broadcast-stream around asdf:load-system — both *standard-output* and *error-output* redirected so compilation warnings do not pollute REPL output"
  - "print-result added to innate.repl :export — shell script calls innate.repl:print-result externally; it must be exported for the reader to resolve the symbol"

patterns-established:
  - "Shell script --eval args kept on single lines to avoid multiline parsing issues when SBCL receives them as --eval strings (piped stdin cannot distinguish eval continuation from input)"

requirements-completed: [RUN-03, RUN-04, PRJ-05]

# Metrics
duration: 2min
completed: 2026-03-29
---

# Phase 9 Plan 02: REPL and Integration Summary

**run-repl.sh shell entry point connecting SBCL to innate.repl:repl and innate.repl:run-file, completing the user-facing CLI surface with burg_pipeline.dpn end-to-end verified**

## Performance

- **Duration:** ~2 min
- **Started:** 2026-03-29T05:04:54Z
- **Completed:** 2026-03-29T05:06:27Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments

- Created `run-repl.sh` with both interactive mode (no args) and file mode (one arg)
- `burg_pipeline.dpn` evaluates end-to-end through the full tokenize->parse->evaluate pipeline with exit code 0
- 174/174 tests pass (all existing tests, no regressions)
- `rlwrap ./run-repl.sh` works with no changes to Lisp code (no terminal manipulation in REPL loop)
- Interactive mode tested: `decree name [World]\n@name` correctly stores decree and resolves reference to `= World`

## Task Commits

1. **Task 1: Create run-repl.sh shell script** - `5edc28e` (feat)
2. **Task 2: End-to-end integration verification + print-result export fix** - `b1a18d2` (fix)

## Files Created/Modified

- `/home/n8k99/Development/innatescript/run-repl.sh` - Shell entry point; interactive and file evaluation modes
- `/home/n8k99/Development/innatescript/src/packages.lisp` - Added `#:print-result` to innate.repl :export list

## Decisions Made

- Interactive mode uses plain `sbcl` (not `--non-interactive`) — the `--non-interactive` flag disables `read-line` from stdin, breaking the REPL loop entirely
- ASDF compilation noise suppressed via `(let ((*standard-output* (make-broadcast-stream)) (*error-output* (make-broadcast-stream))) ...)` around `asdf:load-system` — prevents compilation messages from polluting REPL output or file runner results
- Shell `--eval` arguments kept on single lines — multi-line heredoc-style eval strings caused SBCL to misparse when stdin was a pipe (it tried to read continuation from stdin)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical] Exported print-result from innate.repl package**
- **Found during:** Task 2 (End-to-end integration verification)
- **Issue:** Shell script calls `innate.repl:print-result` externally, but the symbol was not in the package's `:export` list. SBCL reader error: "The symbol PRINT-RESULT is not external in the INNATE.REPL package."
- **Fix:** Added `#:print-result` to `(:export #:repl #:run-file #:print-result)` in `src/packages.lisp`
- **Files modified:** src/packages.lisp
- **Verification:** `./run-repl.sh burg_pipeline.dpn` exits 0, `./run-tests.sh` exits 0 (174/174)
- **Committed in:** b1a18d2 (Task 2 commit)

---

**Total deviations:** 1 auto-fixed (Rule 2 - missing critical export)
**Impact on plan:** Necessary correctness fix. Without the export the shell script cannot call print-result at all. No scope creep.

## Issues Encountered

The initial multi-line `LOAD_SYSTEM` bash variable with embedded newlines caused SBCL to enter the interactive debugger when stdin was a pipe (the reader tried to read the variable continuation as interactive input). Fixed by keeping all `--eval` arguments on a single line each.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- `run-repl.sh` is complete and verified
- Phase 09 is now fully complete: REPL (Plan 01) + shell entry point (Plan 02)
- The full Innate interpreter is user-accessible: `./run-repl.sh` for interactive use, `./run-repl.sh file.dpn` for batch evaluation
- All 174 tests pass; burg_pipeline.dpn evaluates end-to-end
- Ready for noosphere resolver integration (private repo, future phase)

---
*Phase: 09-repl-and-integration*
*Completed: 2026-03-29*
