# Project Research Summary

**Project:** Innatescript — Innate Scripting Language Interpreter
**Domain:** DSL / scripting language interpreter in Common Lisp (SBCL), zero external dependencies
**Researched:** 2026-03-27
**Confidence:** HIGH

## Executive Summary

Innate is a novel DSL ("language of intention") implemented as a Common Lisp interpreter on SBCL with a strict zero-external-dependencies constraint. Unlike general-purpose scripting languages or literate programming tools, Innate treats prose as first-class AST nodes and evaluates the same expression differently depending on evaluation context (query, scope, commission, or render). The recommended implementation approach is a hand-rolled recursive descent parser feeding a two-pass CLOS-based evaluator, with the resolver backend abstracted behind a `defgeneric` protocol — keeping the core interpreter entirely decoupled from Postgres, noosphere infrastructure, or any other deployment-specific backend.

The design has four foundational decisions that must be made in Phase 1 and cannot easily be reversed: (1) the two-pass hoisting architecture that enables `@reference` before declaration; (2) the CLOS generic function boundary at the resolver interface with `etypecase` dispatch inside the evaluator for performance; (3) the stateful lexer that resolves the `[[` wikilink vs. nested bracket ambiguity; and (4) a single `packages.lisp` loaded first in ASDF that defines all package namespaces before any implementation files are compiled. Getting these right in Phase 1 eliminates the five highest-recovery-cost pitfalls.

The key risk is scope creep: once the interpreter is functional, the temptation to add conditionals, iteration, or arithmetic will be strong. Every such addition violates the "a human unfamiliar with programming should understand what this does" constraint and migrates Innate from a purposive language toward a general-purpose language with inferior tooling. The PROJECT.md Out of Scope list must be reviewed at every milestone and treated as a governing constraint, not a preference. Given well-established interpreter implementation patterns and high-confidence sources for ASDF, CLOS, and recursive descent parsing in Common Lisp, the technical risk is low. The language design risk — keeping Innate's unique semantics intact through implementation — is where discipline is required.

## Key Findings

### Recommended Stack

The entire interpreter is implemented in SBCL Common Lisp using only ANSI CL facilities and ASDF (bundled with SBCL — not an external dependency). No Quicklisp, no external parser generators, no external test frameworks. This is both the AF64 project constraint and the technically correct choice for an interpreter whose grammar is irregular enough that parser generators would fight the prose-passthrough design rather than help it.

The resolver protocol — the only external interface — is defined as CLOS `defgeneric` functions in `innate/resolver`. All other evaluation dispatch uses `etypecase` inside the evaluator for SBCL-compiled jump-table performance. Interactive REPL line editing is handled by `rlwrap` at the shell level (zero Lisp code, available on Arch as `pacman -S rlwrap`).

**Core technologies:**
- **SBCL 2.x**: Implementation runtime — native compilation, fast, no impedance mismatch since ghosts already run on it
- **ASDF 3.3+ (bundled)**: Build and system definition — zero install friction; explicit `:depends-on` per component, not `:serial t`
- **Hand-rolled recursive descent parser**: Precise control over error messages, natural prose passthrough via fall-through grammar rule, no external parser generator
- **CLOS `defgeneric` (resolver boundary only)**: Pluggable backend protocol — evaluator calls generics, never imports a concrete resolver
- **`etypecase` (internal evaluator dispatch)**: SBCL compiles to a jump table; CLOS dispatch on every AST node walk is measurably slow
- **Hand-rolled 40-line test harness**: Based on Seibel's PCL framework; zero deps; `deftest` / `check` / `combine-results` macros cover everything needed
- **`rlwrap` (shell-level)**: REPL line editing — history, editing, zero Lisp code

### Expected Features

**Must have (table stakes — interpreter does not function without these):**
- Tokenizer/lexer handling full symbol vocabulary (`@`, `![]`, `||`, `->`, `[[]]`, `[]`, `()`, `{}`, `<emoji>`, `#`, `+`, `:`)
- Recursive descent parser producing typed AST
- All 18+ AST node types defined (bracket, agent, bundle, reference, search, fulfillment, emission, decree, wikilink, combinator, lens, kv-pair, modifier, prose, heading, string, number, bare-word, emoji-slot)
- Two-pass evaluator with hoisting (collect decrees in pass 1, evaluate in pass 2)
- Resolver protocol (`defgeneric`: `resolve-reference`, `resolve-search`, `fulfill-commission`, `resolve-decree`, `resolve-wikilink`)
- Stub resolver (in-memory hashtables, no network, no filesystem)
- Prose passthrough (non-expression lines become `prose-node` AST nodes, never silently dropped)
- Resistance/fulfillment error model (structural failures propagate; `||` commissions an agent rather than erroring)
- Emission (`->`) producing output sequences
- `decree` declarations collected in first pass, available as bundle references
- Interactive REPL over stdin/stdout (via `rlwrap` shell wrapper)
- Test suite at four levels: tokenizer, parser, evaluator, integration against `burg_pipeline.dpn`

**Should have (differentiators — what makes Innate worth building):**
- Multi-context evaluation: same expression yields different results in query / scope / commission / render contexts
- Fulfillment operator (`||`) as missing-resource work order, not boolean OR
- Purposive sequencing: block bodies exist *in order to* accomplish the header goal, not as sequential statements
- Wikilinks (`[[]]`) as a native value type distinct from strings
- `@` reference hoisting across the entire script regardless of declaration order
- Prepositional bracket addressing (`[db[get_count[entry]]]`) vs. method call semantics
- Emoji slot (`<emoji>`) as a native type annotation

**Defer (v2+):**
- LSP server — requires stable, versioned grammar; partial parse handling adds significant complexity
- Debugger / step execution — requires stable AST and eval semantics
- Laptop CLI (`innate push`, `innate eval`, `innate watch`) — CLI is for the droplet integration phase
- Syntax highlighting grammar (`.tmLanguage`) — useful for adoption, adds no interpreter capability
- Metacircular evaluator — Phase 6 in the bootstrapping arc; language must be mature first
- Template explicit parameter syntax — current design handles via `@` free variables

### Architecture Approach

The architecture is a classic pipeline (tokenizer → parser → evaluator) with a formal protocol boundary at the resolver layer. The evaluator never imports a concrete resolver — only the `innate/resolver` package of `defgeneric` declarations. Entry points (REPL, script runner) assemble the full pipeline at runtime by injecting a resolver instance. A `packages.lisp` file defining all `defpackage` forms loads first in ASDF; every other file starts with `(in-package :innate.COMPONENT)` and uses explicit `:import-from` rather than `:use`-ing other application packages.

**Major components and build order:**
1. `innate/conditions` — all `define-condition` forms; no system imports
2. `innate/ast` — `defstruct` hierarchy for all AST node types; imports conditions
3. `innate/tokenizer` — text to token stream; pure functions, no state, imports conditions
4. `innate/parser` — token stream to AST; recursive descent; imports ast, tokenizer, conditions
5. `innate/environment` — evaluation environment struct (resolver, decrees hashtable, bindings alist, scope); imports ast
6. `innate/resolver` — `defgeneric` protocol only; no implementations; imports ast, environment, conditions
7. `innate/evaluator` — two-pass AST walker; `etypecase` dispatch; calls resolver generics; imports resolver, environment, ast, conditions
8. `innate/stub-resolver` — in-memory hashtable implementation of resolver protocol; for tests and default REPL
9. `innate/repl` — assembles full pipeline; handles conditions; provides `:quit`, `:resolver`, `:reset` meta-commands
10. `innate` (api.lisp) — re-export surface only; no implementation logic; what external consumers import

### Critical Pitfalls

1. **`[[` wikilink vs. nested bracket ambiguity** — Use a stateful lexer with context modes: emit `WIKILINK-OPEN` only when `[[` appears in top-level/prose context; emit `LBRACKET` when already inside an open bracket. Test `[[Burg]]`, `[[@thing]]`, and `[[x]]+[y]` at the very start of tokenizer work — never later.

2. **Two-pass hoisting divergence** — Colocate collection-pass and evaluation-pass dispatch so adding a new node type forces updating both. Write a forward-reference test for every node type (definition after use) before the parser is considered complete. Never add a node type to the evaluator without checking the collection pass.

3. **CLOS generic dispatch on every AST node** — Reserve CLOS for the resolver protocol boundary only. Internal AST evaluation uses `etypecase` which SBCL compiles to a jump table. This is an architectural decision that is expensive to reverse — make it at the start of Phase 1.

4. **Recursive descent operator associativity bug** — `->` emission chains require left associativity; the natural right-recursive descent rule gives right associativity. Use iterative loops (`loop while (next-is-op) collect ...`) not mutual recursion for infix operators. Test three-step chains (`a -> b -> c`) before considering the parser complete.

5. **DSL scope creep** — Innate has no loops, no conditionals, no arithmetic by design. Every request to add general-purpose constructs must be evaluated against: "Can a human unfamiliar with programming understand what this does?" The PROJECT.md Out of Scope list is the governing constraint at every milestone.

6. **CL package symbol conflicts** — All `defpackage` forms in a single `packages.lisp` loaded first. Use `:use (:cl)` only; import inter-package symbols with explicit `:import-from`. Never name symbols the same as CL exports unless intentionally shadowing.

7. **ASDF cold-load failures** — A shell script that removes the fasl cache (`rm -rf ~/.cache/common-lisp/`) and runs `sbcl --eval "(asdf:load-system :innatescript)"` must exist and pass before any feature work begins. REPL-driven development masks loading order bugs.

8. **Resolver protocol leakage** — Write the resolver protocol spec (documented call signatures, return types, "not found" behavior, "fulfillment required" behavior) before writing any resolver implementation. Write a conformance test suite that any correct resolver must pass. The stub resolver is a conforming implementation, not a test fixture.

## Implications for Roadmap

Based on combined research, all nine pitfalls map to Phase 1. This is not accidental: the research is unanimous that architectural decisions made in the first phase are the ones with the highest recovery cost. The roadmap should reflect this by making Phase 1 a deep, unhurried foundation phase — not a "get something running" sprint.

### Phase 1: Foundation — Scaffolding, Conditions, AST, Tokenizer

**Rationale:** Every other component depends on the package namespace, condition hierarchy, AST node definitions, and correct tokenization. The `[[` lexer ambiguity must be resolved before any other token type is built. Package conflicts discovered mid-project require touching every source file. Build order is strictly: packages → conditions → ast → tokenizer.

**Delivers:** A loadable ASDF system with zero warnings; all package namespaces defined; all 18+ AST node types as `defstruct` instances; tokenizer that correctly handles the full Innate symbol vocabulary including `[[` wikilinks; structured condition types for parse, resolution, and fulfillment errors; cold-load test script passing.

**Addresses:** Tokenizer (table stakes), AST node types (table stakes)

**Avoids:** `[[` ambiguity (critical), package symbol conflicts (critical), ASDF loading order failures (critical), error messages as afterthought (critical)

**Research flag:** Standard patterns — well-documented recursive descent lexer and ASDF scaffolding. Skip `/gsd:research-phase`.

---

### Phase 2: Parser — Recursive Descent, Prose Passthrough, Expression Grammar

**Rationale:** Parser depends on the tokenizer and AST from Phase 1. The expression grammar — including operator associativity for `->`, `+`, `||`, `:` — must be locked in before the evaluator is written. Prose passthrough must be a named grammar production from the start, not bolted on afterward. Three-step chain tests for every infix operator must pass before Phase 2 is considered complete.

**Delivers:** Recursive descent parser producing typed AST from any valid `.dpn` input; prose passthrough as `prose-node` in the AST; correct left-associative expression grammar for all infix operators; structured parse error conditions with source positions; test suite for parser.

**Addresses:** Parser (table stakes), prose passthrough (table stakes and differentiator)

**Avoids:** Operator associativity bug (critical), prose as special case in evaluator (anti-pattern)

**Research flag:** Standard patterns — well-documented recursive descent. Skip `/gsd:research-phase`.

---

### Phase 3: Resolver Protocol + Stub Resolver + Environment

**Rationale:** The resolver protocol must be defined before the evaluator, because the evaluator calls protocol generics. Writing the protocol spec (not just the code) before the stub forces clarity about contracts. The stub is then written to the spec, not to make evaluator tests pass. The evaluation environment struct is defined here as well — it carries the resolver instance through the evaluator.

**Delivers:** Written resolver protocol specification; `innate/resolver` package with documented `defgeneric` forms; `innate/environment` struct; `innate/stub-resolver` in-memory implementation; resolver conformance test suite that stub passes.

**Addresses:** Resolver protocol (table stakes), stub resolver (table stakes)

**Avoids:** Resolver protocol leakage (critical), evaluator importing concrete resolver (anti-pattern)

**Research flag:** CLOS generic protocol is a standard pattern. Conformance test suite structure may benefit from a brief `/gsd:research-phase` if prior art for CL resolver conformance suites is desired — otherwise standard patterns apply.

---

### Phase 4: Evaluator — Two-Pass, `etypecase` Dispatch, Error Model

**Rationale:** Evaluator requires all components from Phases 1-3. The two-pass hoisting architecture and `etypecase`-vs-CLOS dispatch decision must be made here and documented as architecture decisions — they cannot be reversed cheaply. The resistance/fulfillment error model maps to CL conditions: `innate-resolution-error` is a `serious-condition`; `innate-fulfillment-signal` is a signal (not an error).

**Delivers:** Two-pass evaluator with hoisting (decree collection in pass 1, full evaluation in pass 2); `etypecase` dispatch on AST node types; `defmethod eval-node` for every node type including prose (returns nil); resistance propagation via `innate-resolution-error`; `||` fulfillment calling `fulfill-commission` on the resolver; emission (`->`) producing output sequences; test suite at evaluator level including forward-reference tests for all node types.

**Addresses:** Two-pass evaluator with hoisting (table stakes), resistance/fulfillment error model (table stakes), emission (table stakes), decree declarations (table stakes), multi-context evaluation (differentiator), fulfillment operator (differentiator)

**Avoids:** Two-pass hoisting divergence (critical), CLOS dispatch performance (critical), mixing error condition types (anti-pattern)

**Research flag:** Two-pass evaluation and CL condition system are well-documented. The multi-context evaluation (same expression yields different results in query/scope/commission/render) is Innate-specific and has no prior art to research — it will require implementation-time design decisions. Consider a design spike during this phase.

---

### Phase 5: REPL — Pipeline Assembly, Interactive Loop, Error Recovery

**Rationale:** REPL is the final integration point that assembles the full pipeline. It is the primary interface for validating that the interpreter works end-to-end. The REPL must never crash on bad input — structured condition handling at the loop level prevents `innate-parse-error` or `innate-resolution-error` from propagating to SBCL.

**Delivers:** Interactive `read-line` loop with `rlwrap` shell wrapper; handler for all interpreter conditions (parse errors return to prompt, resolution errors print and continue, fulfillment signals print "commission queued"); `:quit`, `:resolver`, `:reset` meta-commands; integration test against `burg_pipeline.dpn` end-to-end; `innate` public API re-export surface.

**Addresses:** Interactive REPL (table stakes), test suite integration level (table stakes)

**Avoids:** REPL crashing on bad input (critical), REPL operating in wrong package (integration gotcha)

**Research flag:** Standard REPL loop patterns. Skip `/gsd:research-phase`.

---

### Phase Ordering Rationale

- The build order (conditions → ast → tokenizer → parser → environment → resolver → evaluator → stub-resolver → repl) is dictated by compile-time symbol dependencies — this is not a preference, it is the load graph
- All critical pitfalls are Phase 1 concerns, justifying a longer Phase 1 with explicit acceptance criteria before any parser work begins
- Resolver protocol is defined before the evaluator (Phase 3 before Phase 4) because the evaluator calls generics that must already be declared
- The stub resolver ships in Phase 3 so Phase 4 evaluator tests have a working backend from the first day of evaluator work
- REPL is last because it is the only component that imports all others — it is the integration test, not a foundation

### Research Flags

Phases needing deeper research during planning:
- **Phase 4 (multi-context evaluation):** Innate's context-as-argument evaluation model has no direct analog in documented interpreter patterns. The design needs a spike to validate how context threading interacts with decree bodies and nested bracket evaluation.

Phases with standard patterns (skip research-phase):
- **Phase 1** — ASDF scaffolding, recursive descent lexers, CL package design: all well-documented with HIGH-confidence sources
- **Phase 2** — Recursive descent parsers: canonical literature (Crafting Interpreters, Eli Bendersky) covers all cases
- **Phase 3** — CLOS defgeneric protocol and in-memory stub implementations: standard Common Lisp patterns
- **Phase 5** — REPL loop: standard read-eval-print pattern with CL `handler-case`

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | Core technologies (SBCL, ASDF, hand-rolled parser, CLOS, rlwrap) are verified with HIGH-confidence official sources; REPL implementation patterns are MEDIUM but well-covered |
| Features | HIGH | Table stakes are derived from well-established interpreter implementation patterns; Innate-specific differentiators are drawn directly from the language design spec (primary source) |
| Architecture | HIGH | Component boundaries, build order, and CLOS/etypecase dispatch decision are based on authoritative ASDF and CLOS documentation; the resolver protocol pattern is standard CLOS idiom |
| Pitfalls | HIGH (parser/CL-specific), MEDIUM (DSL scope discipline) | Lexer ambiguity, package conflicts, ASDF loading, CLOS performance, and associativity bugs have HIGH-confidence foundational sources; DSL scope creep mitigation is drawn from real-world DSL case studies (MEDIUM) |

**Overall confidence:** HIGH

### Gaps to Address

- **Multi-context evaluation design:** The research identifies this as an Innate-specific differentiator with no direct prior art to cite. How context threading interacts with nested bracket evaluation and decree body evaluation will require a design spike during Phase 4. Add this as a task in Phase 4 planning.

- **`||` chaining semantics:** The spec is not yet clear on whether `![...] || (a){...} || (b){escalate}` chains are supported in v1. The evaluator and stub resolver need a spec decision before the `||` fulfillment operator is implemented. Flag for spec clarification before Phase 4 begins.

- **Template free variable binding:** How `@burg_name` receives its value in a living template (is binding explicit or context-passed?) is unresolved. Listed as v1.x in features research but the evaluator architecture may need an affordance for it in Phase 4. Flag for spec decision during or before Phase 4.

- **`defstruct` vs. `defclass` for AST nodes:** STACK.md recommends `defclass` for REPL-friendly live redefinition; ARCHITECTURE.md uses `defstruct` for performance and simplicity. Both are valid; the choice should be documented as an explicit architecture decision in Phase 1 and committed to. The research presents both cases; the implementer must decide.

## Sources

### Primary (HIGH confidence)
- [SBCL User Manual 2.6.2](https://www.sbcl.org/manual/) — runtime reference
- [ASDF Best Practices](https://github.com/fare/asdf/blob/master/doc/best_practices.md) — explicit deps, test system separation
- [ASDF Manual](https://asdf.common-lisp.dev/asdf.html) — system definition reference
- [Practical Common Lisp: Building a Unit Test Framework](https://gigamonkeys.com/book/practical-building-a-unit-test-framework.html) — `deftest`/`check`/`combine-results` macros
- [CL Cookbook: Defining Systems](https://lispcookbook.github.io/cl-cookbook/systems.html) — ASDF patterns
- [CL Cookbook: Fundamentals of CLOS](https://lispcookbook.github.io/cl-cookbook/clos.html) — defgeneric protocol
- [Crafting Interpreters: Resolving and Binding](https://craftinginterpreters.com/resolving-and-binding.html) — two-pass resolution, hoisting patterns
- [Common Lisp Tips: The Four Causes of Symbol Conflicts](https://lisptips.com/post/34436452765/the-four-causes-of-symbol-conflicts) — CL package conflicts
- [ASDF 3 Upgrade Pitfalls](https://asdf.common-lisp.dev/asdf/Pitfalls-of-the-upgrade-to-ASDF-3.html) — ASDF cold-load behavior
- [Eli Bendersky: Some Problems of Recursive Descent Parsers](https://eli.thegreenplace.net/2009/03/14/some-problems-of-recursive-descent-parsers) — associativity and operator precedence
- [Maximal Munch — Wikipedia](https://en.wikipedia.org/wiki/Maximal_munch) — lexer ambiguity theory
- [Two-Pass Assembler: Forward References (Iowa)](https://homepage.cs.uiowa.edu/~jones/syssoft/notes/04fwd.html) — foundational two-pass theory
- Innate Language Design Spec (`docs/specs/2026-03-27-innate-language-design.md`) — primary source for Innate-specific semantics
- Innate PROJECT.md (`.planning/PROJECT.md`) — active requirements and constraints

### Secondary (MEDIUM confidence)
- [CL Crafting Interpreters](https://github.com/gwangjinkim/cl-crafting-interpreters) — CLOS-based evaluator pattern
- [CL Cookbook: Testing](https://lispcookbook.github.io/cl-cookbook/testing.html) — framework comparison
- [CL Cookbook: Performance Tuning](https://lispcookbook.github.io/cl-cookbook/performance.html) — CLOS dispatch benchmarks
- [Abstract Heresies: defclass vs defstruct (2025)](http://funcall.blogspot.com/2025/03/defclass-vs-defstruct.html) — performance tradeoff analysis
- [Comparison of CL Testing Frameworks (2023)](https://sabracrolleton.github.io/testing-framework) — 1am/fiveam data
- [Joe Duffy: The Error Model](https://joeduffyblog.com/2016/02/07/the-error-model/) — exception alternatives
- [Parsing Ambiguity: Type Argument vs Less Than (Keleshev)](https://keleshev.com/parsing-ambiguity-type-argument-v-less-than) — analogous bracket ambiguity case
- [WebDSL Lessons Learned — InfoQ](https://www.infoq.com/news/2008/05/webdsl-case-study/) — real-world DSL scope discipline
- [DSL Lessons Learned — Wile (academic)](https://john.cs.olemiss.edu/~hcc/csci555/notes/localcopy/WileLessonsLearnedDSL.pdf) — DSL design principles
- [awesome-cl](https://github.com/CodyReichert/awesome-cl) — CL ecosystem survey

---
*Research completed: 2026-03-27*
*Ready for roadmap: yes*
