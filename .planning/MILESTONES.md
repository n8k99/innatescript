# Milestones

## v1.0 Innate Interpreter MVP (Shipped: 2026-03-29)

**Phases completed:** 9 phases, 19 plans, 30 tasks

**Key accomplishments:**

- ASDF system definition with nine package namespaces and stub source modules giving the innatescript Common Lisp project a loadable skeleton with zero external dependencies
- Export contracts for 32 innate.types symbols and 7 innate.conditions symbols established; two test sub-packages added; ASDF test system updated with test-conditions and test-types components
- Three-condition error model with signal-not-error innate-resistance contract implemented and proved by 6 behavioral tests; all 23 tests pass
- Single universal `defstruct node` with 20 keyword constants, innate-result and resistance structs fully implemented; 13 round-trip tests pass with 23/23 total test suite
- token defstruct with line/col tracking, innate.parser.tokenizer package with 6 exports, and test-tokenizer ASDF wiring establishing the foundation for Plans 02 and 03
- Complete tokenizer loop with cond-based character dispatch, two-char operator lookahead, and four literal readers (string/number/bare-word/emoji-slot) covering TOK-01 through TOK-15
- Wikilink disambiguation via pure lookahead, prose detection with nesting-depth gating, newline emission with collapse, and burg_pipeline.dpn integration test — completing all 23 token types and all 18 TOK requirements
- Recursive descent parser with token cursor struct, anonymous bracket bodies, kv-pair detection via lookahead, prose nodes, and multi-statement programs — 71/71 tests pass
- Complete expression grammar — reference with qualifier/combinator/lens postfix chain, agent, bundle, lens, search, decree, modifier, all parsing correctly; compound @type:"[[Burg]]"+all{state:==} produces exact locked node structure; 85/85 tests pass
- Complete parser — emission (->), fulfillment (||) with correct precedence and left-associativity; burg_pipeline.dpn parses without error; all 5 ROADMAP Phase 4 success criteria have explicit passing tests; 97/97 tests pass
- src/eval/resolver.lisp
- In-memory stub resolver with 6 CLOS method specializations, 4 seeding helpers, and 21 conformance tests covering qualifier chains, commission ordering, and case-insensitive plist lookup
- 1. [Rule 1 - Bug] Fixed missing closing parenthesis in bracket case
- Emission (`->`), wikilink (`[[]]`), and bundle (`{}`) eval-node cases replaced with real logic using the resolver protocol generics
- Parser infinite loop on `(agent){bundle}` expressions
- Interactive REPL and file runner connecting tokenize->parse->evaluate with per-condition error recovery at the loop boundary
- run-repl.sh shell entry point connecting SBCL to innate.repl:repl and innate.repl:run-file, completing the user-facing CLI surface with burg_pipeline.dpn end-to-end verified

---
