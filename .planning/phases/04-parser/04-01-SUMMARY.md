---
phase: 04-parser
plan: 01
subsystem: parser
tags: [common-lisp, recursive-descent, ast, token-cursor, bracket-parsing, kv-pair]

# Dependency graph
requires:
  - phase: 03-tokenizer
    provides: "tokenize function, 23 token types, token defstruct with type/value/line/col"
  - phase: 02-conditions-and-ast-nodes
    provides: "innate-parse-error condition, node defstruct, +node-*+ constants"
provides:
  - Token cursor struct (parse-cursor) with peek, consume, expect, peek-next operations
  - parse entry point returning :program node from token list
  - parse-statement-list: top-level statement collection skipping :newline separators
  - parse-statement: dispatch to bracket/prose/heading/expression stubs
  - parse-expression: dispatch to atom/bracket/heading/stubs for Plans 02-03
  - parse-atom: bare-word, string-lit, number-lit, wikilink, emoji-slot
  - parse-bracket: anonymous bracket bodies with heterogeneous children in source order
  - parse-bracket-body: inner dispatch loop (kv-pairs, nested brackets, prose, atoms)
  - parse-kv-pair: bare-word COLON expression patterns
  - parse-heading: HASH followed by bare-word accumulation
  - innate.tests.parser test package with 17 parser tests
affects: [04-parser-02, 04-parser-03, 05-evaluator]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Token cursor struct (parse-cursor) over flat token list — positional scan without mutation"
    - "cursor-peek-next used for kv-pair disambiguation (bare-word followed by :colon)"
    - "Bracket bodies are always anonymous (nil value) — all tokens become children"
    - "Stub functions signal innate-parse-error with 'Not yet implemented: TYPE' for Plans 02-03"
    - "TDD: failing tests committed, then implementation to pass, all in one atomic commit"

key-files:
  created:
    - "tests/test-parser.lisp — 17 parser tests covering cursor, bracket parsing, kv-pairs, prose, statements"
  modified:
    - "src/parser/parser.lisp — full recursive descent parser with cursor struct and all bracket parsing"
    - "src/packages.lisp — innate.parser package updated with imports from tokenizer/types/conditions and exports parse"
    - "tests/packages.lisp — innate.tests.parser package added with complete import mirror"
    - "innatescript.asd — test-parser component added to innatescript/tests system"

key-decisions:
  - "Brackets are always anonymous (nil value) — bare-words are never consumed as bracket names, always become children (contradicts plan action text, but matches PAR-01, PAR-21 behavior tests)"
  - "cursor-peek-next used for single-token lookahead in kv-pair detection — bare-word followed by :colon triggers parse-kv-pair"
  - "parse-bracket and cursor helpers are not exported — only parse is the public API"
  - "Stub functions in parse-expression signal innate-parse-error — Plans 02 and 03 replace them"

patterns-established:
  - "Token cursor pattern: defstruct with tokens list and pos fixnum — all traversal via cursor-peek/consume/expect"
  - "Bracket body dispatch: loop until :rbracket or nil, cond on token-type with kv-pair lookahead special case"
  - "Test: use (parse (tokenize \"source\")) as the test entry point — parser receives real token streams"
  - "Named test functions match PAR-XX requirement IDs for traceability"

requirements-completed: [PAR-01, PAR-02, PAR-03, PAR-15, PAR-20, PAR-21, PAR-22]

# Metrics
duration: 6min
completed: 2026-03-28
---

# Phase 04 Plan 01: Parser Infrastructure and Bracket Core Summary

**Recursive descent parser with token cursor struct, anonymous bracket bodies, kv-pair detection via lookahead, prose nodes, and multi-statement programs — 71/71 tests pass**

## Performance

- **Duration:** 6 min
- **Started:** 2026-03-28T22:39:35Z
- **Completed:** 2026-03-28T22:45:35Z
- **Tasks:** 2 (combined into 1 atomic commit)
- **Files modified:** 5

## Accomplishments

- Token cursor struct with peek, consume, expect (with error signaling), and peek-next lookahead
- Full bracket parsing: anonymous bodies, nested brackets to arbitrary depth, bracket body dispatch loop
- KV-pair detection via single-token lookahead: bare-word immediately followed by colon triggers kv-pair, not atom
- Atom parsing: bare-word, string-lit, number-lit, wikilink, emoji-slot — all 5 types handled
- Prose tokens at top level and inside brackets become :prose AST nodes
- Multi-statement programs: newlines consumed as separators, all statements appear as :program children
- 17 new parser tests covering PAR-01, PAR-02, PAR-03, PAR-15, PAR-20, PAR-21, PAR-22

## Task Commits

Tasks 1 and 2 were executed together (TDD tests plus implementation):

1. **Task 1 + Task 2: Token cursor, package wiring, bracket/statement core** - `efd1f1a` (feat)

**Plan metadata:** (to be committed with this SUMMARY)

_Note: TDD tasks — tests written and implementation made GREEN in single atomic commit_

## Files Created/Modified

- `/home/n8k99/Development/innatescript/src/parser/parser.lisp` — Full parser: cursor struct, parse entry point, statement list, expression dispatch, atom dispatch, bracket/kv-pair/heading parsers
- `/home/n8k99/Development/innatescript/tests/test-parser.lisp` — 17 parser tests (TDD)
- `/home/n8k99/Development/innatescript/src/packages.lisp` — innate.parser package updated with imports from tokenizer, types, conditions; exports parse
- `/home/n8k99/Development/innatescript/tests/packages.lisp` — innate.tests.parser package added
- `/home/n8k99/Development/innatescript/innatescript.asd` — test-parser component added

## Decisions Made

**Brackets are always anonymous — no bare-word name consumption.** The plan's action section described consuming a leading bare-word as the bracket name when not followed by colon. But the plan's behavior tests (PAR-01: `[a[b[c]]]` has "a" as a child, PAR-21: `[a b c]` has 3 children) contradict this. Behavior tests are canonical in TDD — anonymous brackets with all tokens as children is the correct behavior. Named brackets are a concern for the evaluator, not the parser.

**Single-token lookahead for kv-pair.** Inside bracket bodies, bare-word followed by colon is a kv-pair key. This is detected with cursor-peek-next (not separate state) — minimal lookahead, no backtracking.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Anonymous brackets: removed named bracket consumption**
- **Found during:** Task 2 (test-bracket-body-sequence, test-nested-brackets)
- **Issue:** Plan action described consuming a leading bare-word as bracket name. But PAR-01 (`[a[b[c]]]` innermost has "c" as a child, not name) and PAR-21 (`[a b c]` has 3 children) both require bare-words to stay in the bracket body. Named bracket logic would consume "a", "b", "c" as names instead.
- **Fix:** Removed name-consumption code from parse-bracket. All tokens inside brackets are children. Bracket value is always nil at parse time.
- **Files modified:** src/parser/parser.lisp
- **Verification:** test-nested-brackets, test-anonymous-bracket-depth, test-bracket-body-sequence all pass
- **Committed in:** efd1f1a

**2. [Rule 1 - Bug] Fixed test to use double-quoted strings (tokenizer rejects single quotes)**
- **Found during:** Task 2 (test-anonymous-bracket-depth)
- **Issue:** Test used `'Hello'` (single quotes) but tokenizer only handles double-quoted strings
- **Fix:** Changed to `"Hello"` in test source string
- **Files modified:** tests/test-parser.lisp
- **Committed in:** efd1f1a

**3. [Rule 1 - Bug] Fixed wikilink test to use correct tokenizer context**
- **Found during:** Task 2 (test-wikilink-atom)
- **Issue:** `[[[MyPage]]]` tokenizes as three separate brackets, not a wikilink inside a bracket. Wikilink syntax `[[name]]` only tokenizes as :wikilink when appearing inside a bracket context (nesting-depth > 0) as `[[name]]`, not as `[[[name]]]`.
- **Fix:** Changed test to use `[x [[MyPage]] y]` — `[[MyPage]]` appears inside a bracket body where nesting-depth > 0, so it tokenizes as :wikilink correctly.
- **Files modified:** tests/test-parser.lisp
- **Committed in:** efd1f1a

---

**Total deviations:** 3 auto-fixed (3 Rule 1 bugs)
**Impact on plan:** All fixes resolve contradictions between plan action text and behavior tests. The behavior tests are canonical. No scope creep.

## Issues Encountered

None beyond the deviations documented above.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Token cursor and bracket core are ready for Phase 04 Plans 02 and 03
- Stubs in parse-expression signal innate-parse-error with "Not yet implemented: TYPE" — Plans 02 and 03 replace these stubs
- Plans 02: reference (@), agent ()), bundle/lens ({}), search (![])), decree
- Plan 03: emission (->), fulfillment (||), reference postfix chains (:qualifier, +combinator, {lens})
- Downstream (Phase 05): `(parse (tokenize source))` produces :program node ready for evaluator

## Self-Check: PASSED

---
*Phase: 04-parser*
*Completed: 2026-03-28*
