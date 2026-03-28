# Phase 3: Tokenizer - Research

**Researched:** 2026-03-28
**Domain:** Hand-rolled lexer in Common Lisp — character-by-character tokenization of `.dpn` source text
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Token representation:**
- `defstruct token` with four slots: `type` (keyword), `value` (string or number), `line` (integer), `col` (integer)
- Token types are keywords: `:lbracket`, `:rbracket`, `:lparen`, `:rparen`, `:lbrace`, `:rbrace`, `:at`, `:bang-bracket`, `:pipe-pipe`, `:arrow`, `:plus`, `:colon`, `:comma`, `:hash`, `:slash`, `:string`, `:number`, `:bare-word`, `:emoji-slot`, `:decree`, `:wikilink`, `:prose`, `:newline`
- Separate struct from AST `node` — tokens are flat positional data, nodes are trees. The parser converts tokens to nodes.
- Constructor: `make-token &key type value line col`
- Exported from `innate.parser.tokenizer`: `make-token`, `token-type`, `token-value`, `token-line`, `token-col`, `tokenize` (the main entry point, takes a string, returns list of tokens)

**Whitespace and newline handling:**
- Spaces and tabs between tokens on the same line are consumed silently (not emitted)
- Newlines emit a `:newline` token
- Consecutive newlines collapse to a single `:newline` token
- Indentation whitespace at line start is consumed before examining the first significant character

**Prose line detection:**
- A line is prose if its first non-whitespace character is NOT one of: `[`, `(`, `{`, `@`, `!`, `#`, `/`, `>`, `-` (for `->`)`, `d` (for `decree`)
- Special case: a line starting with `decree` keyword is executable, not prose
- Special case: a line starting with `->` is emission, not prose
- Lines starting with bare words that are NOT `decree` are prose
- The tokenizer emits the entire line content as a single `:prose` token with the text in `value`
- Prose detection happens at line-start only

**Wikilink disambiguation (from TOK-16, locked):**
- On encountering `[[`: scan forward character by character
- If `]` is reached before any `[`: this is a wikilink — emit `:wikilink` token with the inner text as value
- If `[` is reached first: this is nested brackets — emit two `:lbracket` tokens and continue normal tokenization
- `[[Burg]]` → one `:wikilink` token with value `"Burg"`
- `[[sylvia[command]]]` → `:lbracket`, `:lbracket`, `:bare-word("sylvia")`, `:lbracket`, `:bare-word("command")`, `:rbracket`, `:rbracket`, `:rbracket`

**String literals:**
- Double-quoted only, no single quotes
- Escape sequences: `\"` (literal quote), `\\` (literal backslash)
- Wikilinks inside strings are preserved as literal text in the string value

**Number literals:**
- Integers only (no floats, no negative sign as part of the number token)
- Sequence of `[0-9]+`

**Error handling:**
- Unterminated string → signal `innate-parse-error` with line/col of the opening quote
- Unexpected character → signal `innate-parse-error` with line/col
- The tokenizer never returns partial results

**Main entry point:**
- `(tokenize source-string)` → list of `token` structs
- Input is always a string
- No stream/lazy behavior — full eager tokenization

### Claude's Discretion
- Internal helper function organization (char-classification predicates, etc.)
- Buffer management for accumulating multi-character tokens
- Exact test case selection beyond the spec-mandated vocabulary coverage

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope.
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| TOK-01 | Tokenize all bracket types: `[`, `]`, `(`, `)`, `{`, `}` | Single-char dispatch on `[`, `]`, `(`, `)`, `{`, `}` → emit typed token with current line/col |
| TOK-02 | Tokenize `@name` as a reference token with the name extracted | Emit `:at` token at `@`, then scanner reads following `[a-zA-Z_][a-zA-Z0-9_]*` as `:bare-word`; parser combines. See Design Note 1. |
| TOK-03 | Tokenize `![]` as a search directive opener | Two-char lookahead: `!` + peek next char; if next is `[`, emit `:bang-bracket` and consume both chars |
| TOK-04 | Tokenize `\|\|` as the fulfillment operator | Two-char lookahead: `\|` + peek next; if next is `\|`, emit `:pipe-pipe`, consume both |
| TOK-05 | Tokenize `->` as emission | Two-char lookahead: `-` + peek next; if next is `>`, emit `:arrow`, consume both |
| TOK-06 | Tokenize `+word` as a combinator with the word extracted | Emit `:plus` at `+`, then bare-word scanner reads the identifier; parser combines |
| TOK-07 | Tokenize `:` as colon | Single-char dispatch → `:colon` |
| TOK-08 | Tokenize `,` as comma | Single-char dispatch → `:comma` |
| TOK-09 | Tokenize `#` at line start as heading with text extracted | Emit `:hash` at `#`, then bare-word scanner reads identifier; parser combines. See Design Note 2. |
| TOK-10 | Tokenize `/word` as a presentation modifier | Emit `:slash` at `/`, then bare-word scanner reads identifier; parser combines |
| TOK-11 | Tokenize double-quoted string literals with escape support | Char loop: consume `"`, accumulate chars until closing `"`, handle `\"` and `\\`, signal on unterminated |
| TOK-12 | Tokenize integer number literals | Digit loop: consume `[0-9]+`, accumulate into string, emit `:number` with string value |
| TOK-13 | Tokenize bare words (identifiers) | Char loop: consume `[a-zA-Z_][a-zA-Z0-9_]*`; check against `"decree"` keyword before emitting |
| TOK-14 | Tokenize `<emoji>` as emoji slot | Literal sequence match: `<emoji>` is exactly 7 chars; peek-match against fixed string, emit `:emoji-slot` |
| TOK-15 | Tokenize `decree` as keyword | Bare-word accumulator: after accumulating, compare with `"decree"` string; if match emit `:decree`, else `:bare-word` |
| TOK-16 | Disambiguate `[[...]]` (wikilink) from nested brackets | Forward scan at `[[`: count brackets until first `]` or `[`; if `]` first → wikilink; if `[` first → two `:lbracket` tokens |
| TOK-17 | Detect prose lines and emit as prose tokens | At line start, after consuming leading whitespace, check first char against executable sigil set; if not in set → read to EOL, emit `:prose` |
| TOK-18 | Track line and column numbers on every token | Maintain `line` and `col` variables in the tokenizer loop; increment `line` at `\n`, reset `col`; increment `col` per char consumed |
</phase_requirements>

---

## Summary

Phase 3 implements the character-level tokenizer for the Innate language. The tokenizer reads a source string and emits a flat list of `token` structs, each carrying type, value, line, and column. All design decisions are locked in CONTEXT.md; this phase has no open architecture choices. The work is pure implementation of a well-specified hand-rolled lexer.

The tokenizer handles two classes of tokens: single-character punctuation (dispatched immediately on the character), and multi-character tokens (string literals, number literals, bare words, wikilinks, prose lines, and two-character operators). The most complex logic is the wikilink disambiguation algorithm (TOK-16) and the prose line detection at line-start (TOK-17). Both are fully specified in CONTEXT.md.

The phase builds on Phase 2 artifacts: `innate-parse-error` (conditions.lisp) for error signaling, the existing package stub (packages.lisp), and the test harness (tests/test-framework.lisp). It produces no AST nodes — that is Phase 4's job. The output contract is: `(tokenize "source")` → `(list token ...)`.

**Primary recommendation:** Implement the tokenizer as a single `defun tokenize` over a character pointer (`pos` integer into the source string), dispatching on `(char source pos)` with a `case` or `cond`. Maintain `line`/`col` as mutable locals. Return the accumulated token list. Do not use streams, do not use the CL `read` function, do not use any regex library.

---

## Standard Stack

### Core
| Technology | Version | Purpose | Why Standard |
|------------|---------|---------|--------------|
| SBCL | 2.x (bundled) | Runtime | Project-wide constraint; all prior phases use it |
| `defstruct` | ANSI CL | Token representation | Locked decision from CONTEXT.md; matches `node` struct pattern from Phase 2 |
| `read-char` / `peek-char` / string indexing | ANSI CL | Character access | No external deps; direct string indexing (`char source pos`) is simpler and faster than stream-based access for eager in-memory tokenization |
| `innate-parse-error` condition | Phase 2 artifact | Error signaling | Already defined in conditions.lisp; tokenizer uses `(error 'innate-parse-error :line L :col C :text ...)` |

### Supporting Patterns
| Pattern | Purpose | When to Use |
|---------|---------|-------------|
| Position-integer cursor (`pos`) over source string | Replaces stream-based char reading | Always — source is a string, `(char source pos)` and `(1+ pos)` are O(1) |
| Mutable `line`/`col` locals | Position tracking for TOK-18 | Always — increment on every consumed char, reset `col` on `\n` |
| Two-char lookahead via `(char source (1+ pos))` | Two-character operator dispatch | `->`, `\|\|`, `![ ` — peek before consuming |
| `with-output-to-string` / char accumulator list | Buffer for multi-char tokens | Accumulate chars for strings, numbers, bare words, prose; convert to string at emit time |
| `nreverse` on token accumulator | Return list in source order | Push tokens onto a list, reverse at end — avoids O(n) appends |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| String index cursor | `make-string-input-stream` + `read-char` | Stream has overhead and manages its own position; index is simpler, zero allocation |
| `nreverse` accumulator | `vector` with `vector-push-extend` | Vector is fine but adds no benefit; list + nreverse is the idiomatic CL pattern |
| `case` dispatch on current char | `cond` with `char=` tests | `case` on characters is valid CL (`char` values work with `case`); both are fine — choose for readability |

**Installation:** No packages to install. SBCL + ASDF bundled. Zero external deps per AF64 convention.

---

## Architecture Patterns

### Recommended File Structure

The tokenizer lives entirely in one file:

```
src/parser/tokenizer.lisp      — defstruct token + defun tokenize + helpers
tests/test-tokenizer.lisp      — innate.tests.tokenizer package, all TOK-* tests
```

`packages.lisp` needs two edits:
1. Add exports to `innate.parser.tokenizer` defpackage
2. Add `innate.tests.tokenizer` defpackage
3. Update `innatescript/tests` ASDF system to include `test-tokenizer`

### Pattern 1: Position-Based Character Loop

The main tokenizer loop advances a position integer through the source string. No recursion is needed for the top-level loop.

```common-lisp
(defun tokenize (source)
  "Convert SOURCE string to a list of token structs.
   Signals innate-parse-error on unterminated strings or unexpected characters."
  (let ((tokens '())
        (pos 0)
        (line 1)
        (col 1)
        (len (length source)))
    (labels ((current ()
               (when (< pos len) (char source pos)))
             (advance ()
               (let ((c (char source pos)))
                 (incf pos)
                 (if (char= c #\Newline)
                     (progn (incf line) (setf col 1))
                     (incf col))
                 c))
             (peek-next ()
               (when (< (1+ pos) len) (char source (1+ pos))))
             (emit (type &optional value)
               (push (make-token :type type
                                 :value value
                                 :line line
                                 :col col)
                     tokens)))
      ;; ... main dispatch loop ...
      )
    (nreverse tokens)))
```

Note: The `line`/`col` at emit time should be captured BEFORE advancing. The pattern is: record `start-line`/`start-col` at the first char of a token, emit with those coords after accumulating.

### Pattern 2: Single-Character Dispatch

Single-character tokens dispatch directly in the main loop:

```common-lisp
(case (current)
  (#\[ (let ((sl line) (sc col))
         (advance)
         ;; check for [[ wikilink/nested case
         (if (char= (current) #\[)
             (handle-double-bracket sl sc)
             (push (make-token :type :lbracket :value nil :line sl :col sc) tokens))))
  (#\] (let ((sl line) (sc col)) (advance)
         (push (make-token :type :rbracket :value nil :line sl :col sc) tokens)))
  ;; ... etc
  )
```

### Pattern 3: Wikilink Disambiguation (TOK-16)

The disambiguation algorithm scans forward without consuming, then decides what to emit:

```common-lisp
(defun %disambiguate-double-bracket (source pos)
  "Given POS pointing to the second [ in [[, scan forward.
   Returns :wikilink if ] is found before [, :nested-bracket otherwise.
   Also returns the inner text (for wikilink case) and the end pos."
  (let ((scan (1+ pos))  ; skip past the second [
        (len (length source))
        (buf '()))
    (loop
      (when (>= scan len)
        (return (values :unterminated nil scan)))
      (let ((c (char source scan)))
        (cond
          ((char= c #\]) (return (values :wikilink
                                          (coerce (nreverse buf) 'string)
                                          scan)))
          ((char= c #\[) (return (values :nested-bracket nil scan)))
          (t (push c buf) (incf scan)))))))
```

This is a pure lookahead function. The main tokenizer calls it, then decides how many characters to consume.

### Pattern 4: Prose Detection at Line Start

Track a `line-start-p` boolean that is `T` at the beginning of the source and after each `\n`:

```common-lisp
;; At the top of the loop, when line-start-p is T:
;;   1. Consume leading whitespace (spaces/tabs)
;;   2. Check the first non-whitespace character
;;   3. If it is in the executable-sigil set: set line-start-p nil, continue normal dispatch
;;   4. If it is NOT: read to end of line, emit :prose, consume the newline, reset line-start-p
```

The executable-sigil set (chars that prevent prose detection):
`[`, `(`, `{`, `@`, `!`, `#`, `/`, `>`, `-`

Special case for `d`: if the line starts with `d`, peek forward to check if the word is exactly `"decree"`. If yes, it's executable. If no, it's prose.

### Pattern 5: String Literal Accumulation

```common-lisp
;; On encountering #\":
(let ((start-line line) (start-col col))
  (advance)  ; consume opening "
  (let ((buf '()))
    (loop
      (cond
        ((null (current))
         (error 'innate-parse-error
                :line start-line :col start-col
                :text "Unterminated string literal"))
        ((char= (current) #\\)
         (advance)  ; consume backslash
         (case (current)
           (#\" (push #\" buf) (advance))
           (#\\ (push #\\ buf) (advance))
           (t (error 'innate-parse-error :line line :col col
                     :text (format nil "Unknown escape \\~a" (current))))))
        ((char= (current) #\")
         (advance)  ; consume closing "
         (return (push (make-token :type :string
                                   :value (coerce (nreverse buf) 'string)
                                   :line start-line :col start-col)
                       tokens)))
        (t (push (current) buf) (advance))))))
```

### Pattern 6: `<emoji>` Literal Match

`<emoji>` is exactly seven characters: `<`, `e`, `m`, `o`, `j`, `i`, `>`. Use a forward match:

```common-lisp
(defun %match-emoji-slot-p (source pos)
  "Return T if source[pos..pos+6] is exactly \"<emoji>\"."
  (and (>= (- (length source) pos) 7)
       (string= "<emoji>" source :start2 pos :end2 (+ pos 7))))
```

If it matches, advance 7 chars and emit `:emoji-slot` with value `"<emoji>"`.

### Pattern 7: `decree` Keyword Detection

After accumulating a bare-word string, compare it against `"decree"`:

```common-lisp
(defun %emit-bare-word-or-decree (word line col tokens)
  (push (make-token :type (if (string= word "decree") :decree :bare-word)
                    :value word
                    :line line
                    :col col)
        tokens))
```

### Anti-Patterns to Avoid

- **Using CL `read`:** CL reader expects S-expressions. It will error on `@`, `![]`, `->`, and all Innate sigils.
- **Using streams for source input:** Source is always a string. Stream wrapping adds allocation overhead with no benefit.
- **Consuming before recording start position:** Always record `start-line`/`start-col` before the first `advance` of a multi-char token.
- **Emitting partial results on error:** The tokenizer must signal `innate-parse-error` and return nothing on error. Never return a partial list.
- **Forgetting newline collapse:** Consecutive `:newline` tokens must be collapsed. Either collapse during emission (track `last-emitted-type`) or in a post-pass.
- **Treating `d` at line start as always-prose:** A line starting with `d` followed by `ecree` and then whitespace/end is executable. Read the full bare-word first, then decide.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Error condition with line/col | Custom error struct | `innate-parse-error` from Phase 2 | Already defined in conditions.lisp with `:line`, `:col`, `:text` slots |
| Test assertions | Custom comparison helpers | `assert-equal`, `assert-true`, `assert-signals` from test-framework.lisp | Phase 1 deliverable, fully functional |
| ASDF integration | Manual `load` calls | `innatescript/tests` secondary ASDF system | Already registered; just add new test file to components list |

**Key insight:** The Phase 2 condition system is the only external piece the tokenizer depends on. Everything else (struct, loop, char dispatch) is ANSI CL with no dependencies.

---

## Common Pitfalls

### Pitfall 1: Position-Before-Value in Token Emission

**What goes wrong:** Token emitted with `line`/`col` reflecting the position AFTER the token's last character, not the first.

**Why it happens:** The loop advances position as it consumes, so by the time emit is called, `line`/`col` reflect the post-token position.

**How to avoid:** Capture `start-line` and `start-col` into locals at the first character of each token (before any `advance` call for that token). Emit using `start-line`/`start-col`, not the current `line`/`col`.

**Warning signs:** Test failures where `token-col` is off by the length of the token value.

### Pitfall 2: Wikilink Scan Consuming Source Characters

**What goes wrong:** The forward-scan for wikilink disambiguation advances the position cursor, so after deciding it's nested brackets (not a wikilink), the source chars are lost.

**Why it happens:** The scan and the consume are conflated.

**How to avoid:** Implement disambiguation as a pure lookahead that takes `source` and `pos` but does NOT mutate `pos`. Only after the decision is made does the main loop consume chars.

**Warning signs:** Tokens missing inner characters after `[[` in nested-bracket mode.

### Pitfall 3: Prose Detection Missing the `decree` Edge Case

**What goes wrong:** A `.dpn` file containing `decree some-name` at line start emits a `:prose` token instead of `:decree` + `:bare-word`.

**Why it happens:** The prose sigil check sees `d` (not in the sigil set) and immediately reads to EOL as prose.

**How to avoid:** When first non-whitespace char is `d`, do NOT immediately emit prose. Instead, read the full bare-word (chars matching `[a-zA-Z_][a-zA-Z0-9_]*`), check if it equals `"decree"`. Only if it does not match `"decree"` should the line be treated as prose.

**Warning signs:** `(tokenize "decree foo")` returns a single `:prose` token instead of `:decree` + `:bare-word`.

### Pitfall 4: Newline Handling Breaks Line/Col Tracking

**What goes wrong:** After a newline, `col` continues incrementing from the previous line's count rather than resetting to 1.

**Why it happens:** `col` increment logic doesn't distinguish `\n` from other characters.

**How to avoid:** In the `advance` helper, when the consumed character is `\n`: increment `line`, reset `col` to 1. For all other characters: increment `col` only.

**Warning signs:** Token on the second line of input has `col` > actual column.

### Pitfall 5: Consecutive Newline Collapse

**What goes wrong:** Two blank lines between sections emit two `:newline` tokens; the parser is not designed to handle multiple consecutive `:newline` tokens.

**Why it happens:** Each `\n` naively emits one `:newline` token.

**How to avoid:** Track last-emitted token type. Before emitting `:newline`, check if the last emitted token was also `:newline`. If so, skip the emission (collapse). A simple `last-was-newline` boolean flag is sufficient.

**Warning signs:** Parser tests fail on inputs with blank lines; more tokens than expected in the output list.

### Pitfall 6: `innate.parser.tokenizer` Package Exports Missing

**What goes wrong:** ASDF loads the system, but `(innate.parser.tokenizer:tokenize ...)` throws a `package-error` because symbols were not added to the export list.

**Why it happens:** The package stub in `packages.lisp` has `(:export)` with no symbols listed. The implementation must be accompanied by a `packages.lisp` edit.

**How to avoid:** As the first task of this phase, add the six exports (`make-token`, `token-type`, `token-value`, `token-line`, `token-col`, `tokenize`) to the `innate.parser.tokenizer` defpackage in `packages.lisp`.

**Warning signs:** `(asdf:load-system "innatescript")` succeeds but calling `tokenize` from another package throws `SYMBOL-NOT-FOUND`.

---

## Code Examples

### Complete Token Struct Definition

```common-lisp
;; Source: CONTEXT.md locked decision + defstruct pattern from types.lisp
(defstruct (token (:constructor make-token (&key type value line col)))
  "A single lexical token from Innate source text.
  type  — keyword: one of the 23 token types defined in packages.lisp exports
  value — string for :string/:number/:bare-word/:decree/:wikilink/:prose/:emoji-slot;
          nil for punctuation tokens
  line  — 1-based line number of the first character of this token
  col   — 1-based column number of the first character of this token"
  (type  nil)
  (value nil)
  (line  1   :type integer)
  (col   1   :type integer))
```

### Package Export Addition (packages.lisp edit)

```common-lisp
;; Replace the empty (:export) in innate.parser.tokenizer:
(defpackage :innate.parser.tokenizer
  (:use :cl)
  (:import-from :innate.conditions
    #:innate-parse-error)
  (:export
   #:make-token
   #:token-type
   #:token-value
   #:token-line
   #:token-col
   #:tokenize))
```

### Test Package Definition (tests/packages.lisp addition)

```common-lisp
(defpackage :innate.tests.tokenizer
  (:use :cl)
  (:import-from :innate.tests
    #:deftest
    #:assert-equal
    #:assert-true
    #:assert-nil
    #:assert-signals
    #:run-tests)
  (:import-from :innate.parser.tokenizer
    #:make-token
    #:token-type
    #:token-value
    #:token-line
    #:token-col
    #:tokenize)
  (:import-from :innate.conditions
    #:innate-parse-error)
  (:export))
```

### ASDF Test System Addition

```common-lisp
;; In innatescript/tests defsystem, add test-tokenizer after test-types:
(:file "test-tokenizer" :depends-on ("packages" "test-framework"))
```

---

## Design Notes

### Note 1: `@name` Token Emission — `:at` + `:bare-word` Pattern

The CONTEXT.md token type list contains `:at` (not `:at-reference`). TOK-02 says "with the name extracted." The CONTEXT.md specifics section clarifies the parser/tokenizer split with analogous tokens: `+word` emits `:plus` then `:bare-word`, and `/word` emits `:slash` then `:bare-word`. By symmetry, `@name` emits `:at` then `:bare-word`. "With the name extracted" in TOK-02 means the bare-word scanner runs immediately after consuming `@`, making the name available in the next `:bare-word` token. The parser (Phase 4) combines `:at` + `:bare-word` into a reference node.

**Implication:** The tokenizer does NOT need to peek ahead and combine `@name` into one token. It emits `:at` (no value), then the bare-word scanner picks up the following identifier as `:bare-word` with the name in `:value`.

### Note 2: `#` Heading — `:hash` + `:bare-word` Pattern

TOK-09 says "heading with text extracted." The CONTEXT.md token type for `#` is `:hash`. Following the same parser/tokenizer split: the tokenizer emits `:hash` at the `#` character, then the bare-word scanner reads the following identifier. The parser combines `:hash` + `:bare-word` into a heading node. The "at line start" constraint from TOK-09 applies to prose detection (lines starting with `#` are NOT prose), not to a special tokenizer mode — `#` anywhere in a line emits `:hash`.

### Note 3: Token Type Count

The CONTEXT.md decisions list exactly 23 token types:
`:lbracket`, `:rbracket`, `:lparen`, `:rparen`, `:lbrace`, `:rbrace`, `:at`, `:bang-bracket`, `:pipe-pipe`, `:arrow`, `:plus`, `:colon`, `:comma`, `:hash`, `:slash`, `:string`, `:number`, `:bare-word`, `:emoji-slot`, `:decree`, `:wikilink`, `:prose`, `:newline`

All 23 must be covered by test cases and documented in the package export list.

### Note 4: `!` Alone Is Not Valid

From CONTEXT.md specifics: "The `!` alone is not a valid token in Innate." If `!` appears in source not followed by `[`, the tokenizer must signal `innate-parse-error`. Only the two-character sequence `![` is valid, emitting `:bang-bracket`.

### Note 5: `-` Without `>` Is Not a Standalone Token

The token type list does not contain a `:minus` or `:dash` token. The tokenizer only recognizes `-` as the start of `->` (`:arrow`). A bare `-` not followed by `>` should signal `innate-parse-error` unless it appears inside a string literal or prose line.

Exception: In `burg_pipeline.dpn`, lines starting with `- "..."` appear as list items. These lines would be detected as prose (since `-` IS in the executable-sigil list... wait: CONTEXT.md says prose lines are those whose first char is NOT in `[`, `(`, `{`, `@`, `!`, `#`, `/`, `>`, `-`). So lines starting with `-` are NOT prose — they start the `->` check. If the next char after `-` is not `>`, signal a parse error. This means the list-item syntax in `burg_pipeline.dpn` (`- "<emoji> Seed"`) would be a parse error under the current spec. This is an open question for the planner to flag.

---

## Open Questions

1. **List-item lines in `burg_pipeline.dpn`**
   - What we know: Lines starting with `- "..."` appear in the sample `.dpn` file (burg_pipeline.dpn lines 4-6). The CONTEXT.md prose-sigil list explicitly includes `-` as an executable sigil (for `->` detection).
   - What's unclear: Under the current spec, `- "<emoji> Seed"` would attempt `->` parse, fail (next char is space, not `>`), and signal `innate-parse-error`. But the sample file contains this pattern.
   - Recommendation: Either (a) add `-` followed by non-`>` as prose in the prose detection rule, or (b) add `- expr` as a new token/construct to the spec. The planner should flag this as a spec gap before implementing TOK-17/TOK-05. For now, implement per spec (signal error on bare `-`) but include a test case that documents this behavior.

2. **`>` in the prose sigil set**
   - What we know: CONTEXT.md lists `>` in the executable sigil set (preventing prose). There is no `>` operator in the current token type list.
   - What's unclear: What does `>` introduce? A blockquote? A comparison operator?
   - Recommendation: Signal `innate-parse-error` on bare `>` outside strings (same as `!` alone). The prose-sigil set may be conservatively over-specified for future operators.

---

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | Hand-rolled (`deftest`/`assert-equal`/`assert-signals`) — `tests/test-framework.lisp` |
| Config file | `innatescript.asd` — `innatescript/tests` secondary system |
| Quick run command | `sbcl --non-interactive --load tests/run-tests.lisp 2>&1 \| tail -5` |
| Full suite command | `bash run-tests.sh` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| TOK-01 | `(tokenize "[")` → `(list token :lbracket)` | unit | `sbcl --load run-tests.lisp` (filter "tokenizer") | Wave 0 |
| TOK-01 | All 6 bracket chars emit correct token types | unit | same | Wave 0 |
| TOK-02 | `(tokenize "@foo")` → `:at` then `:bare-word("foo")` | unit | same | Wave 0 |
| TOK-03 | `(tokenize "![")` → single `:bang-bracket` token | unit | same | Wave 0 |
| TOK-04 | `(tokenize "\|\|")` → single `:pipe-pipe` token | unit | same | Wave 0 |
| TOK-05 | `(tokenize "->")` → single `:arrow` token | unit | same | Wave 0 |
| TOK-06 | `(tokenize "+all")` → `:plus` then `:bare-word("all")` | unit | same | Wave 0 |
| TOK-07 | `(tokenize ":")` → single `:colon` token | unit | same | Wave 0 |
| TOK-08 | `(tokenize ",")` → single `:comma` token | unit | same | Wave 0 |
| TOK-09 | `(tokenize "#header")` → `:hash` then `:bare-word("header")` | unit | same | Wave 0 |
| TOK-10 | `(tokenize "/wrapLeft")` → `:slash` then `:bare-word("wrapLeft")` | unit | same | Wave 0 |
| TOK-11 | `(tokenize "\"hello\"")` → `:string("hello")` | unit | same | Wave 0 |
| TOK-11 | `(tokenize "\"he\\\"llo\"")` → `:string("he\"llo")` (escape) | unit | same | Wave 0 |
| TOK-11 | Unterminated `"hello` signals `innate-parse-error` | unit | same | Wave 0 |
| TOK-12 | `(tokenize "42")` → `:number("42")` | unit | same | Wave 0 |
| TOK-13 | `(tokenize "entry")` → `:bare-word("entry")` | unit | same | Wave 0 |
| TOK-14 | `(tokenize "<emoji>")` → `:emoji-slot` with value `"<emoji>"` | unit | same | Wave 0 |
| TOK-15 | `(tokenize "decree")` → single `:decree` token | unit | same | Wave 0 |
| TOK-15 | `(tokenize "decrement")` → `:bare-word("decrement")` (not `:decree`) | unit | same | Wave 0 |
| TOK-16 | `(tokenize "[[Burg]]")` → single `:wikilink("Burg")` token | unit | same | Wave 0 |
| TOK-16 | `(tokenize "[[sylvia[cmd]]]")` → 3 `:lbracket` + `:bare-word` + ... | unit | same | Wave 0 |
| TOK-17 | Prose line emits single `:prose` token with full line text | unit | same | Wave 0 |
| TOK-17 | `decree foo` at line start is NOT prose | unit | same | Wave 0 |
| TOK-18 | All tokens carry correct `line`/`col` | unit | same | Wave 0 |
| TOK-18 | Second-line token has `line` = 2 | unit | same | Wave 0 |
| Integration | `(tokenize (file-string "burg_pipeline.dpn"))` completes without error | smoke | same | Wave 0 |

### Sampling Rate
- **Per task commit:** `sbcl --non-interactive --load tests/run-tests.lisp 2>&1 | grep -E "Results:|FAIL"`
- **Per wave merge:** `bash run-tests.sh`
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `tests/test-tokenizer.lisp` — covers all TOK-* requirements (does not exist yet)
- [ ] `tests/packages.lisp` — needs `innate.tests.tokenizer` defpackage added
- [ ] `innatescript.asd` — needs `test-tokenizer` component added to `innatescript/tests`
- [ ] `src/packages.lisp` — needs `innate.parser.tokenizer` exports filled in

---

## Sources

### Primary (HIGH confidence)
- `.planning/phases/03-tokenizer/03-CONTEXT.md` — all locked design decisions
- `.planning/REQUIREMENTS.md` — TOK-01 through TOK-18 requirement text
- `src/conditions.lisp` — `innate-parse-error` condition definition (Phase 2 artifact)
- `src/types.lisp` — `defstruct` constructor pattern used for `token` struct design
- `src/packages.lisp` — current package stubs, export gaps identified
- `tests/test-framework.lisp` — `deftest`/`assert-signals` macros available
- `dpn-lang-spec.md` — formal grammar, token vocabulary, wikilink disambiguation rule
- `burg_pipeline.dpn` — integration test input with real-world token diversity

### Secondary (MEDIUM confidence)
- `CLAUDE.md` (project) — AF64 zero-deps convention, SBCL as runtime, hand-rolled patterns

### Tertiary (LOW confidence)
- None — all findings derived from primary sources in the repository.

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all decisions locked in CONTEXT.md, derived from existing codebase patterns
- Architecture patterns: HIGH — all algorithmic logic is fully specified in CONTEXT.md; code examples follow established project patterns
- Pitfalls: HIGH — derived from direct analysis of the spec and codebase; no speculation
- Open questions: MEDIUM — edge cases identified from sample file vs. spec; require spec decision, not implementation uncertainty

**Research date:** 2026-03-28
**Valid until:** Stable until spec changes — no external dependencies to drift
