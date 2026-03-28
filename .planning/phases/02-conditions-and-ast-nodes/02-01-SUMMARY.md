---
phase: 02-conditions-and-ast-nodes
plan: 01
subsystem: testing
tags: [common-lisp, asdf, packages, exports, innate-types, innate-conditions]

# Dependency graph
requires:
  - phase: 01-project-scaffolding
    provides: Package stubs in src/packages.lisp and tests/packages.lisp; ASDF system definition in innatescript.asd
provides:
  - Complete export lists for innate.types (32 symbols) and innate.conditions (7 symbols)
  - Test package namespaces innate.tests.types and innate.tests.conditions with correct :import-from lists
  - ASDF test system registration for test-conditions and test-types file components
affects:
  - 02-02 (types.lisp implementation — imports make-node, +node-*+ constants from innate.types)
  - 02-03 (conditions.lisp implementation — imports innate-condition, innate-parse-error, innate-resistance from innate.conditions)
  - 03-parser (imports innate.types symbols via :import-from)
  - 05-evaluator (imports innate.types and innate.conditions)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Export contract first: package exports defined before implementation, downstream packages can :import-from immediately"
    - "Test package mirrors implementation package: innate.tests.types imports exactly the same symbols as innate.types exports"

key-files:
  created: []
  modified:
    - src/packages.lisp
    - tests/packages.lisp
    - innatescript.asd

key-decisions:
  - "innate.conditions :import-from :innate.types left without explicit symbol list — conditions.lisp will declare specific imports at implementation time"
  - "Test package innate.tests.conditions imports all 7 condition symbols; innate.tests.types imports all 32 type symbols — test packages are complete import mirrors of their implementation packages"
  - "test-conditions and test-types ASDF components depend only on packages and test-framework — no inter-test dependencies"

patterns-established:
  - "Contract-first package exports: define complete (:export) lists before writing any implementation code"
  - "Test package naming: innate.tests.<subsystem> mirrors innate.<subsystem>"
  - "Test package imports: copy the full export list of the implementation package into the test package :import-from"

requirements-completed: [ERR-01, ERR-02, ERR-03, PAR-22]

# Metrics
duration: 2min
completed: 2026-03-28
---

# Phase 02 Plan 01: Package Export Contracts Summary

**Export contracts for 32 innate.types symbols and 7 innate.conditions symbols established; two test sub-packages added; ASDF test system updated with test-conditions and test-types components**

## Performance

- **Duration:** ~2 min
- **Started:** 2026-03-28T19:11:45Z
- **Completed:** 2026-03-28T19:12:49Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments

- innate.types export list filled: make-node, 4 accessors (node-kind, node-value, node-children, node-props), 20 +node-*+ constants, innate-result types (make-innate-result, innate-result-value, innate-result-context), and resistance types (make-resistance, resistance-p, resistance-message, resistance-source)
- innate.conditions export list filled: innate-condition, innate-parse-error, innate-resistance, parse-error-line, parse-error-col, resistance-condition-message, resistance-condition-source
- Test packages innate.tests.types and innate.tests.conditions defined in tests/packages.lisp with full :import-from lists mirroring the implementation exports
- innatescript/tests ASDF system updated to include test-conditions and test-types file components

## Task Commits

Each task was committed atomically:

1. **Task 1: Fill innate.types and innate.conditions export lists** - `fb716c0` (feat)
2. **Task 2: Add test sub-packages and register test files in ASDF** - `74e580d` (feat)

## Files Created/Modified

- `src/packages.lisp` - Filled (:export) forms for innate.types (32 symbols) and innate.conditions (7 symbols)
- `tests/packages.lisp` - Appended innate.tests.conditions and innate.tests.types package definitions
- `innatescript.asd` - Added test-conditions and test-types file components to innatescript/tests system

## Decisions Made

- innate.conditions `:import-from :innate.types` kept without specific symbol list — conditions.lisp will declare precise imports at implementation time (Wave 2); keeping it unspecified here avoids anticipating implementation details
- Test package imports are a complete mirror of implementation exports — this ensures test files have everything available without re-importing symbol by symbol in each test file

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Plan 02 (types.lisp implementation) can proceed: innate.types export contract is now complete and all +node-*+ constants, make-node, and result/resistance struct constructors are declared
- Plan 03 (conditions.lisp implementation) can proceed: innate.conditions export contract is complete with all 3 condition types and their slot accessors declared
- Test files test-types.lisp and test-conditions.lisp can be created in Wave 2 without any further ASDF or package changes

## Self-Check: PASSED

- FOUND: src/packages.lisp
- FOUND: tests/packages.lisp
- FOUND: innatescript.asd
- FOUND: 02-01-SUMMARY.md
- FOUND: commit fb716c0 (Task 1)
- FOUND: commit 74e580d (Task 2)

---
*Phase: 02-conditions-and-ast-nodes*
*Completed: 2026-03-28*
