# Phase 7: Evaluator Core - Context

**Gathered:** 2026-03-29
**Status:** Ready for planning
**Source:** Auto-generated (--auto flag, recommended defaults)

<domain>
## Phase Boundary

The two-pass hoisting architecture is in place, all non-commission AST node types evaluate correctly via etypecase dispatch, and resistance propagates upward through nested brackets. This phase builds the evaluator engine. Commission evaluation (`(agent){instruction}`), search directives (`![...]`), fulfillment (`||`), emission (`->`), wikilinks, and bundles are Phase 8.

**In scope (Phase 7):** Two-pass architecture, decree collection (pass 1), `@` reference resolution (pass 2), bracket expression evaluation via resolver, prose/heading passthrough, resistance propagation, `etypecase` dispatch.

**Out of scope (Phase 8):** `(agent){instruction}` commissions, `![search]` directives, `||` fulfillment operator, `->` emission, `[[wikilink]]` evaluation, `{bundle}` loading.

</domain>

<decisions>
## Implementation Decisions

### Two-pass architecture (EVL-01)

- **Pass 1 (collect):** Walk the AST top-level children. For every `:decree` node, store `(node-value decree-node)` → `decree-node` in `(eval-env-decrees env)`. Do NOT evaluate anything in pass 1 — just populate the decree hash-table.
- **Pass 2 (evaluate):** Walk the AST top-level children again. Evaluate each node via `etypecase` dispatch on `(node-kind node)`. Decree nodes are skipped in pass 2 (already collected).
- Entry point: `(evaluate ast env)` where `ast` is the `:program` node from the parser, `env` is an `eval-env` struct.
- Return value: a list of evaluation results (one per top-level statement), in source order. Prose/heading nodes produce their text values. Bracket expressions produce resolver results.

### Decree collection and @reference resolution (EVL-02, EVL-08)

- `@name` resolution order: check `(eval-env-decrees env)` first (local decrees), then fall through to `(resolve-reference (eval-env-resolver env) name qualifiers)`.
- Forward references work because pass 1 collects ALL decrees before pass 2 evaluates ANY references. `@name` appearing before `decree name` in the source text resolves correctly.
- `decree name [body]` — the decree node's `value` is the name string, its `children` are the body nodes. The entire node is stored in decrees, not just the body.

### etypecase dispatch (EVL-14)

- The core dispatch function: `(eval-node node env)` using `(etypecase (node-kind node) ...)`.
- Cases for Phase 7:
  - `:program` → evaluate children via two-pass
  - `:bracket` → evaluate via `resolve-context` on the resolver
  - `:reference` → look up in decrees, then resolver
  - `:decree` → skip in pass 2 (already collected in pass 1)
  - `:prose` → pass through as text value
  - `:heading` → pass through as text value
  - `:string-lit` → return string value
  - `:number-lit` → return numeric value (parse-integer)
  - `:bare-word` → return string value
  - `:emoji-slot` → return string value
  - `:kv-pair` → evaluate value child, return as cons pair
  - `:combinator` → return combinator value (used by reference postfix)
  - `:lens` → evaluate lens children
  - `:modifier` → return modifier value (used by expression postfix)
- Phase 8 cases (stubbed with resistance): `:agent`, `:bundle`, `:search`, `:fulfillment`, `:emission`, `:wikilink`

### Bracket expression evaluation (EVL-03)

- `[context[verb[args]]]` — the bracket node's children represent the nesting. The evaluator:
  1. Evaluates the first child as `context`
  2. If children have nested brackets: evaluates recursively
  3. Evaluates kv-pairs inside the bracket body
  4. Calls `(resolve-context resolver context verb args)` with the evaluated pieces
- For flat brackets (no named context): passes the children as-is to the resolver
- The resolver returns `innate-result` or `resistance`

### Prose and heading passthrough (EVL-11, EVL-12)

- `:prose` nodes return their `(node-value node)` string as-is — they appear in the output stream
- `:heading` nodes return their `(node-value node)` string, possibly prefixed with `#` level markers
- Neither prose nor headings are discarded — they are first-class output values
- Presentation directives (`/modifier`) are preserved as metadata but don't transform output in the evaluator — that's a renderer concern

### Resistance propagation (EVL-15)

- When `resolve-context`, `resolve-reference`, or any resolver call returns a `resistance` struct (checked via `resistance-p`):
  - If inside a bracket expression with no `||` fulfillment: signal `innate-resistance` condition
  - The signal propagates upward through `handler-case` frames until caught
  - If no handler catches it at any bracket level, it surfaces to the top-level caller
- Natural CL condition propagation handles resistance — `innate-resistance` signals propagate upward through the call stack without needing explicit `handler-case` at every bracket level. The evaluator checks `resistance-p` on direct resolver return values; nested signals propagate naturally.
- Phase 8 adds `||` fulfillment which uses `handler-case` to catch resistance before it propagates

### Package and exports

- `innate.eval` exports: `evaluate` (main entry point)
- `innate.eval` imports from: `innate.eval.resolver` (all protocol symbols + eval-env), `innate.types` (node accessors + node constants + result types), `innate.conditions` (innate-resistance for signaling)
- The evaluator NEVER imports from `innate.eval.stub-resolver` — boundary enforcement from Phase 5

### Claude's Discretion

- Internal helper function decomposition (e.g., separate `collect-decrees` function vs inline in evaluate)
- Whether to wrap pass 2 results in `innate-result` or return raw values
- How to represent the evaluation output stream (list of values, list of innate-results, or a custom struct)
- Error message formatting for resistance signals
- Test organization and helper utilities

</decisions>

<specifics>
## Specific Ideas

- The evaluator is the heart of Innate — but Phase 7 is specifically the "core" (non-commission, non-fulfillment paths). Phase 8 adds the agent/commission layer on top.
- `etypecase` will error on unrecognized node kinds — this is intentional. If the parser produces a kind the evaluator doesn't handle, it's a bug, not a runtime error.
- Phase 8 stubs: for node kinds not yet implemented (`:agent`, `:search`, `:fulfillment`, `:emission`, `:wikilink`, `:bundle`), the evaluator should signal `innate-resistance` with a "not yet implemented" message. This way Phase 7 tests can verify resistance propagation without Phase 8 features.

</specifics>

<canonical_refs>
## Canonical References

### Language design
- `dpn-lang-spec.md` — Evaluation semantics, two-pass model, decree hoisting, context-determines-meaning principle

### Phase 2 artifacts (AST nodes evaluated)
- `src/types.lisp` — 20 `+node-*+` constants, `make-node`, `node-kind`/`value`/`children`/`props` accessors, `make-innate-result`, `make-resistance`, `resistance-p`

### Phase 4 artifacts (parser output consumed)
- `src/parser/parser.lisp` — `parse` function returning `:program` node, AST structure

### Phase 5 artifacts (resolver protocol called)
- `src/eval/resolver.lisp` — 6 defgenerics, `eval-env` struct with resolver/decrees/bindings/scope

### Phase 6 artifacts (test resolver)
- `src/eval/stub-resolver.lisp` — `stub-resolver` class, seeding helpers for test setup

### Existing stubs
- `src/eval/evaluator.lisp` — stub file to be filled
- `src/conditions.lisp` — `innate-resistance` condition for signaling

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `eval-env` struct from Phase 5 — carries resolver, decrees, bindings, scope through dispatch
- `make-stub-resolver` + seeding helpers from Phase 6 — test setup
- `parse` from Phase 4 — `(parse (tokenize source))` produces AST for evaluator
- `innate-resistance` condition from Phase 2 — signal for propagation
- `resistance-p` predicate — check resolver return values
- `tests/test-framework.lisp` — test macros

### Established Patterns
- `etypecase` dispatch on keywords — used for node kinds (locked decision from Phase 2)
- `defstruct` with `(:constructor make-X (&key ...))` — consistent across all data types
- Explicit `eval-env` argument threading (not dynamic `*resolver*`)

### Integration Points
- `innate.eval` package exists as stub — needs imports and `evaluate` export added to `packages.lisp`
- `src/eval/evaluator.lisp` registered in ASDF
- Full pipeline test: `(evaluate (parse (tokenize source)) env)` — first time all layers connect

</code_context>

<deferred>
## Deferred Ideas

- Dynamic `*current-script*` variable for error context — could add later if error messages need source file info
- Evaluation tracing/debugging hooks — future phase (out of scope for v1)
- Lazy evaluation / streaming results — not needed for v1 (scripts are small)

</deferred>

---

*Phase: 07-evaluator-core*
*Context gathered: 2026-03-29 via --auto (recommended defaults)*
