# Requirements: Innate

**Defined:** 2026-03-27
**Core Value:** A human unfamiliar with any programming language should be able to make a reasonable guess at what an Innate program does — and that same program should execute.

## v1 Requirements

### Tokenizer

- [ ] **TOK-01**: Tokenize all bracket types: `[`, `]`, `(`, `)`, `{`, `}`
- [ ] **TOK-02**: Tokenize `@name` as a reference token with the name extracted
- [ ] **TOK-03**: Tokenize `![]` as a search directive opener
- [ ] **TOK-04**: Tokenize `||` as the fulfillment operator
- [ ] **TOK-05**: Tokenize `->` as emission
- [ ] **TOK-06**: Tokenize `+word` as a combinator with the word extracted
- [ ] **TOK-07**: Tokenize `:` as colon (qualifier/kv separator)
- [ ] **TOK-08**: Tokenize `,` as comma (argument separator)
- [ ] **TOK-09**: Tokenize `#` at line start as heading with text extracted
- [ ] **TOK-10**: Tokenize `/word` as a presentation modifier
- [ ] **TOK-11**: Tokenize double-quoted string literals with escape support
- [ ] **TOK-12**: Tokenize integer number literals
- [ ] **TOK-13**: Tokenize bare words (identifiers)
- [ ] **TOK-14**: Tokenize `<emoji>` as emoji slot
- [ ] **TOK-15**: Tokenize `decree` as keyword
- [ ] **TOK-16**: Disambiguate `[[...]]` (wikilink) from nested brackets: scan forward from `[[` — if `]` is reached before any `[`, it's a wikilink; if `[` is hit first, it's nested brackets. `[[Burg]]` = wikilink, `[[sylvia[command]]]` = three bracket levels
- [ ] **TOK-17**: Detect prose lines (lines not starting with executable syntax) and emit as prose tokens
- [ ] **TOK-18**: Track line and column numbers on every token for error reporting

### Parser

- [ ] **PAR-01**: Parse `[context[verb[args]]]` nested bracket expressions
- [ ] **PAR-02**: Parse anonymous bracket depth — `[[["Hello"]]]` as a complete statement with three nesting levels
- [ ] **PAR-03**: Parse multiple top-level statements per file (multiple `[[[]]]` enclosures)
- [ ] **PAR-04**: Parse `(agent_name)` agent address expressions
- [ ] **PAR-05**: Parse `(agent){instruction}` agent-with-bundle commission
- [ ] **PAR-06**: Parse `{name}` bundle references
- [ ] **PAR-07**: Parse `{key:value}` lens expressions (filter/grouping)
- [ ] **PAR-08**: Parse `@name` direct references
- [ ] **PAR-09**: Parse `@name:qualifier` references with colon-separated natural-language qualifiers
- [ ] **PAR-10**: Parse `@type:"[[Burg]]"+all{state:==}` compound reference with type filter, combinator, and lens
- [ ] **PAR-11**: Parse `![search_expr]` search directives
- [ ] **PAR-12**: Parse `expr || (agent){instruction}` fulfillment expressions
- [ ] **PAR-13**: Parse `-> value [, value]*` emission statements
- [ ] **PAR-14**: Parse `decree name [body]` declarations
- [ ] **PAR-15**: Parse `key: value` key-value pairs inside brackets
- [ ] **PAR-16**: Parse `+word` combinators attached to expressions
- [ ] **PAR-17**: Parse `/modifier` presentation directives
- [ ] **PAR-18**: Parse `[[Title]]` wikilinks as AST nodes
- [ ] **PAR-19**: Parse `# text` headings as AST nodes
- [ ] **PAR-20**: Parse prose lines as first-class AST nodes (not discarded)
- [ ] **PAR-21**: Parse block bodies with purposive sequencing (multiple operations in a named bracket)
- [ ] **PAR-22**: Produce typed AST using `defstruct` nodes with kind, value, children, props

### Evaluator

- [ ] **EVL-01**: Two-pass evaluation: pass 1 collects all decree definitions (hoisting), pass 2 evaluates
- [ ] **EVL-02**: `@` references resolve against decrees first (any position in script), then fall through to resolver. `@` is a soft/indirect reference (hoisted, can be local). `[[]]` always goes straight to the resolver (hard link to the substrate).
- [ ] **EVL-03**: Evaluate bracket expressions by calling `resolve-context` on the resolver
- [ ] **EVL-04**: Evaluate `(agent){instruction}` by calling `deliver-commission` on the resolver
- [ ] **EVL-05**: Evaluate `![search]` by calling `resolve-search` on the resolver
- [ ] **EVL-06**: Evaluate `expr || (agent){instruction}` — try left side, if resistance, fire right side commission
- [ ] **EVL-07**: Evaluate `-> values` emission — return values to caller
- [ ] **EVL-08**: Evaluate `decree` — register in environment, make available to `@` references
- [ ] **EVL-09**: Evaluate `[[Title]]` wikilinks by calling `resolve-wikilink` on the resolver
- [ ] **EVL-10**: Evaluate `{bundle_name}` by calling `load-bundle` on the resolver
- [ ] **EVL-11**: Pass through prose and headings as rendered text
- [ ] **EVL-12**: Pass through presentation directives (`#header`, `/modifier`) as part of rendered output
- [ ] **EVL-13**: Carry evaluation context (query/scope/render/commission) as an argument through all dispatch
- [ ] **EVL-14**: Use `etypecase` for internal AST dispatch, not CLOS methods
- [ ] **EVL-15**: Propagate resistance upward through bracket nesting for unresolvable references with no fulfillment

### Resolver Protocol

- [ ] **RES-01**: Define `resolve-reference` generic function (name, qualifiers -> result or resistance)
- [ ] **RES-02**: Define `resolve-search` generic function (search-type, terms -> result or resistance)
- [ ] **RES-03**: Define `deliver-commission` generic function (agent-name, instruction -> result)
- [ ] **RES-04**: Define `resolve-wikilink` generic function (title -> result or resistance)
- [ ] **RES-05**: Define `resolve-context` generic function (context, verb, args -> result or resistance)
- [ ] **RES-06**: Define `load-bundle` generic function (name -> AST or nil)
- [ ] **RES-07**: Default methods on base `resolver` class return resistance
- [ ] **RES-08**: Stub resolver with in-memory entity store for testing
- [ ] **RES-09**: Stub resolver records commissions for test assertions
- [ ] **RES-10**: Stub resolver resolves `@` references with qualifier chains against plist entities

### Error Model

- [ ] **ERR-01**: Define `innate-resistance` condition for structural failures (reference cannot resolve, no fulfillment)
- [ ] **ERR-02**: Define `innate-parse-error` condition for syntax errors with line/col
- [ ] **ERR-03**: Resistance is a condition, not an error — it signals, not raises
- [ ] **ERR-04**: Fulfillment converts resistance into commission (the `||` operator)

### REPL and Runner

- [ ] **RUN-01**: Interactive REPL with `read-line` loop and `handler-case` error recovery
- [ ] **RUN-02**: File execution: parse and evaluate a `.dpn` file
- [ ] **RUN-03**: Shell script `run-tests.sh` that loads system, runs all tests, exits with pass/fail code
- [ ] **RUN-04**: Shell script `run-repl.sh` that loads system and starts REPL (or runs a file if argument given)
- [x] **RUN-05**: ASDF cold-load test: wipe fasl cache, full `asdf:load-system`, verify clean load

### Project Structure

- [x] **PRJ-01**: ASDF system definition with explicit `:depends-on` per component (not `:serial t`)
- [x] **PRJ-02**: Single `packages.lisp` with all `defpackage` forms using `:import-from` (not `:use`)
- [x] **PRJ-03**: Zero external dependencies
- [x] **PRJ-04**: Hand-rolled test framework (deftest, assert-equal, assert-true, run-tests)
- [ ] **PRJ-05**: Integration test that parses and evaluates `burg_pipeline.dpn`

## v2 Requirements

### Laptop CLI

- **CLI-01**: `innate eval '<expression>'` — one-shot evaluation via dpn-api
- **CLI-02**: `innate push script.dpn` — register script on droplet
- **CLI-03**: `innate watch` — live-push on file save during development

### Advanced Language Features

- **ADV-01**: Chained fulfillment: `![...] || (a){...} || (b){escalate}`
- **ADV-02**: Template parameters — explicit syntax for binding free variables
- **ADV-03**: Multi-line REPL input for decree blocks
- **ADV-04**: Inward flow operator `<-` for explicit binding

### Integration

- **INT-01**: `/api/innate/eval` endpoint in dpn-api
- **INT-02**: `/api/innate/register` endpoint for script persistence
- **INT-03**: `innate_scripts` table in master_chronicle

## Out of Scope

| Feature | Reason |
|---------|--------|
| Noosphere resolver | Private, lives in project-noosphere-ghosts — connects Innate to the substrate and ghosts |
| General-purpose control flow (if/else, loops) | Violates "language of intention" design — agents decide, not scripts |
| Exception-based error handling (try/catch) | Resistance + fulfillment is the error model |
| External Lisp library dependencies | AF64 convention: zero deps |
| Hardcoded infrastructure references | Public repo, generic interpreter |
| Debugger / step-through | Correct but premature for v1 |
| LSP / editor integration | Correct but premature for v1 |
| Metacircular evaluator | The dream, not v1 |
| dpn-tui rewrite | Depends on working interpreter + noosphere resolver |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| PRJ-01 | Phase 1 | Complete |
| PRJ-02 | Phase 1 | Complete |
| PRJ-03 | Phase 1 | Complete |
| PRJ-04 | Phase 1 | Complete |
| RUN-05 | Phase 1 | Complete |
| ERR-01 | Phase 2 | Pending |
| ERR-02 | Phase 2 | Pending |
| ERR-03 | Phase 2 | Pending |
| PAR-22 | Phase 2 | Pending |
| TOK-01 | Phase 3 | Pending |
| TOK-02 | Phase 3 | Pending |
| TOK-03 | Phase 3 | Pending |
| TOK-04 | Phase 3 | Pending |
| TOK-05 | Phase 3 | Pending |
| TOK-06 | Phase 3 | Pending |
| TOK-07 | Phase 3 | Pending |
| TOK-08 | Phase 3 | Pending |
| TOK-09 | Phase 3 | Pending |
| TOK-10 | Phase 3 | Pending |
| TOK-11 | Phase 3 | Pending |
| TOK-12 | Phase 3 | Pending |
| TOK-13 | Phase 3 | Pending |
| TOK-14 | Phase 3 | Pending |
| TOK-15 | Phase 3 | Pending |
| TOK-16 | Phase 3 | Pending |
| TOK-17 | Phase 3 | Pending |
| TOK-18 | Phase 3 | Pending |
| PAR-01 | Phase 4 | Pending |
| PAR-02 | Phase 4 | Pending |
| PAR-03 | Phase 4 | Pending |
| PAR-04 | Phase 4 | Pending |
| PAR-05 | Phase 4 | Pending |
| PAR-06 | Phase 4 | Pending |
| PAR-07 | Phase 4 | Pending |
| PAR-08 | Phase 4 | Pending |
| PAR-09 | Phase 4 | Pending |
| PAR-10 | Phase 4 | Pending |
| PAR-11 | Phase 4 | Pending |
| PAR-12 | Phase 4 | Pending |
| PAR-13 | Phase 4 | Pending |
| PAR-14 | Phase 4 | Pending |
| PAR-15 | Phase 4 | Pending |
| PAR-16 | Phase 4 | Pending |
| PAR-17 | Phase 4 | Pending |
| PAR-18 | Phase 4 | Pending |
| PAR-19 | Phase 4 | Pending |
| PAR-20 | Phase 4 | Pending |
| PAR-21 | Phase 4 | Pending |
| RES-01 | Phase 5 | Pending |
| RES-02 | Phase 5 | Pending |
| RES-03 | Phase 5 | Pending |
| RES-04 | Phase 5 | Pending |
| RES-05 | Phase 5 | Pending |
| RES-06 | Phase 5 | Pending |
| RES-07 | Phase 5 | Pending |
| EVL-13 | Phase 5 | Pending |
| RES-08 | Phase 6 | Pending |
| RES-09 | Phase 6 | Pending |
| RES-10 | Phase 6 | Pending |
| EVL-01 | Phase 7 | Pending |
| EVL-02 | Phase 7 | Pending |
| EVL-03 | Phase 7 | Pending |
| EVL-08 | Phase 7 | Pending |
| EVL-11 | Phase 7 | Pending |
| EVL-12 | Phase 7 | Pending |
| EVL-14 | Phase 7 | Pending |
| EVL-15 | Phase 7 | Pending |
| EVL-04 | Phase 8 | Pending |
| EVL-05 | Phase 8 | Pending |
| EVL-06 | Phase 8 | Pending |
| EVL-07 | Phase 8 | Pending |
| EVL-09 | Phase 8 | Pending |
| EVL-10 | Phase 8 | Pending |
| ERR-04 | Phase 8 | Pending |
| RUN-01 | Phase 9 | Pending |
| RUN-02 | Phase 9 | Pending |
| RUN-03 | Phase 9 | Pending |
| RUN-04 | Phase 9 | Pending |
| PRJ-05 | Phase 9 | Pending |

**Coverage:**
- v1 requirements: 79 total (note: REQUIREMENTS.md previously stated 74 — recount of actual listed requirements is 79)
- Mapped to phases: 79
- Unmapped: 0

---
*Requirements defined: 2026-03-27*
*Last updated: 2026-03-27 after roadmap creation — all requirements mapped*
