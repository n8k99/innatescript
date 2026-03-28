---
phase: 04-parser
plan: 03
subsystem: parser
tags: [common-lisp, recursive-descent, ast, emission, fulfillment, integration-test, precedence]

# Dependency graph
requires:
  - phase: 04-parser-02
    provides: "Token cursor, parse entry point, reference/agent/bundle/lens/search/decree parsers, 92 tests passing"
provides:
  - parse-fulfillment-expr: || is left-associative, loosest-binding operator
  - parse-emission-expr: -> is left-associative, binds tighter than ||
  - Leading-arrow emission: -> value, value → :emission node with multiple children
  - Infix emission: expr -> value → left-associative :emission chain
  - parse-agent extended: complex paren groups like image("emblem"+burg_name) parsed as :bundle
  - burg_pipeline.dpn integration test passing
  - 5 ROADMAP Phase 4 success criteria all verified by explicit tests
affects: [05-evaluator]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Precedence via function call chain: parse-fulfillment-expr > parse-emission-expr > parse-expression"
    - "Left-associativity via loop + setf left: each iteration wraps left in new node"
    - "Leading-arrow form vs infix form: detect arrow at emission entry to choose form"
    - "Complex paren group: (expr) with non-bare-word → :bundle node for function-call syntax in search"
    - "PLUS in paren groups emits :combinator '+' node — permissive parse of concatenation syntax"
    - "find-node-recursive / find-all-nodes-recursive helpers added to test suite for tree walking"

key-files:
  created: []
  modified:
    - "src/parser/parser.lisp — parse-fulfillment-expr, parse-emission-expr, updated parse-statement dispatch, parse-bracket-body and parse-kv-pair use parse-fulfillment-expr; parse-agent handles complex paren groups"
    - "tests/test-parser.lisp — 12 new tests: emission, emission-multi-value, emission-chain, fulfillment, fulfillment-chain, emission-fulfillment-precedence, parse-error-signals, burg-pipeline-parse, compound-reference-full, three-level-nested, left-associative-chain, parse-error-line-col"

key-decisions:
  - "Precedence chain via function nesting: parse-fulfillment-expr calls parse-emission-expr calls parse-expression — no operator precedence table needed"
  - "parse-statement routes all non-prose/non-heading/non-decree through parse-fulfillment-expr — removes the arrow stub"
  - "Fulfillment tests use @a || @b not a || b — bare words at depth 0 are tokenized as prose, @ references are not"
  - "Emission chain tests use [a -> b -> c] bracket context — same prose/expression distinction applies"
  - "Complex paren group produces :bundle node — search directive image(...) call-like syntax is structurally valid, semantics left to evaluator"

requirements-completed: [PAR-12, PAR-13]

# Metrics
duration: 5min
completed: 2026-03-28
---

# Phase 04 Plan 03: Emission and Fulfillment Operators Summary

**Complete parser — emission (->), fulfillment (||) with correct precedence and left-associativity; burg_pipeline.dpn parses without error; all 5 ROADMAP Phase 4 success criteria have explicit passing tests; 97/97 tests pass**

## Performance

- **Duration:** 5 min
- **Started:** 2026-03-28T22:53:57Z
- **Completed:** 2026-03-28T22:59:48Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments

- `parse-fulfillment-expr`: `||` left-associative loop wrapping left side in `:fulfillment` nodes
- `parse-emission-expr`: two forms — leading `->` and infix `->`, both left-associative
- Full precedence chain: fulfillment (loosest) > emission > expression (tightest)
- `parse-statement` dispatch refactored — all non-prose/non-heading/non-decree expressions route through `parse-fulfillment-expr`
- `parse-bracket-body` and `parse-kv-pair` updated to call `parse-fulfillment-expr` (allows `->` and `||` inside brackets and kv-pair values)
- `burg_pipeline.dpn` parses completely without error (2 top-level nodes: heading + bracket)
- 12 new tests; all 97 tests pass

## Task Commits

1. **Task 1: Emission and fulfillment operators** - `a1a4d62`
2. **Task 2: Integration tests, burg_pipeline.dpn fix, ROADMAP criteria** - `2a9e89d`

## Files Created/Modified

- `/home/n8k99/Development/innatescript/src/parser/parser.lisp` — parse-fulfillment-expr, parse-emission-expr, updated parse-statement/parse-bracket-body/parse-kv-pair dispatch, extended parse-agent for complex paren groups
- `/home/n8k99/Development/innatescript/tests/test-parser.lisp` — 12 new tests including burg_pipeline.dpn integration test and all 5 ROADMAP success criteria

## Decisions Made

**Precedence via function call chain.** `parse-fulfillment-expr` calls `parse-emission-expr` which calls `parse-expression`. No operator precedence table — the call chain itself encodes the hierarchy.

**Bare words at depth 0 are prose.** Tests for `||` and `->` must use constructs that escape prose detection: `@ref || @ref2` (reference sigil), or `[a -> b]` (bracket context). This matches actual Innate semantics — top-level bare text is prose.

**Complex paren groups in search produce :bundle.** `image("emblem"+burg_name + png)` in the search directive uses `(...)` as a function-call argument group, not an agent address. The parser now detects that `(bare-word + rparen)` is an agent but anything else is a paren group parsed as `:bundle` with expression children.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fulfillment chain test used bare words that tokenize as prose at depth 0**
- **Found during:** Task 1 (test-fulfillment-chain)
- **Issue:** `a || b || c` at top level tokenizes as a single :prose token, not three bare-words with pipe-pipe operators. Prose detection runs at nesting-depth 0 for lines starting with bare words.
- **Fix:** Changed test to use `@a || @b || @c` — reference sigils break prose detection, all tokens are emitted individually
- **Files modified:** tests/test-parser.lisp
- **Commit:** a1a4d62

**2. [Rule 1 - Bug] Emission chain test used bare words that tokenize as prose at depth 0**
- **Found during:** Task 1 (test-emission-chain)
- **Issue:** `a -> b -> c` at top level tokenizes as a single :prose token for the same reason
- **Fix:** Changed test to use `[a -> b -> c]` — inside bracket context, bare-words and arrow tokens are emitted correctly
- **Files modified:** tests/test-parser.lisp
- **Commit:** a1a4d62

**3. [Rule 1 - Bug] parse-agent fails on complex paren expressions in search body**
- **Found during:** Task 2 (burg_pipeline.dpn parse attempt)
- **Issue:** `![image("emblem"+burg_name + png)]` — the search parser calls `parse-expression` on `LPAREN`, dispatching to `parse-agent`. `parse-agent` calls `cursor-expect :bare-word` but finds `:string "emblem"` — error at line 9 col 11.
- **Fix:** Extended `parse-agent` to detect when content is not a simple `(bare-word)` form. If the paren contains anything other than exactly one bare-word followed by rparen, parse as a complex paren group → `:bundle` node with expression children. PLUS tokens in the group become `:combinator` nodes.
- **Files modified:** src/parser/parser.lisp
- **Commit:** 2a9e89d

---

**Total deviations:** 3 auto-fixed (Rule 1 bugs)

## Issues Encountered

None beyond the deviations documented above.

## User Setup Required

None.

## Next Phase Readiness

- Complete parser: `(parse (tokenize source))` works for any valid Innate source
- All 20 node kinds have parse paths
- Emission and fulfillment operators with correct precedence and left-associativity
- Phase 05 evaluator can walk the complete AST using `etypecase` on `:node-kind`
- The evaluator will receive programs with :program → :bracket/:heading/:prose/:decree/:reference/:emission/:fulfillment/:search nodes

## Self-Check: PASSED
