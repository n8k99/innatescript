# Innate

## What This Is

Innate is a scripting language of intention — "markdown that runs." You write `.dpn` files that are simultaneously readable documents and executable programs. The interpreter is written in Common Lisp (SBCL) with a pluggable resolver protocol. v1.0 ships a complete interpreter: tokenizer, recursive descent parser, two-pass evaluator with decree hoisting, resistance/fulfillment error model, interactive REPL, and file runner. The stub resolver enables standalone testing; the noosphere resolver (private, separate repo) connects to the Dragonpunk ghost platform.

## Core Value

A human unfamiliar with any programming language should be able to make a reasonable guess at what an Innate program does — and that same program should execute.

## Current State

**v1.0 shipped 2026-03-29** — 1,945 LOC source, 2,141 LOC tests, 174 tests passing, zero external dependencies.

- `./run-repl.sh` — interactive Innate REPL
- `./run-repl.sh file.dpn` — evaluate a `.dpn` file
- `./run-tests.sh` — full test suite (174 tests)
- `rlwrap ./run-repl.sh` — line history and editing

## Requirements

### Validated

- ✓ Parser that reads `.dpn` files into an AST — v1.0
- ✓ Evaluator that walks the AST against a pluggable resolver protocol — v1.0
- ✓ Container Trinity syntax: `[]` place, `()` person, `{}` thing — v1.0
- ✓ `@` direct references with hoisting (two-pass: parse everything, then resolve) — v1.0
- ✓ `![]` search directives for finding resources that may not exist — v1.0
- ✓ `||` fulfillment operator — unresolved searches become agent commissions — v1.0
- ✓ `->` emission — results flow out — v1.0
- ✓ `decree` declarations for defining persistent structure — v1.0
- ✓ `[[]]` wikilink document references as a native type — v1.0
- ✓ `+` combinator for extending scope — v1.0
- ✓ `{}` as lenses (filter/grouping on result sets) — v1.0
- ✓ `:` as natural-language qualifier on references — v1.0
- ✓ `#` heading / presentation directives — v1.0
- ✓ Prose passthrough — non-executable lines are documentation — v1.0
- ✓ Resistance error model (structural failures propagate, missing resources trigger fulfillment) — v1.0
- ✓ Stub resolver for testing (in-memory entities, no external dependencies) — v1.0
- ✓ Interactive REPL — v1.0
- ✓ Shell scripts for running tests and REPL — v1.0

### Active

(None — next milestone requirements defined via `/gsd:new-milestone`)

### Out of Scope

- Noosphere resolver (connects to master_chronicle + ghost roster) — private, lives in project-noosphere-ghosts
- dpn-api refactoring — separate project, ghosts will handle it using Innate
- Laptop CLI (`innate push`, `innate eval`) — v2 feature
- dpn-tui rewrite — depends on working interpreter + noosphere resolver
- Metacircular evaluator (Innate interpreting itself) — the dream, not v1
- Any hardcoded references to specific databases, agent rosters, or infrastructure
- Chained fulfillment `a || b || c` — v2 (parser left-associates, evaluator handles single binary)
- Template parameters / inward flow `<-` — v2
- Multi-line REPL input for decree blocks — v2

## Context

Innate emerged from the Dragonpunk noosphere — an agentic AI platform where 60+ persistent AI agents (ghosts) run on a Common Lisp tick engine, perceiving work from a Postgres database and executing it. Nathan needed a way to speak to the ghosts directly: write scripts that define types, workflows, routing rules, and presentation templates. "Moses handing out the ten commandments."

Key insight: the same expression (`@type:"[[Burg]]"+all{state:==}`) serves as a query (at a REPL), a workflow scope (in a template), and a UI definition (as a file). Context determines meaning, not syntax.

The interpreter is generic by design. The resolver protocol (CLOS generic functions) defines how symbols connect to infrastructure. The noosphere resolver is one implementation. Others are possible.

**v1.0 tech stack:** SBCL 2.x, ASDF 3.3+, hand-rolled recursive descent parser, hand-rolled test harness, zero external Lisp dependencies. 99 commits across 2 days.

## Constraints

- **Language**: Common Lisp (SBCL) — the ghosts speak Lisp natively, so Innate must too
- **No external dependencies**: follows AF64 conventions (hand-rolled everything, ASDF system definition, package-per-module)
- **Public repo**: zero secrets, zero hardcoded substrate references
- **Generic**: the interpreter must know nothing about any specific substrate, agent roster, or deployment
- **File extension**: `.dpn`

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Common Lisp for interpreter | Ghosts speak Lisp natively — no FFI, no serialization boundary | ✓ Good |
| Pluggable resolver protocol | Language must be generic; specific infrastructure is configuration | ✓ Good |
| Two-pass evaluation (hoisting) | `@` references can appear before their definitions in the same script | ✓ Good |
| `\|\|` as fulfillment, not boolean OR | Missing resources become agent commissions, not error branches | ✓ Good |
| Own repo, not inside project-noosphere-ghosts | Innate is the language, the noosphere is one dialect | ✓ Good |
| No external Lisp libraries | Follows AF64 conventions, keeps the dependency tree at zero | ✓ Good |
| Universal `defstruct node` with `etypecase` dispatch | Adding node kinds requires zero struct changes; evaluator dispatch is explicit | ✓ Good |
| `eval-env` explicit argument (not dynamic `*resolver*`) | Cleaner for two-pass architecture, different decree states per pass | ✓ Good |
| Commission adjacency in evaluate loop | Parser emits agent+bundle as siblings; evaluator detects adjacency | ⚠️ Revisit — parser could group `(agent){bundle}` as a single expression |
| `resistance` struct vs `innate-resistance` condition | Struct is return value, condition is signalable — prevents accessor collision | ✓ Good |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition:**
1. Requirements invalidated? -> Move to Out of Scope with reason
2. Requirements validated? -> Move to Validated with phase reference
3. New requirements emerged? -> Add to Active
4. Decisions to log? -> Add to Key Decisions
5. "What This Is" still accurate? -> Update if drifted

**After each milestone:**
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-03-29 after v1.0 milestone completion*
