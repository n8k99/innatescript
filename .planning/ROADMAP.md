# Roadmap: Innate

## Overview

Innate is a Common Lisp interpreter for a "language of intention" — markdown-like `.dpn` files that are simultaneously readable documents and executable programs. The build order is dictated by compile-time dependencies: packages → conditions → AST → tokenizer → parser → environment → resolver protocol → stub resolver → evaluator → REPL. Each phase delivers one coherent, loadable, testable layer. Nothing runs end-to-end until Phase 9, but everything is verifiable at each boundary.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [x] **Phase 1: Project Scaffolding** - ASDF system, package namespaces, test harness, cold-load verification (completed 2026-03-28)
- [x] **Phase 2: Conditions and AST Nodes** - All condition types and all AST defstruct definitions (completed 2026-03-28)
- [ ] **Phase 3: Tokenizer** - Full Innate symbol vocabulary including wikilink disambiguation
- [x] **Phase 4: Parser** - Recursive descent, prose passthrough, complete expression grammar (completed 2026-03-28)
- [x] **Phase 5: Resolver Protocol and Environment** - defgeneric boundary, evaluation environment struct (completed 2026-03-28)
- [x] **Phase 6: Stub Resolver** - In-memory implementation conforming to resolver protocol (completed 2026-03-29)
- [x] **Phase 7: Evaluator Core** - Two-pass hoisting, etypecase dispatch, prose/heading passthrough (completed 2026-03-29)
- [ ] **Phase 8: Commission and Fulfillment Evaluation** - Agent, search, emission, wikilink, bundle, || operator
- [ ] **Phase 9: REPL and Integration** - Interactive loop, file runner, shell scripts, burg_pipeline integration test

## Phase Details

### Phase 1: Project Scaffolding
**Goal**: The ASDF system loads cleanly from a cold cache with zero warnings, and a hand-rolled test harness is available for all subsequent phases
**Depends on**: Nothing (first phase)
**Requirements**: PRJ-01, PRJ-02, PRJ-03, PRJ-04, RUN-05
**Success Criteria** (what must be TRUE):
  1. Running `sbcl --eval "(asdf:load-system :innatescript)"` after wiping `~/.cache/common-lisp/` completes with zero errors and zero warnings
  2. All package namespaces are defined in a single `packages.lisp` loaded first; no symbol conflicts arise when loading any component in any order
  3. `deftest`, `assert-equal`, `assert-true`, and `run-tests` macros are available and a trivial test passes
  4. Zero external Lisp library dependencies are listed in the `.asd` file
**Plans**: 2 plans

Plans:
- [x] 01-01-PLAN.md — ASDF system definition, packages.lisp, and all nine module stub files
- [x] 01-02-PLAN.md — Test framework (deftest macros), test packages, smoke test, and run-tests.sh

### Phase 2: Conditions and AST Nodes
**Goal**: Every condition type and every AST node type exists as a named, inspectable Lisp object before any tokenizer or parser code is written
**Depends on**: Phase 1
**Requirements**: ERR-01, ERR-02, ERR-03, PAR-22
**Success Criteria** (what must be TRUE):
  1. `innate-resistance` condition can be signaled and caught with `handler-case`
  2. `innate-parse-error` condition carries line and column numbers accessible as slots
  3. Making a `resistance` condition does not call `error` — it calls `signal` (resistance is not an unrecoverable failure)
  4. All 18+ AST node types exist as `defstruct` instances with `kind`, `value`, `children`, and `props` fields; constructors and accessors compile and round-trip in a test
**Plans**: 3 plans

Plans:
- [x] 02-01-PLAN.md — Package export contracts (innate.types, innate.conditions), test sub-packages, ASDF test system registration
- [x] 02-02-PLAN.md — Condition hierarchy implementation (innate-condition, innate-parse-error, innate-resistance) and condition tests
- [x] 02-03-PLAN.md — AST node defstructs, node kind constants, result/resistance structs, and types round-trip tests

### Phase 3: Tokenizer
**Goal**: Any valid Innate source text can be converted to a typed, positioned token stream with no ambiguity on wikilinks vs. nested brackets
**Depends on**: Phase 2
**Requirements**: TOK-01, TOK-02, TOK-03, TOK-04, TOK-05, TOK-06, TOK-07, TOK-08, TOK-09, TOK-10, TOK-11, TOK-12, TOK-13, TOK-14, TOK-15, TOK-16, TOK-17, TOK-18
**Success Criteria** (what must be TRUE):
  1. `[[Burg]]` tokenizes as a single WIKILINK token; `[[sylvia[command]]]` tokenizes as three nested LBRACKET levels — the disambiguation is correct in both directions
  2. Every token in the stream carries a line number and column number accessible as fields
  3. A tokenizer test suite passes for every symbol in the Innate vocabulary: `@`, `![]`, `||`, `->`, `[[]]`, `[]`, `()`, `{}`, `<emoji>`, `#`, `+`, `:`, `,`, `/`, `decree`, bare words, strings, integers, and prose lines
  4. Prose lines (not starting with executable syntax) emit as PROSE tokens rather than being discarded or causing errors
**Plans**: 3 plans

Plans:
- [x] 03-01-PLAN.md — Package exports, token defstruct, ASDF wiring, and test scaffold
- [x] 03-02-PLAN.md — Core tokenizer loop: single-char dispatch, two-char operators, string/number/bare-word literals, emoji slot, decree keyword
- [x] 03-03-PLAN.md — Wikilink disambiguation, prose line detection, newline handling, integration test with burg_pipeline.dpn

### Phase 4: Parser
**Goal**: Any tokenized Innate source produces a typed AST where prose is a first-class node, all infix operators have correct left-associativity, and compound expressions like `@type:"[[Burg]]"+all{state:==}` parse completely
**Depends on**: Phase 3
**Requirements**: PAR-01, PAR-02, PAR-03, PAR-04, PAR-05, PAR-06, PAR-07, PAR-08, PAR-09, PAR-10, PAR-11, PAR-12, PAR-13, PAR-14, PAR-15, PAR-16, PAR-17, PAR-18, PAR-19, PAR-20, PAR-21
**Success Criteria** (what must be TRUE):
  1. `[db[get_count[entry]]]` parses as a three-level nested bracket AST node with correct parent-child relationships
  2. `a -> b -> c` parses with left associativity: `(-> (-> a b) c)` — a three-step chain test passes
  3. Prose lines appear as `prose-node` AST nodes in the output; they are not discarded
  4. `@type:"[[Burg]]"+all{state:==}` parses as a compound reference node with type filter, combinator, and lens as distinct AST children
  5. A `innate-parse-error` with line/col is signaled on malformed input rather than a raw SBCL error
**Plans**: 3 plans

Plans:
- [x] 04-01-PLAN.md — Parser infrastructure (packages, ASDF, cursor struct) and bracket/statement core
- [x] 04-02-PLAN.md — Expression types: references, agents, bundles, lenses, search, decree, modifiers
- [x] 04-03-PLAN.md — Emission and fulfillment operators, burg_pipeline.dpn integration test

### Phase 5: Resolver Protocol and Environment
**Goal**: The resolver contract is defined as CLOS defgenerics with documented call signatures, and the evaluation environment struct carries context through all subsequent evaluator work
**Depends on**: Phase 4
**Requirements**: RES-01, RES-02, RES-03, RES-04, RES-05, RES-06, RES-07, EVL-13
**Success Criteria** (what must be TRUE):
  1. Calling any resolver defgeneric (`resolve-reference`, `resolve-search`, `deliver-commission`, `resolve-wikilink`, `resolve-context`, `load-bundle`) on the base `resolver` class returns a resistance value, not an unhandled error
  2. The evaluation environment struct exists with `resolver`, `decrees`, `bindings`, and `scope` fields; it can be constructed and passed as an argument
  3. The evaluator package imports only from `innate/resolver` (the defgeneric declarations) — no concrete resolver implementation is visible to the evaluator
  4. A written resolver protocol specification (in `docs/` or docstrings) describes what each generic must return for "found", "not found", and "fulfillment required" cases
**Plans**: 1 plan

Plans:
- [x] 05-01-PLAN.md — Resolver class, 6 defgenerics with default methods, eval-env struct, protocol tests

### Phase 6: Stub Resolver
**Goal**: A fully conforming in-memory resolver exists that passes the resolver conformance test suite, enabling evaluator tests to run without any external infrastructure
**Depends on**: Phase 5
**Requirements**: RES-08, RES-09, RES-10
**Success Criteria** (what must be TRUE):
  1. The stub resolver passes every test in the resolver conformance suite — it is a correct implementation, not a minimal fixture
  2. Commissions delivered to the stub resolver are recorded and retrievable for test assertions (e.g., `(assert-equal (stub-commissions resolver) '(("agent-name" "instruction")))`)
  3. `@name:qualifier` reference chains resolve against plist entities stored in the stub's in-memory hashtable
**Plans**: 1 plan

Plans:
- [x] 06-01-PLAN.md — stub-resolver class, 6 method specializations, seeding helpers, conformance tests

### Phase 7: Evaluator Core
**Goal**: The two-pass hoisting architecture is in place, all non-commission AST node types evaluate correctly via etypecase dispatch, and resistance propagates upward through nested brackets
**Depends on**: Phase 6
**Requirements**: EVL-01, EVL-02, EVL-03, EVL-08, EVL-11, EVL-12, EVL-14, EVL-15
**Success Criteria** (what must be TRUE):
  1. A `@reference` that appears before its `decree` definition in the same script resolves correctly — forward-reference tests pass for every node type
  2. `decree` definitions are collected in pass 1 and are available to `@` lookups in pass 2, regardless of their position in the script
  3. Prose nodes and heading nodes pass through evaluation and appear in rendered output rather than being dropped or causing errors
  4. An unresolvable `@reference` with no `||` fulfillment propagates `innate-resistance` upward through all enclosing bracket levels until it surfaces to the caller
  5. Internal evaluator dispatch uses `etypecase` on AST node kinds — CLOS method dispatch is not used for AST walking
**Plans**: 2 plans

Plans:
- [x] 07-01-PLAN.md — Two-pass architecture, decree collection, etypecase dispatch skeleton, passthrough and literal evaluation
- [x] 07-02-PLAN.md — Reference resolution (decrees-first then resolver), bracket evaluation, resistance propagation, full pipeline tests

### Phase 8: Commission and Fulfillment Evaluation
**Goal**: Agent commissions, search directives, the fulfillment operator, emission, wikilinks, and bundle loading all evaluate correctly against the stub resolver
**Depends on**: Phase 7
**Requirements**: EVL-04, EVL-05, EVL-06, EVL-07, EVL-09, EVL-10, ERR-04
**Success Criteria** (what must be TRUE):
  1. `(agent){instruction}` evaluates by calling `deliver-commission` on the resolver; the stub records the commission
  2. `![search_expr]` evaluates by calling `resolve-search` on the resolver; a resistance from the search triggers the `||` right-hand side
  3. `expr || (agent){instruction}` — when the left side produces resistance, the right side commission fires; when the left side succeeds, the right side is never called
  4. `-> value, value` emission evaluates and returns the value sequence to the caller
  5. `[[Title]]` wikilinks evaluate by calling `resolve-wikilink`; `{bundle_name}` evaluates by calling `load-bundle`
**Plans**: 2 plans

Plans:
- [x] 08-01-PLAN.md — Emission, wikilink, and bundle evaluation (replace 3 stubs)
- [x] 08-02-PLAN.md — Commission adjacency, search, and fulfillment operator (replace final 3 stubs)

### Phase 9: REPL and Integration
**Goal**: The full pipeline is assembled end-to-end; the REPL handles all conditions gracefully and never crashes on bad input; `burg_pipeline.dpn` evaluates without error
**Depends on**: Phase 8
**Requirements**: RUN-01, RUN-02, RUN-03, RUN-04, PRJ-05
**Success Criteria** (what must be TRUE):
  1. The interactive REPL starts via `run-repl.sh`, accepts Innate expressions, and returns results — entering malformed syntax prints an error and returns to the prompt rather than crashing
  2. Running `run-repl.sh burg_pipeline.dpn` evaluates the full `burg_pipeline.dpn` file without unhandled errors
  3. Running `run-tests.sh` executes the full test suite and exits with code 0 on pass or non-zero on failure
  4. A fulfillment signal (`innate-resistance` that reaches the REPL boundary) prints "commission queued" and returns to the prompt
  5. `rlwrap run-repl.sh` provides line history and editing without any Lisp code changes
**Plans**: 2 plans

Plans:
- [ ] 09-01-PLAN.md — REPL loop, file runner, package exports, REPL tests with burg_pipeline.dpn integration
- [ ] 09-02-PLAN.md — run-repl.sh shell script and end-to-end integration verification

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3 → 4 → 5 → 6 → 7 → 8 → 9

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Project Scaffolding | 2/2 | Complete   | 2026-03-28 |
| 2. Conditions and AST Nodes | 3/3 | Complete   | 2026-03-28 |
| 3. Tokenizer | 2/3 | In Progress|  |
| 4. Parser | 3/3 | Complete   | 2026-03-28 |
| 5. Resolver Protocol and Environment | 1/1 | Complete   | 2026-03-28 |
| 6. Stub Resolver | 1/1 | Complete   | 2026-03-29 |
| 7. Evaluator Core | 2/2 | Complete   | 2026-03-29 |
| 8. Commission and Fulfillment Evaluation | 1/2 | In Progress|  |
| 9. REPL and Integration | 0/2 | Not started | - |
