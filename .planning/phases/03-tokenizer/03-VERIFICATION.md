---
phase: 03-tokenizer
verified: 2026-03-28T22:05:00Z
status: passed
score: 7/7 must-haves verified
re_verification: false
---

# Phase 03: Tokenizer Verification Report

**Phase Goal:** Any valid Innate source text can be converted to a typed, positioned token stream with no ambiguity on wikilinks vs. nested brackets
**Verified:** 2026-03-28T22:05:00Z
**Status:** passed
**Re-verification:** No — initial verification

---

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | `[[Burg]]` tokenizes as a single `:wikilink` token with value "Burg" | VERIFIED | `test-wikilink-simple` PASS; `%scan-double-bracket` pure lookahead in tokenizer.lisp lines 155-178 |
| 2 | `[[sylvia[command]]]` tokenizes as nested `:lbracket` tokens, not wikilink | VERIFIED | `test-wikilink-vs-nested-brackets` PASS; returns 8 tokens starting `:lbracket :lbracket` |
| 3 | Prose lines at line start emit as `:prose` tokens | VERIFIED | `test-prose-line` PASS; `line-start-p` + `nesting-depth` detection in tokenizer.lisp lines 215-302 |
| 4 | `decree foo` at line start is NOT prose — emits `:decree` then `:bare-word` | VERIFIED | `test-prose-not-decree` PASS; "decree" keyword checked before prose fallback |
| 5 | Newlines emit as `:newline` tokens; consecutive newlines collapse to one | VERIFIED | `test-newline-collapse` PASS; `last-was-newline` flag at line 26 and collapse guard at lines 204-208 |
| 6 | Every token carries correct line and column numbers including across multiple lines | VERIFIED | `test-multiline-position-tracking` PASS; `test-newline-position` PASS; `@` on line 3 has `line=3 col=1` |
| 7 | `burg_pipeline.dpn` tokenizes without error | VERIFIED | `test-burg-pipeline-tokenizes` PASS; confirms `:lbracket`, `:string`, `:colon`, `:hash`, `:at`, `:bang-bracket`, `:slash`, `:bare-word` all present |

**Score:** 7/7 truths verified

---

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `src/parser/tokenizer.lisp` | Token defstruct + complete tokenizer with wikilink, prose, newline | VERIFIED | 490 lines; contains `defstruct (token`, `defun tokenize`, `wikilink`, `line-start-p`, `last-was-newline` |
| `tests/test-tokenizer.lisp` | Full test suite covering all 18 TOK requirements + integration | VERIFIED | 357 lines; contains `test-wikilink-simple`, `test-wikilink-vs-nested-brackets`, `test-prose-line`, `test-newline-collapse`, `test-burg-pipeline-tokenizes`, `test-multiline-position-tracking` |
| `src/packages.lisp` | `innate.parser.tokenizer` exports 6 symbols | VERIFIED | Exports `make-token`, `token-type`, `token-value`, `token-line`, `token-col`, `tokenize`; imports `innate-parse-error` from `innate.conditions` |
| `tests/packages.lisp` | `innate.tests.tokenizer` package with full import mirrors | VERIFIED | Package defined at line 77; imports all 6 tokenizer symbols + `innate-parse-error` |
| `innatescript.asd` | `test-tokenizer` wired into `innatescript/tests` system | VERIFIED | `:file "test-tokenizer" :depends-on ("packages" "test-framework")` at line 37 |

---

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `src/packages.lisp` | `src/parser/tokenizer.lisp` | defpackage exports match defstruct accessors | VERIFIED | All 6 exported symbols (`make-token`, `token-type`, `token-value`, `token-line`, `token-col`, `tokenize`) exactly match defstruct accessor names in tokenizer.lisp |
| `tests/test-tokenizer.lisp` | `src/parser/tokenizer.lisp` | import-from innate.parser.tokenizer; calls tokenize + token-type | VERIFIED | Tests call `(tokenize ...)` and check `(token-type ...)`, `(token-value ...)`, `(token-line ...)`, `(token-col ...)` throughout; 31 deftest forms |
| `src/parser/tokenizer.lisp` | `src/conditions.lisp` | signals `innate-parse-error` on malformed input | VERIFIED | 8 occurrences of `innate-parse-error` in tokenizer.lisp (unterminated string, unknown escape, unterminated `[[`, invalid `!`, invalid `|`, unexpected char) |
| `tests/test-tokenizer.lisp` | `burg_pipeline.dpn` | reads file and passes to tokenize as integration test | VERIFIED | `%read-file-to-string "burg_pipeline.dpn"` in `test-burg-pipeline-tokenizes`; file exists at project root |

---

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| TOK-01 | 03-02 | Tokenize all bracket types: `[`, `]`, `(`, `)`, `{`, `}` | SATISFIED | `test-single-bracket-tokens` PASS; all 6 bracket types emit correct token |
| TOK-02 | 03-02 | Tokenize `@name` as reference token | SATISFIED | `test-at-reference` PASS; `:at` then `:bare-word("foo")` |
| TOK-03 | 03-02 | Tokenize `![]` as search directive opener | SATISFIED | `test-two-char-operators` PASS; `![ ` → single `:bang-bracket` |
| TOK-04 | 03-02 | Tokenize `\|\|` as fulfillment operator | SATISFIED | `test-two-char-operators` PASS; `\|\|` → single `:pipe-pipe` |
| TOK-05 | 03-02 | Tokenize `->` as emission | SATISFIED | `test-two-char-operators` PASS; `->` → single `:arrow` |
| TOK-06 | 03-02 | Tokenize `+word` as combinator | SATISFIED | `test-plus-bare-word` PASS; `:plus` then `:bare-word("all")` |
| TOK-07 | 03-02 | Tokenize `:` as colon | SATISFIED | `test-single-punctuation-tokens` PASS |
| TOK-08 | 03-02 | Tokenize `,` as comma | SATISFIED | `test-single-punctuation-tokens` PASS |
| TOK-09 | 03-02 | Tokenize `#` at line start as heading | SATISFIED | `test-single-punctuation-tokens` PASS; `:hash` emitted; REQUIREMENTS.md describes "heading with text extracted" — tokenizer emits `:hash` token; heading node construction is deferred to parser phase (Phase 4), which is consistent with tokenizer scope |
| TOK-10 | 03-02 | Tokenize `/word` as presentation modifier | SATISFIED | `test-single-punctuation-tokens` PASS; `:slash` emitted; modifier construction deferred to parser |
| TOK-11 | 03-02 | Tokenize double-quoted string literals with escape support | SATISFIED | `test-string-literal` PASS; `\"` and `\\` escapes verified; `test-string-unterminated` PASS |
| TOK-12 | 03-02 | Tokenize integer number literals | SATISFIED | `test-number-literal` PASS; "42" and "0" emit `:number` |
| TOK-13 | 03-02 | Tokenize bare words (identifiers) | SATISFIED | `test-bare-word` PASS; inside brackets → `:bare-word`; at line start → `:prose` (consistent with TOK-17) |
| TOK-14 | 03-02 | Tokenize `<emoji>` as emoji slot | SATISFIED | `test-emoji-slot` PASS; exact 7-char match `:emoji-slot` with value `"<emoji>"` |
| TOK-15 | 03-02 | Tokenize `decree` as keyword | SATISFIED | `test-decree-keyword` PASS; "decree" → `:decree`; "decrement" → `:prose` at line start |
| TOK-16 | 03-03 | Disambiguate `[[...]]` wikilink from nested brackets | SATISFIED | `test-wikilink-simple` PASS; `test-wikilink-vs-nested-brackets` PASS; pure lookahead `%scan-double-bracket` |
| TOK-17 | 03-03 | Detect prose lines and emit as prose tokens | SATISFIED | `test-prose-line`, `test-prose-not-decree`, `test-prose-not-lbracket`, `test-prose-not-arrow` all PASS; nesting-depth gating prevents false prose inside brackets |
| TOK-18 | 03-01/03-03 | Track line and column numbers on every token | SATISFIED | `test-token-struct-round-trip` PASS; `test-newline-position` PASS; `test-multiline-position-tracking` PASS; `:newline` collapse with `last-was-newline` flag |

All 18 requirements: SATISFIED. All marked Complete in REQUIREMENTS.md.

**No orphaned requirements.** REQUIREMENTS.md maps TOK-01 through TOK-18 exclusively to Phase 3; all 18 are claimed across plans 03-01, 03-02, 03-03.

---

### Anti-Patterns Found

No blockers. No warnings. No TODO/FIXME/HACK/PLACEHOLDER comments in tokenizer.lisp or test-tokenizer.lisp.

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `src/parser/tokenizer.lisp` | 116 | `.` in bare-word chars (spec gap comment) | Info | Documented spec gap for filename tokens; does not affect correctness of wikilink or prose detection |
| `src/parser/tokenizer.lisp` | 232-244 | `-` without `>` at line start → prose (spec gap comment) | Info | Documented burg_pipeline.dpn compat; comment present; no silent behavior |
| `src/parser/tokenizer.lisp` | 456-464 | `-` without `>` in normal dispatch → prose (spec gap comment) | Info | Same as above; applies inside brackets; comment present |

All three are explicitly documented spec-gap decisions with code comments. None block the phase goal.

---

### Human Verification Required

None. All 7 observable truths are verifiable programmatically. The test suite is fully automated and passes 54/54 with exit code 0.

---

### Commit Audit

All 5 commits documented in summaries exist and are verified:

| Commit | Plan | Description |
|--------|------|-------------|
| `14a8e10` | 03-01 Task 1 | Package exports, test package, ASDF wiring |
| `ca59d39` | 03-01 Task 2 | Token defstruct and initial round-trip tests |
| `a4a45eb` | 03-02 Tasks 1+2 | Tokenizer main loop, single-char dispatch, literals |
| `4a6ca6b` | 03-03 Task 1 | Wikilink disambiguation, prose detection, newline collapse |
| `ac1fb8b` | 03-03 Task 2 | Integration tests, nesting depth, burg_pipeline compat |

---

### Gaps Summary

No gaps. The phase goal is fully achieved:

- All 18 TOK requirements are satisfied with passing tests
- The tokenizer correctly disambiguates `[[...]]` wikilinks from nested brackets via pure lookahead
- Prose detection is gated by both `line-start-p` and `nesting-depth`, preventing false positives inside bracket expressions
- Every token carries line/col numbers; newline collapse works correctly
- `burg_pipeline.dpn` tokenizes without error
- The full test suite (54/54) passes at exit code 0

---

_Verified: 2026-03-28T22:05:00Z_
_Verifier: Claude (gsd-verifier)_
