---
status: verifying
trigger: "Parser hangs on (sylvia){\"fix\"} — infinite loop in recursive descent"
created: 2026-03-28T00:00:00Z
updated: 2026-03-28T00:01:00Z
---

## Current Focus

hypothesis: After parse-agent returns an :agent node for (sylvia), parse-expression returns that node to parse-emission-expr. parse-emission-expr returns it to parse-fulfillment-expr (no || present). parse-fulfillment-expr returns it to parse-statement. Then parse-statement-list does NOT advance past the { token — it just calls parse-statement again for the remaining { "fix" } tokens. parse-statement dispatches to parse-fulfillment-expr → parse-emission-expr → parse-expression which sees :lbrace and calls parse-bundle-or-lens. That succeeds. So the question is what causes the LOOP.

Actually: re-reading the token list — :lparen :bare-word("sylvia") :rparen :lbrace :string("fix") :rbrace

parse-bundle-or-lens is called. tok = :lbrace (consumed by cursor-expect). Then it peeks at the next token after lbrace: tok = :string("fix"), next = :rbrace.

- Case 1 (lens): tok is bare-word AND next is colon → NO (tok is :string, not bare-word)
- Case 2 (bundle): tok is bare-word → NO (tok is :string)
- Case 3 (else): Falls to the else branch — "consume until rbrace" loop

In the else branch at line 491-501: the loop peeks t2. t2 = :string("fix"). It is NOT null, NOT :rbrace, and NOT handled — so it falls through the cond with no action taken, loops again, sees :string("fix") again — INFINITE LOOP.

test: Trace through parse-bundle-or-lens with tokens [:lbrace, :string("fix"), :rbrace]
expecting: The else branch loops forever because :string token is not consumed and not :rbrace
next_action: Fix the else branch to consume unknown tokens, OR better: add a :string case to parse-bundle-or-lens that parses bundle contents generically

## Symptoms

expected: `(parse (tokenize "(sylvia){\"fix\"}"))` returns a :program node with :agent and :bundle children
actual: SBCL hangs indefinitely, never returns
errors: None — no crash, just infinite loop
reproduction: `sbcl --eval '(asdf:load-system :innatescript)' --eval '(innate.parser:parse (innate.parser.tokenizer:tokenize "(sylvia){\"fix\"}"))'` hangs
started: First discovered when running Phase 8 tests. Parser built in Phase 4 and passed all tests. This expression wasn't tested in Phase 4.

## Eliminated

(none yet)

## Evidence

- timestamp: 2026-03-28T00:00:00Z
  checked: Token stream for "(sylvia){\"fix\"}"
  found: 6 tokens — :lparen, :bare-word("sylvia"), :rparen, :lbrace, :string("fix"), :rbrace
  implication: parse-agent handles (sylvia) as simple agent form. Then {\"fix\"} is parsed by parse-bundle-or-lens.

- timestamp: 2026-03-28T00:00:00Z
  checked: parse-bundle-or-lens (lines 444-502)
  found: After consuming :lbrace, it peeks tok=:string("fix"), next=:rbrace. Case 1 requires tok=:bare-word + next=:colon → fails. Case 2 requires tok=:bare-word → fails. Falls to else branch (lines 490-502). Else branch loops: peeks t2=:string("fix"). Cond has only null, :rbrace, :newline cases. :string falls through with NO consume and NO return. Loop repeats forever.
  implication: The else "consume until rbrace" branch is missing a default consume for unrecognized tokens. It only handles :rbrace (exits) and :newline (consumes), but silently does nothing for all other token types, causing an infinite loop.

## Resolution

root_cause: parse-bundle-or-lens else branch (lines 490-502) had no default token-consuming case. When encountering a :string (or any non-bare-word, non-newline, non-rbrace token) as brace content, the loop peeked it, none of the cond clauses matched, and the loop repeated without advancing the cursor — infinite loop.
fix: Replaced the bare consume-until-rbrace loop in the else branch with a proper expression-collecting loop. Added :newline skip and a default else clause that calls parse-expression to consume and collect each token as a child node. Changed the result from :lens with nil children to :bundle with expression children.
verification: SBCL parsed "(sylvia){\"fix\"}" returning :program with 2 children — :agent "sylvia" and :bundle with :string-lit "fix" child. No hang. All 161 existing tests continue to pass (2 failures in test suite are pre-existing from unrelated evaluator/stub-resolver changes in the working tree).
files_changed: [src/parser/parser.lisp]
