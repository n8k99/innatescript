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

## Technology Stack

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

### Parsing Techniques
- Hand-Rolled Recursive Descent: full control over error messages, easy prose passthrough, straightforward two-pass architecture
- Do NOT Use: esrap, cl-yacc, or any parser generator

### Alternatives Considered
| Recommended | Alternative | Why Not |
|-------------|-------------|---------|
| Hand-rolled recursive descent | esrap (PEG parser generator) | External dep via Quicklisp; PEG fights prose passthrough; less control over error messages |
| Hand-rolled recursive descent | cl-yacc | External dep; LALR grammar not natural for Innate's mixed-syntax format |
| `defclass` + `defmethod` for AST | `defstruct` + `typecase` | `defstruct` instances become stale after redefinition; `typecase` is an anti-pattern (add a node type → must update every typecase) |
| Hand-rolled 40-line test harness | fiveam | External dep; 5x API surface with no benefit for this scope |
| `rlwrap` at shell level for REPL | cl-readline bindings | External dep binding GNU readline C library; same functionality at zero Lisp cost |
| Dynamic `*resolver*` variable | Pass resolver as explicit arg everywhere | Pollutes every evaluator function signature; dynamic var is the Lisp convention for implicit context |

### What NOT to Use
| Avoid | Why | Use Instead |
|-------|-----|-------------|
| `read` (CL reader) for parsing Innate input | CL reader expects S-expressions; will error on `@`, `![]`, `->` and other Innate syntax | Hand-rolled lexer calling `read-char`/`peek-char` on input string |
| `:serial t` in ASDF for non-trivial systems | Hides dependency graph, serializes compilation unnecessarily | Explicit `:depends-on` per component |
| `defpackage :use :common-lisp-user` | Inherits a large, browser-namespaced package; symbol conflicts | `(defpackage :innate.FOO (:use :common-lisp))` only |
| `cl:eval` inside the evaluator | Conflates Innate evaluation with CL evaluation; impossible to sandbox | Walk the AST with `defmethod evaluate (node resolver)` |
| Printing directly from evaluator | Couples evaluation to output, prevents embedding | Return values; let REPL and `->` operator handle output |
| Any `ql:quickload` or Quicklisp | Violates AF64 zero-deps convention; adds network/disk dependency to builds | ASDF + SBCL built-ins only |

### Sources
- [Practical Common Lisp: Building a Unit Test Framework](https://gigamonkeys.com/book/practical-building-a-unit-test-framework.html) — `deftest`/`check`/`combine-results` macros, HIGH confidence
- [CL Cookbook: Defining Systems](https://lispcookbook.github.io/cl-cookbook/systems.html) — ASDF patterns, HIGH confidence
- [ASDF Best Practices (fare/asdf)](https://github.com/fare/asdf/blob/master/doc/best_practices.md) — explicit deps, test system separation, HIGH confidence
- [SBCL User Manual 2.6.2](https://www.sbcl.org/manual/) — runtime reference, HIGH confidence

## Planning Hierarchy

All planning lives in the Vault (`~/Documents/Droplet-Org/The Work/Innatescript/`). The hierarchy is:

```
Project (📋 InnateScript)
  └── Milestone (🏔️) — a shippable increment (e.g., "Choreographic Lexing and Parsing")
       └── Goal (🎯) — a success criterion with acceptance criteria
            └── Task (☑️) — atomic work unit, has blocked_by/blocks
```

- **Project** = the InnateScript entry in `The Work/Innatescript/`
- **Milestone** = what the ROADMAP calls a "Phase" (Phase 10 = Milestone 10)
- **Goal** = each success criterion from the ROADMAP's phase details
- **Task** = implementation steps under a goal

All planning documents use vault templates from `The Commons/Templates/` and carry `type: "[[Template]]"` frontmatter. Never use `.planning/` or `.gsd/` directories.

Reference docs synced to this repo (`docs/ROADMAP.md`, `docs/REQUIREMENTS.md`, `docs/specs/InnateScript.md`, `README.md`) are copies — the vault is the source of truth. A vault-sync daemon keeps them in sync automatically.

## Conventions

Conventions not yet established. Will populate as patterns emerge during development.

## Architecture

Architecture not yet mapped. Follow existing patterns found in the codebase.
