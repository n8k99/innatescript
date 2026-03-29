# Innate

## What This Is

Innate is a scripting language of intention — "markdown that runs." You write `.dpn` files that are simultaneously readable documents and executable programs. The interpreter is written in Common Lisp with a pluggable resolver protocol, so it can be connected to any substrate or agent system. The first resolver connects it to the Dragonpunk noosphere (private, separate repo), but the language itself is generic and public.

## Core Value

A human unfamiliar with any programming language should be able to make a reasonable guess at what an Innate program does — and that same program should execute.

## Requirements

### Validated

(None yet — ship to validate)

### Active

- [ ] Parser that reads `.dpn` files into an AST
- [ ] Evaluator that walks the AST against a pluggable resolver protocol
- [ ] Container Trinity syntax: `[]` place, `()` person, `{}` thing
- [ ] `@` direct references with hoisting (two-pass: parse everything, then resolve)
- [ ] `![]` search directives for finding resources that may not exist
- [ ] `||` fulfillment operator — unresolved searches become agent commissions
- [ ] `->` emission — results flow out
- [ ] `decree` declarations for defining persistent structure (types, workflows, routing, presentation)
- [ ] `[[]]` wikilink document references as a native type
- [ ] `+` combinator for extending scope
- [ ] `{}` as lenses (filter/grouping on result sets)
- [ ] `:` as natural-language qualifier on references
- [ ] `#` heading / presentation directives
- [ ] Prose passthrough — non-executable lines are documentation
- [ ] Resistance error model (structural failures propagate, missing resources trigger fulfillment)
- [ ] Stub resolver for testing (in-memory entities, no external dependencies)
- [ ] Interactive REPL
- [ ] Shell scripts for running tests and REPL

### Out of Scope

- Noosphere resolver (connects to master_chronicle + ghost roster) — private, lives in project-noosphere-ghosts
- dpn-api refactoring — separate project, ghosts will handle it using Innate
- Laptop CLI (`innate push`, `innate eval`) — future phase, after core interpreter works
- dpn-tui rewrite — future phase
- Metacircular evaluator (Innate interpreting itself) — the dream, not v1
- Any hardcoded references to specific databases, agent rosters, or infrastructure

## Context

Innate emerged from the Dragonpunk noosphere — an agentic AI platform where 60+ persistent AI agents (ghosts) run on a Common Lisp tick engine, perceiving work from a Postgres database and executing it. Nathan needed a way to speak to the ghosts directly: write scripts that define types, workflows, routing rules, and presentation templates. "Moses handing out the ten commandments."

The language design was captured in two spec iterations (`dpn-lang-spec.md` and the renamed `Innate Language Specification`), plus a sample program (`burg_pipeline.dpn`). A design spec was written during the brainstorming session on 2026-03-27.

Key insight: the same expression (`@type:"[[Burg]]"+all{state:==}`) serves as a query (at a REPL), a workflow scope (in a template), and a UI definition (as a file). Context determines meaning, not syntax.

The interpreter is generic by design. The resolver protocol (CLOS generic functions) defines how symbols connect to infrastructure. The noosphere resolver is one implementation. Others are possible.

An `innatescript.ttf` font file exists on the droplet, suggesting visual/branding work has been considered.

## Constraints

- **Language**: Common Lisp (SBCL) — the ghosts speak Lisp natively, so Innate must too
- **No external dependencies**: follows AF64 conventions (hand-rolled everything, ASDF system definition, package-per-module)
- **Public repo**: zero secrets, zero hardcoded substrate references
- **Generic**: the interpreter must know nothing about any specific substrate, agent roster, or deployment
- **File extension**: `.dpn`

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Common Lisp for interpreter | Ghosts speak Lisp natively — no FFI, no serialization boundary | -- Pending |
| Pluggable resolver protocol | Language must be generic; specific infrastructure is configuration | -- Pending |
| Two-pass evaluation (hoisting) | `@` references can appear before their definitions in the same script | -- Pending |
| `\|\|` as fulfillment, not boolean OR | Missing resources become agent commissions, not error branches | -- Pending |
| Own repo, not inside project-noosphere-ghosts | Innate is the language, the noosphere is one dialect | -- Pending |
| No external Lisp libraries | Follows AF64 conventions, keeps the dependency tree at zero | -- Pending |

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
*Last updated: 2026-03-29 after Phase 9 (REPL and Integration) completion — v1.0 MILESTONE COMPLETE*
