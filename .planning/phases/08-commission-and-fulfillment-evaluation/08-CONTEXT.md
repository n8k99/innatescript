# Phase 8: Commission and Fulfillment Evaluation - Context

**Gathered:** 2026-03-29
**Status:** Ready for planning
**Source:** Auto-generated (--auto flag, recommended defaults)

<domain>
## Phase Boundary

Agent commissions, search directives, the fulfillment operator, emission, wikilinks, and bundle loading all evaluate correctly against the stub resolver. This phase replaces the 6 Phase 7 stubs (`:agent`, `:bundle`, `:search`, `:fulfillment`, `:emission`, `:wikilink`) with real evaluation logic.

</domain>

<decisions>
## Implementation Decisions

### Agent commission evaluation (EVL-04)

- `(agent){instruction}` — the parser emits `:agent` and `:bundle` as adjacent siblings (CONTEXT.md Phase 4 decision)
- The evaluator must recognize this adjacency pattern: when evaluating a statement list and an `:agent` node is followed by a `:bundle` node, treat them as a commission
- Call `(deliver-commission resolver agent-name instruction-string)` on the resolver
- The stub resolver records the commission in its commissions list
- Return the `innate-result` from `deliver-commission`
- Standalone `:agent` without a following `:bundle` is valid — it's an agent address, not a commission. Return the agent name as a value.

### Search directive evaluation (EVL-05)

- `![search_expr]` — the `:search` node's children are the search expression terms
- Evaluate children to extract search-type and terms
- Call `(resolve-search resolver search-type terms)` on the resolver
- Return result or propagate resistance

### Fulfillment operator (EVL-06, ERR-04)

- `expr || (agent){instruction}` — the `:fulfillment` node has two children: left (the expression) and right (the commission/fallback)
- Evaluate the LEFT side first
- If left succeeds (no resistance): return the left result. The right side is NEVER evaluated.
- If left produces resistance: catch the `innate-resistance` signal via `handler-case`, then evaluate the RIGHT side and return its result
- This is the core of Innate's error model: resistance + fulfillment replaces try/catch
- The `handler-case` wraps only the left-side evaluation — the right side runs in the normal handler context

### Emission evaluation (EVL-07)

- `-> value, value` — the `:emission` node's children are the emitted values
- Evaluate each child in order
- Return the list of evaluated values (or the single value if only one child)
- For left-associative chains `a -> b -> c`: the parser already built `(-> (-> a b) c)`, so the evaluator just evaluates the nested `:emission` nodes recursively

### Wikilink evaluation (EVL-09)

- `[[Title]]` — the `:wikilink` node's value is the title string
- Call `(resolve-wikilink resolver title)` on the resolver
- Return result or propagate resistance

### Bundle loading (EVL-10)

- `{bundle_name}` — the `:bundle` node's value is the bundle name
- When standalone (not adjacent to an `:agent` node), call `(load-bundle resolver name)`
- `load-bundle` returns a list of AST nodes or nil
- If nodes returned: evaluate them as a sub-program (call `eval-node` on each, collect results)
- If nil: the bundle was not found — signal resistance

### Commission adjacency detection

- The evaluator needs to detect `(agent){bundle}` adjacency during statement list evaluation
- Approach: in `evaluate` pass 2, peek ahead when processing an `:agent` node. If the next sibling is `:bundle`, consume both and call `deliver-commission`. Otherwise, evaluate the `:agent` standalone.
- This keeps the parser simple (emits siblings) while the evaluator handles the semantic grouping.

### Claude's Discretion

- Internal helper decomposition (e.g., separate `eval-commission`, `eval-search`, `eval-fulfillment` helpers vs inline in etypecase)
- How to handle the adjacency peek (index-based iteration vs lookahead in dolist)
- Test organization and helper utilities
- Whether emission returns a flat list or nested structure for chains

</decisions>

<specifics>
## Specific Ideas

- The `||` fulfillment is the most important feature of Phase 8 — it converts resistance into action. Without it, unresolvable references are fatal. With it, they become agent commissions.
- Commission adjacency detection is the one place where the evaluator needs sibling context, not just the current node. This is the only deviation from the pure `eval-node` single-dispatch pattern.
- All 6 stubs in evaluator.lisp currently signal `innate-resistance` with "not yet implemented" messages. Phase 8 replaces each with real logic.

</specifics>

<canonical_refs>
## Canonical References

### Phase 7 artifacts (evaluator to extend)
- `src/eval/evaluator.lisp` — Current evaluator with 6 stubs to replace
- `tests/test-evaluator.lisp` — Existing evaluator tests

### Phase 5 artifacts (resolver protocol)
- `src/eval/resolver.lisp` — `deliver-commission`, `resolve-search`, `resolve-wikilink`, `load-bundle` generics

### Phase 6 artifacts (test resolver)
- `src/eval/stub-resolver.lisp` — `stub-add-entity`, `stub-add-wikilink`, `stub-add-bundle`, `stub-commissions`

### Phase 4 artifacts (parser output)
- `src/parser/parser.lisp` — How `:agent`, `:bundle`, `:search`, `:fulfillment`, `:emission`, `:wikilink` nodes are structured

### Conditions
- `src/conditions.lisp` — `innate-resistance` for fulfillment handler-case

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `eval-node` etypecase dispatch — extend existing cases
- `stub-resolver` with seeding helpers — test setup for commissions, wikilinks, bundles
- `stub-commissions` accessor — assert commission delivery in tests
- `handler-case` for `innate-resistance` — fulfillment catches resistance

### Established Patterns
- `resistance-p` check on resolver return → `signal 'innate-resistance` (from `:reference` and `:bracket` cases)
- `eval-node` recurses on children for compound nodes
- `evaluate` iterates top-level children with `dolist`

### Integration Points
- Replace 6 stub cases in `eval-node` etypecase
- Modify `evaluate` pass 2 loop for commission adjacency detection
- Full pipeline tests: `(evaluate (parse (tokenize "![search] || (agent){fix}")) env)`

</code_context>

<deferred>
## Deferred Ideas

- Chained fulfillment `a || b || c` — v2 (ADV-01). Parser left-associates, evaluator handles single binary for now.
- Template parameter binding — v2 (ADV-02).

</deferred>

---

*Phase: 08-commission-and-fulfillment-evaluation*
*Context gathered: 2026-03-29 via --auto (recommended defaults)*
