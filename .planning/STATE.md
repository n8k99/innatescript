---
gsd_state_version: 1.0
milestone: v1.0
milestone_name: milestone
status: unknown
stopped_at: Completed 03-tokenizer/03-03-PLAN.md
last_updated: "2026-03-28T21:34:31.836Z"
progress:
  total_phases: 9
  completed_phases: 3
  total_plans: 8
  completed_plans: 8
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-03-27)

**Core value:** A human unfamiliar with any programming language should be able to make a reasonable guess at what an Innate program does — and that same program should execute.
**Current focus:** Phase 03 — tokenizer

## Current Position

Phase: 4
Plan: Not started

## Performance Metrics

**Velocity:**

- Total plans completed: 0
- Average duration: -
- Total execution time: -

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| - | - | - | - |

**Recent Trend:**

- Last 5 plans: none yet
- Trend: -

*Updated after each plan completion*
| Phase 01-project-scaffolding P01 | 2 | 3 tasks | 11 files |
| Phase 01-project-scaffolding P02 | 2 | 2 tasks | 5 files |
| Phase 02-conditions-and-ast-nodes P01 | 2 | 2 tasks | 3 files |
| Phase 02-conditions-and-ast-nodes P02 | 2 | 2 tasks | 2 files |
| Phase 02-conditions-and-ast-nodes P03 | 2 | 2 tasks | 2 files |
| Phase 03-tokenizer P01 | 2 | 2 tasks | 5 files |
| Phase 03-tokenizer P02 | 3 | 2 tasks | 2 files |
| Phase 03-tokenizer P03 | 9min | 2 tasks | 2 files |

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Recent decisions affecting current work:

- Foundation: Use `etypecase` for internal AST dispatch, CLOS only at resolver boundary — baked into Phase 5 and 7 success criteria
- Foundation: Two-pass evaluation with hoisting (decree collection pass 1, evaluation pass 2) — baked into Phase 7
- Foundation: `defstruct` vs `defclass` for AST nodes is an open architecture decision — must be committed to and logged in PROJECT.md during Phase 2
- [Phase 01-project-scaffolding]: ASDF system uses explicit :depends-on per component, not :serial t — dependency graph is explicit and visible
- [Phase 01-project-scaffolding]: All nine package namespaces defined in single packages.lisp loaded first by ASDF — load-order spine established
- [Phase 01-project-scaffolding]: Zero external system-level :depends-on in innatescript.asd — AF64 zero-deps convention upheld
- [Phase 01-project-scaffolding]: Cross-package references use :import-from exclusively — prevents CL builtin symbol conflicts
- [Phase 01-project-scaffolding]: deftest uses *test-failures* dynamic var scoped per test body — isolates assertion failure counts without global accumulator
- [Phase 01-project-scaffolding]: run-tests returns boolean T/NIL mapped to sb-ext:exit code 0/1 in run-tests.sh — keeps Lisp function testable without shell context
- [Phase 01-project-scaffolding]: innatescript/tests secondary ASDF system uses explicit :depends-on per component, consistent with primary system convention
- [Phase 02-conditions-and-ast-nodes]: innate.conditions :import-from :innate.types left without explicit symbol list — conditions.lisp declares precise imports at implementation time
- [Phase 02-conditions-and-ast-nodes]: Test packages are complete import mirrors of their implementation packages — innate.tests.types imports all 32 innate.types symbols
- [Phase 02-conditions-and-ast-nodes]: innate-resistance inherits from (innate-condition condition) NOT error — signal not error enables handler-case fulfillment without debugger
- [Phase 02-conditions-and-ast-nodes]: resistance-condition- slot reader prefix avoids collision with defstruct resistance accessors in types.lisp
- [Phase 02-conditions-and-ast-nodes]: Universal node defstruct (not defclass hierarchy) — etypecase dispatch on node-kind keyword keeps AST extensible without class redefinition overhead
- [Phase 02-conditions-and-ast-nodes]: defconstant for node kind constants is safe with keyword values — keywords are self-evaluating in SBCL, no redefinition error on image reload
- [Phase 02-conditions-and-ast-nodes]: resistance struct is a data return value; innate-resistance is a signalable condition — naming difference prevents accessor collision between resistance-message and resistance-condition-message
- [Phase 03-tokenizer]: token is a defstruct (not defclass) — flat positional data distinct from AST nodes, no CLOS dispatch needed on tokens
- [Phase 03-tokenizer]: tokenize stub uses (declare (ignore source)) — avoids SBCL unused-variable NOTE on compilation
- [Phase 03-tokenizer]: cond used instead of case for main dispatch — mixes char= tests with digit-char-p/alpha-char-p predicates in one form
- [Phase 03-tokenizer]: labels-local helpers inside tokenize (%read-X pattern) share pos/line/col/tokens lexically, no parameter threading
- [Phase 03-tokenizer]: newline and [[ handling stubbed in Plan 02 — consumed silently, :newline emission and wikilink disambiguation deferred to Plan 03
- [Phase 03-tokenizer]: nesting-depth tracker gates prose detection inside brackets — prevents multi-line bracket expressions from being misclassified as prose
- [Phase 03-tokenizer]: dash '-' without '>' emits :prose in both line-start and normal dispatch — burg_pipeline.dpn list-item syntax compatibility (spec gap)
- [Phase 03-tokenizer]: dot '.' added to bare-word chars — filename tokens like burg_pipeline.dpn parse correctly (spec gap, not in grammar)

### Pending Todos

None yet.

### Blockers/Concerns

- Phase 4 (multi-context evaluation): Innate's context-as-argument evaluation model has no prior art. A design spike is needed during Phase 7/8 planning to validate how context threading interacts with decree bodies and nested bracket evaluation.
- Phase 8 (|| chaining semantics): Spec does not yet clarify whether `![...] || (a){...} || (b){escalate}` chains are v1. Needs spec decision before Phase 8 planning begins.
- Phase 8 (template free variable binding): How `@burg_name` receives its value in a living template is unresolved. Flag for spec decision during Phase 7 planning.

## Session Continuity

Last session: 2026-03-28T21:31:19.221Z
Stopped at: Completed 03-tokenizer/03-03-PLAN.md
Resume file: None
