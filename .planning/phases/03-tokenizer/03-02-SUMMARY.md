---
phase: 03-tokenizer
plan: 02
subsystem: parser
tags: [common-lisp, tokenizer, lexer, hand-rolled, sbcl]

# Dependency graph
requires:
  - phase: 03-tokenizer/03-01
    provides: token defstruct, innate.parser.tokenizer package with 6 exports, test-tokenizer ASDF wiring
  - phase: 02-conditions-and-ast-nodes
    provides: innate-parse-error condition used for error signaling
provides:
  - tokenize defun — full character loop dispatching all 11 single-char and 3 two-char operator tokens
  - %read-string helper with \" and \\ escape support, signals on unterminated string
  - %read-number helper accumulating digit sequences as :number tokens
  - %read-bare-word helper with "decree" keyword detection
  - %try-emoji-slot helper matching literal <emoji> 7-char sequence
  - position tracking (line/col) correct on all emitted tokens via start-line/start-col capture before advance
  - 17 new passing tests covering TOK-01 through TOK-15
affects:
  - 03-tokenizer/03-03 (wikilink/prose/newline logic builds on this tokenize loop)
  - phase 04 (parser consumes the token list produced here)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - position-integer cursor (pos over source string) with labels helpers (current/advance/peek-next)
    - start-line/start-col capture before first advance — emit uses pre-advance position, not post-advance
    - cond dispatch on current character in main loop (not case — cond handles digit-char-p and alpha-char-p predicates cleanly)
    - labels-local helper functions (%read-string, %read-number, %read-bare-word, %try-emoji-slot) inside tokenize
    - nreverse on token accumulator list — push tokens, reverse at return

key-files:
  created: []
  modified:
    - src/parser/tokenizer.lisp
    - tests/test-tokenizer.lisp

key-decisions:
  - "cond used instead of case for main dispatch — case on character values works in CL, but cond is required to mix char= tests with predicate calls like digit-char-p and alpha-char-p; one dispatch form handles all branches cleanly"
  - "labels used for helper functions inside tokenize — keeps all char-level helpers in lexical scope of the loop's mutable pos/line/col/tokens variables; avoids threading 5+ parameters through each helper"
  - "newline emits nothing for now (Plan 03 stub) — plan spec explicitly calls for newline to be consumed silently in this wave, with :newline emission and collapse logic deferred to Plan 03"
  - "[ emits :lbracket directly for now (Plan 03 stub) — wikilink disambiguation via [[ lookahead deferred to Plan 03 per plan spec"

patterns-established:
  - "labels-local helpers pattern: %read-X naming convention for character accumulation helpers inside tokenize"
  - "position-before-value pattern: let ((sl line) (sc col)) before any advance; emit uses sl/sc not current line/col"
  - "emoji slot: (string= \"<emoji>\" source :start2 pos :end2 (+ pos 7)) inline match, no regex"

requirements-completed: [TOK-01, TOK-02, TOK-03, TOK-04, TOK-05, TOK-06, TOK-07, TOK-08, TOK-09, TOK-10, TOK-11, TOK-12, TOK-13, TOK-14, TOK-15]

# Metrics
duration: 3min
completed: 2026-03-28
---

# Phase 03 Plan 02: Tokenizer Core Loop Summary

**Complete tokenizer loop with cond-based character dispatch, two-char operator lookahead, and four literal readers (string/number/bare-word/emoji-slot) covering TOK-01 through TOK-15**

## Performance

- **Duration:** 3 min
- **Started:** 2026-03-28T21:15:17Z
- **Completed:** 2026-03-28T21:18:30Z
- **Tasks:** 2 (implemented together in one GREEN pass)
- **Files modified:** 2

## Accomplishments

- `tokenize` main loop dispatches correctly on all 11 single-char tokens and 3 two-char operators with correct line/col tracking
- String literal reader handles `\"` and `\\` escape sequences; signals `innate-parse-error` on unterminated strings
- Bare-word reader detects `"decree"` keyword: `(tokenize "decree")` → `:decree`; `(tokenize "decrement")` → `:bare-word`
- Emoji slot matched with inline `string=` against exact 7-char `"<emoji>"` sequence
- 17 new tests added; full suite 40/40 at exit code 0

## Task Commits

Both tasks implemented and committed together (one GREEN pass):

1. **Task 1: Main loop + Task 2: Literals** - `a4a45eb` (feat)

**Note:** Tasks 1 and 2 were written to tests-RED, then both implemented in a single GREEN pass because the helpers (%read-string etc.) are called from the main loop dispatch — they cannot be green independently without the other.

## Files Created/Modified

- `src/parser/tokenizer.lisp` — tokenize stub replaced with 200-line implementation: main loop with cond dispatch, 4 labels-local helper functions
- `tests/test-tokenizer.lisp` — 17 new deftest forms added covering TOK-01 through TOK-15 + position tracking

## Decisions Made

- `cond` used instead of `case` for main character dispatch — `case` works for literal character values but `cond` is necessary to cleanly mix `char=` tests with predicate calls (`digit-char-p`, `alpha-char-p`). Single dispatch form handles all 20+ branches.
- `labels` used for helpers — all helpers are lexically inside `tokenize`, sharing access to `pos`/`line`/`col`/`tokens`/`source`/`len` without threading them as parameters.
- Newline consumed silently (stub for Plan 03) — per plan spec, `:newline` emission with collapse logic is deferred.
- `[` emits `:lbracket` directly (stub for Plan 03) — wikilink `[[` disambiguation deferred.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed parenthesis count in tokenizer main loop**
- **Found during:** Task 1 implementation (first compile attempt)
- **Issue:** Extra `)` after the unexpected-character error clause made the file fail to compile with "unmatched close parenthesis at line 262"
- **Fix:** Removed one `)` from the error clause close — `c))))))) ` corrected to `c))))))` (6 close parens: format, error, t-clause, cond, let, loop)
- **Files modified:** `src/parser/tokenizer.lisp`
- **Verification:** File compiled successfully; all 40 tests passed
- **Committed in:** `a4a45eb` (same task commit)

---

**Total deviations:** 1 auto-fixed (Rule 1 - paren count bug introduced during authoring)
**Impact on plan:** Fix required for compilation. No behavior change.

## Issues Encountered

Syntax error (unmatched close parenthesis) on first compile — an authoring error with 7 close parens where 6 were needed after the unexpected-character error clause. Fixed immediately via Rule 1. Tests proceeded to 40/40 on the corrected file.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- `tokenize` handles TOK-01 through TOK-15; Plan 03 can add wikilink disambiguation, prose detection, and newline collapse directly to the same loop
- The two stub branches (`[` → `:lbracket` and newline → advance) are clearly marked with `; Plan 03` comments
- 40/40 tests green; all Phase 2 and prior tests still pass

## Self-Check: PASSED

- src/parser/tokenizer.lisp: FOUND
- tests/test-tokenizer.lisp: FOUND
- 03-02-SUMMARY.md: FOUND
- Commit a4a45eb: FOUND

---
*Phase: 03-tokenizer*
*Completed: 2026-03-28*
