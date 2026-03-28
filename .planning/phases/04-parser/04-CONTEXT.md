# Phase 4: Parser - Context

**Gathered:** 2026-03-28
**Status:** Ready for planning

<domain>
## Phase Boundary

Any tokenized Innate source produces a typed AST where prose is a first-class node, all infix operators have correct left-associativity, and compound expressions like `@type:"[[Burg]]"+all{state:==}` parse completely. The parser consumes token lists from `(tokenize source)` and returns a `:program` node whose children are the top-level statements.

</domain>

<decisions>
## Implementation Decisions

### Precedence hierarchy (tightest to loosest)

The recursive descent function call chain reflects precedence:

1. **Atoms** (tightest) — `:bare-word`, `:string`, `:number`, `:wikilink`, `:emoji-slot`
2. **Primary expressions** — `@name`, `(agent)`, `{bundle}`, `![search]`, `[bracket]`, `#heading`
3. **Postfix chains on references** — `:qualifier`, `+combinator`, `{lens}` — these attach left-to-right onto a reference expression, producing a single compound `:reference` node
4. **Presentation modifiers** — `/modifier` attaches to preceding expression
5. **Emission** — `-> value, value` (left-associative per success criteria)
6. **Fulfillment** (loosest) — `expr || (agent){instruction}` — binary only in v1

This means `@type:"[[Burg]]"+all{state:==}` parses as one `:reference` node with qualifier, combinator, and lens as children — not as nested binary operations.

### Compound reference node structure

`@type:"[[Burg]]"+all{state:==}` produces:

```
(:reference
  :value "type"
  :children (
    (:string-lit :value "[[Burg]]")    ; qualifier value
    (:combinator :value "all")
    (:lens :children ((:kv-pair :value "state" :children ((:bare-word :value "==")))))
  )
  :props (:qualifiers ("[[Burg]]") :combinator "all"))
```

Qualifiers go in both `children` (for tree-walking) and `props` (for quick evaluator access). The `:` after `@name` triggers qualifier parsing. The `+` after a reference triggers combinator parsing. The `{` after a reference triggers lens parsing. All three are optional postfix extensions.

### Bracket body parsing (purposive sequencing)

Inside `[...]`, the parser reads a sequence of heterogeneous statements as children of the `:bracket` node, in source order. No separation of kv-pairs from nested expressions — everything is a child.

The bracket body loop recognizes:
- `bare-word COLON` → parse as `:kv-pair` (key is the bare-word, value is the expression after colon)
- `LBRACKET` → nested bracket expression (recursive)
- `HASH` → heading/presentation directive
- `AT` → reference expression
- `BANG-BRACKET` → search directive
- `ARROW` → emission statement
- `PROSE` token → `:prose` node (preserved as-is, including list items like `- "<emoji> Seed"`)
- `DECREE` → decree declaration
- Any other expression → parse as expression

Bracket body terminates at matching `RBRACKET`.

### Colon disambiguation

- `bare-word COLON` at bracket-body level → kv-pair (the colon separates key from value)
- `AT bare-word COLON` → reference with qualifier (the colon attaches a qualifier to `@name`)
- Rule: if a lone `bare-word` is immediately followed by `:`, it's a kv-pair. If `@name` is followed by `:`, it's a qualifier chain. Context-free — no lookahead beyond one token needed.

### Fulfillment operator

- `||` is binary only in v1 — `left || right`
- The parser left-associates if multiple `||` appear (builds the tree structure), but the evaluator only handles one level. This is forward-compatible with ADV-01 (chained fulfillment in v2).
- `||` binds looser than everything else except top-level statement boundaries.

### Emission operator

- `->` is left-associative: `a -> b -> c` → `(-> (-> a b) c)`
- `-> value, value` — the comma separates multiple emission values. The `:emission` node's `children` are the emitted values.
- `->` binds tighter than `||` but looser than reference postfix chains.

### Comparison operators inside lenses

- `{state:==}` means "filter where state fields are equal"
- `==` is a value/operator inside lenses — the parser treats the RHS of `key:` in a lens as a generic expression (bare-word, string, number, or operator-word like `==`)
- No hardcoded operator set — the parser emits whatever token appears as a `:bare-word` node. The evaluator interprets operator semantics.
- This keeps the parser permissive. Ghosts internalize the grammar codebook and know what operators mean.

### Search directive body

- `![expr]` — after `BANG-BRACKET`, parse an expression list until `RBRACKET`
- The expression inside can be a function-call-like syntax: `image("emblem"+burg_name + png)`
- Parser treats the inside as a sequence of expressions (bare-words, strings, combinators) — children of the `:search` node
- Parenthesized arguments inside search (`(...)`) parse as agent-address or argument-list depending on context

### Agent commission

- `(agent_name)` alone → `:agent` node with `value` = name
- `(agent){instruction}` → the parser sees `:agent` followed by `{...}` → wraps in a commission. The commission is not a separate node kind — it's `(agent)` followed by `{bundle}` which the evaluator interprets as a commission. Alternatively: create a synthetic grouping at parse time.
- Decision: parser emits `(agent)` and `{instruction}` as siblings. The evaluator recognizes the `agent + bundle` adjacency pattern. This keeps the parser simple and the evaluator responsible for semantic grouping.

### Decree parsing

- `decree name [body]` → `:decree` node with `value` = name, `children` = body contents
- Body is optional — `decree name` alone is valid (forward declaration)
- Body is enclosed in brackets: `decree routing_rules [...]`

### Top-level statement list

- A `.dpn` file is a sequence of top-level statements separated by newlines
- The parser consumes `:newline` tokens as statement separators (not emitted as nodes)
- Top-level statements: prose lines, headings, bracket expressions, decree declarations, reference expressions, emission statements, search directives
- The `:program` node's children are all top-level statements in source order

### Error handling

- On unexpected token: signal `innate-parse-error` with line/col from the token
- No partial AST recovery — parse either succeeds completely or signals
- Error messages should reference the token type and position, not internal parser state
- The parser imports `innate-parse-error` from `innate.conditions` (already available)

### Parser permissiveness

- The parser should be structurally permissive — build valid trees for anything that's syntactically well-formed, even if the evaluator won't know what to do with it
- Ghosts will have the grammar codebook and speak Innate natively. The parser's job is to build the tree; meaning lives in the evaluator and resolver.
- Templates in the noosphere will contain `[[[]]]` statements in specific sections as process rules. The parser must handle arbitrary nesting depth without artificial limits.

### Claude's Discretion

- Exact recursive descent function naming and decomposition
- Whether to use a token-cursor struct or pass index + token-list
- Test case selection beyond the 5 success criteria
- Internal helper organization

</decisions>

<specifics>
## Specific Ideas

- `burg_pipeline.dpn` exercises: nested brackets 3 deep, kv-pairs, wikilinks-as-values, heading inside brackets, search with combinator and presentation modifier, prose list items. It is the integration test target.
- `@Alaran:generative hard prompt` — the qualifier after `:` is a multi-word bare sequence. The parser needs to accumulate bare-words after the qualifier colon until hitting a token that ends the qualifier (like `+`, `{`, `]`, `)`, newline).
- `![image("emblem"+burg_name + png)]/wrapLef` — search directive with modifier attached. The `/wrapLef` is a presentation modifier on the search result.
- Ghost templates will have deeply nested bracket structures. No depth limit in the parser.

</specifics>

<canonical_refs>
## Canonical References

### Language design
- `dpn-lang-spec.md` — Full symbol vocabulary (Core Syntax section), formal grammar (BNF productions), expression examples
- `dpn-lang-spec.md` Formal Grammar section — BNF for `expression`, `bracket_expr`, `reference`, `search_directive`, `fulfillment`, `emission`, `decree`

### Phase 2 artifacts (AST node definitions)
- `src/types.lisp` — 20 `+node-*+` constants, universal `node` defstruct with `kind`/`value`/`children`/`props`
- `src/conditions.lisp` — `innate-parse-error` condition with `line`/`col` slots

### Phase 3 artifacts (token stream)
- `src/parser/tokenizer.lisp` — `tokenize` function, 23 token types, `token` defstruct
- `.planning/phases/03-tokenizer/03-CONTEXT.md` — Token type vocabulary, prose detection rules, wikilink disambiguation

### Sample programs
- `burg_pipeline.dpn` — Integration test target exercising nested brackets, kv-pairs, wikilinks, headings, search, modifiers, prose list items

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `innate.parser.tokenizer:tokenize` — returns list of token structs, the parser's input
- `innate.parser.tokenizer:token-type`, `token-value`, `token-line`, `token-col` — accessors for reading tokens
- `innate.types:make-node` — constructor for all AST nodes
- `innate.types:+node-*+` — 20 node kind constants
- `innate.conditions:innate-parse-error` — signal on parse errors with line/col
- `tests/test-framework.lisp` — `deftest`, `assert-equal`, `assert-true`, `assert-signals`

### Established Patterns
- Token struct: `defstruct (token (:constructor make-token (&key type value line col)))`
- Node struct: `defstruct (node (:constructor make-node (&key kind value children props)))`
- Package exports in `packages.lisp`, implementation in module file
- Tests in `tests/` with dedicated package (`innate.tests.parser`)

### Integration Points
- `innate.parser` package exists as stub — needs imports from `innate.parser.tokenizer` and `innate.types` added to `packages.lisp`
- `src/parser/parser.lisp` is the implementation file — registered in ASDF as stub
- Parser entry point: `(parse token-list)` → `:program` node
- Downstream: `innate.eval` will call `(parse (tokenize source))` and walk the resulting AST

</code_context>

<deferred>
## Deferred Ideas

- Chained fulfillment `a || b || c` with escalation semantics — v2 (ADV-01). Parser left-associates now, evaluator handles in v2.
- Template parameter binding (`@burg_name` receiving values) — v2 (ADV-02). Parser treats as normal `@` reference.
- Inward flow operator `<-` — v2 (ADV-04). Not tokenized or parsed in v1.

</deferred>

---

*Phase: 04-parser*
*Context gathered: 2026-03-28*
