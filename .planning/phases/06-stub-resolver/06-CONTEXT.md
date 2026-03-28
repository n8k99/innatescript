# Phase 6: Stub Resolver - Context

**Gathered:** 2026-03-28
**Status:** Ready for planning
**Source:** Auto-generated (--auto flag, recommended defaults)

<domain>
## Phase Boundary

A fully conforming in-memory resolver exists that passes the resolver conformance test suite, enabling evaluator tests to run without any external infrastructure. The stub resolver specializes all 6 Phase 5 defgenerics with in-memory implementations. No external I/O, no database, no network.

</domain>

<decisions>
## Implementation Decisions

### Stub resolver class

- `defclass stub-resolver (resolver)` — subclass of the Phase 5 `resolver` base class
- Slots:
  1. `entities` — hash-table mapping entity names (strings) to plists. Each entity is a plist of properties: `(:type "Burg" :state "Seed" :description "...")`
  2. `commissions` — list of `(agent-name instruction)` pairs, accumulated in order. Used for test assertions.
  3. `wikilinks` — hash-table mapping title strings to content strings (or AST node lists)
  4. `bundles` — hash-table mapping bundle names to lists of AST nodes
  5. `contexts` — hash-table mapping `"context.verb"` compound keys to result values
- Constructor helper: `(make-stub-resolver)` → fresh instance with empty hash-tables and nil commissions list

### Generic specializations

- `resolve-reference (stub-resolver name qualifiers)`:
  - Look up `name` in `entities` hash-table
  - If found: return `(make-innate-result :value entity-plist :context (eval-env-scope ...))`
  - If qualifiers: walk the plist — `@name:qualifier` looks up `(getf entity (intern (string-upcase qualifier) :keyword))`
  - If not found: return `(make-resistance :message "..." :source name)`

- `resolve-search (stub-resolver search-type terms)`:
  - Iterate `entities`, filter by matching properties
  - Return `(make-innate-result :value matching-list ...)` or resistance if none match

- `deliver-commission (stub-resolver agent-name instruction)`:
  - Push `(list agent-name instruction)` onto `commissions` slot
  - Return `(make-innate-result :value t :context :commission)`

- `resolve-wikilink (stub-resolver title)`:
  - Look up `title` in `wikilinks` hash-table
  - Return result or resistance

- `resolve-context (stub-resolver context verb args)`:
  - Build compound key `"context.verb"`, look up in `contexts` hash-table
  - Return result or resistance

- `load-bundle (stub-resolver name)`:
  - Look up `name` in `bundles` hash-table
  - Return list of AST nodes or `nil`

### Test data seeding

- Provide `stub-add-entity (resolver name plist)` — add an entity to the entities hash-table
- Provide `stub-add-wikilink (resolver title content)` — add a wikilink
- Provide `stub-add-bundle (resolver name nodes)` — add a bundle
- Provide `stub-add-context (resolver context verb result)` — add a context resolution
- Provide `stub-commissions (resolver)` — accessor for the commissions list (for test assertions)
- All seeding functions are exported from `innate.eval.stub-resolver`

### Qualifier chain resolution (RES-10)

- `@name:qualifier` resolves by: find entity by `name`, then access property by `qualifier`
- Multiple qualifiers chain: `@name:q1:q2` → find entity, get property `q1`, if result is a plist get property `q2`
- Qualifier values can be strings — `@type:"[[Burg]]"` → find entity, match property `type` against value `"[[Burg]]"`. This is a filter, not a property access.
- For v1: simple single-level qualifier access is sufficient. Deep chaining can be extended later.

### Package exports

- `innate.eval.stub-resolver` exports: `stub-resolver`, `make-stub-resolver`, `stub-add-entity`, `stub-add-wikilink`, `stub-add-bundle`, `stub-add-context`, `stub-commissions`

### Claude's Discretion

- Internal helper functions for entity matching
- Exact search filtering logic
- Test case design beyond the 3 success criteria
- Whether qualifier matching is case-sensitive (recommend: case-insensitive with `string-equal`)

</decisions>

<specifics>
## Specific Ideas

- The stub resolver is NOT a mock — it's a fully conforming implementation. It should handle edge cases (empty qualifier list, missing entity properties, nil instruction) gracefully.
- Commission recording order matters — tests assert against the list in delivery order.
- The stub is the ONLY resolver available until the noosphere resolver (separate repo). All evaluator tests (Phases 7-9) depend on it.

</specifics>

<canonical_refs>
## Canonical References

### Phase 5 artifacts (protocol to implement)
- `src/eval/resolver.lisp` — 6 defgenerics with docstrings defining the contract
- `src/packages.lisp` — `innate.eval.resolver` exports, `innate.eval.stub-resolver` import stub

### Phase 2 artifacts (types used)
- `src/types.lisp` — `make-innate-result`, `make-resistance`, `resistance-p`

### Existing stubs
- `src/eval/stub-resolver.lisp` — stub file to be filled

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `resolver` base class and 6 defgenerics from Phase 5
- `make-innate-result`, `make-resistance` from `innate.types`
- `tests/test-framework.lisp` — test macros

### Established Patterns
- `defclass` with `(:constructor ...)` not applicable — CLOS uses `make-instance`
- Package exports in `packages.lisp`, implementation in module file
- `:import-from` exclusively

### Integration Points
- `innate.eval.stub-resolver` package exists — needs exports added to `packages.lisp`
- `src/eval/stub-resolver.lisp` registered in ASDF
- Evaluator tests (Phase 7+) will create `(make-stub-resolver)` and seed test data

</code_context>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 06-stub-resolver*
*Context gathered: 2026-03-28 via --auto (recommended defaults)*
