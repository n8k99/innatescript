---
phase: 03-tokenizer
plan: 03
subsystem: parser
tags: [common-lisp, tokenizer, wikilink, prose-detection, newline, integration-test, sbcl]

# Dependency graph
requires:
  - phase: 03-tokenizer/03-02
    provides: tokenize loop with all 11 single-char and 3 two-char operators, %read-string, %read-number, %read-bare-word, %try-emoji-slot
  - phase: 02-conditions-and-ast-nodes
    provides: innate-parse-error condition for error signaling
provides:
  - wikilink disambiguation: [[Burg]] -> :wikilink; [[x[y]]] -> nested :lbracket pair
  - prose detection: alpha lines at top-level line-start (not "decree") -> :prose tokens
  - newline emission with consecutive collapse: :newline tokens, last-was-newline flag
  - nesting depth tracking: prose detection bypassed inside brackets/parens/braces
  - burg_pipeline.dpn integration test (smoke test for real-world .dpn file)
  - 4 new integration/position tests covering TOK-16/17/18 comprehensively
  - Complete tokenizer: all 23 token types covered, 54 tests passing
affects:
  - phase 04 (parser consumes token list including :wikilink/:prose/:newline tokens)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - line-start-p boolean reset after each newline and T at start — prose detection gating
    - last-was-newline boolean — consecutive :newline token collapse
    - nesting-depth integer — prose detection skips inside bracket/paren/brace expressions
    - pure lookahead %scan-double-bracket — no pos mutation; caller advances after decision
    - loop-with-incf pos for wikilink inner text skip — avoids col tracking mismatch
    - dot-in-bare-word — %read-bare-word accepts '.' for filename tokens (spec gap, burg_pipeline compat)
    - dash-as-prose in normal dispatch — '-' without '>' emits :prose (spec gap, burg_pipeline compat)

key-files:
  created: []
  modified:
    - src/parser/tokenizer.lisp
    - tests/test-tokenizer.lisp

key-decisions:
  - "nesting-depth tracker added: prose detection only applies at top-level (nesting-depth = 0); inside brackets/parens/braces all chars tokenize normally — required for multi-line bracket expressions like burg_pipeline.dpn"
  - "prose detection falls through for all punctuation tokens: ], ), }, :, ,, |, +, \", <, #, /, @ — prevents line-start from incorrectly treating standalone punctuation tokens as prose in unit tests"
  - "dot '.' added to bare-word chars: filenames like burg_pipeline.dpn tokenize as single :bare-word (spec gap — dpn-lang-spec does not mention dots in identifiers)"
  - "dash '-' without '>' emits :prose in both line-start AND normal dispatch: burg_pipeline.dpn uses '- text' list items inside brackets; spec does not define :dash token"
  - "test-bare-word and test-decree-keyword updated: bare alpha words at line start now correctly emit :prose per TOK-17; tests updated to verify both prose behavior (standalone) and :bare-word behavior (inside brackets)"
  - "test-newline-position-tracking updated from Plan 02: expected 2 tokens from '[NL['; now correctly expects 3 tokens (:lbracket :newline :lbracket) because :newline tokens are emitted"

patterns-established:
  - "Nesting depth pattern: incf on [, (, { open; decf on ], ), } close; prose detection cond on (and line-start-p (zerop nesting-depth))"
  - "Wikilink lookahead: %scan-double-bracket reads source chars without advancing pos; loop while (< pos close-pos) do (incf col) (incf pos) advances cleanly after decision"

requirements-completed: [TOK-16, TOK-17, TOK-18]

# Metrics
duration: 9min
completed: 2026-03-28
---

# Phase 03 Plan 03: Tokenizer Wave 3 Summary

**Wikilink disambiguation via pure lookahead, prose detection with nesting-depth gating, newline emission with collapse, and burg_pipeline.dpn integration test — completing all 23 token types and all 18 TOK requirements**

## Performance

- **Duration:** 9 min
- **Started:** 2026-03-28T21:21:34Z
- **Completed:** 2026-03-28T21:29:44Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments

- `[[Burg]]` → single `:wikilink` token with value `"Burg"` (TOK-16)
- `[[sylvia[command]]]` → 8 tokens starting with `:lbracket :lbracket` (TOK-16)
- `"This is plain text"` at line start → `:prose` token (TOK-17)
- `"decree foo"` at line start → `:decree :bare-word` NOT prose (TOK-17)
- Consecutive `\n\n` collapse to one `:newline` token (TOK-18)
- `burg_pipeline.dpn` tokenizes without error — all key token types present
- Multi-line position tracking verified: `@` on line 3 has line=3, col=1
- `"[[Burg]]"` inside string stays as `:string`, not `:wikilink`
- 54/54 tests pass (up from 50 in Plan 02)

## Task Commits

Each task was committed atomically:

1. **Task 1: Wikilink disambiguation, prose detection, newline collapse** - `4a6ca6b` (feat)
2. **Task 2: Integration tests, nesting depth, burg_pipeline compat** - `ac1fb8b` (feat)

## Files Created/Modified

- `src/parser/tokenizer.lisp` — three major additions: wikilink lookahead (lines ~155-185), prose detection with nesting-depth gating (line-start-p + nesting-depth variables), newline emission with last-was-newline collapse; also: dot-in-bare-word and dash-as-prose spec gap fixes
- `tests/test-tokenizer.lisp` — 14 new deftest forms (9 in Task 1: wikilink/prose/newline; 4 in Task 2: integration/position); 2 existing tests updated for new semantics (test-bare-word, test-decree-keyword, test-newline-position-tracking)

## Decisions Made

- `nesting-depth` tracker added to the tokenizer — not in the original plan spec, but required for correct behavior of multi-line bracket expressions. Without it, every line inside `[burg[...]]` would be treated as prose.
- `prose detection falls through for all punctuation` — the line-start sigil check originally only listed `[ ( { @ ! # / |`, but punctuation like `:`, `,`, `]`, `)`, `}` also needed fall-through to preserve unit test behavior for standalone tokens.
- `dot in bare-word` — `burg_pipeline.dpn` first line `# burg_pipeline.dpn` has `.dpn` which would error without dot support. Added `.` to bare-word chars with a spec-gap comment.
- `dash-as-prose in normal dispatch` — `burg_pipeline.dpn` uses `- "text"` list items inside brackets; since nesting-depth > 0 means prose detection is skipped, the normal dispatch `-` path also needs to emit prose when not followed by `>`.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing functionality] Added nesting-depth tracker for prose gating**
- **Found during:** Task 2 (burg_pipeline integration test failing on `@Alaran`)
- **Issue:** `description:[@Alaran...]` inside brackets was treated as prose because line-start-p was T after the preceding newline, even though nesting-depth was > 0
- **Fix:** Added `nesting-depth` integer variable; incremented on `[`, `(`, `{` open; decremented on `]`, `)`, `}` close; prose detection gated on `(and line-start-p (zerop nesting-depth))`
- **Files modified:** `src/parser/tokenizer.lisp`
- **Commit:** `ac1fb8b`

**2. [Rule 1 - Bug] Extended punctuation fall-through set in line-start prose detection**
- **Found during:** Task 1 GREEN pass (TEST-SINGLE-BRACKET-TOKENS, TEST-SINGLE-PUNCTUATION-TOKENS failing)
- **Issue:** Tokens `]`, `)`, `}`, `:`, `,` at line start were triggering prose detection because they're not in the executable sigil set; unit tests for standalone tokens were returning `:prose` instead of the correct token type
- **Fix:** Added all punctuation chars to the "fall through to normal dispatch" branch in line-start detection
- **Files modified:** `src/parser/tokenizer.lisp`
- **Commit:** `4a6ca6b`

**3. [Rule 1 - Bug] Dot in bare-word for burg_pipeline.dpn compat**
- **Found during:** Task 2 integration test (`# burg_pipeline.dpn` line signaling parse error at `.`)
- **Issue:** `burg_pipeline.dpn` in `# burg_pipeline.dpn` has a dot; bare-word reader didn't include `.`; unexpected char error signaled
- **Fix:** Added `(char= (current) #\.)` to the bare-word accumulation loop condition with spec-gap comment
- **Files modified:** `src/parser/tokenizer.lisp`
- **Commit:** `ac1fb8b`

**4. [Rule 1 - Bug] Dash-as-prose in normal dispatch for burg_pipeline list items**
- **Found during:** Task 2 integration test (parse error "- must be followed by >" on line 4)
- **Issue:** `- "<emoji> Seed"` inside `[levels ...]` bracket had nesting-depth > 0, bypassing line-start prose detection; normal dispatch `-` handler signaled error when not followed by `>`
- **Fix:** Changed `-` normal dispatch to emit `:prose` (read to EOL) instead of signaling error when not followed by `>`; added spec-gap comment
- **Files modified:** `src/parser/tokenizer.lisp`
- **Commit:** `ac1fb8b`

**5. [Rule 1 - Bug] Updated Plan 02 tests for :newline emission**
- **Found during:** Task 1 GREEN pass (TEST-NEWLINE-POSITION-TRACKING failing: expected 2 tokens, got 3)
- **Issue:** Plan 02 test `test-newline-position-tracking` expected 2 tokens from `"[\n["` because newlines were silently consumed in Plan 02. Plan 03 emits `:newline` tokens, so the correct count is 3.
- **Fix:** Updated test to assert 3 tokens (`:lbracket :newline :lbracket`) with correct types and positions
- **Files modified:** `tests/test-tokenizer.lisp`
- **Commit:** `4a6ca6b`

## Self-Check: PASSED

- src/parser/tokenizer.lisp: FOUND
- tests/test-tokenizer.lisp: FOUND
- 03-03-SUMMARY.md: FOUND
- Commit 4a6ca6b: FOUND
- Commit ac1fb8b: FOUND

---
*Phase: 03-tokenizer*
*Completed: 2026-03-28*
