---
title: Innatescript Overview
type: "[[Project]]"
icon: 📋
Lifestage: 🌱 Seed
status: active
owner: nathan
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
repo: github.com/n8k99/innatescript
---
# Innatescript — Project Overview

## The Problem
Real work requires multiple AI agents — each with different strengths — coordinating toward a shared outcome. Today, that coordination is bolted on after the fact: ad-hoc prompt chains, orchestration frameworks, centralized dispatchers. Agents hallucinate. Agents respond lazily. There is no built-in way to verify one agent's output before passing it to the next, no way to express concurrent work with synchronization, no language-level concept of time-bounded obligation or structured fallback. These are distributed systems problems that don't go away by making agents smarter. Coordination must be a first-class concern in the language itself.

## What This Is
Innate is a choreographic programming language that solves this. A single intention is expressed once as a repeatable process. The evaluator projects each agent's local slice. Coordination primitives — verification, concurrency, synchronization, temporal bounds, fulfillment — are part of the grammar. The result: a structured series of prompts distributed across multiple agents that produces dependable outcomes. Multiple agents' strengths compound. The choreography guarantees the composition.

Innate expressions live inside markdown — in `.md` files, in database records, anywhere markdown is stored. The interpreter is written in Common Lisp (SBCL) with a pluggable resolver protocol.

## Core Value
A human unfamiliar with any programming language should be able to make a reasonable guess at what an Innate program does — and that same program should execute as a coordinated multi-agent choreography.

## Repo
github.com/n8k99/innatescript (public)

## Tech Stack
- Common Lisp (SBCL) — zero external deps (AF64 convention)
- Hand-rolled recursive descent parser
- CLOS defgeneric pluggable resolver protocol
- defstruct AST nodes with keyword dispatch

## Syntax Overview

### Containers
| Container | Syntax | Role |
|-----------|--------|------|
| Brackets | `[context[verb[args]]]` | Place — navigation, choreography structure |
| Braces | `{name}` | Thing — bundle/scope/lens |

Agents are entities addressed by `@`, not a separate container. `(@name)` and `@name` are semantically identical.

### Key Operators
- `@` — direct reference (hoisted, two-pass) — agents and data alike
- `![]` — search directive
- `||` — fulfillment (resistance becomes commission)
- `->` — emission (results flow forward)
- `<-` — verification (results checked against reality before advancing)
- `[[]]` — wikilink document reference
- `+` — combinator (extend scope)
- `{}` — lens (filter/group)

### Coordination Primitives
- `concurrent` — multiple agents work simultaneously
- `join` — wait for all concurrent branches (timing only)
- `until` — time-bounded or condition-bounded waiting
- `sync` — side-channel alongside main flow
- `at` — temporal trigger

### Three-Bracket Limit
Maximum three levels of bracket nesting. Deeper complexity extracts as a named choreography (a separate `.md` document or database record) referenced by `@`. This constraint forces self-composition — Innate programs are built from other Innate programs.

## Current Status
- Phase 1 (scaffolding): COMPLETE — ASDF, packages, test harness
- Phase 2 (conditions/AST): COMPLETE — 3 conditions, 20 node types, 23 tests
- Phase 3 (tokenizer): Context gathered, ready for planning
- Phases 4-9: Not started
- Choreographic semantics: Spec complete (April 2026), implementation phases TBD

## Constraints
- Language must be generic — no hardcoded substrate references
- Innate expressions are markdown — no special file extension required
- Public repo — zero secrets
- Ghosts speak Lisp natively — no impedance mismatch

## Related Work
- [Kiran Gopinathan — Multi-Agentic Software Development as a Distributed Systems Problem](https://kirancodes.me/posts/log-distributed-llms.html) (2026)
- [Fabrizio Montesi — Choreographic Programming](https://www.fabriziomontesi.com/publication/choreographic-programming) (2013)
- [Chorex — Restartable, Language-Integrated Choreographies](https://programming-journal.org/2025/10/20/) (2025)
