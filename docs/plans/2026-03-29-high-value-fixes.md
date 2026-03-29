# Innate High-Value Fixes

**Date:** 2026-03-29

**Goal:** Fix the highest-value correctness and maintenance issues now that the core interpreter is working and the test suite is green.

## Priority Order

### 1. Fix REPL resistance reporting

**Problem**

The REPL currently reports every `innate-resistance` as `[commission queued]`, even when the underlying failure is an unresolved reference, missing bundle, missing wikilink, or missing context.

**Why this is first**

- It is a direct user-facing behavior bug.
- It makes debugging interpreter behavior harder.
- It undermines trust in the semantics of both resistance and commissions.

**Files**

- `src/repl.lisp`
- `tests/test-repl.lisp`

**Work**

- Add a small formatting function for `innate-resistance` conditions.
- Distinguish ordinary resistance from successful commission delivery.
- Print the actual resistance message and source instead of a hard-coded commission string.
- Keep commission output behavior explicit and testable.

**Acceptance criteria**

- Unresolved references print a resistance message that matches the actual condition.
- Missing bundles and context failures print accurate resistance messages.
- Existing commission behavior remains covered by tests.
- New REPL tests assert the user-visible output for both resistance and commission paths.

### 2. Tighten public API and documentation alignment

**Problem**

The README and top-level API description have drifted away from the implementation. The docs still describe the system as scaffolding and refer to CLOS/node-class dispatch, while the implementation is already running and uses `defstruct` plus `etypecase`.

**Why this is second**

- It affects onboarding immediately.
- It is low-cost and reduces future confusion.
- It makes later refactors easier because the intended API surface becomes explicit.

**Files**

- `README.md`
- `src/innate.lisp`
- `tests/` if top-level exports are added

**Work**

- Keep the README synced with actual capabilities.
- Decide what the `:innate` package should export as the public entry point.
- Add top-level wrapper functions if needed instead of forcing callers through internal packages.

**Acceptance criteria**

- README matches actual interpreter behavior and architecture.
- `src/innate.lisp` either exposes a real public API or clearly documents that it is intentionally pending.
- Public entry points have basic coverage if new wrappers are added.

### 3. Remove O(n^2) hotspots in parser and top-level evaluator loops

**Problem**

The parser cursor and evaluator both use repeated `nth` access on lists. That is acceptable for small inputs but scales poorly as programs and documents grow.

**Why this is third**

- It is not yet breaking behavior.
- It is the clearest structural limit on scaling the interpreter.
- The change is localized and should be safe behind existing tests.

**Files**

- `src/parser/parser.lisp`
- `src/eval/evaluator.lisp`

**Work**

- Replace list-plus-index cursor access with a sequence better suited to positional reads, or switch the parser to cons-cell traversal.
- Replace evaluator `nth`-based iteration with direct list traversal while preserving agent-plus-bundle adjacency handling.
- Keep behavior identical.

**Acceptance criteria**

- No parser or evaluator behavior regressions.
- Full test suite remains green.
- Indexed `nth` access is removed from hot-path parsing/evaluation loops.

### 4. Narrow test runner cache deletion

**Problem**

`run-tests.sh` currently deletes the full `~/.cache/common-lisp/` tree. That is broader than necessary and caused permission friction during verification.

**Why this is fourth**

- It is operationally rough but not a language bug.
- The fix is straightforward once the higher-value correctness issue is addressed.

**Files**

- `run-tests.sh`

**Work**

- Restrict cache deletion to project-specific artifacts, or make cold-load behavior optional.
- Keep the script deterministic without deleting unrelated cache entries.

**Acceptance criteria**

- Running tests does not wipe unrelated Common Lisp cache state.
- The script still supports reliable clean runs.

## Recommended execution sequence

1. Fix REPL resistance reporting and add tests.
2. Add any missing top-level API wrappers needed for a coherent public surface.
3. Refactor parser/evaluator traversal away from `nth`.
4. Narrow cache-clearing behavior in the test runner.

## Definition of done for this phase

- README is accurate.
- REPL output is semantically correct for resistance cases.
- The highest-risk maintenance hotspots have a concrete implementation path.
- The full test suite passes after each change set.
