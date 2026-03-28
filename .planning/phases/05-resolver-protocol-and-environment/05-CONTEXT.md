# Phase 5: Resolver Protocol and Environment - Context

**Gathered:** 2026-03-28
**Status:** Ready for planning
**Source:** Auto-generated (--auto flag, recommended defaults)

<domain>
## Phase Boundary

The resolver contract is defined as CLOS defgenerics with documented call signatures, and the evaluation environment struct carries context through all subsequent evaluator work. This phase creates the abstraction boundary between the evaluator (Phase 7) and any concrete resolver (Phase 6 stub, future noosphere resolver). No evaluation logic — only the protocol definition and environment data structure.

</domain>

<decisions>
## Implementation Decisions

### Resolver base class and generics

- Define `resolver` as a CLOS `defclass` with no slots — it exists only as a dispatch target for generic functions
- Six generic functions on `resolver`:
  1. `resolve-reference (resolver name qualifiers)` → `innate-result` or `resistance` struct
  2. `resolve-search (resolver search-type terms)` → `innate-result` or `resistance` struct
  3. `deliver-commission (resolver agent-name instruction)` → `innate-result` (commissions always succeed from the resolver's perspective — the agent handles it)
  4. `resolve-wikilink (resolver title)` → `innate-result` or `resistance` struct
  5. `resolve-context (resolver context verb args)` → `innate-result` or `resistance` struct
  6. `load-bundle (resolver name)` → AST node list or `nil`
- Default methods on the base `resolver` class return `resistance` structs (using `make-resistance`) — not errors, not signals. The evaluator decides whether to signal `innate-resistance` based on context (e.g., if no `||` fulfillment is available).
- Return types use the existing `innate-result` and `resistance` structs from `innate.types` — no new types needed.

### Return value protocol

- **Found:** Return `(make-innate-result :value <data> :context <mode>)` where `<mode>` is one of `:query`, `:scope`, `:render`, `:commission`
- **Not found:** Return `(make-resistance :message "..." :source "...")`
- **Fulfillment required:** Return `(make-resistance ...)` — the evaluator catches resistance and routes to `||` fulfillment if available. The resolver doesn't know about fulfillment — that's evaluator semantics.
- No third "fulfillment-required" return type. Resistance IS the signal that fulfillment is needed. The evaluator interprets resistance in context.

### Evaluation environment struct

- `defstruct eval-env` with four slots:
  1. `resolver` — the `resolver` instance (CLOS object)
  2. `decrees` — hash-table mapping decree names (strings) to AST nodes (populated in evaluator pass 1)
  3. `bindings` — hash-table mapping variable names (strings) to values (for future `<-` inward flow, initially empty)
  4. `scope` — keyword indicating evaluation context: `:query`, `:scope`, `:render`, `:commission`
- Constructor: `make-eval-env &key resolver decrees bindings scope`
- The environment is passed as an explicit argument through evaluator dispatch — not a dynamic variable. The `*resolver*` dynamic var pattern mentioned in CLAUDE.md is reconsidered: explicit env argument is cleaner for the two-pass architecture since pass 1 and pass 2 need different decree states.
- `eval-env` lives in `innate.eval.resolver` package — the evaluator imports it from there alongside the generics.

### Package boundary enforcement

- `innate.eval.resolver` exports: `resolver` class, all six generics, `eval-env` struct + accessors
- `innate.eval` imports ONLY from `innate.eval.resolver` for resolver access — never from `innate.eval.stub-resolver`
- `innate.eval.stub-resolver` imports from `innate.eval.resolver` to specialize the generics
- This enforces the success criterion: "the evaluator package imports only from innate/resolver"

### Protocol specification

- Each generic function gets a docstring describing:
  - What the evaluator passes as arguments
  - What a conforming resolver must return for "found" vs "not found"
  - Any invariants (e.g., `deliver-commission` always returns a result, never resistance)
- The protocol spec lives in docstrings on the `defgeneric` forms — no separate `docs/` file needed. The docstrings ARE the spec. This keeps the spec co-located with the code and verifiable.

### Claude's Discretion

- Whether to add `print-object` methods for `resolver` and `eval-env`
- Exact parameter names on generics (e.g., `terms` vs `search-terms`)
- Test structure for verifying default methods return resistance
- Whether `eval-env-decrees` starts as `nil` or `(make-hash-table :test 'equal)`

</decisions>

<specifics>
## Specific Ideas

- The `resolver` class is intentionally empty — no slots, no state. Concrete resolvers add their own slots (e.g., stub-resolver will have an in-memory hash-table for entities).
- `deliver-commission` never returns resistance because commissions are fire-and-forget from the resolver's perspective. The agent may fail internally, but the resolver's job is just to deliver.
- `load-bundle` returns a list of AST nodes (the bundle's parsed contents) or `nil` if not found. It does NOT return a resistance struct — `nil` is sufficient for "bundle not found" and the evaluator can decide whether to resist.
- The `scope` slot on `eval-env` carries the evaluation context keyword that the PROJECT.md describes: "Context determines meaning, not syntax."

</specifics>

<canonical_refs>
## Canonical References

### Language design
- `dpn-lang-spec.md` — Resolver operations implied by syntax: `@` → resolve-reference, `![]` → resolve-search, `(){}` → deliver-commission, `[[]]` → resolve-wikilink, `[]` → resolve-context, `{}` (standalone) → load-bundle

### Phase 2 artifacts (types used by resolver)
- `src/types.lisp` — `make-innate-result`, `innate-result-value`, `innate-result-context`, `make-resistance`, `resistance-p`, `resistance-message`, `resistance-source`
- `src/conditions.lisp` — `innate-resistance` condition (signaled by evaluator, not resolver)

### Existing stubs
- `src/eval/resolver.lisp` — stub file to be filled with defclass + defgenerics
- `src/eval/evaluator.lisp` — stub file (Phase 7) that will import from resolver
- `src/eval/stub-resolver.lisp` — stub file (Phase 6) that will specialize the generics
- `src/packages.lisp` — `innate.eval.resolver` package needs exports filled

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `innate.types:make-resistance` / `innate.types:make-innate-result` — return types for all resolver generics
- `innate.types:resistance-p` — predicate for evaluator to check resolver return values
- `innate.conditions:innate-resistance` — condition the evaluator signals (not the resolver)
- `tests/test-framework.lisp` — `deftest`, `assert-equal`, `assert-true`

### Established Patterns
- `defstruct` with `(:constructor make-X (&key ...))` — used for `token`, `node`, `innate-result`, `resistance`
- Package exports in `packages.lisp`, implementation in module file
- `:import-from` exclusively — no `:use` except `:cl`

### Integration Points
- `innate.eval.resolver` package exists as stub — needs exports for class, generics, env struct
- `innate.eval` will import from `innate.eval.resolver` only (boundary enforcement)
- `innate.eval.stub-resolver` will specialize the generics (Phase 6)
- `src/eval/resolver.lisp` is registered in ASDF — just needs implementation

</code_context>

<deferred>
## Deferred Ideas

- Dynamic `*resolver*` variable for implicit threading — reconsidered in favor of explicit `eval-env` argument. Could revisit if evaluator function signatures get unwieldy.
- `resolve-template` generic for template instantiation — not in v1 requirements.
- Error recovery generics (restart-based) — the resistance/fulfillment model handles this through `||`, not through CL restarts at the resolver level.

</deferred>

---

*Phase: 05-resolver-protocol-and-environment*
*Context gathered: 2026-03-28 via --auto (recommended defaults)*
