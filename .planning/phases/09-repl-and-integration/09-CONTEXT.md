# Phase 9: REPL and Integration - Context

**Gathered:** 2026-03-29
**Status:** Ready for planning
**Source:** Auto-generated (--auto flag, recommended defaults)

<domain>
## Phase Boundary

The full pipeline is assembled end-to-end; the REPL handles all conditions gracefully and never crashes on bad input; `burg_pipeline.dpn` evaluates without error. This is the final phase — it connects tokenizer→parser→evaluator into a user-facing REPL and file runner, wraps everything in shell scripts, and runs the integration test against `burg_pipeline.dpn`.

</domain>

<decisions>
## Implementation Decisions

### REPL loop (RUN-01)

- `read-line` loop with `handler-case` error recovery
- Prompt: `innate> ` (simple, recognizable)
- On each line: `(tokenize input)` → `(parse tokens)` → `(evaluate ast env)` → print results
- The REPL creates ONE `eval-env` with a fresh `stub-resolver` and persists it across the session — decrees accumulate, so `decree name [body]` defined on line 1 is available to `@name` on line 5
- Exit: `(quit)`, `(exit)`, EOF (Ctrl-D), or `:quit`

### Error handling in REPL

- `innate-parse-error` → print "Parse error at line N, col M: message", return to prompt
- `innate-resistance` at REPL boundary → print "commission queued: source", return to prompt (this is the fulfillment signal — the REPL is the outermost handler)
- Any other `error` → print "Error: message", return to prompt
- The REPL NEVER crashes on bad input — `handler-case` wraps the entire eval pipeline

### File runner (RUN-02)

- `(run-file path env)` — reads file as string, tokenizes, parses, evaluates
- `run-repl.sh` with an argument: `run-repl.sh burg_pipeline.dpn` → load and evaluate the file, print results, exit
- `run-repl.sh` without arguments: start interactive REPL
- The file runner uses the same `eval-env` as the REPL — same resolver, same decree accumulation

### Shell scripts (RUN-03, RUN-04)

- `run-repl.sh` already partially exists (loads system). Extend to:
  - If argument: `(run-file arg env)` then exit
  - If no argument: `(repl env)` loop
- `run-tests.sh` already exists and works (170/170 passing)
- Both scripts use `sbcl --non-interactive` for file mode, `sbcl` (interactive) for REPL mode

### rlwrap compatibility (RUN-04 success criterion 5)

- The REPL uses `read-line` only — no `sb-ext:*` readline bindings, no terminal manipulation
- `rlwrap run-repl.sh` works automatically because rlwrap wraps stdin/stdout
- No Lisp code changes needed for rlwrap — this is a design constraint, not an implementation task

### Integration test: burg_pipeline.dpn (PRJ-05)

- `burg_pipeline.dpn` must parse AND evaluate without unhandled errors
- The stub resolver won't have real data, so bracket expressions will return resistance values — but the REPL catches those as "commission queued" messages
- The integration test proves the full pipeline works end-to-end, not that the resolver returns meaningful data
- A test in `test-evaluator.lisp` (or a new integration test file) calls `(run-file "burg_pipeline.dpn" env)` and asserts no unhandled conditions

### Package exports

- `innate.repl` exports: `repl` (interactive loop), `run-file` (file evaluation)
- `innate.repl` imports from: `innate.eval` (evaluate), `innate.parser` (parse), `innate.parser.tokenizer` (tokenize), `innate.eval.resolver` (make-eval-env), `innate.eval.stub-resolver` (make-stub-resolver), `innate.types` (node accessors), `innate.conditions` (error types)

### Claude's Discretion

- Result printing format (how evaluated values are displayed to the user)
- Whether to print a welcome banner on REPL start
- Multi-line input handling (or deferring to v2)
- Whether `run-file` prints each result or only the final result

</decisions>

<specifics>
## Specific Ideas

- The REPL is the "Moses handing out commandments" interface — it should feel clean and immediate
- `burg_pipeline.dpn` evaluating without crashes is the capstone test for the entire project
- The stub resolver is the default resolver for the REPL — future work connects the noosphere resolver (separate repo)

</specifics>

<canonical_refs>
## Canonical References

### All prior phase artifacts (full pipeline)
- `src/parser/tokenizer.lisp` — `tokenize` entry point
- `src/parser/parser.lisp` — `parse` entry point
- `src/eval/evaluator.lisp` — `evaluate` entry point
- `src/eval/resolver.lisp` — `eval-env` struct
- `src/eval/stub-resolver.lisp` — `make-stub-resolver`
- `src/conditions.lisp` — `innate-parse-error`, `innate-resistance`

### Sample programs
- `burg_pipeline.dpn` — Integration test target

### Existing scripts
- `run-tests.sh` — Already works (170/170 passing)
- `run-repl.sh` — Needs creation/extension

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- Full pipeline: `(evaluate (parse (tokenize source)) env)` — proven in Phase 7-8 tests
- `make-stub-resolver` + `make-eval-env` — REPL session setup
- `handler-case` pattern from fulfillment — same pattern for REPL error recovery
- `run-tests.sh` — reference for shell script patterns

### Established Patterns
- `sbcl --non-interactive --eval` for script execution
- `handler-case` wrapping for condition recovery
- `read-line` for input (CLAUDE.md specifies this)

### Integration Points
- `innate.repl` package exists as stub — needs imports and exports in `packages.lisp`
- `src/repl.lisp` registered in ASDF — just needs implementation
- `run-repl.sh` needs to be created or updated

</code_context>

<deferred>
## Deferred Ideas

- Multi-line REPL input for decree blocks — v2 (ADV-03)
- Noosphere resolver connection — separate repo
- `innate eval` / `innate push` CLI commands — v2 (CLI-01, CLI-02)

</deferred>

---

*Phase: 09-repl-and-integration*
*Context gathered: 2026-03-29 via --auto (recommended defaults)*
