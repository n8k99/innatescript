---
phase: 04-parser
plan: 02
subsystem: parser
tags: [common-lisp, recursive-descent, ast, reference, agent, bundle, lens, search, decree, modifier]

# Dependency graph
requires:
  - phase: 04-parser-01
    provides: "Token cursor, parse entry point, bracket/kv-pair/prose/heading parsers, 71 passing tests"
provides:
  - parse-reference: @name with optional :qualifier, +combinator, {lens} postfix chain
  - parse-agent: (agent_name) -> :agent node
  - parse-bundle-or-lens: {name} -> :bundle, {key:value} -> :lens with kv-pair children
  - parse-lens: {key:value} for use as postfix on references
  - parse-search: ![expr] -> :search node with expression children
  - parse-modifier: /name -> :modifier node
  - parse-decree: decree name [body] -> :decree node (replaces Plan 01 stub)
  - parse-heading: extended to handle optional bracket body children
  - Compound reference @type:"[[Burg]]"+all{state:==} -> exact locked node structure
  - 14 new parser tests covering PAR-04, PAR-06, PAR-07, PAR-08, PAR-09, PAR-10, PAR-11, PAR-14, PAR-17, PAR-18, PAR-19
affects: [04-parser-03, 05-evaluator]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Reference postfix chain: qualifier -> combinator -> lens, all optional, parsed left-to-right onto single :reference node"
    - "Multi-word qualifier accumulation: bare-words collected until terminator token (+, {, ], ), newline, EOF)"
    - "Bundle/lens disambiguation: bare-word followed by :colon in braces -> :lens; bare-word followed by :rbrace -> :bundle"
    - "parse-lens used as standalone (from parse-bundle-or-lens) and as postfix on references (from parse-reference)"
    - "Operator bare-words: = character added to bare-word char set in tokenizer for lens comparison operators (==, >=, <=)"

key-files:
  created: []
  modified:
    - "src/parser/parser.lisp — added parse-reference, parse-agent, parse-bundle-or-lens, parse-lens, parse-search, parse-modifier, parse-decree; extended parse-heading; replaced all Plan 01 stubs"
    - "src/parser/tokenizer.lisp — added = to bare-word char set for operator words like ==; added = case to main dispatch"
    - "tests/test-parser.lisp — 14 new tests for all new expression parsers"

key-decisions:
  - "Qualifiers stored in both children (string-lit node) and props (:qualifiers list) per CONTEXT.md — evaluator has both tree-walk and fast-access paths"
  - "parse-lens is separate from parse-bundle-or-lens — reference postfix uses parse-lens directly, outer braces use parse-bundle-or-lens for disambiguation"
  - "= added to tokenizer bare-word chars (Rule 1 auto-fix) — lens comparison operators like == are document-specified as bare-words per CONTEXT.md"
  - "Wikilink test uses [x [[Title]] y] pattern — [[name]] only tokenizes as :wikilink at nesting-depth > 0, same constraint documented in Plan 01"

requirements-completed: [PAR-04, PAR-05, PAR-06, PAR-07, PAR-08, PAR-09, PAR-10, PAR-11, PAR-14, PAR-16, PAR-17, PAR-18, PAR-19]

# Metrics
duration: 4min
completed: 2026-03-28
---

# Phase 04 Plan 02: Expression Grammar Summary

**Complete expression grammar — reference with qualifier/combinator/lens postfix chain, agent, bundle, lens, search, decree, modifier, all parsing correctly; compound @type:"[[Burg]]"+all{state:==} produces exact locked node structure; 85/85 tests pass**

## Performance

- **Duration:** 4 min
- **Started:** 2026-03-28T22:47:47Z
- **Completed:** 2026-03-28T22:51:45Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments

- `parse-reference` with full postfix chain: qualifier (bare-word multi-word and string literal), combinator, and lens — all optional, left-to-right
- `parse-agent` for `(agent_name)` -> `:agent` node
- `parse-bundle-or-lens` for `{name}` -> `:bundle` and `{key:value}` -> `:lens`
- `parse-lens` for postfix lens on references (shared with bundle/lens parser)
- `parse-search` for `![expr]` -> `:search` node
- `parse-modifier` for `/modifier` -> `:modifier` node
- `parse-decree` for `decree name [body]` -> `:decree` node (no body also valid)
- `parse-heading` extended with optional bracket children
- Tokenizer: `=` character added to bare-word set for lens comparison operators
- 14 new parser tests; all 85 tests pass

## Task Commits

1. **Task 1: Reference, agent, bundle, lens, search, modifier parsers** - `06c02df`
2. **Task 2: Decree and heading tests (implementation already in Task 1)** - `d3789b5`

## Files Created/Modified

- `/home/n8k99/Development/innatescript/src/parser/parser.lisp` — All new parsers plus decode stub replacement and heading extension
- `/home/n8k99/Development/innatescript/src/parser/tokenizer.lisp` — `=` in bare-word char set
- `/home/n8k99/Development/innatescript/tests/test-parser.lisp` — 14 new tests

## Decisions Made

**Qualifiers stored in both children and props.** Per CONTEXT.md locked structure: qualifier string-lit appears in children (for AST tree-walking) and `:qualifiers` list appears in `:props` (for fast evaluator access). Both paths are required.

**parse-lens is separate from parse-bundle-or-lens.** The reference postfix chain (`@type:"[[Burg]]"+all{state:==}`) needs to call `parse-lens` on the trailing `{state:==}` without the bundle disambiguation logic. Having a standalone `parse-lens` (used by both reference postfix and bracket kv-pair value parsing) keeps the code clean.

**`=` added to tokenizer bare-word chars.** CONTEXT.md explicitly states: "No hardcoded operator set — the parser emits whatever token appears as a `:bare-word` node. The evaluator interprets operator semantics." The `==` in `{state:==}` must tokenize as `:bare-word`. This required adding `=` as a valid bare-word character in the tokenizer and as a starting character in the main dispatch.

**Wikilink test uses existing confirmed pattern.** Plan 01 documented that `[[name]]` tokenizes as `:wikilink` only at nesting-depth > 0. My initial `[[[Title]]]` test was wrong — three separate lbrackets. Changed to `[x [[Title]] y]` which matches the Plan 01 test-wikilink-atom pattern.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Tokenizer does not handle = character for lens comparison operators**
- **Found during:** Task 1 (test-compound-reference)
- **Issue:** `@type:"[[Burg]]"+all{state:==}` fails with "Unexpected character: =" because `=` was not in the tokenizer's character set. CONTEXT.md explicitly documents `==` as a bare-word lens operator.
- **Fix:** Added `#\=` to `%read-bare-word` char set and added `=` case to main tokenizer dispatch (falls through to `%read-bare-word`, emits `:bare-word`)
- **Files modified:** src/parser/tokenizer.lisp
- **Commit:** 06c02df

**2. [Rule 1 - Bug] test-wikilink-in-program used wrong nesting pattern**
- **Found during:** Task 2
- **Issue:** `[[[Title]]]` tokenizes as three nested empty brackets with bare-word "Title", not as bracket containing wikilink. Wikilinks require `[[name]]` at nesting-depth > 0 but not inside triple-bracket depth.
- **Fix:** Changed test to `[x [[Title]] y]` — matches confirmed Plan 01 pattern
- **Files modified:** tests/test-parser.lisp
- **Commit:** d3789b5

---

**Total deviations:** 2 auto-fixed (2 Rule 1 bugs)

## Issues Encountered

None beyond deviations documented above.

## User Setup Required

None.

## Next Phase Readiness

- All expression types parse correctly: reference, agent, bundle, lens, search, decree, modifier, heading, wikilink, prose, atoms
- Remaining for Plan 03: emission (`->`), fulfillment (`||`)
- Plan 03 stubs (`:arrow` in parse-statement) are already in place
- Phase 05 evaluator can walk the complete AST

## Self-Check: PASSED
