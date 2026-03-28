<!-- GSD:project-start source:PROJECT.md -->
## Project

**Innate**

Innate is a scripting language of intention — "markdown that runs." You write `.dpn` files that are simultaneously readable documents and executable programs. The interpreter is written in Common Lisp with a pluggable resolver protocol, so it can be connected to any substrate or agent system. The first resolver connects it to the Dragonpunk noosphere (private, separate repo), but the language itself is generic and public.

**Core Value:** A human unfamiliar with any programming language should be able to make a reasonable guess at what an Innate program does — and that same program should execute.

### Constraints

- **Language**: Common Lisp (SBCL) — the ghosts speak Lisp natively, so Innate must too
- **No external dependencies**: follows AF64 conventions (hand-rolled everything, ASDF system definition, package-per-module)
- **Public repo**: zero secrets, zero hardcoded substrate references
- **Generic**: the interpreter must know nothing about any specific substrate, agent roster, or deployment
- **File extension**: `.dpn`
<!-- GSD:project-end -->

<!-- GSD:stack-start source:research/STACK.md -->
## Technology Stack

## Recommended Stack
### Core Technologies
| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| SBCL | 2.x (current) | Implementation runtime | Native compilation, fast, standard in the CL ecosystem; ghosts already run on it — no impedance mismatch |
| ASDF | 3.3+ (bundled with SBCL) | Build and system definition | Bundled with SBCL — zero install friction; `package-inferred-system` eliminates `.asd` boilerplate as the codebase grows |
| Hand-rolled recursive descent parser | N/A | Lexer + parser | No parser generator needed; Innate's grammar is small and irregular enough that hand-rolling gives precise error messages and full control over whitespace/prose passthrough |
| CLOS `defclass` + `defmethod` | N/A | AST node representation + evaluator dispatch | Dynamic dispatch via `defmethod` on node type eliminates Visitor pattern boilerplate; nodes are redefinable at the REPL during development |
| Hand-rolled test harness | N/A | Test runner | Three macros cover everything (see Testing section); no Quicklisp, no fiveam dependency — consistent with AF64 zero-deps convention |
### Supporting Patterns (not libraries)
| Pattern | Purpose | When to Use |
|---------|---------|-------------|
| Two-pass evaluation (collect-then-resolve) | Hoisting `@` references | Always — Innate semantics require it; first pass builds symbol table, second pass resolves references |
| `handler-case` / `restart-case` for error model | Resistance error propagation | In the evaluator; structural failures propagate, missing-resource conditions trigger restarts for fulfillment |
| `with-gensyms` (hand-rolled) | Macro hygiene in test harness | Whenever writing macros that introduce bindings |
| Dynamic variables (`*current-script*`, `*resolver*`) | Context threading | Avoid passing resolver everywhere; dynamic binding keeps the evaluator clean |
| Pluggable protocol via `defgeneric` | Resolver abstraction | One `defgeneric resolve-reference` that any resolver can specialize |
### Development Tools
| Tool | Purpose | Notes |
|------|---------|-------|
| SBCL `--load` / `--eval` flags | Run tests and REPL non-interactively | Shell scripts call `sbcl --non-interactive --load run-tests.lisp` |
| `rlwrap sbcl` | Line editing in interactive REPL | Zero Lisp deps — `rlwrap` is a Unix wrapper; handles history/editing outside the Lisp image |
| Helix + SBCL subprocess | Development workflow | Consistent with n8k99 machine profile |
## Parsing Techniques
### Use: Hand-Rolled Recursive Descent
- Full control over error messages (critical for a "human-readable" language)
- Easy prose passthrough (if no recognized sigil on a line, emit it as `:prose` node)
- Straightforward two-pass architecture (parse pass returns AST, resolve pass walks it)
### Do NOT Use: esrap, cl-yacc, or any parser generator
## AST Representation
### Use: `defclass` hierarchy
## Evaluator Architecture
### Two-Pass Design
### Resolver Protocol
## Testing
### Use: Hand-Rolled Three-Macro Framework
### Test file organization
## ASDF System Organization
### Pattern: Explicit dependency graph, separate test system
## REPL Implementation
### Pattern: `read-line` loop with `handler-case`
## File Structure
## Alternatives Considered
| Recommended | Alternative | Why Not |
|-------------|-------------|---------|
| Hand-rolled recursive descent | esrap (PEG parser generator) | External dep via Quicklisp; PEG fights prose passthrough; less control over error messages |
| Hand-rolled recursive descent | cl-yacc | External dep; LALR grammar not natural for Innate's mixed-syntax format |
| `defclass` + `defmethod` for AST | `defstruct` + `typecase` | `defstruct` instances become stale after redefinition; `typecase` is an anti-pattern (add a node type → must update every typecase) |
| Hand-rolled 40-line test harness | fiveam | External dep; 5x API surface with no benefit for this scope |
| Hand-rolled 40-line test harness | parachute | External dep; designed for library-quality test suites, not interpreter development |
| `rlwrap` at shell level for REPL | cl-readline bindings | External dep binding GNU readline C library; same functionality at zero Lisp cost |
| Dynamic `*resolver*` variable | Pass resolver as explicit arg everywhere | Pollutes every evaluator function signature; dynamic var is the Lisp convention for implicit context |
## What NOT to Use
| Avoid | Why | Use Instead |
|-------|-----|-------------|
| `read` (CL reader) for parsing Innate input | CL reader expects S-expressions; will error on `@`, `![]`, `->` and other Innate syntax | Hand-rolled lexer calling `read-char`/`peek-char` on input string |
| `:serial t` in ASDF for non-trivial systems | Hides dependency graph, serializes compilation unnecessarily | Explicit `:depends-on` per component |
| `defpackage :use :common-lisp-user` | Inherits a large, browser-namespaced package; symbol conflicts | `(defpackage :innate.FOO (:use :common-lisp))` only |
| `cl:eval` inside the evaluator | Conflates Innate evaluation with CL evaluation; impossible to sandbox | Walk the AST with `defmethod evaluate (node resolver)` |
| Printing directly from evaluator | Couples evaluation to output, prevents embedding | Return values; let REPL and `->` operator handle output |
| Any `ql:quickload` or Quicklisp | Violates AF64 zero-deps convention; adds network/disk dependency to builds | ASDF + SBCL built-ins only |
## Version Compatibility
| Component | SBCL version | Notes |
|-----------|--------------|-------|
| ASDF package-inferred-system | Bundled with SBCL 1.3.4+ | Safe on any current SBCL |
| `defclass` / `defgeneric` / MOP | All current SBCL | Standard ANSI CL; no version constraints |
| `handler-case` / `restart-case` | All SBCL | Standard ANSI CL |
| `rlwrap` | System package (not Lisp) | `pacman -S rlwrap` on Arch; already likely installed |
## Sources
- [Simple recursive descent generator in Common Lisp (GitHub Gist)](https://gist.github.com/c7cfb77a8d7a2ec99a75) — technique confirmation, MEDIUM confidence
- [CL Crafting Interpreters (cl-crafting-interpreters)](https://github.com/gwangjinkim/cl-crafting-interpreters) — CLOS-based evaluator pattern, MEDIUM confidence
- [Practical Common Lisp: Building a Unit Test Framework](https://gigamonkeys.com/book/practical-building-a-unit-test-framework.html) — `deftest`/`check`/`combine-results` macros, HIGH confidence (authoritative primary source)
- [CL Cookbook: Testing](https://lispcookbook.github.io/cl-cookbook/testing.html) — framework comparison, MEDIUM confidence
- [Comparison of CL Testing Frameworks (2023)](https://sabracrolleton.github.io/testing-framework) — 1am/fiveam performance data, MEDIUM confidence
- [CL Cookbook: Defining Systems](https://lispcookbook.github.io/cl-cookbook/systems.html) — ASDF patterns, HIGH confidence
- [ASDF Best Practices (fare/asdf)](https://github.com/fare/asdf/blob/master/doc/best_practices.md) — explicit deps, test system separation, HIGH confidence
- [Abstract Heresies: defclass vs defstruct (2025)](http://funcall.blogspot.com/2025/03/defclass-vs-defstruct.html) — performance tradeoff analysis, MEDIUM confidence
- [SBCL User Manual 2.6.2](https://www.sbcl.org/manual/) — runtime reference, HIGH confidence
- [awesome-cl](https://github.com/CodyReichert/awesome-cl) — ecosystem survey, MEDIUM confidence
<!-- GSD:stack-end -->

<!-- GSD:conventions-start source:CONVENTIONS.md -->
## Conventions

Conventions not yet established. Will populate as patterns emerge during development.
<!-- GSD:conventions-end -->

<!-- GSD:architecture-start source:ARCHITECTURE.md -->
## Architecture

Architecture not yet mapped. Follow existing patterns found in the codebase.
<!-- GSD:architecture-end -->

<!-- GSD:workflow-start source:GSD defaults -->
## GSD Workflow Enforcement

Before using Edit, Write, or other file-changing tools, start work through a GSD command so planning artifacts and execution context stay in sync.

Use these entry points:
- `/gsd:quick` for small fixes, doc updates, and ad-hoc tasks
- `/gsd:debug` for investigation and bug fixing
- `/gsd:execute-phase` for planned phase work

Do not make direct repo edits outside a GSD workflow unless the user explicitly asks to bypass it.
<!-- GSD:workflow-end -->



<!-- GSD:profile-start -->
## Developer Profile

> Profile not yet configured. Run `/gsd:profile-user` to generate your developer profile.
> This section is managed by `generate-claude-profile` -- do not edit manually.
<!-- GSD:profile-end -->
