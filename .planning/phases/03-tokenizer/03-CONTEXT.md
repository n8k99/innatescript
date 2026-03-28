# Phase 3: Tokenizer - Context

**Gathered:** 2026-03-28
**Status:** Ready for planning

<domain>
## Phase Boundary

Any valid Innate source text can be converted to a typed, positioned token stream with no ambiguity on wikilinks vs. nested brackets. The tokenizer reads `.dpn` source strings and emits a list of token structs. The parser (Phase 4) consumes these tokens — this phase does not build AST nodes.

</domain>

<decisions>
## Implementation Decisions

### Token representation
- `defstruct token` with four slots: `type` (keyword), `value` (string or number), `line` (integer), `col` (integer)
- Token types are keywords: `:lbracket`, `:rbracket`, `:lparen`, `:rparen`, `:lbrace`, `:rbrace`, `:at`, `:bang-bracket`, `:pipe-pipe`, `:arrow`, `:plus`, `:colon`, `:comma`, `:hash`, `:slash`, `:string`, `:number`, `:bare-word`, `:emoji-slot`, `:decree`, `:wikilink`, `:prose`, `:newline`
- Separate struct from AST `node` — tokens are flat positional data, nodes are trees. The parser converts tokens to nodes.
- Constructor: `make-token &key type value line col`
- Exported from `innate.parser.tokenizer`: `make-token`, `token-type`, `token-value`, `token-line`, `token-col`, `tokenize` (the main entry point, takes a string, returns list of tokens)

### Whitespace and newline handling
- Spaces and tabs between tokens on the same line are consumed silently (not emitted)
- Newlines emit a `:newline` token — the parser needs line boundaries for prose detection, heading recognition, and `->` statement parsing
- Consecutive newlines collapse to a single `:newline` token (blank lines are not semantically meaningful)
- Indentation whitespace at line start is consumed before examining the first significant character

### Prose line detection
- A line is prose if its first non-whitespace character is NOT one of: `[`, `(`, `{`, `@`, `!`, `#`, `/`, `>`, `-` (for `->`)`, `d` (for `decree`)
- Special case: a line starting with `decree` keyword is executable, not prose
- Special case: a line starting with `->` is emission, not prose
- Lines starting with bare words that are NOT `decree` are prose — bare words only appear as tokens inside bracket/paren/brace expressions, never as standalone executable statements
- The tokenizer emits the entire line content as a single `:prose` token with the text in `value`
- Prose detection happens at line-start only — once an executable sigil is found, the rest of the line tokenizes normally

### Wikilink disambiguation (from TOK-16, locked)
- On encountering `[[`: scan forward character by character
- If `]` is reached before any `[`: this is a wikilink — emit `:wikilink` token with the inner text as value
- If `[` is reached first: this is nested brackets — emit two `:lbracket` tokens and continue normal tokenization
- `[[Burg]]` → one `:wikilink` token with value `"Burg"`
- `[[sylvia[command]]]` → `:lbracket`, `:lbracket`, `:bare-word("sylvia")`, `:lbracket`, `:bare-word("command")`, `:rbracket`, `:rbracket`, `:rbracket`

### String literals
- Double-quoted only, no single quotes
- Escape sequences: `\"` (literal quote), `\\` (literal backslash) — minimal set, not C-style
- Wikilinks inside strings (`"[[Burg]]"`) are preserved as literal text in the string value — the parser or evaluator handles wikilink-in-string semantics, not the tokenizer

### Number literals
- Integers only (no floats, no negative sign as part of the number token)
- Sequence of `[0-9]+` — no underscore separators, no hex/octal

### Error handling
- Unterminated string → signal `innate-parse-error` with line/col of the opening quote
- Unexpected character → signal `innate-parse-error` with line/col
- The tokenizer never returns partial results — it either succeeds with a complete token list or signals a condition

### Main entry point
- `(tokenize source-string)` → list of `token` structs
- Input is always a string (file reading happens upstream)
- No stream/lazy behavior — full eager tokenization. Innate scripts are small (human-written intention documents, not generated code)

### Claude's Discretion
- Internal helper function organization (char-classification predicates, etc.)
- Buffer management for accumulating multi-character tokens
- Exact test case selection beyond the spec-mandated vocabulary coverage

</decisions>

<specifics>
## Specific Ideas

- The `![]` search directive opener is a two-character token — `!` followed by `[`. The `!` alone is not a valid token in Innate.
- `<emoji>` is a literal seven-character sequence, not a Unicode emoji. It's a type annotation placeholder.
- The `+` combinator token is `+` followed by a bare word — but the tokenizer emits them as separate tokens (`:plus` then `:bare-word`). Combining them is the parser's job.
- `/modifier` similarly emits as `:slash` then `:bare-word` — the parser combines.

</specifics>

<canonical_refs>
## Canonical References

### Language design
- `dpn-lang-spec.md` — Full symbol vocabulary (§Core Syntax), formal grammar (§Formal Grammar), type table (§Types), wikilink disambiguation rule
- `dpn-lang-spec.md` §Formal Grammar — BNF-style grammar defining `bare_word`, `number`, `string`, `wikilink`, `emoji_slot` productions

### Phase 2 artifacts (upstream dependencies)
- `src/types.lisp` — 20 `+node-*+` constants defining the AST node vocabulary the parser will build from tokens
- `src/conditions.lisp` — `innate-parse-error` condition with `line`/`col` slots used for tokenizer error reporting
- `src/packages.lisp` — Current package definitions; `innate.parser.tokenizer` exports need filling

### Sample programs
- `burg_pipeline.dpn` — Real `.dpn` file exercising brackets, wikilinks, bare words, strings, emoji slots, `@` references, `/` modifiers, `#` headings

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `innate-parse-error` condition (Phase 2) — signal with `line`/`col` on tokenizer errors
- `tests/test-framework.lisp` — `deftest`, `assert-equal`, `assert-true`, `assert-signals` all available
- `burg_pipeline.dpn` — integration test input for tokenizer smoke test

### Established Patterns
- `defstruct` with `(:constructor make-X (&key ...))` pattern from `types.lisp`
- Package exports defined in `packages.lisp`, implementation in module file
- Tests in `tests/` with dedicated package (`innate.tests.tokenizer`)

### Integration Points
- `innate.parser.tokenizer` package exists as stub — needs exports added to `packages.lisp`
- `src/parser/tokenizer.lisp` is the implementation file — already registered in ASDF
- `innate.parser` imports from `innate.parser.tokenizer` — parser will consume token structs directly

</code_context>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 03-tokenizer*
*Context gathered: 2026-03-28*
