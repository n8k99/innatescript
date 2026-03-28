# Phase 1: Project Scaffolding - Context

**Gathered:** 2026-03-28
**Status:** Ready for planning

<domain>
## Phase Boundary

The ASDF system loads cleanly from a cold cache with zero warnings, and a hand-rolled test harness is available for all subsequent phases. This phase creates the project skeleton — ASDF definition, all package namespaces, test framework, stub files for every module, and a cold-load verification script.

</domain>

<decisions>
## Implementation Decisions

### ASDF system name
- System name: `"innatescript"` — matches the repository name
- Package prefix: `innate.*` — shorter, matches the language name
- System and packages use different prefixes: ASDF is `innatescript`, packages are `innate.types`, `innate.parser`, etc.

### Package naming convention
- Dot-separated, following AF64 convention: `innate.types`, `innate.parser.tokenizer`, `innate.eval.resolver`
- Single `packages.lisp` file defines ALL packages upfront
- Use `:import-from` exclusively, never `:use` (except `:cl`) — prevents symbol conflicts with CL builtins like `error`, `type`, `read`
- Full package list:
  - `innate.types` — AST node defstructs, result types, resistance
  - `innate.conditions` — condition hierarchy (parse-error, resistance)
  - `innate.parser.tokenizer` — .dpn text → token stream
  - `innate.parser` — token stream → AST
  - `innate.eval.resolver` — defgeneric protocol + base resolver class
  - `innate.eval` — evaluator (walks AST, calls resolver)
  - `innate.eval.stub-resolver` — in-memory resolver for testing
  - `innate.repl` — interactive evaluator
  - `innate` — top-level re-exports

### Test runner design
- Separate ASDF secondary system: `innatescript/tests`
- Verbose output: each test name printed as it runs, then pass/fail result
- Hand-rolled framework: `deftest`, `assert-equal`, `assert-true`, `assert-nil`, `assert-signals`, `run-tests`
- `run-tests` accepts optional prefix string to filter by test name
- Exit code: 0 on all pass, 1 on any failure
- Test packages mirror source packages: `innate.tests.types`, `innate.tests.tokenizer`, etc.

### ASDF component structure
- Explicit `:depends-on` per component, NOT `:serial t`
- Each module stub file created with just `(in-package ...)` so the system loads cleanly from day one
- Cold-load test: `run-tests.sh` wipes fasl cache before loading

### Claude's Discretion
- Exact `defpackage` export lists (will be populated as modules are implemented)
- Shell script details (bash, shebang, error handling)
- Whether to include a `.gitignore` for fasl cache directories

</decisions>

<specifics>
## Specific Ideas

- Follow AF64 project structure as the model: single `packages.lisp`, module directories, ASDF system file at root
- The `innate.conditions` package is separate from `innate.types` — conditions are the error model, types are the AST. Research flagged that conditions should exist before any parser code.
- Test files live in `tests/` directory, not alongside source

</specifics>

<canonical_refs>
## Canonical References

### Project spec
- `docs/specs/2026-03-27-innate-language-design.md` — Full language design spec, architecture section describes file layout

### Research
- `.planning/research/STACK.md` — Stack recommendations: ASDF patterns, test framework design, package organization
- `.planning/research/ARCHITECTURE.md` — Component boundaries, build order, ASDF explicit deps rationale
- `.planning/research/PITFALLS.md` — Package conflict prevention, ASDF cold-load as CI gate, `:serial t` trap

### AF64 reference (on droplet)
- `/opt/project-noosphere-ghosts/lisp/packages.lisp` — AF64 package naming convention model
- `/opt/project-noosphere-ghosts/lisp/af64.asd` — AF64 ASDF system definition model

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- None — greenfield project. The existing files in the repo are spec documents and one sample `.dpn` file.

### Established Patterns
- AF64 (project-noosphere-ghosts) uses dot-separated packages, `:import-from`, single `packages.lisp`, ASDF with `:serial t` (but we're using explicit `:depends-on` per research recommendation)

### Integration Points
- None for Phase 1. The ASDF system will be loadable standalone. Integration with project-noosphere-ghosts happens via a separate noosphere resolver (not in this repo).

</code_context>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 01-project-scaffolding*
*Context gathered: 2026-03-28*
