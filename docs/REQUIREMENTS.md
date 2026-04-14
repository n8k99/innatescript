---
title: Innatescript Requirements
type: "[[Project]]"
icon: 📋
Lifestage: 🌱 Seed
status: active
owner: ""
domain: "[[The Work]]"
repository: ""
project_number:
description: ""
visibility: private
started:
target_completion:
completed:
created:
updated:
tags: []
project: "[[InnateScript]]"
total: 98
complete: 79
pending: 19
---
# Requirements: Innate

**Defined:** 2026-03-27
**Core Value:** A human unfamiliar with any programming language should be able to make a reasonable guess at what an Innate program does — and that same program should execute.

## v1 Requirements

### Tokenizer

- [x] **TOK-01**: Tokenize all bracket types: `[`, `]`, `(`, `)`, `{`, `}`
- [x] **TOK-02**: Tokenize `@name` as a reference token with the name extracted
- [x] **TOK-03**: Tokenize `![]` as a search directive opener
- [x] **TOK-04**: Tokenize `||` as the fulfillment operator
- [x] **TOK-05**: Tokenize `->` as emission
- [x] **TOK-06**: Tokenize `+word` as a combinator with the word extracted
- [x] **TOK-07**: Tokenize `:` as colon (qualifier/kv separator)
- [x] **TOK-08**: Tokenize `,` as comma (argument separator)
- [x] **TOK-09**: Tokenize `#` at line start as heading with text extracted
- [x] **TOK-10**: Tokenize `/word` as a presentation modifier
- [x] **TOK-11**: Tokenize double-quoted string literals with escape support
- [x] **TOK-12**: Tokenize integer number literals
- [x] **TOK-13**: Tokenize bare words (identifiers)
- [x] **TOK-14**: Tokenize `<emoji>` as emoji slot
- [x] **TOK-15**: Tokenize `decree` as keyword
- [x] **TOK-16**: Disambiguate `[[]]` (wikilink) from nested brackets: scan forward from `[[` — if `]` is reached before any `[`, it's a wikilink; if `[` is hit first, it's nested brackets. `[[Burg]]` = wikilink, `sylvia[command]` = three bracket levels
- [x] **TOK-17**: Detect prose lines (lines not starting with executable syntax) and emit as prose tokens
- [x] **TOK-18**: Track line and column numbers on every token for error reporting

### Parser

- [x] **PAR-01**: Parse `[context[verb[args]]]` nested bracket expressions
- [x] **PAR-02**: Parse anonymous bracket depth — `["Hello"]` as a complete statement with three nesting levels
- [x] **PAR-03**: Parse multiple top-level statements per file (multiple `[[]]]` enclosures)
- [x] **PAR-04**: Parse `(agent_name)` agent address expressions
- [x] **PAR-05**: Parse `(agent){instruction}` agent-with-bundle commission
- [x] **PAR-06**: Parse `{name}` bundle references
- [x] **PAR-07**: Parse `{key:value}` lens expressions (filter/grouping)
- [x] **PAR-08**: Parse `@name` direct references
- [x] **PAR-09**: Parse `@name:qualifier` references with colon-separated natural-language qualifiers
- [x] **PAR-10**: Parse `@type:"[[Burg]]"+all{state:==}` compound reference with type filter, combinator, and lens
- [x] **PAR-11**: Parse `![search_expr]` search directives
- [x] **PAR-12**: Parse `expr || (agent){instruction}` fulfillment expressions
- [x] **PAR-13**: Parse `-> value [, value]*` emission statements
- [x] **PAR-14**: Parse `decree name [body]` declarations
- [x] **PAR-15**: Parse `key: value` key-value pairs inside brackets
- [x] **PAR-16**: Parse `+word` combinators attached to expressions
- [x] **PAR-17**: Parse `/modifier` presentation directives
- [x] **PAR-18**: Parse `Title` wikilinks as AST nodes
- [x] **PAR-19**: Parse `# text` headings as AST nodes
- [x] **PAR-20**: Parse prose lines as first-class AST nodes (not discarded)
- [x] **PAR-21**: Parse block bodies with purposive sequencing (multiple operations in a named bracket)
- [x] **PAR-22**: Produce typed AST using `defstruct` nodes with kind, value, children, props

### Evaluator

- [x] **EVL-01**: Two-pass evaluation: pass 1 collects all decree definitions (hoisting), pass 2 evaluates
- [x] **EVL-02**: `@` references resolve against decrees first (any position in script), then fall through to resolver. `@` is a soft/indirect reference (hoisted, can be local). `[[]]` always goes straight to the resolver (hard link to the substrate).
- [x] **EVL-03**: Evaluate bracket expressions by calling `resolve-context` on the resolver
- [x] **EVL-04**: Evaluate `(agent){instruction}` by calling `deliver-commission` on the resolver
- [x] **EVL-05**: Evaluate `![search]` by calling `resolve-search` on the resolver
- [x] **EVL-06**: Evaluate `expr || (agent){instruction}` — try left side, if resistance, fire right side commission
- [x] **EVL-07**: Evaluate `-> values` emission — return values to caller
- [x] **EVL-08**: ~~Evaluate `decree`~~ — **Superseded.** Named bracket expressions replace `decree`. v1.0 implements decrees; named bracket replacement is a choreographic-era migration (see CHR-08).
- [x] **EVL-09**: Evaluate `Title` wikilinks by calling `resolve-wikilink` on the resolver
- [x] **EVL-10**: Evaluate `{bundle_name}` by calling `load-bundle` on the resolver
- [x] **EVL-11**: Pass through prose and headings as rendered text
- [x] **EVL-12**: Pass through presentation directives (`#header`, `/modifier`) as part of rendered output
- [x] **EVL-13**: Carry evaluation context (query/scope/render/commission) as an argument through all dispatch
- [x] **EVL-14**: Use `etypecase` for internal AST dispatch, not CLOS methods
- [x] **EVL-15**: Propagate resistance upward through bracket nesting for unresolvable references with no fulfillment

### Resolver Protocol

- [x] **RES-01**: Define `resolve-reference` generic function (name, qualifiers -> result or resistance)
- [x] **RES-02**: Define `resolve-search` generic function (search-type, terms -> result or resistance)
- [x] **RES-03**: Define `deliver-commission` generic function (agent-name, instruction -> result)
- [x] **RES-04**: Define `resolve-wikilink` generic function (title -> result or resistance)
- [x] **RES-05**: Define `resolve-context` generic function (context, verb, args -> result or resistance)
- [x] **RES-06**: Define `load-bundle` generic function (name -> AST or nil)
- [x] **RES-07**: Default methods on base `resolver` class return resistance
- [x] **RES-08**: Stub resolver with in-memory entity store for testing
- [x] **RES-09**: Stub resolver records commissions for test assertions
- [x] **RES-10**: Stub resolver resolves `@` references with qualifier chains against plist entities

### Error Model

- [x] **ERR-01**: Define `innate-resistance` condition for structural failures (reference cannot resolve, no fulfillment)
- [x] **ERR-02**: Define `innate-parse-error` condition for syntax errors with line/col
- [x] **ERR-03**: Resistance is a condition, not an error — it signals, not raises
- [x] **ERR-04**: Fulfillment converts resistance into commission (the `||` operator)

### Choreographic Semantics (April 2026)

- [ ] **CHR-01**: Verification operator `<-` — sends prior stage output to verifying agent, returns corrections before advancing
- [ ] **CHR-02**: `concurrent` keyword — evaluate contained expressions in parallel
- [ ] **CHR-03**: `join` keyword — synchronization barrier, wait for all concurrent branches (timing only)
- [ ] **CHR-04**: `until` postfix — time-bounded or condition-bounded agent obligation
- [ ] **CHR-05**: `until` block — time-bounded choreographic context bounding all contained agents
- [ ] **CHR-06**: `sync` keyword — side-channel expression that runs alongside main flow without blocking
- [ ] **CHR-07**: `at` keyword — absolute (wikilink date) or relative (duration) temporal trigger
- [ ] **CHR-08**: Three-bracket nesting limit — enforce maximum depth of three; deeper expressions must extract as named markdown documents
- [ ] **CHR-09**: Projection — evaluator decomposes global choreography into per-agent local slices
- [ ] **CHR-10**: `<-` nests inside `concurrent` blocks for parallel verification against multiple facets
- [ ] **CHR-11**: Agent identity — `(@name)` and `@name` are semantically identical; no separate agent type

### Evaluator (Choreographic Extensions)

- [ ] **EVL-16**: Evaluate `<- @agent{instruction}` — route verification to agent, apply corrections to prior output
- [ ] **EVL-17**: Evaluate `concurrent [...]` — dispatch contained expressions in parallel
- [ ] **EVL-18**: Evaluate `join` — block until all concurrent branches complete
- [ ] **EVL-19**: Evaluate `until` (postfix and block forms) — enforce time/condition bounds with optional `||` fulfillment on expiry
- [ ] **EVL-20**: Evaluate `sync` — launch side-channel expression without blocking main flow
- [ ] **EVL-21**: Evaluate `at` — schedule expression for future evaluation at specified time

### Resolver Protocol (Choreographic Extensions)

- [ ] **RES-11**: Define `deliver-verification` generic function (agent-name, prior-output -> corrections)
- [ ] **RES-12**: Define `schedule-at` generic function (time, expression -> handle) for temporal triggers

### REPL and Runner

- [x] **RUN-01**: Interactive REPL with `read-line` loop and `handler-case` error recovery
- [x] **RUN-02**: File execution: parse and evaluate a `.dpn` file
- [x] **RUN-03**: Shell script `run-tests.sh` that loads system, runs all tests, exits with pass/fail code
- [x] **RUN-04**: Shell script `run-repl.sh` that loads system and starts REPL (or runs a file if argument given)
- [x] **RUN-05**: ASDF cold-load test: wipe fasl cache, full `asdf:load-system`, verify clean load

### Project Structure

- [x] **PRJ-01**: ASDF system definition with explicit `:depends-on` per component (not `:serial t`)
- [x] **PRJ-02**: Single `packages.lisp` with all `defpackage` forms using `:import-from` (not `:use`)
- [x] **PRJ-03**: Zero external dependencies
- [x] **PRJ-04**: Hand-rolled test framework (deftest, assert-equal, assert-true, run-tests)
- [x] **PRJ-05**: Integration test that parses and evaluates `burg_pipeline.dpn`

## v2 Requirements

### Laptop CLI

- **CLI-01**: `innate eval '<expression>'` — one-shot evaluation via dpn-api
- **CLI-02**: `innate push script.dpn` — register script on droplet
- **CLI-03**: `innate watch` — live-push on file save during development

### Advanced Language Features

- **ADV-01**: Chained fulfillment: `![...] || (a){...} || (b){escalate}`
- **ADV-02**: Template parameters — explicit syntax for binding free variables
- **ADV-03**: Multi-line REPL input for decree blocks
- ~~**ADV-04**: Inward flow operator `<-` for explicit binding~~ — **Promoted to core.** See EVL-16, RES-11, CHR-* below.

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
| ERR-01 | Phase 2 | Complete |
| ERR-02 | Phase 2 | Complete |
| ERR-03 | Phase 2 | Complete |
| PAR-22 | Phase 2 | Complete |
| TOK-01 | Phase 3 | Complete |
| TOK-02 | Phase 3 | Complete |
| TOK-03 | Phase 3 | Complete |
| TOK-04 | Phase 3 | Complete |
| TOK-05 | Phase 3 | Complete |
| TOK-06 | Phase 3 | Complete |
| TOK-07 | Phase 3 | Complete |
| TOK-08 | Phase 3 | Complete |
| TOK-09 | Phase 3 | Complete |
| TOK-10 | Phase 3 | Complete |
| TOK-11 | Phase 3 | Complete |
| TOK-12 | Phase 3 | Complete |
| TOK-13 | Phase 3 | Complete |
| TOK-14 | Phase 3 | Complete |
| TOK-15 | Phase 3 | Complete |
| TOK-16 | Phase 3 | Complete |
| TOK-17 | Phase 3 | Complete |
| TOK-18 | Phase 3 | Complete |
| PAR-01 | Phase 4 | Complete |
| PAR-02 | Phase 4 | Complete |
| PAR-03 | Phase 4 | Complete |
| PAR-04 | Phase 4 | Complete |
| PAR-05 | Phase 4 | Complete |
| PAR-06 | Phase 4 | Complete |
| PAR-07 | Phase 4 | Complete |
| PAR-08 | Phase 4 | Complete |
| PAR-09 | Phase 4 | Complete |
| PAR-10 | Phase 4 | Complete |
| PAR-11 | Phase 4 | Complete |
| PAR-12 | Phase 4 | Complete |
| PAR-13 | Phase 4 | Complete |
| PAR-14 | Phase 4 | Complete |
| PAR-15 | Phase 4 | Complete |
| PAR-16 | Phase 4 | Complete |
| PAR-17 | Phase 4 | Complete |
| PAR-18 | Phase 4 | Complete |
| PAR-19 | Phase 4 | Complete |
| PAR-20 | Phase 4 | Complete |
| PAR-21 | Phase 4 | Complete |
| RES-01 | Phase 5 | Complete |
| RES-02 | Phase 5 | Complete |
| RES-03 | Phase 5 | Complete |
| RES-04 | Phase 5 | Complete |
| RES-05 | Phase 5 | Complete |
| RES-06 | Phase 5 | Complete |
| RES-07 | Phase 5 | Complete |
| EVL-13 | Phase 5 | Complete |
| RES-08 | Phase 6 | Complete |
| RES-09 | Phase 6 | Complete |
| RES-10 | Phase 6 | Complete |
| EVL-01 | Phase 7 | Complete |
| EVL-02 | Phase 7 | Complete |
| EVL-03 | Phase 7 | Complete |
| EVL-08 | Phase 7 | Complete |
| EVL-11 | Phase 7 | Complete |
| EVL-12 | Phase 7 | Complete |
| EVL-14 | Phase 7 | Complete |
| EVL-15 | Phase 7 | Complete |
| EVL-04 | Phase 8 | Complete |
| EVL-05 | Phase 8 | Complete |
| EVL-06 | Phase 8 | Complete |
| EVL-07 | Phase 8 | Complete |
| EVL-09 | Phase 8 | Complete |
| EVL-10 | Phase 8 | Complete |
| ERR-04 | Phase 8 | Complete |
| RUN-01 | Phase 9 | Complete |
| RUN-02 | Phase 9 | Complete |
| RUN-03 | Phase 9 | Complete |
| RUN-04 | Phase 9 | Complete |
| PRJ-05 | Phase 9 | Complete |
| CHR-11 | Phase 10 | Pending |
| RES-11 | Phase 10 | Pending |
| RES-12 | Phase 10 | Pending |
| CHR-01 | Phase 10 | Pending |
| EVL-16 | Phase 10 | Pending |
| CHR-02 | Phase 11 | Pending |
| CHR-03 | Phase 11 | Pending |
| CHR-04 | Phase 11 | Pending |
| CHR-05 | Phase 11 | Pending |
| CHR-06 | Phase 11 | Pending |
| CHR-07 | Phase 11 | Pending |
| CHR-10 | Phase 11 | Pending |
| EVL-17 | Phase 11 | Pending |
| EVL-18 | Phase 11 | Pending |
| EVL-19 | Phase 11 | Pending |
| EVL-20 | Phase 11 | Pending |
| EVL-21 | Phase 11 | Pending |
| CHR-08 | Phase 12 | Pending |
| CHR-09 | Phase 12 | Pending |

**Coverage:**
- v1 requirements: 79 total, 79 complete
- Choreographic requirements: 19 total, 0 complete
- Grand total: 98 total, 79 mapped and complete

---
*Requirements defined: 2026-03-27*
*Last updated: 2026-04-14 — v1.0 completion reconciled, choreographic traceability added*
