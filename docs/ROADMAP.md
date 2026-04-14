---
title: Innatescript Roadmap
type: "[[Project]]"
icon: 📋
Lifestage: "🌿 Sapling"
status: active
owner: "[[NathanEckenrode]]"
domain: "[[The Work]]"
repository: ""
project_number:
description: "Roadmap for the Innate scripting language interpreter"
visibility: private
started: "[[2026-03-28]]"
target_completion:
completed: 10
created: "[[2026-03-28]]"
updated: "[[2026-04-14]]"
tags: []
project: "[[InnateScript]]"
current_milestone: v2.0-choreographic
milestones: 12
---
# Roadmap: Innate

## Overview

Innate is a Common Lisp interpreter for a choreographic programming language — markdown files containing Innate expressions that are simultaneously readable documents and executable multi-agent choreographies. The build order is dictated by compile-time dependencies: packages → conditions → AST → tokenizer → parser → environment → resolver protocol → stub resolver → evaluator → REPL. Each milestone delivers one coherent, loadable, testable layer.

v1.0 shipped 2026-03-29 with 9 milestones, 19 task sets, and 97+ passing tests. The interpreter handles the full Innate expression grammar including tokenization, parsing, resolver protocol, stub resolver, two-pass evaluation, commission/fulfillment, and an interactive REPL with file runner. Milestones 10-12 extend the language with choreographic semantics.

## Milestones

- [x] **Milestone 1: Project Scaffolding** - ASDF system, package namespaces, test harness, cold-load verification (completed 2026-03-28)
- [x] **Milestone 2: Conditions and AST Nodes** - All condition types and all AST defstruct definitions (completed 2026-03-28)
- [x] **Milestone 3: Tokenizer** - Full Innate symbol vocabulary, wikilink disambiguation, prose detection (completed 2026-03-28; choreographic tokens `<-`, `concurrent`, `join`, `until`, `sync`, `at` deferred to Milestone 10)
- [x] **Milestone 4: Parser** - Recursive descent, prose passthrough, complete expression grammar (completed 2026-03-28; three-bracket limit enforcement deferred to Milestone 12)
- [x] **Milestone 5: Resolver Protocol and Environment** - defgeneric boundary, evaluation environment struct (completed 2026-03-28 with 6 generics; `deliver-verification` and `schedule-at` deferred to Milestone 10)
- [x] **Milestone 6: Stub Resolver** - In-memory stub resolver conforming to v1 resolver protocol (completed 2026-03-28; choreographic method specializations deferred to Milestone 10)
- [x] **Milestone 7: Evaluator Core** - Two-pass hoisting, etypecase dispatch, prose/heading passthrough (completed 2026-03-29; bracket depth enforcement deferred to Milestone 12)
- [x] **Milestone 8: Commission and Fulfillment Evaluation** - Agent commission, search, emission, wikilink, bundle, fulfillment operator (completed 2026-03-29; `<-` verification operator deferred to Milestone 10)
- [x] **Milestone 9: REPL and Integration** - Interactive loop, file runner, shell scripts, burg_pipeline integration test (completed 2026-03-29)
- [x] **Milestone 10: Choreographic Lexing and Parsing** - `<-` verification, choreographic tokens, resolver protocol extensions (completed 2026-04-14)
- [ ] **Milestone 11: Choreographic Coordination** - `concurrent`, `join`, `until`, `sync`, `at` evaluation and projection
- [ ] **Milestone 12: Choreographic Integration** - Three-bracket enforcement, projection, decree migration, end-to-end choreographic tests

## Milestone Details

### Milestone 1: Project Scaffolding
**Objective**: The ASDF system loads cleanly from a cold cache with zero warnings, and a hand-rolled test harness is available for all subsequent milestones
**Depends on**: Nothing (first milestone)
**Requirements**: PRJ-01, PRJ-02, PRJ-03, PRJ-04, RUN-05
**Goals** (what must be TRUE):
  1. Running `sbcl --eval "(asdf:load-system :innatescript)"` after wiping `~/.cache/common-lisp/` completes with zero errors and zero warnings
  2. All package namespaces are defined in a single `packages.lisp` loaded first; no symbol conflicts arise when loading any component in any order
  3. `deftest`, `assert-equal`, `assert-true`, and `run-tests` macros are available and a trivial test passes
  4. Zero external Lisp library dependencies are listed in the `.asd` file
**Tasks**: 2 (completed)

### Milestone 2: Conditions and AST Nodes
**Objective**: Every condition type and every AST node type exists as a named, inspectable Lisp object before any tokenizer or parser code is written
**Depends on**: Milestone 1
**Requirements**: ERR-01, ERR-02, ERR-03, PAR-22
**Goals** (what must be TRUE):
  1. `innate-resistance` condition can be signaled and caught with `handler-case`
  2. `innate-parse-error` condition carries line and column numbers accessible as slots
  3. Making a `resistance` condition does not call `error` — it calls `signal` (resistance is not an unrecoverable failure)
  4. All 18+ AST node types exist as `defstruct` instances with `kind`, `value`, `children`, and `props` fields; constructors and accessors compile and round-trip in a test
**Tasks**: 3 (completed)

### Milestone 3: Tokenizer
**Objective**: Any valid Innate source text can be converted to a typed, positioned token stream with no ambiguity on wikilinks vs. nested brackets
**Depends on**: Milestone 2
**Requirements**: TOK-01 through TOK-18
**Goals** (what must be TRUE):
  1. `[[Burg]]` tokenizes as a single WIKILINK token; `sylvia[command]` tokenizes as three nested LBRACKET levels — the disambiguation is correct in both directions
  2. Every token in the stream carries a line number and column number accessible as fields
  3. A tokenizer test suite passes for every symbol in the v1 Innate vocabulary: `@`, `![]`, `||`, `->`, `[[]]`, `[]`, `{}`, `<emoji>`, `#`, `+`, `:`, `,`, `/`, `decree`, bare words, strings, integers, and prose lines
  4. Prose lines (not starting with executable syntax) emit as PROSE tokens rather than being discarded or causing errors
**Tasks**: 3 (completed)

### Milestone 4: Parser
**Objective**: Any tokenized Innate source produces a typed AST where prose is a first-class node, all infix operators have correct left-associativity, and compound expressions like `@type:"[[Burg]]"+all{state:==}` parse completely
**Depends on**: Milestone 3
**Requirements**: PAR-01 through PAR-21
**Goals** (what must be TRUE):
  1. `[db[get_count[entry]]]` parses as a three-level nested bracket AST node with correct parent-child relationships
  2. `a -> b -> c` parses with left associativity: `(-> (-> a b) c)` — a three-step chain test passes
  3. Prose lines appear as `prose-node` AST nodes in the output; they are not discarded
  4. `@type:"[[Burg]]"+all{state:==}` parses as a compound reference node with type filter, combinator, and lens as distinct AST children
  5. A `innate-parse-error` with line/col is signaled on malformed input rather than a raw SBCL error
**Tasks**: 3 (completed)

### Milestone 5: Resolver Protocol and Environment
**Objective**: The resolver contract is defined as CLOS defgenerics with documented call signatures, and the evaluation environment struct carries context through all subsequent evaluator work
**Depends on**: Milestone 4
**Requirements**: RES-01 through RES-07, EVL-13
**Goals** (what must be TRUE):
  1. Calling any v1 resolver defgeneric (`resolve-reference`, `resolve-search`, `deliver-commission`, `resolve-wikilink`, `resolve-context`, `load-bundle`) on the base `resolver` class returns a resistance value, not an unhandled error
  2. The evaluation environment struct exists with `resolver`, `bindings`, and `scope` fields; it can be constructed and passed as an argument
  3. The evaluator package imports only from `innate/resolver` (the defgeneric declarations) — no concrete resolver implementation is visible to the evaluator
  4. A written resolver protocol specification (in `docs/` or docstrings) describes what each generic must return for "found", "not found", and "fulfillment required" cases
**Tasks**: 1 (completed)

### Milestone 6: Stub Resolver
**Objective**: A fully conforming in-memory resolver exists that passes the resolver conformance test suite, enabling evaluator tests to run without any external infrastructure
**Depends on**: Milestone 5
**Requirements**: RES-08, RES-09, RES-10
**Goals** (what must be TRUE):
  1. The stub resolver passes every test in the resolver conformance suite — it is a correct implementation, not a minimal fixture
  2. Commissions delivered to the stub resolver are recorded and retrievable for test assertions (e.g., `(assert-equal (stub-commissions resolver) '(("agent-name" "instruction")))`)
  3. `@name:qualifier` reference chains resolve against plist entities stored in the stub's in-memory hashtable
**Tasks**: 1 (completed)

### Milestone 7: Evaluator Core
**Objective**: The two-pass hoisting architecture is in place, all non-commission AST node types evaluate correctly via etypecase dispatch, and resistance propagates upward through nested brackets
**Depends on**: Milestone 6
**Requirements**: EVL-01, EVL-02, EVL-03, EVL-08, EVL-11, EVL-12, EVL-14, EVL-15
**Goals** (what must be TRUE):
  1. A `@reference` that appears before its definition in the same script resolves correctly — forward-reference tests pass for every node type
  2. Named bracket expressions are collected in pass 1 and available to `@` lookups in pass 2, regardless of position
  3. Prose nodes and heading nodes pass through evaluation and appear in rendered output rather than being dropped or causing errors
  4. An unresolvable `@reference` with no `||` fulfillment propagates `innate-resistance` upward through all enclosing bracket levels until it surfaces to the caller
  5. Internal evaluator dispatch uses `etypecase` on AST node kinds — CLOS method dispatch is not used for AST walking
**Tasks**: 2 (completed)

### Milestone 8: Commission and Fulfillment Evaluation
**Objective**: Agent commissions, search directives, the fulfillment operator, emission, wikilinks, and bundle loading all evaluate correctly against the stub resolver
**Depends on**: Milestone 7
**Requirements**: EVL-04, EVL-05, EVL-06, EVL-07, EVL-09, EVL-10, ERR-04
**Goals** (what must be TRUE):
  1. `@agent{instruction}` evaluates by calling `deliver-commission` on the resolver; the stub records the commission
  2. `![search_expr]` evaluates by calling `resolve-search` on the resolver; a resistance from the search triggers the `||` right-hand side
  3. `expr || @agent{instruction}` — when the left side produces resistance, the right side commission fires; when the left side succeeds, the right side is never called
  4. `-> value, value` emission evaluates and returns the value sequence to the caller
  5. `[[Title]]` wikilinks evaluate by calling `resolve-wikilink`; `{bundle_name}` evaluates by calling `load-bundle`
**Tasks**: 1 (completed)

### Milestone 9: REPL and Integration
**Objective**: The full pipeline is assembled end-to-end; the REPL handles all conditions gracefully and never crashes on bad input; `burg_pipeline.dpn` evaluates without error
**Depends on**: Milestone 8
**Requirements**: RUN-01, RUN-02, RUN-03, RUN-04, PRJ-05
**Goals** (what must be TRUE):
  1. The interactive REPL starts via `run-repl.sh`, accepts Innate expressions, and returns results — entering malformed syntax prints an error and returns to the prompt rather than crashing
  2. Running `run-repl.sh burg_pipeline.dpn` evaluates the full `burg_pipeline.dpn` file without unhandled errors
  3. Running `run-tests.sh` executes the full test suite and exits with code 0 on pass or non-zero on failure
  4. A fulfillment signal (`innate-resistance` that reaches the REPL boundary) prints "commission queued" and returns to the prompt
  5. `rlwrap run-repl.sh` provides line history and editing without any Lisp code changes
**Tasks**: 2 (completed)

### Milestone 10: Choreographic Lexing and Parsing
**Objective**: Extend the tokenizer and parser to handle choreographic syntax — `<-` verification operator, `concurrent`, `join`, `until`, `sync`, `at` keywords — and add `deliver-verification` and `schedule-at` to the resolver protocol
**Depends on**: Milestone 9
**Requirements**: CHR-11, RES-11, RES-12, CHR-01, EVL-16
**Goals** (what must be TRUE):
  1. `<-` tokenizes as a VERIFICATION token, distinct from `->` emission
  2. `concurrent`, `join`, `until`, `sync`, `at` tokenize as keyword tokens
  3. Parser produces AST nodes for verification expressions, coordination blocks, and temporal triggers
  4. `deliver-verification` and `schedule-at` generics are defined on the resolver protocol
  5. Stub resolver specializes both new generics
**Tasks**: 12 (completed)

### Milestone 11: Choreographic Coordination
**Objective**: The five coordination primitives (`concurrent`, `join`, `until`, `sync`, `at`) evaluate correctly, enabling multi-agent choreographies with parallel execution, synchronization, time-bounded obligations, and temporal triggers
**Depends on**: Milestone 10
**Requirements**: CHR-02, CHR-03, CHR-04, CHR-05, CHR-06, CHR-07, CHR-10, EVL-17, EVL-18, EVL-19, EVL-20, EVL-21
**Goals** (what must be TRUE):
  1. `concurrent [expr1 expr2]` evaluates both expressions in parallel; both commissions are delivered to the stub resolver
  2. `join` blocks until all concurrent branches complete — a test with simulated async resolution verifies this
  3. `@agent{task} until 3 days || @fallback{escalate}` — postfix `until` bounds the agent's obligation; on timeout, fulfillment fires
  4. `until 3 days [expr1 expr2] || @fallback{escalate}` — block `until` bounds the entire context; on timeout, fulfillment fires
  5. `sync @agent{task}` dispatches alongside the main flow without blocking subsequent evaluation
  6. `at [[2026-04-15]] @agent{task}` calls `schedule-at` on the resolver with the correct time and expression
  7. `<-` verification operators nest correctly inside `concurrent` blocks for parallel verification
**Tasks**: 15

### Milestone 12: Choreographic Integration
**Objective**: Three-bracket enforcement, per-agent projection, decree-to-named-bracket migration, and end-to-end choreographic tests
**Depends on**: Milestone 11
**Requirements**: CHR-08, CHR-09
**Goals** (what must be TRUE):
  1. Bracket nesting beyond three levels produces `innate-parse-error`
  2. Projection decomposes a global choreography into per-agent local slices
  3. Named bracket expressions replace `decree` for registration
  4. End-to-end choreographic test file evaluates without error
**Tasks**: 12

## Progress

**Execution Order:**
v1.0 milestones (1-9) executed sequentially and are complete. Choreographic milestones (10-12) execute sequentially: 10 -> 11 -> 12

| Milestone | Goals Complete | Status | Completed |
|-----------|---------------|--------|-----------|
| 1. Project Scaffolding | 4/4 | Complete | 2026-03-28 |
| 2. Conditions and AST Nodes | 4/4 | Complete | 2026-03-28 |
| 3. Tokenizer | 4/4 | Complete | 2026-03-28 |
| 4. Parser | 5/5 | Complete | 2026-03-28 |
| 5. Resolver Protocol and Environment | 4/4 | Complete | 2026-03-28 |
| 6. Stub Resolver | 3/3 | Complete | 2026-03-28 |
| 7. Evaluator Core | 5/5 | Complete | 2026-03-29 |
| 8. Commission and Fulfillment | 5/5 | Complete | 2026-03-29 |
| 9. REPL and Integration | 5/5 | Complete | 2026-03-29 |
| 10. Choreographic Lexing and Parsing | 5/5 | Complete | 2026-04-14 |
| 11. Choreographic Coordination | 0/7 | Not started | - |
| 12. Choreographic Integration | 0/4 | Not started | - |
