---
gsd_state_version: 1.0
milestone: v1.0
milestone_name: milestone
status: unknown
stopped_at: Completed 09-repl-and-integration/09-02-PLAN.md
last_updated: "2026-03-29T05:07:25.499Z"
progress:
  total_phases: 9
  completed_phases: 9
  total_plans: 19
  completed_plans: 19
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-03-27)

**Core value:** A human unfamiliar with any programming language should be able to make a reasonable guess at what an Innate program does — and that same program should execute.
**Current focus:** Phase 09 — repl-and-integration

## Current Position

Phase: 09 (repl-and-integration) — EXECUTING
Plan: 2 of 2

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
| Phase 04-parser P01 | 6min | 2 tasks | 5 files |
| Phase 04-parser P02 | 4min | 2 tasks | 3 files |
| Phase 04 P03 | 5min | 2 tasks | 2 files |
| Phase 05 P01 | 2min | 2 tasks | 5 files |
| Phase 06-stub-resolver P01 | 3min | 1 tasks | 5 files |
| Phase 07-evaluator-core P01 | 185s | 2 tasks | 5 files |
| Phase 07-evaluator-core P02 | 216 | 2 tasks | 2 files |
| Phase 08-commission-and-fulfillment-evaluation P01 | 105s | 2 tasks | 3 files |
| Phase 09 P01 | 2min | 2 tasks | 5 files |
| Phase 09 P02 | 2min | 2 tasks | 2 files |

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
- [Phase 04-parser]: Brackets are always anonymous (nil value) — bare-words never consumed as bracket names; all tokens become children. Behavior tests (PAR-01, PAR-21) are canonical.
- [Phase 04-parser]: cursor-peek-next used for kv-pair disambiguation: bare-word followed by :colon in bracket body triggers parse-kv-pair, not atom parsing
- [Phase 04-parser]: Qualifiers stored in both children (string-lit node) and props (:qualifiers list) — evaluator has both tree-walk and fast-access paths
- [Phase 04-parser]: = added to tokenizer bare-word char set for lens comparison operators (==, >=, <=) — CONTEXT.md specifies no hardcoded operator set
- [Phase 04-parser]: Precedence via function call chain: parse-fulfillment-expr calls parse-emission-expr calls parse-expression — no operator precedence table needed
- [Phase 04-parser]: Complex paren groups in search produce :bundle node — image(...) call-like syntax parsed structurally, semantics deferred to evaluator
- [Phase 05]: resolver is empty CLOS class — no slots, exists only as dispatch target; concrete resolvers add their own state
- [Phase 05]: deliver-commission default returns innate-result (never resistance) — commissions are fire-and-forget at the protocol level
- [Phase 05]: load-bundle default returns nil (not resistance) — bundle-not-found is a soft miss, not an error; evaluator proceeds without bundle
- [Phase 05]: eval-env decrees and bindings default to fresh hash-tables — prevents null-pointer in evaluator decree collection pass
- [Phase 06-stub-resolver]: stub-commissions as CLOS slot accessor serves as getter/setter — consistent with other slot accessors in stub-resolver class
- [Phase 06-stub-resolver]: deliver-commission returns innate-result :value t — signals successful delivery, distinguishes from no-op nil
- [Phase 06-stub-resolver]: Qualifier lookup uses (intern (string-upcase qual) :keyword) for case-insensitive plist access — normalizes parser strings to keywords
- [Phase 07-evaluator-core]: evaluate entry point takes :program node + eval-env, returns flat list of results in source order; decree nodes collected in pass 1, filtered in pass 2
- [Phase 07-evaluator-core]: :reference and :bracket stub with (signal 'innate-resistance ...) in Plan 01 — Plan 02 replaces these with full resolution logic
- [Phase 07-evaluator-core]: :program reaching eval-node signals error (not resistance) — this is a BUG indicator, not a recoverable condition
- [Phase 07-evaluator-core]: Decree body evaluation evaluates first child of decree node — simple and sufficient for Phase 7; complex decree bodies deferred
- [Phase 07-evaluator-core]: Bracket context/verb extraction: first bare-word = context, inner bracket's first bare-word = verb — consistent with spec's [ctx[verb]] notation
- [Phase 07-evaluator-core]: resistance-p guard on both reference and bracket paths — evaluator never swallows resistance silently
- [Phase 08-commission-and-fulfillment-evaluation]: Emission: single child returns value directly, multiple children returns list — matches spec
- [Phase 08-commission-and-fulfillment-evaluation]: Bundle progn semantics: evaluate all returned nodes, return last result — consistent with sub-program model
- [Phase 08-commission-and-fulfillment-evaluation]: Bundle nil-as-not-found: load-bundle returns nil (not resistance), evaluator signals innate-resistance on nil
- [Phase 09-repl-and-integration]: unless used instead of next-iteration for empty-line skip — CL's loop does not have next-iteration (that is ITERATE); unless guards the eval block
- [Phase 09-repl-and-integration]: run-file uses file-length + make-string + read-sequence for full-file slurp — avoids line-by-line iteration and preserves newline semantics the tokenizer depends on
- [Phase 09-repl-and-integration]: Interactive mode uses sbcl without --non-interactive — that flag disables stdin read-line; file mode uses --non-interactive to force exit after eval
- [Phase 09-repl-and-integration]: print-result exported from innate.repl — shell scripts call it externally via package-qualified symbol; must be in :export list

### Pending Todos

None yet.

### Blockers/Concerns

- Phase 4 (multi-context evaluation): Innate's context-as-argument evaluation model has no prior art. A design spike is needed during Phase 7/8 planning to validate how context threading interacts with decree bodies and nested bracket evaluation.
- Phase 8 (|| chaining semantics): Spec does not yet clarify whether `![...] || (a){...} || (b){escalate}` chains are v1. Needs spec decision before Phase 8 planning begins.
- Phase 8 (template free variable binding): How `@burg_name` receives its value in a living template is unresolved. Flag for spec decision during Phase 7 planning.

## Session Continuity

Last session: 2026-03-29T05:07:25.495Z
Stopped at: Completed 09-repl-and-integration/09-02-PLAN.md
Resume file: None
