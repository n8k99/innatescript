---
phase: 07-evaluator-core
plan: 01
subsystem: eval
tags: [evaluator, two-pass, etypecase, decree-hoisting, tdd]
dependency_graph:
  requires:
    - src/eval/resolver.lisp (eval-env struct, resolver protocol)
    - src/types.lisp (node struct, all 20 node kind constants)
    - src/conditions.lisp (innate-resistance condition)
  provides:
    - src/eval/evaluator.lisp (evaluate, collect-decrees, eval-node)
    - tests/test-evaluator.lisp (13 passing evaluator tests)
  affects:
    - src/packages.lisp (innate.eval package now exports #:evaluate)
    - tests/packages.lisp (innate.tests.evaluator package added)
    - innatescript.asd (test-evaluator registered in test system)
tech_stack:
  added: []
  patterns:
    - Two-pass evaluation (collect-decrees pass 1, eval-node pass 2)
    - etypecase dispatch on node-kind keyword
    - innate-resistance signal for unimplemented node types
key_files:
  created:
    - tests/test-evaluator.lisp
  modified:
    - src/eval/evaluator.lisp
    - src/packages.lisp
    - tests/packages.lisp
    - innatescript.asd
decisions:
  - "evaluate entry point takes :program node and eval-env, returns flat list of results in source order"
  - "collect-decrees is a separate named function (not inline) for testability"
  - "decree nodes produce nil in eval-node but are also filtered by unless in evaluate — double-safety"
  - ":reference and :bracket stub with (signal 'innate-resistance ...) — Plan 02 replaces these"
  - "Phase 8 node kinds signal innate-resistance with descriptive messages rather than error"
  - ":program reaching eval-node is a BUG — signals error (not resistance) to make it loud"
metrics:
  duration: "185s (~3 min)"
  completed_date: "2026-03-29"
  tasks_completed: 2
  files_modified: 5
---

# Phase 7 Plan 01: Two-Pass Evaluator Skeleton Summary

Two-pass evaluator with `etypecase` dispatch implementing decree hoisting, passthrough node evaluation, and integer literal conversion from string.

## What Was Built

The core evaluator architecture for the Innate interpreter:

- **`collect-decrees`** — Pass 1 function that walks top-level children and stores `:decree` nodes in `eval-env-decrees` hash-table, keyed by decree name string.
- **`eval-node`** — Pass 2 dispatch function using `etypecase` on `(node-kind node)`. Handles all 20 node kinds: passthrough types return their value, `:number-lit` parses string to integer, `:decree` returns nil (filtered in `evaluate`), and unimplemented/Phase 8 types signal `innate-resistance`.
- **`evaluate`** — Two-pass entry point. Takes a `:program` node and `eval-env`, runs collect-decrees then eval-node on each non-decree child. Returns flat list of results in source order.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Package wiring, ASDF registration, test scaffold (RED) | dbf7af9 | src/packages.lisp, tests/packages.lisp, innatescript.asd, tests/test-evaluator.lisp |
| 2 | Implement evaluate with two-pass architecture (GREEN) | 36aedeb | src/eval/evaluator.lisp |

## Deviations from Plan

None - plan executed exactly as written.

## Test Coverage

13 tests added in `tests/test-evaluator.lisp`:

- `test-decree-collected-in-pass-1` — decree stored in env hash-table
- `test-decree-not-in-results` — decree produces no result
- `test-decree-stores-full-node` — stored value is the full decree node
- `test-prose-passthrough` — prose value in results
- `test-heading-passthrough` — heading value in results
- `test-string-lit-returns-value` — string literal returns value
- `test-number-lit-returns-integer` — string "42" becomes integer 42
- `test-bare-word-returns-string` — bare-word returns string value
- `test-emoji-slot-returns-string` — emoji-slot returns string value
- `test-multiple-top-level-results` — results list preserves source order
- `test-mixed-decree-and-prose` — mixed decree+prose produces only prose results
- `test-combinator-returns-value` — combinator returns value string
- `test-modifier-returns-value` — modifier returns value string

**Full suite: 142/142 tests pass**

## Self-Check: PASSED
