# Pitfalls Research

**Domain:** Language interpreter / DSL in Common Lisp (SBCL)
**Researched:** 2026-03-27
**Confidence:** HIGH (parser/CL-specific), MEDIUM (DSL scope discipline)

---

## Critical Pitfalls

### Pitfall 1: The `[[` Wikilink vs Nested Bracket Ambiguity

**What goes wrong:**
The lexer sees `[[` and cannot decide in a context-free way whether it is opening a wikilink token or opening two nested bracket expressions. If the tokenizer greedily consumes `[[` as a wikilink opener (maximal munch), it will misparse `[[ some-expression ]]` that is genuinely a nested bracket. Conversely, if it does not, every wikilink requires parser-level disambiguation — the complexity migrates from the lexer to the parser, and error messages become incomprehensible.

Innate has this exact conflict: `[[Burg]]` is a wikilink native type, while `[]` is the place container. A naive lexer will either swallow `[` tokens into wikilink state and corrupt place expressions, or defer the decision and force the parser to track ambiguous state.

**Why it happens:**
Maximal munch — the standard rule that a lexer should consume as many characters as possible — is correct for most tokens but breaks when two valid token sequences share a prefix. This is the same bug that plagued C++ with `>>` in template parameters (fixed in C++11) and C with `/*` in arithmetic expressions.

**How to avoid:**
Use a stateful lexer with context modes. When the lexer is inside a `[` bracket expression, treat a following `[` as `LBRACKET` (not wikilink start). Only emit `WIKILINK-OPEN` when `[[` appears in "top-level prose" or "expression start" mode. Alternatively, use a single-pass recursive descent parser (no separate lexer phase) where the parser directly controls what the next token means based on current parse state — this eliminates the lexer/parser split and the ambiguity disappears.

A second option: reserve `[[...]]` as a distinct syntactic form that can only appear at expression-start positions, making the grammar unambiguous. If `[[` can never appear inside an open `[`, there is no conflict.

**Warning signs:**
- Test file: `[[Burg]]` parsed as a place containing `[Burg]` (one bracket eaten)
- Test file: `[@thing]` parsed correctly but `[[@thing]]` fails or produces wrong AST
- Any test that mixes wikilinks and bracket expressions in the same line fails nondeterministically

**Phase to address:**
Phase 1 (Lexer/Tokenizer) — must be resolved before any other token type is implemented. Adding test cases for `[[x]]` standalone, `[[x]] + [y]` mixed, and `[[[x]]]` triply-nested at the start of tokenizer work prevents compound debt.

---

### Pitfall 2: Two-Pass Hoisting Maintenance Divergence

**What goes wrong:**
The `@` reference hoisting design requires two passes over the AST: pass 1 collects all declarations and symbol definitions; pass 2 resolves references against the collected table. This produces two traversal functions that must be kept in sync as the AST grows. When a new node type is added (e.g., `decree` declarations), the developer adds handling to the evaluator but forgets to add it to the collection pass. Forward references to that node type silently return `nil` or trigger a "symbol not found" error during evaluation, but only when the reference appears before the definition in the file — making the bug order-dependent and intermittent.

**Why it happens:**
The two passes feel like the same operation viewed differently, so adding a new feature naturally leads to updating "the evaluator" without realizing there is a separate collection phase. This is compounded if collection and evaluation are in separate files — there is no mechanical reminder to update both.

**How to avoid:**
Colocate the collection-pass dispatch and the evaluation-pass dispatch in the same `defmethod` or the same `cond` branch. Use a pattern where each node type has a single handler that contains a `(when collecting ...)` clause and an `(unless collecting ...)` clause. This makes it structurally impossible to add a node type in one pass without seeing the other. Alternatively, use a visitor protocol: a `VISIT-NODE` generic function with a `:pass` keyword argument, forcing every node type to be addressed once with explicit pass-switching logic.

Also: write a test that places every node type with a forward reference — definition after use — and verify it resolves correctly.

**Warning signs:**
- Tests pass when definitions precede uses but fail when uses precede definitions
- A new keyword like `decree` resolves when defined first but returns nil when referenced before definition
- Inconsistent resolution behavior between REPL (interactive, incremental) and file evaluation (batch)

**Phase to address:**
Phase 1 (evaluator architecture) — the two-pass pattern must be established as a first-class design, not bolted on later. Later phases adding new node types inherit the pattern automatically.

---

### Pitfall 3: CLOS Generic Dispatch Over Every AST Node Walk

**What goes wrong:**
The resolver protocol is correctly defined as CLOS generic functions — this is the right architectural choice. However, if the main AST evaluator is also structured as a generic function dispatching on each node type, every recursive step in the evaluation walk incurs a full CLOS dispatch. For a DSL with 10 operators and short scripts this is imperceptible. For scripts with hundreds of nodes, or for a REPL where the same expression is evaluated many times (e.g., during test suite iteration), the dispatch overhead becomes measurable. Benchmarks from the CL Cookbook Performance guide show unoptimized generic dispatch running ~60x slower than type-declared static calls.

Innate's `no external dependencies` constraint means the `inlined-generic-function` and `static-dispatch` optimization libraries are ruled out.

**Why it happens:**
CLOS is idiomatic for "dispatch on type" and is the natural first implementation of `evaluate-node`. The developer writes `(defgeneric evaluate (node resolver))` and adds methods for each node type. This is correct and clean — but the performance ceiling arrives unexpectedly when the evaluator becomes the hot path.

**How to avoid:**
Use CLOS generic functions for the resolver protocol (the external interface) but use a `typecase` or `etypecase` dispatch for the internal AST evaluator. A single `(etypecase node ...)` in the evaluator is compiled to a jump table by SBCL and runs at the same cost as a C switch statement. Keep the CLOS boundary at the resolver interface only — that is where runtime polymorphism is genuinely needed. This gives full extensibility where it matters and maximum performance where it is irrelevant to extension.

**Warning signs:**
- REPL response time grows noticeably with script length
- `(time ...)` profiling shows `#<STANDARD-GENERIC-FUNCTION EVALUATE>` in the top callers
- Test suite becomes slow when script complexity increases (not data volume, just AST depth)

**Phase to address:**
Phase 1 (evaluator core) — the dispatch strategy is an architectural decision that is expensive to reverse. Choosing `etypecase` for internal dispatch and CLOS for the resolver boundary is a one-time decision with no downstream cost.

---

### Pitfall 4: Recursive Descent Operator Associativity Bug

**What goes wrong:**
Innate has infix-style operators: `+` (combinator), `->` (emission), `:` (qualifier), `||` (fulfillment). A naive recursive descent implementation of `expr -> term OP expr` produces right-associative evaluation. `a + b + c` becomes `a + (b + c)` instead of `(a + b) + c`. For `+` as set union this may be harmless, but for `->` emission chains the ordering matters: `query -> filter -> output` must execute left-to-right, and a right-associative parse inverts the pipeline.

Additionally, `||` in Innate is not boolean OR — it is a fulfillment operator. A developer reading the grammar will expect standard boolean-OR precedence and associativity and may implement it accordingly, breaking the fulfillment semantics.

**Why it happens:**
The standard recursive descent expression rule `expr := term (OP expr)?` recurses on the right side, making everything right-associative. Left associativity requires either converting to iterative loops (EBNF-style `{OP term}*`) or using a Pratt parser for infix expressions. Most tutorials show the right-recursive form because it is simpler, and it works correctly for right-associative operators like exponentiation — making the bug invisible until tested with chained left-associative operators.

**How to avoid:**
For each infix operator, explicitly decide the required associativity during grammar design, document it in the spec, and implement using iterative loops: `(loop while (next-is-op) collect ...)` rather than mutual recursion. For `->` emission chains specifically, left associativity is required and should be tested with three-step chains (`a -> b -> c`) before any higher-level features are built on top.

**Warning signs:**
- `a -> b -> c` evaluates as `a -> (b -> c)` (rightmost executes first)
- Multi-step `->` pipelines produce results in wrong order
- Any chain of three or more same-operator expressions gives unexpected results

**Phase to address:**
Phase 1 (parser, expression grammar) — write a three-step chain test for each infix operator before considering the parser complete.

---

### Pitfall 5: The "Make It General-Purpose" Scope Creep

**What goes wrong:**
Innate is described as "markdown that runs" with a specific purpose: scripts that define types, workflows, routing rules, and presentation templates for the noosphere. The DSL has intentional constraints — no loops, no arithmetic, no general computation. However, as the interpreter becomes usable, requests will arrive to add: conditional expressions, iteration, arithmetic, string manipulation, variable assignment. Each request is individually reasonable. Collectively they produce a language that is "almost Python" but with worse tooling, no community, and no standard library. The original constraint — "a human unfamiliar with any programming language should make a reasonable guess at what this does" — is violated once the language requires knowing what `(map filter accumulate)` does.

**Why it happens:**
The second system effect: once a working foundation exists, it feels cheap to extend it. "It's just one more operator" is always true individually. DSL designers consistently underestimate how each added generality degrades domain legibility. Research on DSL lessons learned explicitly names "design only what is necessary" and the "80% solution" principle as the primary discipline for successful DSLs.

**How to avoid:**
Write the "non-goals" section of the spec explicitly and visibly. For Innate, this means: no arithmetic, no iteration, no string manipulation, no general function definition. When a feature request arrives, evaluate it against the core value statement: "a human unfamiliar with any programming language should make a reasonable guess at what this does." If the feature requires understanding a programming concept, reject it. If it requires understanding the domain (agents, noosphere, workflow), it may belong.

Keep the `Out of Scope` section of PROJECT.md as the governing list. Add to it, not just the requirements.

**Warning signs:**
- New operator cannot be explained without using a programming term (loop, conditional, function)
- A non-programmer user asked to read a script says "what does that part do?"
- The parser grammar file grows significantly between milestones without a corresponding growth in domain expressiveness

**Phase to address:**
All phases — this is a process pitfall, not a technical one. The discipline must be enforced at every milestone review.

---

### Pitfall 6: Common Lisp Package Symbol Conflicts

**What goes wrong:**
Innate uses a package-per-module structure following AF64 conventions. Symbol conflicts arise in exactly four ways: (1) two packages are both `:use`d by a third package and both export the same symbol name; (2) a symbol is imported that shadows an already-accessible symbol; (3) a symbol is exported that conflicts with an already-imported symbol in a using package; (4) a shadowing symbol is unintered, revealing a previously hidden conflict. In a hand-rolled parser where each phase (lexer, parser, evaluator, resolver) is a package, common names like `PARSE`, `EVALUATE`, `TOKEN`, `NODE`, `ERROR` are likely to appear in multiple packages. `:use :cl` in each package inherits the entire CL namespace, making conflicts with CL's own `ERROR`, `TYPE`, `SYMBOL`, and `READ` a near-certainty if those names are reused casually.

**Why it happens:**
New CL developers (and developers coming from single-namespace languages) underestimate how much the CL package system requires upfront naming discipline. The error messages for symbol conflicts are precise but alarming: `Symbol TOKEN is accessible in package INNATE-LEXER and package INNATE-PARSER` — intimidating enough that developers reach for `:shadowing-import-from` as a quick fix, which hides the conflict without resolving the underlying naming issue.

**How to avoid:**
- Use `:use (:cl)` only, never `:use (:cl :some-other-package)` in application packages. Import specific symbols with `:import-from` instead.
- Never name symbols the same as CL exported symbols unless intentionally shadowing. Prefix package-internal concepts: `TOKEN` becomes `INNATE-TOKEN` or use the package qualifier `lexer:token`.
- Define all packages in a single `packages.lisp` file loaded first in the ASDF system. This gives a single place to see all namespace decisions.
- Use string designators in `defpackage` forms, not symbols — `(:export "TOKEN" "PARSE")` not `(:export token parse)` — to avoid the symbol accidentally being interned into the wrong package at read time.

**Warning signs:**
- SBCL signals `Name conflict` errors during system load
- Different behavior when loading with `asdf:load-system` vs. individual `load` calls on files
- `(find-symbol "TOKEN" :innate-lexer)` returns a different object than `(find-symbol "TOKEN" :innate-parser)`

**Phase to address:**
Phase 1 (project scaffolding) — `packages.lisp` must be the first file in the ASDF `:components` list and must be reviewed before any other files are written. Getting this wrong early requires touching every source file to fix.

---

### Pitfall 7: ASDF Loading Order and File Dependency Mistakes

**What goes wrong:**
Without explicit `:depends-on` declarations in the ASDF system definition, files are loaded in the order they appear in `:components`. This works until it doesn't: a single refactor that moves a function to a "more appropriate" file silently breaks compilation because the ASDF file order no longer reflects actual compile-time dependencies. The failure mode is `undefined function` or `undefined variable` errors that appear only during a cold `asdf:load-system` (not during incremental REPL development), making them CI-only bugs that are invisible during normal development.

A second issue: loading `.asd` files with `cl:load` instead of `asdf::load-asd`. The `cl:load` approach does not register the system with ASDF's registry, so `(asdf:load-system :innatescript)` fails with "system not found" even though the `.asd` file has been loaded.

**Why it happens:**
REPL-driven development masks loading order issues. During development, the developer `load`s files individually in the order they need them, everything works, and the ASDF definition is written to approximate that order. But ASDF serial loading and REPL incremental loading are not equivalent — ASDF recompiles when source timestamps change, the REPL does not.

**How to avoid:**
- Use `:serial t` initially to enforce a strict linear load order matching the file list.
- Add explicit `:depends-on` at the file level for any file that uses symbols from a non-adjacent file.
- Include a CI step (or a shell script) that does a fresh `rm -rf ~/.cache/common-lisp/` followed by `sbcl --eval "(asdf:load-system :innatescript)"` to verify cold-load works.
- Never use `cl:load` to load `.asd` files; always add the system directory to `asdf:*central-registry*` or use the standard `~/.config/common-lisp/source-registry.conf.d/` mechanism.

**Warning signs:**
- Works at the REPL after manual loading but fails with `sbcl --load build.lisp`
- Cold compile after `rm -rf ~/.cache/common-lisp/` fails with undefined symbol errors
- Developers write `(load "lexer.lisp")` before starting the REPL — this indicates the ASDF definition is not trusted

**Phase to address:**
Phase 1 (project scaffolding) — the ASDF system definition and a cold-load test script must be present from day one. A `make test` target that does a cold load before running tests catches this permanently.

---

### Pitfall 8: Error Messages as an Afterthought

**What goes wrong:**
The interpreter is developed against a test suite of valid programs. The error path is wired up to `(error "parse error at ~A" position)` or similar, which satisfies the test suite but produces catastrophic user experience. Panic-mode error recovery — aborting on the first error — causes a cascade: fix one parse error, reveal the next, repeat five times for a script with five issues. Experienced compiler developers know that only the first reported error in panic mode is trustworthy; all subsequent errors are artifacts of recovery state. For Innate, where the target user is "a human unfamiliar with programming," a cryptic cascade error is a show-stopper.

**Why it happens:**
Error message quality is invisible in unit tests. A test written as `(assert (signals-error (parse "bad input")))` passes whether the message is "Unexpected ']' at position 47" or "Parse failure". The investment in good error messages produces no test coverage improvement, so it is deferred until user feedback arrives — which for a language means "after the language has users."

**How to avoid:**
- Define error types as CLOS conditions from the start: `innate-parse-error`, `innate-resolution-error`, `innate-fulfillment-error`. Each condition type carries source location (line, column), expected token, and actual token.
- Write at least one error-message test per error type: assert that the condition's printed representation contains the source location and a human-readable description.
- For the REPL specifically: never let unhandled conditions crash the REPL loop. Install a handler that prints the condition and returns to the prompt.
- Defer error recovery (continuing past the first error) to a later phase — but do not defer structured condition types and source locations.

**Warning signs:**
- Test suite has no tests for error cases
- Errors produce Lisp backtrace output rather than DSL-level messages
- `(innate:eval-string "bad input")` crashes the SBCL process rather than signaling a condition

**Phase to address:**
Phase 1 (condition system) — define condition types before writing much parser code. The parser will use them immediately, and defining them first keeps error paths first-class throughout.

---

### Pitfall 9: Resolver Protocol Leaking into the Core

**What goes wrong:**
The pluggable resolver design is correct: the interpreter knows nothing about Postgres, the noosphere, or any specific backend. However, as features are added, the evaluator accumulates conveniences — cached lookups, default entity shapes, fallback behaviors — that implicitly assume a specific resolver implementation. The stub resolver used for testing starts to require specific entity fields or response shapes. When the noosphere resolver is eventually wired in, it behaves slightly differently and breaks tests that were supposed to be resolver-independent.

**Why it happens:**
The stub resolver is written to make tests pass, not to be a correct example of the resolver protocol. If the protocol is not formally defined (as a set of required generic function signatures with documented contracts), each new feature written against the stub creates an implicit assumption about resolver behavior that may not be documented anywhere.

**How to avoid:**
Define the resolver protocol as a formal interface document before writing any resolver implementation. Each resolver generic function must have: a documented call signature, documented return type, documented behavior for the "not found" case, and documented behavior for the "fulfillment required" case. The stub resolver must be written to this contract, not to make tests pass.

Write a "resolver conformance test suite" — a set of tests that any correct resolver implementation must pass — and run it against the stub. This also serves as the specification for the eventual noosphere resolver.

**Warning signs:**
- Stub resolver tests check specific field names in returned entities
- Adding a new field to stub entities causes evaluator tests to fail (evaluator depends on entity shape)
- The resolver protocol definition exists only in code, not in a written spec

**Phase to address:**
Phase 1 (resolver protocol definition) — the protocol spec must be written before the stub resolver is implemented. The stub is a conforming implementation, not a test fixture.

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Single flat ASDF `:serial t` system, no per-file `:depends-on` | Fast initial setup | Refactoring moves symbols without updating load order; cold-load failures are CI-only bugs | Phase 1 only, must be corrected by Phase 2 |
| Error paths all signal generic `(error "message")` | Tests pass without condition design work | REPL crashes on bad input; no structured recovery; user-hostile messages | Never: condition types are cheap and must be first-class from the start |
| CLOS generic dispatch for entire evaluator (not just resolver boundary) | Clean OOP structure, easy to add node types | Measurable performance overhead at REPL scale; cannot be fixed without restructuring | MVP only if scripts stay under 50 nodes; refactor before REPL launch |
| Wikilink `[[` handled with special-case string matching in the parser | Avoids lexer state machine complexity | Breaks on any expression that legitimately contains `[[`; error messages are wrong | Never: the `[[` ambiguity must be resolved in the lexer architecture before any tokens are built |
| `defpackage` with `:use (:cl :another-package)` for convenience | Shorter symbol names | Symbol conflicts appear at load time, not compile time; hard to diagnose | Never: use explicit `:import-from` for all inter-package symbols |

---

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| ASDF + SBCL cold load | Developer tests with `(load "file.lisp")` at REPL, not with `asdf:load-system` | Add a shell script `test.sh` that removes fasl cache and runs `sbcl --eval "(asdf:test-system :innatescript)"` — run it before every commit |
| Stub resolver in test suite | Stub grows to match evaluator assumptions rather than protocol contract | Write resolver conformance tests first; stub must pass them; evaluator tests must not depend on stub-specific behavior |
| REPL `:innate` package interaction | User types CL forms at the REPL, accidentally interns symbols into the `innate` package | REPL should operate in a dedicated `innate-user` package; reset package on each REPL start |
| SBCL fasl cache stale after refactor | Old compiled code is loaded silently, hiding regressions | Cold-load CI step; developer alias `alias rebuild-innate='rm -rf ~/.cache/common-lisp/innatescript && sbcl --eval "(asdf:load-system :innatescript)"'` |

---

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| Full CLOS dispatch on every evaluator AST node | REPL latency grows with script length; `(time ...)` shows GF calls dominating | Use `etypecase` for internal AST dispatch; reserve CLOS for resolver protocol boundary | Noticeable with scripts over ~100 nodes; REPL becomes sluggish |
| Recursive descent with deep precedence nesting | Parsing a simple literal requires 6+ function calls | Flatten precedence hierarchy; use iterative loops for same-precedence operators | Any script using chained operators; performance is latent but never critical for this scale |
| String allocation in lexer | Every token is a freshly allocated string | Intern frequently-used keyword strings; use `(intern ...)` for keyword tokens | Irrelevant for DSL scale; only matters if Innate ever processes megabyte-scale files |
| Two-pass collecting all references before any resolution | Large scripts with deeply recursive `decree` chains cause O(n) memory growth | The two-pass approach is correct for this scale; not a trap at Innate's expected script sizes | Not a practical concern unless scripts contain thousands of forward references |

---

## "Looks Done But Isn't" Checklist

- [ ] **Lexer:** The `[[` ambiguity test passes — `[[Burg]]` tokenizes as WIKILINK-OPEN `Burg` WIKILINK-CLOSE, not as LBRACKET LBRACKET `Burg` RBRACKET RBRACKET
- [ ] **Parser:** Three-step `->` chain `a -> b -> c` produces a left-associative AST, not right-associative
- [ ] **Two-pass hoisting:** `@ref` where the definition of `ref` appears after the use resolves correctly
- [ ] **Resolver protocol:** The stub resolver passes the conformance test suite, not just the evaluator tests
- [ ] **ASDF cold load:** `rm -rf ~/.cache/common-lisp/ && sbcl --eval "(asdf:load-system :innatescript)"` succeeds without errors
- [ ] **Error conditions:** `(innate:eval-string "broken input")` signals a structured condition, does not crash SBCL
- [ ] **REPL error recovery:** A parse error at the REPL returns to the prompt, does not exit the process
- [ ] **Package cleanliness:** `(asdf:load-system :innatescript)` produces zero package conflict warnings
- [ ] **Prose passthrough:** Non-executable lines appear verbatim in the AST (as `prose-node`), not silently dropped
- [ ] **`||` semantics:** `||` is parsed as fulfillment, not boolean OR — it does not short-circuit

---

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| `[[` lexer ambiguity discovered after parser is complete | HIGH | Parser likely requires partial rewrite to separate wikilink state; test suite must be re-run against all existing expressions; estimated 2-3 days |
| Two-pass hoisting divergence discovered in later phases | MEDIUM | Audit every node type for collection-pass handling; add missing cases; 1 day plus regression test run |
| CLOS dispatch performance discovered at REPL usability testing | MEDIUM | Replace evaluator with `etypecase`; resolver protocol unchanged; 1-2 days plus benchmarking |
| Symbol conflicts from `defpackage` discovered mid-project | HIGH | Requires touching every source file; symbol renames propagate; easiest to fix in a dedicated "namespace cleanup" PR; 1-2 days |
| Resolver protocol found to have leaked evaluator assumptions | HIGH | Must write conformance suite, audit stub, audit evaluator for implicit assumptions; potentially requires changing evaluator + stub + tests simultaneously; 3+ days |
| ASDF cold-load failures discovered in CI | LOW | Fix `:depends-on` declarations in `.asd`; add cold-load test to CI; 2-4 hours |
| Operator associativity bug discovered after pipeline features are built | HIGH | Right-to-left `->` chains may have influenced other design decisions; requires parser fix + evaluator audit + all tests using chained operators; 1-3 days |

---

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| `[[` wikilink vs bracket ambiguity | Phase 1: Lexer | Dedicated lexer test: `[[x]]`, `[x]`, `[[x]]+[y]`, `[[[x]]]` all tokenize correctly |
| Two-pass hoisting divergence | Phase 1: Evaluator architecture | Every node type has a forward-reference test (use before define) |
| CLOS dispatch performance | Phase 1: Evaluator architecture | Commit to `etypecase` internal dispatch; document resolver = CLOS boundary |
| Operator associativity | Phase 1: Parser expression grammar | Three-step chain test for every infix operator before parser is considered complete |
| DSL scope creep | All phases | PROJECT.md Out of Scope list is reviewed at every milestone; new operators require written justification against core value statement |
| Package symbol conflicts | Phase 1: Project scaffolding | `packages.lisp` exists and all packages are defined there; zero conflict warnings on load |
| ASDF loading order | Phase 1: Project scaffolding | Cold-load test script present and passing before any feature work begins |
| Error messages as afterthought | Phase 1: Condition system | Condition types defined; one error-message test per condition type |
| Resolver protocol leakage | Phase 1: Protocol definition | Written resolver protocol spec; conformance test suite; stub passes conformance suite |

---

## Sources

- [The Common Lisp Cookbook: CLOS Fundamentals](https://lispcookbook.github.io/cl-cookbook/clos.html) — MEDIUM confidence (official community resource)
- [The Common Lisp Cookbook: Performance Tuning](https://lispcookbook.github.io/cl-cookbook/performance.html) — MEDIUM confidence (benchmarks may be SBCL-version-specific)
- [Common Lisp Tips: The Four Causes of Symbol Conflicts](https://lisptips.com/post/34436452765/the-four-causes-of-symbol-conflicts) — HIGH confidence (canonical reference for CL package conflicts)
- [ASDF Best Practices](https://github.com/fare/asdf/blob/master/doc/best_practices.md) — HIGH confidence (official ASDF documentation)
- [ASDF 3 Upgrade Pitfalls](https://asdf.common-lisp.dev/asdf/Pitfalls-of-the-upgrade-to-ASDF-3.html) — HIGH confidence (official ASDF documentation)
- [Eli Bendersky: Some Problems of Recursive Descent Parsers](https://eli.thegreenplace.net/2009/03/14/some-problems-of-recursive-descent-parsers) — HIGH confidence (well-established reference, problems are language-independent)
- [Parsing Ambiguity: Type Argument vs Less Than (Keleshev)](https://keleshev.com/parsing-ambiguity-type-argument-v-less-than) — MEDIUM confidence (analogous bracket ambiguity case)
- [Maximal Munch — Wikipedia](https://en.wikipedia.org/wiki/Maximal_munch) — HIGH confidence (foundational lexer theory)
- [Two-Pass Assembler: Forward References (Iowa)](https://homepage.cs.uiowa.edu/~jones/syssoft/notes/04fwd.html) — HIGH confidence (foundational two-pass theory)
- [WebDSL Lessons Learned — InfoQ](https://www.infoq.com/news/2008/05/webdsl-case-study/) — MEDIUM confidence (real-world DSL case study, older but principles stable)
- [DSL Lessons Learned — Wile (academic)](https://john.cs.olemiss.edu/~hcc/csci555/notes/localcopy/WileLessonsLearnedDSL.pdf) — MEDIUM confidence (academic, well-cited)
- [Static Dispatch for CL](https://github.com/alex-gutev/static-dispatch) — HIGH confidence (official library; noted here as an excluded option per AF64 no-deps constraint)
- [Crafting Interpreters: Resolving and Binding](https://craftinginterpreters.com/resolving-and-binding.html) — HIGH confidence (canonical interpreter implementation reference)
- [Resilient LL Parsing Tutorial (matklad)](https://matklad.github.io/2023/05/21/resilient-ll-parsing-tutorial.html) — HIGH confidence (error recovery strategies)

---
*Pitfalls research for: Innate language interpreter / Common Lisp DSL*
*Researched: 2026-03-27*
