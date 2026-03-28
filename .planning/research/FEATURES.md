# Feature Research

**Domain:** DSL / scripting language interpreter — "language of intention," markdown that runs
**Researched:** 2026-03-27
**Confidence:** HIGH (core interpreter features are well-established; Innate-specific differentiators drawn from spec)

---

## Feature Landscape

### Table Stakes (Users Expect These)

Features that any working interpreter must have. Missing these = the interpreter does not function.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Tokenizer / Lexer | All interpreters begin by converting source text into tokens; without this nothing parses | MEDIUM | Innate has unusual token set: `[[]]`, `![]`, `||`, `->`, `@`, `#`, `<emoji>` — must handle bracket depth as part of tokenization, not just nesting counting |
| Parser (recursive descent) | Tokens must become an AST; without an AST the evaluator has nothing to walk | HIGH | Bracket nesting is the core syntactic challenge: `[context[verb[args]]]` is three levels deep. Grammar is defined; a hand-rolled recursive descent parser is appropriate (no external parser generators — AF64) |
| AST node types / type system | Evaluator needs structured representation of each syntactic form | MEDIUM | Node types already enumerated in Phase 1 plan: bracket, agent, bundle, reference, search, fulfillment, emission, decree, wikilink, combinator, lens, kv-pair, modifier, prose, heading, string, number, bare-word, emoji-slot |
| Evaluator (AST walker) | Walks the AST and produces results; the interpreter does nothing without this | HIGH | Must dispatch on node type; CLOS `defmethod` on node kinds is the natural Lisp approach. Must call resolver protocol for any resolution — evaluator itself is generic |
| Resolver protocol (pluggable interface) | Evaluator must delegate resolution to a backend without knowing what that backend is | MEDIUM | CLOS `defgeneric` functions defining the protocol. Innate-specific: separate generics for `resolve-reference`, `deliver-commission`, `search-resource`, `load-bundle` |
| Stub resolver (in-memory, for tests) | Without a working resolver, nothing can be tested end-to-end | LOW | In-memory hash tables for entities, scripts, images. No Postgres, no network. Required to validate parser + evaluator independently |
| Two-pass evaluation (hoisting) | `@` references must resolve to entities defined anywhere in the same script, including later in the file | MEDIUM | First pass: full parse, collect all `decree` declarations. Second pass: evaluate with resolved declarations in scope. This is what allows `@boughrest` before `decree boughrest [...]` |
| Emission (`->`) | The mechanism by which evaluated expressions produce output | LOW | Structural: emission nodes are leaf results in the AST. Evaluator emits them as a sequence. Multi-value emission (`-> 52125, 52`) requires sequence handling |
| Prose passthrough | Non-executable lines must pass through as documentation text without causing parse errors | MEDIUM | Grammar defines `prose := line not matching any other rule`. Parser must gracefully fall through to prose for any line that does not match expression, emission, or decree syntax. This is "markdown that runs" — the prose IS the document |
| Error/resistance model | Some form of structured failure handling is necessary for the interpreter to be usable | MEDIUM | Innate replaces exceptions with two outcomes: Resistance (structural failure, no fulfillment path) and Fulfillment (missing resource triggers agent commission via `||`). Resistance propagates upward through bracket nesting. Implementing this correctly requires clear propagation rules in the evaluator |
| Interactive REPL | Users expect to experiment with expressions interactively | LOW | Read-eval-print loop over stdin/stdout. Innate's REPL is a query context: expressions emit results immediately. Standard: line reader, evaluate, print emission, repeat. Resistance is reported but does not kill the session |
| Test runner + test suite | Without tests the interpreter cannot be validated | MEDIUM | AF64 convention: hand-rolled test runner (no library). Tests at four levels: tokenizer, parser, evaluator, integration (end-to-end `.dpn` files). The `burg_pipeline.dpn` sample is the integration test target |

---

### Differentiators (Competitive Advantage)

Features that make Innate distinct from any other interpreter. These are where the design earns its existence.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Multi-context evaluation (query / scope / commission / render) | The same expression produces different results depending on evaluation context — a query at the REPL, a scope in a template, a commission in the tick engine, a rendered document in the TUI. No other language does this without mode switches | HIGH | Context is an argument to the evaluator, not a mode flag in the syntax. The expression `@type:"[[Burg]]"+all{state:==}` does not change; the evaluator's context parameter does. Requires the evaluator to carry context throughout the walk. This is the core insight of Innate |
| Fulfillment operator (`||`) — missing resources as work orders | When a search fails, `![...] \|\| (agent){instruction}` does not raise an error — it commissions the named agent to create the missing resource. Unresolved searches become demands, not failures | MEDIUM | The `||` operator is not boolean OR — it is "if absent, commission." The evaluator must recognize `fulfillment` AST nodes and, when the search returns nothing, call `deliver-commission` on the resolver. This reframes the error model: the world can be incomplete; Innate asks for it to be completed |
| Purposive sequencing ("IN ORDER TO" semantics) | Block body operations are not "and then" sequences — they exist *in order to* accomplish the goal stated in the block header. The language structurally encodes causal purpose, not just temporal order | HIGH | This is a semantic property, not syntactic. Implementing it requires the evaluator to bind body operations to the result of the outer expression header, not execute them as independent statements. The block header is the *why*; the body operations are the *how*. Few languages model intentionality at all |
| Prepositional addressing vs. method calls | `[db[get_count[entry]]]` reads as "to db, regarding get_count, concerning entry" — not `db.get_count(entry)`. The mental model is delegation (sending a letter) not invocation (calling a function) | LOW | Syntactic differentiator with semantic weight. The bracket nesting model means the outermost context receives everything and decides how to handle it. This matters for agent address: agents receive, they do not execute |
| Prose passthrough as first-class document structure | Lines that don't match any Innate expression are documentation, not errors. A `.dpn` file is simultaneously a specification document and an executable program. The prose is not comments — it is content | MEDIUM | Requires careful grammar design so the parser does not attempt to re-parse prose as expressions. Prose nodes appear in the AST alongside executable nodes. In render context, prose emits as document text. In query context, prose is ignored |
| Wikilinks (`[[]]`) as a native type | Document references in the vault/content graph are a built-in value type, not strings. The interpreter knows that `[[Burg]]` is a reference to a document, not just a string with brackets in it | LOW | Type-level: wikilinks are distinct AST node type. Resolver protocol includes a generic for resolving wikilinks against a document graph. For the stub resolver, wikilinks resolve to their title string. For the noosphere resolver, they traverse the document graph |
| `@` references with hoisting | References (`@boughrest`) resolve anywhere in the same script, even before the decree that defines them. The interpreter fully parses before resolving | MEDIUM | Two-pass requirement (see Table Stakes) is the implementation mechanism. The hoisting behavior means Innate scripts can be written in natural narrative order (use before define), which aligns with the "human-readable document" goal |
| Agent address as delegation, not invocation | `(sylvia)` is not a function call. Agents have judgment — they receive instructions and decide how to carry them out. The parenthesis syntax marks this distinction | LOW | Syntactic: at parse time, agent nodes are distinct from function application. At eval time, `deliver-commission` is called on the resolver — *how* the agent is reached is the resolver's problem, not the evaluator's |
| Decree declarations — persistent structural law | `decree` defines how things *are*, not what to do right now. Decrees are law: types, workflows, routing rules, presentation templates. They persist across evaluations and can be referenced as bundles | MEDIUM | Decrees are collected in the first pass and registered with the interpreter state. They are not executed — they configure the interpreter's understanding of the world. A decree is a named bundle: `{burg_pipeline}` loads the decree named `burg_pipeline` |
| Lenses as grouping/filter syntax inside braces | `{state:==}` and `{state:"Seed"}` are lenses — declarative filters on result sets, written inside the bundle/scope syntax. The same `{}` container serves both as script reference and as inline filter | LOW | Grammar already distinguishes `bundle := '{' bare_word '}'` from `lens := '{' kv_pair '}'`. Evaluator must pattern-match on brace contents to determine whether to load a named script or apply a filter. The dual use is intentional and powerful |
| Emoji slot as native type annotation | `<emoji>` is not a string placeholder — it is a type annotation declaring that a value is of emoji type. Emoji is a native value type in Innate | LOW | Minor but distinctive. The grammar already includes `emoji_slot`. Type checking requires the evaluator to recognize emoji-typed values and handle them distinctly from strings. Matters for Lifestage values like `"<emoji>Seed"` |

---

### Anti-Features (Deliberately Excluded)

Features that look appealing but contradict Innate's design intent. Building these would compromise the core value.

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| General-purpose programming constructs (loops, conditionals, arithmetic) | "Every language needs if/else and loops" | Innate is a language of intention, not a computation engine. Adding control flow turns it into yet another scripting language — it loses the human-readability guarantee and gains all the complexity of a general-purpose language | Use purposive block bodies (`IN ORDER TO` semantics) for sequencing. Use agent address and fulfillment for branching: `![...] \|\| (agent){handle the other case}`. The resolver handles computation |
| Hardcoded infrastructure references (Postgres, noosphere names, file paths) | "We know the target system, let's be specific" | Breaks the generic/public constraint. Innate's value is that it is deployable against any resolver. Hardcoding infrastructure means the language only works for one deployment | The resolver protocol is the abstraction layer. Named contexts (`db`, `noosphere`) are symbols the resolver maps to real infrastructure — not hardcoded in the language |
| External Lisp library dependencies (Quicklisp, external parsers) | "Why hand-roll when libraries exist?" | AF64 convention: zero external dependencies. More importantly, external libraries create deployment friction when Innate is embedded in the ghost tick engine. SBCL's built-in facilities plus ASDF are sufficient for a recursive descent parser and CLOS-based evaluator | Hand-rolled tokenizer and parser. CLOS for dispatch. SBCL's reader for Lisp data when needed. ASDF for system definition |
| Debugger / step execution (v1) | "Developers need to step through programs" | Correct, but premature. A debugger requires stable AST structure, stable evaluation semantics, and a working resolver. Building debugger infrastructure before the core interpreter is validated adds complexity that can block progress | Build a debugger hook in the evaluator's core loop (a callback point at each node evaluation) as a design affordance. Implement actual debugging in a later phase when the language semantics are stable |
| LSP / syntax highlighting (v1) | "Editors need LSP support for developer adoption" | LSP requires a stable, versioned grammar and a working parser that can handle partial/ill-formed input gracefully. Building LSP before the grammar is finalized means rewriting it. Syntax highlighting can be approximated by any editor that supports custom token patterns | Provide a `.tmLanguage` or simple regex-based token definition for editor highlighting in a later phase. Design the tokenizer with LSP in mind (preserve source positions in tokens) but do not build the server yet |
| Live reload / file watching | "Developers want instant feedback when saving `.dpn` files" | Live reload in v1 adds filesystem-watching complexity on top of an unvalidated interpreter. The REPL already provides interactive feedback. File watching belongs in the laptop CLI phase, not the interpreter core | The stub resolver + REPL provides fast feedback. Add `innate watch` in the CLI phase after core is stable |
| Template parameters / explicit parameter syntax | "Templates need to accept arguments" | The current design handles this through `@` references as free variables bound by the caller's context. Adding explicit parameter syntax requires a function-definition model that conflicts with the "decree, not function" philosophy | Free variable binding via `@` and the caller's declaration scope. The resolver's context provides bindings. If parameter syntax proves necessary, add it as a `with` clause on bracket expressions in a later spec iteration |
| Metacircular evaluator (Innate interpreting itself) | "Every serious language needs a metacircular evaluator" | This is the dream (Phase 6 in the bootstrapping arc), not v1. Building it early requires the language to be expressive enough to describe its own evaluation — that requires stable semantics, working resolver, and production usage | Build toward it. Design the AST so it is expressible in Innate syntax. But defer until the language is mature enough to not require constant changes |
| Exception-based error handling | "Developers expect try/catch" | This directly contradicts the resistance/fulfillment error model. Adding exceptions would create two parallel error paths and undermine the intentional design | Resistance + fulfillment covers all cases: structural failures propagate via resistance; missing resources are handled via `||` fulfillment. The REPL reports resistance without killing the session |

---

## Feature Dependencies

```
Tokenizer
    └──required-by──> Parser
                          └──required-by──> AST node types (must exist before parser produces them)
                          └──required-by──> Evaluator
                                                └──required-by──> Resolver protocol (interface)
                                                                       └──required-by──> Stub resolver
                                                                       └──required-by──> REPL

Two-pass evaluation
    └──requires──> Parser (full parse first)
    └──requires──> Decree declaration collection (first pass output)
    └──enables──> @ reference hoisting

Fulfillment operator (||)
    └──requires──> Search directive (![] evaluation)
    └──requires──> Agent address (resolver deliver-commission)
    └──enables──> Missing resource → work order pattern

Prose passthrough
    └──requires──> Parser (fall-through grammar rule)
    └──enables──> Multi-context evaluation (prose renders in document context, silenced in query context)

Multi-context evaluation
    └──requires──> Evaluator (context argument)
    └──requires──> Prose passthrough (render context)
    └──requires──> Fulfillment operator (commission context)
    └──enables──> Living template pattern (.dpn as document + query + workflow)

Decree declarations
    └──requires──> Two-pass evaluation (decrees collected in first pass)
    └──enables──> Bundle references ({burg_pipeline} loads a registered decree)
    └──enables──> Purposive sequencing (decree header = the "why")

Wikilinks as native type
    └──requires──> AST node types (wikilink node)
    └──requires──> Resolver protocol (wikilink resolution generic)
    └──enables──> Document graph traversal (noosphere resolver concern, not v1)

Test suite
    └──requires──> Tokenizer (tokenizer tests first)
    └──requires──> Parser (parser tests)
    └──requires──> Evaluator + stub resolver (evaluator tests)
    └──requires──> burg_pipeline.dpn (integration test)

REPL
    └──requires──> Full pipeline: tokenizer + parser + evaluator + stub resolver
    └──enables──> Interactive experimentation and validation

LSP (future)
    └──requires──> Stable grammar (not v1)
    └──requires──> Source position preservation in tokenizer (design affordance in v1)
```

### Dependency Notes

- **Tokenizer requires nothing:** It is the foundation. Build first.
- **Prose passthrough requires careful parser design:** The fall-through grammar rule must be implemented in the parser, not bolted on afterward. Design the parser with prose as a named production from the start.
- **Two-pass evaluation enables hoisting, but adds evaluator complexity:** The evaluator must accept a pre-resolved declaration context rather than building scope incrementally. This is a core architectural decision that affects every other feature.
- **Multi-context evaluation conflicts with single-pass execution:** Cannot evaluate lazily; must know context before beginning evaluation. Context is an argument to the top-level evaluator call.
- **Fulfillment operator requires resolver involvement:** The `||` operator cannot be implemented in the evaluator alone — it calls `deliver-commission` on the resolver. The stub resolver's commission delivery is a no-op or log statement. This is correct: v1 validates the protocol, not the delivery.

---

## MVP Definition

### Launch With (v1)

Minimum viable interpreter — what is needed to validate that Innate works.

- [ ] Tokenizer that handles full symbol vocabulary (`[]`, `()`, `{}`, `@`, `![]`, `||`, `->`, `[[]]`, `<emoji>`, `#`, `+`, `:`) — why essential: nothing else works without it
- [ ] Recursive descent parser producing a typed AST — why essential: tokenizer output is not executable
- [ ] All AST node types defined (per Phase 1 plan) — why essential: parser and evaluator must agree on structure
- [ ] Two-pass evaluator with hoisting (collect decrees first, then evaluate) — why essential: `@` reference model requires it
- [ ] Resolver protocol (CLOS generics: `resolve-reference`, `deliver-commission`, `search-resource`, `load-bundle`, `resolve-wikilink`) — why essential: evaluator has nowhere to dispatch without the protocol
- [ ] Stub resolver (in-memory hash tables, no network, no filesystem) — why essential: tests cannot run without a resolver
- [ ] Prose passthrough (non-expression lines become prose AST nodes) — why essential: this is the "markdown that runs" promise; failing to parse prose means `.dpn` files are not documents
- [ ] Resistance model (structural failures propagate; `||` fulfillment commissions agent) — why essential: without an error model, the interpreter is not safe to run
- [ ] Emission (`->`) produces output — why essential: without emission, programs have no visible effect
- [ ] `decree` declarations (collected in first pass, available as bundle references) — why essential: `{burg_pipeline}` is in the canonical example; decrees are the structural foundation
- [ ] Interactive REPL over stdin/stdout — why essential: the primary interface for validation; without it the interpreter is a black box
- [ ] Test suite (tokenizer, parser, evaluator, integration against `burg_pipeline.dpn`) — why essential: the interpreter cannot be shipped without validation

### Add After Validation (v1.x)

Features to add once the core interpreter is working and the spec has stabilized.

- [ ] Source position preservation in AST nodes — trigger: LSP design work begins; positions are needed for diagnostics and hover
- [ ] Chained fulfillment (`![...] || (a){...} || (b){escalate}`) — trigger: spec clarifies whether `||` chains; stub resolver needs multi-agent fallback test
- [ ] Template free variable binding (how `@burg_name` receives its value in a living template) — trigger: living template feature is validated; requires spec decision on whether binding is explicit or context-passed
- [ ] `#` heading / presentation directives (render context) — trigger: render context evaluation is implemented; headings are low complexity but require render context first

### Future Consideration (v2+)

Deferred until the language semantics are stable and the noosphere resolver exists.

- [ ] LSP server (diagnostics, completion, go-to-definition) — why defer: grammar must be stable; partial parse handling adds significant complexity; not needed for core use case
- [ ] Debugger / step execution — why defer: requires stable AST, stable eval semantics, and a real use case to drive the UI
- [ ] Laptop CLI (`innate push`, `innate eval`, `innate watch`) — why defer: CLI is for the droplet integration phase; core interpreter does not need it
- [ ] Metacircular evaluator (Innate interpreting itself) — why defer: Phase 6 in the bootstrapping arc; language must be mature and production-tested first
- [ ] `.tmLanguage` / syntax highlighting grammar — why defer: useful for adoption but adds no interpreter capability; generate from the tokenizer's token vocabulary when ready

---

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| Tokenizer | HIGH | MEDIUM | P1 |
| Parser | HIGH | HIGH | P1 |
| AST node types | HIGH | MEDIUM | P1 |
| Two-pass evaluator with hoisting | HIGH | HIGH | P1 |
| Resolver protocol (CLOS generics) | HIGH | MEDIUM | P1 |
| Stub resolver | HIGH | LOW | P1 |
| Prose passthrough | HIGH | MEDIUM | P1 |
| Resistance/fulfillment error model | HIGH | MEDIUM | P1 |
| Emission (`->`) | HIGH | LOW | P1 |
| Decree declarations | HIGH | MEDIUM | P1 |
| Interactive REPL | HIGH | LOW | P1 |
| Test suite | HIGH | MEDIUM | P1 |
| Multi-context evaluation (query/scope/commission/render) | HIGH | HIGH | P1 |
| Source position in AST nodes | MEDIUM | LOW | P2 |
| Chained fulfillment | MEDIUM | LOW | P2 |
| Template free variable binding | HIGH | MEDIUM | P2 |
| Heading / presentation directives | MEDIUM | LOW | P2 |
| LSP server | MEDIUM | HIGH | P3 |
| Debugger | MEDIUM | HIGH | P3 |
| Laptop CLI | HIGH | MEDIUM | P3 |
| Syntax highlighting grammar | LOW | LOW | P3 |
| Metacircular evaluator | HIGH | HIGH | P3 |

**Priority key:**
- P1: Must have for v1 (the interpreter does not work without it)
- P2: Should have, add in v1.x after core is validated
- P3: Future consideration, v2+

---

## Competitor Feature Analysis

Innate has no direct competitor — no other language simultaneously serves as query, workflow scope, UI definition, and prose document. The closest analogues are:

| Feature | Org mode (Emacs) | Jupyter Notebook | MDX | Innate Approach |
|---------|-----------------|------------------|-----|-----------------|
| Prose + code in same file | Yes (noweb) | Yes (markdown cells) | Yes (JSX in markdown) | Yes — prose is first-class AST node, not a comment or cell |
| Executable expressions | Via `#+BEGIN_SRC` code blocks, explicit language tag | Via code cells with kernel | Via JSX evaluation | Any line matching Innate syntax executes; no block delimiters needed |
| Forward references / hoisting | No — evaluation is sequential | No — cells execute in order | No | Yes — two-pass evaluation; `@` references hoist to any position in script |
| Missing resource handling | No — errors if resource absent | No — errors | No | `||` fulfillment operator commissions agents to create missing resources |
| Multi-context evaluation | No — code blocks execute, prose renders | No — cells are either code or markdown | No | Same expression is query / scope / commission / render depending on context argument |
| Pluggable backends | Via org-babel language executors | Via kernels (Jupyter protocol) | Via framework | CLOS generic function resolver protocol; zero coupling between language and backend |
| Error model | Exceptions / eval errors | Python/R/Julia exceptions | JS exceptions | Resistance propagation + fulfillment; no exceptions |
| Declarative structure definition | No | No | No | `decree` declarations: persistent structural law |
| Agent delegation | No | No | No | `(agent)` address syntax; agents receive instructions with judgment |

**Key insight from comparison:** Every existing "literate programming" tool treats prose as documentation and code as computation, with a hard boundary between them. Innate has no such boundary — every line is simultaneously a potential expression and a piece of the document. This is the architectural distinguisher.

---

## Sources

- [Crafting Interpreters — Resolving and Binding](https://craftinginterpreters.com/resolving-and-binding.html) — two-pass resolution, hoisting patterns
- [Literate Programming — Wikipedia](https://en.wikipedia.org/wiki/Literate_programming) — Knuth's original literate programming design
- [Joe Duffy — The Error Model](https://joeduffyblog.com/2016/02/07/the-error-model/) — comprehensive treatment of exception alternatives (Result types, return codes, discriminated unions)
- [The Common Lisp Cookbook — Fundamentals of CLOS](https://lispcookbook.github.io/cl-cookbook/clos.html) — CLOS generic functions and defmethod dispatch
- [Language Server Protocol Specification 3.17](https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/) — LSP capabilities for DSL integration
- [Entangled — Literate Programming in Markdown](https://entangled.github.io/) — modern markdown-that-runs tool for comparison
- [A Debugger is a REPL is a Debugger](https://matklad.github.io/2025/03/25/debugger-is-repl-is-debugger.html) — REPL and debugger convergence patterns
- [ASDF Manual](https://asdf.common-lisp.dev/asdf.html) — ASDF system definition for zero-dependency Common Lisp builds
- Innate Language Design Spec, `docs/specs/2026-03-27-innate-language-design.md` — primary source for all Innate-specific features
- Innate PROJECT.md, `.planning/PROJECT.md` — active requirements and constraints

---
*Feature research for: Innate — DSL / scripting language interpreter*
*Researched: 2026-03-27*
