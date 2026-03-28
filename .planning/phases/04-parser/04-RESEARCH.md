# Phase 4: Parser - Research

**Researched:** 2026-03-28
**Domain:** Hand-rolled recursive descent parser in Common Lisp — token list to typed AST
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Precedence hierarchy (tightest to loosest):**
1. Atoms — `:bare-word`, `:string`, `:number`, `:wikilink`, `:emoji-slot`
2. Primary expressions — `@name`, `(agent)`, `{bundle}`, `![search]`, `[bracket]`, `#heading`
3. Postfix chains on references — `:qualifier`, `+combinator`, `{lens}` — attach left-to-right onto a reference expression, producing a single compound `:reference` node
4. Presentation modifiers — `/modifier` attaches to preceding expression
5. Emission — `-> value, value` (left-associative)
6. Fulfillment (loosest) — `expr || (agent){instruction}` — binary only in v1

**Compound reference node structure:**
`@type:"[[Burg]]"+all{state:==}` produces a `:reference` node with qualifier, combinator, and lens as children. Qualifiers in both `children` (for tree-walking) and `props` (for quick evaluator access). Colon after `@name` triggers qualifier parsing. `+` after a reference triggers combinator parsing. `{` after a reference triggers lens parsing.

**Bracket body parsing (purposive sequencing):**
Inside `[...]`, parser reads a heterogeneous sequence. No separation of kv-pairs from nested expressions — everything is a child. Body loop recognizes:
- `bare-word COLON` → `:kv-pair`
- `LBRACKET` → nested bracket expression (recursive)
- `HASH` → heading/presentation directive
- `AT` → reference expression
- `BANG-BRACKET` → search directive
- `ARROW` → emission statement
- `PROSE` token → `:prose` node (preserved as-is)
- `DECREE` → decree declaration
- Any other expression → parse as expression
Terminates at matching `RBRACKET`.

**Colon disambiguation:**
- `bare-word COLON` at bracket-body level → kv-pair
- `AT bare-word COLON` → reference with qualifier
- Context-free, one-token lookahead only.

**Fulfillment operator:** `||` binary only in v1, left-associates for forward compatibility. Looser than everything except top-level statement boundaries.

**Emission operator:** `->` left-associative. `a -> b -> c` → `(-> (-> a b) c)`. `:emission` node's `children` are emitted values. Comma separates multiple values.

**Comparison operators inside lenses:** `{state:==}` — parser emits the RHS as a `:bare-word` node. No hardcoded operator set. Evaluator interprets semantics.

**Search directive body:** `![expr]` — parse expression list until `RBRACKET`. Inside can be function-call-like syntax.

**Agent commission:** Parser emits `(agent)` and `{instruction}` as siblings. Evaluator recognizes the adjacency pattern.

**Decree parsing:** `decree name [body]` → `:decree` node. Body is optional. Body enclosed in brackets.

**Top-level statement list:** `:newline` tokens consumed as separators, not emitted as nodes. `:program` node children are all top-level statements in source order.

**Error handling:** Signal `innate-parse-error` with line/col from the token. No partial AST recovery. Error messages reference token type and position.

**Parser permissiveness:** Structurally permissive — build valid trees for anything syntactically well-formed. No depth limit on nesting. Ghosts have the grammar codebook.

### Claude's Discretion

- Exact recursive descent function naming and decomposition
- Whether to use a token-cursor struct or pass index + token-list
- Test case selection beyond the 5 success criteria
- Internal helper organization

### Deferred Ideas (OUT OF SCOPE)

- Chained fulfillment `a || b || c` with escalation semantics — v2 (ADV-01)
- Template parameter binding (`@burg_name` receiving values) — v2 (ADV-02)
- Inward flow operator `<-` — v2 (ADV-04)
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| PAR-01 | Parse `[context[verb[args]]]` nested bracket expressions | Bracket body loop with recursive `parse-bracket`, terminates at matching `RBRACKET` |
| PAR-02 | Parse anonymous bracket depth — `[[["Hello"]]]` as complete statement | Same bracket recursion; unnamed brackets have nil value in the node |
| PAR-03 | Parse multiple top-level statements per file | Top-level loop consuming `:newline` separators until EOF |
| PAR-04 | Parse `(agent_name)` agent address expressions | `parse-primary` case for `:lparen` — read bare-word, expect `:rparen` |
| PAR-05 | Parse `(agent){instruction}` agent-with-bundle commission | Siblings in same parent — evaluator recognizes adjacency pattern |
| PAR-06 | Parse `{name}` bundle references | `parse-primary` case for `:lbrace` — read optional bare-word or kv-pairs |
| PAR-07 | Parse `{key:value}` lens expressions | Inside `{...}`, bare-word followed by `:colon` → kv-pair children |
| PAR-08 | Parse `@name` direct references | `parse-reference` — consumes `:at` then `:bare-word` |
| PAR-09 | Parse `@name:qualifier` references with natural-language qualifiers | After `@name`, if next token is `:colon`, accumulate bare-words until terminator |
| PAR-10 | Parse `@type:"[[Burg]]"+all{state:==}` compound reference | Reference postfix chain: qualifier, then combinator, then lens, all optional |
| PAR-11 | Parse `![search_expr]` search directives | `parse-search` — consumes `:bang-bracket`, expression list until `:rbracket` |
| PAR-12 | Parse `expr \|\| (agent){instruction}` fulfillment expressions | `parse-fulfillment` — left operand, consume `:pipe-pipe`, right operand |
| PAR-13 | Parse `-> value [, value]*` emission statements | `parse-emission` — consumes `:arrow`, then value list separated by `:comma` |
| PAR-14 | Parse `decree name [body]` declarations | `parse-decree` — consumes `:decree`, reads name bare-word, optional `[body]` |
| PAR-15 | Parse `key: value` key-value pairs inside brackets | Bracket body loop: `bare-word COLON` lookahead pattern |
| PAR-16 | Parse `+word` combinators attached to expressions | Reference postfix: if next token after reference is `:plus`, parse combinator |
| PAR-17 | Parse `/modifier` presentation directives | `parse-modifier` — consumes `:slash`, reads bare-word; attaches to preceding expr |
| PAR-18 | Parse `[[Title]]` wikilinks as AST nodes | `parse-atom` case for `:wikilink` — direct token-to-node conversion |
| PAR-19 | Parse `# text` headings as AST nodes | `parse-primary` case for `:hash` — reads bare-word after hash |
| PAR-20 | Parse prose lines as first-class AST nodes (not discarded) | `parse-atom` or top-level statement: `:prose` token → `:prose` node with value preserved |
| PAR-21 | Parse block bodies with purposive sequencing | Bracket body loop in `parse-bracket-body` function |
</phase_requirements>

---

## Summary

Phase 4 implements the token-to-AST transformation for Innate. All inputs are lists of token structs produced by the Phase 3 tokenizer. All outputs are `node` structs using the Phase 2 type system. The parser is a hand-rolled recursive descent implementation — consistent with CLAUDE.md zero-external-dependencies convention and established project patterns.

The architecture follows a standard operator-precedence recursive descent structure: each grammar production is a function, tighter-binding constructs are parsed by functions that call into looser-binding functions as their "left side." The special case for Innate is the reference postfix chain (qualifier, combinator, lens), which the CONTEXT.md locks as producing a single flat `:reference` node rather than a nested binary expression tree.

The main implementation challenge is the bracket body dispatch loop, which handles seven different token types with different parsing behaviors in a single heterogeneous sequence. The colon disambiguation (kv-pair vs. qualifier) requires one token of lookahead, which is trivially available in any cursor design.

**Primary recommendation:** Use a token-cursor struct with `peek`, `consume`, and `expect` helpers. This is cleaner than passing a mutable index through recursive calls and avoids the parameter threading anti-pattern established in the existing codebase (see `%read-X` local functions in tokenizer).

---

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| SBCL | 2.x (current) | Runtime | Project convention, established in phases 1-3 |
| ASDF | 3.3+ (bundled) | Build | Established in phase 1; `innatescript.asd` already wires `parser.lisp` |
| `innate.types` | project | AST nodes | `make-node`, `+node-*+` constants — already defined, already exported |
| `innate.conditions` | project | Error signaling | `innate-parse-error` — already defined, already exported |
| `innate.parser.tokenizer` | project | Token input | `tokenize`, `token-type`, `token-value`, `token-line`, `token-col` — already exported |

### Supporting Patterns (not libraries)

| Pattern | Purpose | When to Use |
|---------|---------|-------------|
| Token cursor struct | State encapsulation | Holds `tokens` list and `pos` integer; `peek` returns current token, `consume` advances, `expect` consumes or signals |
| `labels`-local helper functions | Recursive descent functions | All grammar production functions share the cursor lexically — no parameter threading needed |
| `case (token-type (peek cursor))` dispatch | Token dispatch | Standard pattern for deciding which production to invoke |
| One-token lookahead | Colon disambiguation and postfix chain detection | Peek-next without consuming — essential for kv-pair vs. qualifier disambiguation |
| Reference postfix loop | Qualifier/combinator/lens accumulation | After parsing `@name`, loop while next token is `:colon`, `:plus`, or `:lbrace`, accumulating children |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Token cursor struct | Pass `(tokens pos)` pair | Cursor struct is cleaner in recursive calls; pair threading pollutes every function signature — rejected per project dynamic-var convention |
| `labels` local helpers | Top-level `defun` functions | Local helpers in `parse` entry point share cursor lexically; top-level functions would need cursor as explicit parameter or global dynamic var |
| `case` on token-type | `cond` with `token-type-p` predicates | `case` is cleaner when dispatching on keywords; `cond` more appropriate when mixing type tests with predicates (tokenizer uses `cond` for this reason) |

**Installation:** No new packages required. All dependencies already present in the ASDF system.

---

## Architecture Patterns

### Recommended Project Structure

```
src/
├── packages.lisp        # Add :innate.parser exports and imports
├── parser/
│   ├── tokenizer.lisp   # Existing — unchanged
│   └── parser.lisp      # Phase 4 implementation target
tests/
├── packages.lisp        # Add innate.tests.parser package
└── test-parser.lisp     # New test file for Phase 4
```

The ASDF `innatescript.asd` already has `(:file "parser" :depends-on ("tokenizer"))` in the parser module. The tests system needs a new `(:file "test-parser" :depends-on ("packages" "test-framework"))` component added.

### Pattern 1: Token Cursor Struct

**What:** A small struct that holds the token list and current position. All parser functions take the cursor as their first argument.

**When to use:** The cursor is the single shared piece of mutable state. Every recursive descent function reads from it.

```common-lisp
;; Source: established pattern from PCL and CL interpreter implementations
(defstruct (parse-cursor
            (:constructor make-parse-cursor (tokens)))
  "Mutable token stream cursor for recursive descent parsing."
  (tokens  nil)
  (pos     0   :type fixnum))

(defun cursor-peek (cursor)
  "Return current token without consuming, or nil at end."
  (let ((tokens (parse-cursor-tokens cursor))
        (pos    (parse-cursor-pos cursor)))
    (when (< pos (length tokens))
      (nth pos tokens))))

(defun cursor-consume (cursor)
  "Return current token and advance position. Nil at end."
  (let ((tok (cursor-peek cursor)))
    (when tok
      (incf (parse-cursor-pos cursor)))
    tok))

(defun cursor-expect (cursor token-type)
  "Consume token of TYPE or signal innate-parse-error."
  (let ((tok (cursor-peek cursor)))
    (if (and tok (eq (token-type tok) token-type))
        (cursor-consume cursor)
        (error 'innate-parse-error
               :line (if tok (token-line tok) 0)
               :col  (if tok (token-col  tok) 0)
               :text (format nil "Expected ~a, got ~a"
                             token-type
                             (if tok (token-type tok) :eof))))))
```

### Pattern 2: Main Entry Point

**What:** `(parse token-list)` creates a cursor, enters the top-level statement loop, returns a `:program` node.

```common-lisp
(defun parse (tokens)
  "Convert list of token structs to a :program AST node."
  (let ((cursor (make-parse-cursor tokens)))
    (make-node :kind +node-program+
               :children (parse-statement-list cursor))))

(defun parse-statement-list (cursor)
  "Parse zero or more statements, consuming :newline separators."
  (let ((stmts '()))
    (loop
      (let ((tok (cursor-peek cursor)))
        (cond
          ((null tok) (return))
          ((eq (token-type tok) :newline)
           (cursor-consume cursor))  ; consume separator, no node
          (t
           (let ((stmt (parse-statement cursor)))
             (when stmt (push stmt stmts)))))))
    (nreverse stmts)))
```

### Pattern 3: Reference Postfix Chain

**What:** After parsing `@name`, loop consuming optional qualifier (`:colon`), combinator (`:plus`), and lens (`:lbrace`) extensions. All accumulate into a single `:reference` node.

**When to use:** PAR-09, PAR-10, PAR-16 — all reference modifier forms.

```common-lisp
(defun parse-reference (cursor)
  "Parse @name with optional postfix qualifier, combinator, lens.
   Returns a :reference node."
  (let* ((at-tok (cursor-expect cursor :at))
         (name-tok (cursor-expect cursor :bare-word))
         (children '())
         (props '()))
    ;; Optional qualifier: @name:qualifier-words...
    (when (and (cursor-peek cursor)
               (eq (token-type (cursor-peek cursor)) :colon))
      (cursor-consume cursor)  ; consume :
      (let ((qual-words '()))
        (loop while (and (cursor-peek cursor)
                         (eq (token-type (cursor-peek cursor)) :bare-word))
              do (push (token-value (cursor-consume cursor)) qual-words))
        (let ((qual-str (format nil "~{~a~^ ~}" (nreverse qual-words))))
          (push (make-node :kind +node-string-lit+ :value qual-str) children)
          (setf props (list* :qualifiers (list qual-str) props)))))
    ;; Optional combinator: +word
    (when (and (cursor-peek cursor)
               (eq (token-type (cursor-peek cursor)) :plus))
      (cursor-consume cursor)  ; consume +
      (let ((comb-tok (cursor-expect cursor :bare-word)))
        (push (make-node :kind +node-combinator+
                         :value (token-value comb-tok)) children)
        (setf props (list* :combinator (token-value comb-tok) props))))
    ;; Optional lens: {key:value...}
    (when (and (cursor-peek cursor)
               (eq (token-type (cursor-peek cursor)) :lbrace))
      (push (parse-lens cursor) children))
    (make-node :kind +node-reference+
               :value (token-value name-tok)
               :children (nreverse children)
               :props props)))
```

### Pattern 4: Bracket Body Dispatch Loop

**What:** Inside `[...]`, consume tokens until `:rbracket`, dispatching on each token's type.

```common-lisp
(defun parse-bracket-body (cursor)
  "Parse the heterogeneous sequence inside brackets.
   Returns list of child nodes. Cursor must be positioned after LBRACKET."
  (let ((children '()))
    (loop
      (let ((tok (cursor-peek cursor)))
        (cond
          ;; End of bracket body
          ((null tok)
           (error 'innate-parse-error :line 0 :col 0
                  :text "Unterminated bracket expression"))
          ((eq (token-type tok) :rbracket)
           (cursor-consume cursor)  ; consume ]
           (return))
          ;; Newline separator — skip
          ((eq (token-type tok) :newline)
           (cursor-consume cursor))
          ;; Prose node — emit as-is
          ((eq (token-type tok) :prose)
           (cursor-consume cursor)
           (push (make-node :kind +node-prose+
                            :value (token-value tok)) children))
          ;; kv-pair: bare-word followed by COLON
          ((and (eq (token-type tok) :bare-word)
                (let ((next (cursor-peek-next cursor)))
                  (and next (eq (token-type next) :colon))))
           (push (parse-kv-pair cursor) children))
          ;; Nested bracket
          ((eq (token-type tok) :lbracket)
           (push (parse-bracket cursor) children))
          ;; All other expressions
          (t
           (push (parse-expression cursor) children)))))
    (nreverse children)))
```

Note: `cursor-peek-next` peeks at `pos+1` without consuming — used only for the kv-pair lookahead.

### Pattern 5: Left-Associative Emission Chain

**What:** `a -> b -> c` builds `(-> (-> a b) c)`. The `:emission` node has children as the emitted values.

```common-lisp
(defun parse-emission (cursor)
  "Parse -> value [, value]* — returns :emission node."
  (cursor-consume cursor)  ; consume ->
  (let ((values '()))
    (push (parse-expression cursor) values)
    (loop while (and (cursor-peek cursor)
                     (eq (token-type (cursor-peek cursor)) :comma))
          do (cursor-consume cursor)  ; consume ,
             (push (parse-expression cursor) values))
    (make-node :kind +node-emission+
               :children (nreverse values))))
```

For the left-associative chain `a -> b -> c`, the top-level statement loop handles this by recognizing that `->` at statement level wraps the preceding expression. The locked CONTEXT.md decision is that `->` binds as a statement-level infix operator — the statement parser, not the expression parser, handles this.

### Pattern 6: Fulfillment Binary Operator

```common-lisp
(defun parse-fulfillment (left-node cursor)
  "Given a left-side node and cursor at ||, parse the right side."
  (cursor-consume cursor)  ; consume ||
  (let ((right (parse-expression cursor)))
    (make-node :kind +node-fulfillment+
               :children (list left-node right))))
```

### Anti-Patterns to Avoid

- **Embedding token-list position as a global dynamic var:** The tokenizer used `labels`-local helpers sharing `pos` lexically. The parser has recursive calls, not just a linear loop, so dynamic vars for position would be unreliable across recursion. Use a struct.
- **Signaling on `]` mismatch with generic error:** Always include the opening token's line/col in unterminated-bracket errors. The token stream carries line/col on every token.
- **Hardcoding `:newline` as a node type in the AST:** Newlines are consumed as separators at the statement level. They never become AST nodes. The CONTEXT.md explicitly says `:newline` tokens are consumed, not emitted.
- **Trying to infer kv-pair vs. qualifier at the expression level:** These are distinguished by context (bracket-body vs. reference expression). The bracket body loop handles kv-pair detection. The reference parser handles qualifier detection. They are separate code paths.
- **`cl:read` anywhere in the parser:** CL's reader expects S-expressions. `:at`, `:[`, `:->` will all cause errors. Already listed in CLAUDE.md "What NOT to Use."

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| AST node representation | Custom `defclass` hierarchy | `innate.types:make-node` + `+node-*+` constants | Already defined in Phase 2; `etypecase` dispatch on `node-kind` keyword is the established pattern |
| Error signaling | Custom condition type | `innate.conditions:innate-parse-error` | Already defined with `line`/`col`/`text` slots; the tokenizer already uses it |
| Token access | Re-parse token data | `token-type`, `token-value`, `token-line`, `token-col` | Already exported from `innate.parser.tokenizer` |
| Test framework | New assertion macros | `innate.tests:deftest`, `assert-equal`, `assert-signals` | Hand-rolled in Phase 1; `assert-signals` specifically covers the parse-error success criterion |

**Key insight:** Three prior phases have built all the substrate the parser needs. Phase 4 is pure production logic on top of complete infrastructure.

---

## Common Pitfalls

### Pitfall 1: Qualifier Accumulation Stops Too Late

**What goes wrong:** The qualifier parser accumulates all bare-words until it hits a non-bare-word. But `@Alaran:generative hard prompt` needs to stop at `]`, `)`, newline, `+`, `{`. If those are not checked, the qualifier eats into the next construct.

**Why it happens:** The natural loop `while (token-type == :bare-word)` is almost right — but `:bare-word` tokens can appear inside the next `[...]` body too, just after the reference.

**How to avoid:** Qualifier accumulation terminates at: `+` (combinator), `{` (lens), `]` (bracket close), `)` (paren close), `:newline`, `||` (fulfillment), `->` (emission), or EOF. After reading each bare-word, check the next token against this set before continuing.

**Warning signs:** The test `@type:"[[Burg]]"+all{state:==}` fails because the `:string` token after the qualifier colon is not `:bare-word` — the string is the qualifier value. The qualifier parser must handle `:string` as a qualifier value, not just bare-words.

### Pitfall 2: Bracket Nesting Depth Exhausts the Stack

**What goes wrong:** Deep nesting like `[[[[...]]]]` causes excessive recursion in a naive recursive descent implementation.

**Why it happens:** Each `[` calls `parse-bracket`, which calls `parse-bracket-body`, which calls `parse-bracket` again.

**How to avoid:** The CONTEXT.md explicitly allows arbitrary nesting depth and says "no depth limit." SBCL's default stack is large enough for practical nesting depths in normal programs. The implementation should not artificially limit depth. If the nesting is truly pathological, SBCL will signal a stack overflow, which surfaces as a Lisp condition — acceptable behavior for v1.

**Warning signs:** Tests with 3-4 levels of nesting pass but 10+ levels crash. Document the behavior as a known v1 limitation.

### Pitfall 3: Consuming the Closing `]` in Bracket Body vs. Returning to Caller

**What goes wrong:** `parse-bracket` calls `parse-bracket-body`, which consumes the `]`. But `parse-bracket` also tries to consume the `]`. Double consumption skips the next token.

**How to avoid:** Decide exactly who owns the `]` consumption: either `parse-bracket` consumes the opening `[`, calls `parse-bracket-body` to consume everything up to `]` (but not including), then `parse-bracket` consumes `]`; OR `parse-bracket-body` consumes `]` as its termination step. The second approach (body consumes its own `]`) is shown in Pattern 4 above and avoids re-checking in the caller.

**Warning signs:** Parser produces wrong child counts in tests, or skips tokens after a closing bracket.

### Pitfall 4: `packages.lisp` Missing Parser Exports

**What goes wrong:** `innate.parser` package in `packages.lisp` currently has empty `:export` and `(:import-from :innate.parser.tokenizer)` with no specific symbols. The `parse` function won't be visible to `innate` top-level or tests.

**Why it happens:** The package stub was defined in Phase 1 with empty exports as a placeholder.

**How to avoid:** Wave 0 of Phase 4 must update `packages.lisp` to add `parse` to `innate.parser` exports, and add the specific tokenizer symbols and type symbols to `innate.parser`'s `:import-from` clauses. The test package `innate.tests.parser` must also be defined in `tests/packages.lisp`.

**Warning signs:** ASDF load succeeds but calling `(innate.parser:parse ...)` signals `undefined-function`.

### Pitfall 5: `{...}` Parsed as Bundle in Some Contexts and Lens in Others

**What goes wrong:** `{bundle_name}` (a single name reference) vs `{key:value}` (a lens/filter) both start with `{`. Dispatching to the wrong parser produces incorrect node types.

**Why it happens:** The same token sequence prefix (`lbrace` + `bare-word`) serves two different constructs. The disambiguation requires looking at what follows the bare-word — `:colon` means lens, `:rbrace` means bundle.

**How to avoid:** After consuming `{`, peek at the sequence: `bare-word COLON` → it's a lens; `bare-word RBRACE` → it's a bundle. This is one-token lookahead at the content-of-brace level. Implement `parse-brace-expr` that performs this disambiguation before delegating.

**Warning signs:** `{burg_pipeline}` produces a `:lens` node instead of `:bundle`. Or `{state:==}` produces a `:bundle` node instead of `:lens`.

### Pitfall 6: `#heading` Token is `:hash`, Not `:heading`

**What goes wrong:** The tokenizer emits `:hash` for `#`, not a `:heading` type. The heading text is on the same line as an identifier. The parser must assemble the `:heading` node from `:hash` + `:bare-word` (or sequence of bare-words).

**Why it happens:** The tokenizer spec (TOK-09) says "Tokenize `#` at line start as heading with text extracted." Looking at the actual tokenizer code, it emits `:hash` with nil value, not a pre-assembled heading token with text. The heading assembly is a parser responsibility.

**How to avoid:** In `parse-primary`, case `:hash` — consume the hash, then read the following bare-word(s) as the heading text, produce a `:heading` node with value = heading text string.

**Warning signs:** Test for `# header text` produces a bare `:hash` node with no value, rather than a `:heading` node with value `"header text"`.

---

## Code Examples

Verified patterns from the existing codebase:

### Signaling innate-parse-error (from tokenizer.lisp)
```common-lisp
;; Source: src/parser/tokenizer.lisp line 65-68
(error 'innate-parse-error
       :line start-line :col start-col
       :text "Unterminated string literal")
```

### Making an AST node (from types.lisp)
```common-lisp
;; Source: src/types.lisp line 32
(make-node :kind +node-prose+ :value "some prose text" :children nil :props nil)
(make-node :kind +node-reference+ :value "type"
           :children (list child1 child2)
           :props '(:qualifiers ("[[Burg]]") :combinator "all"))
```

### Token struct access (from tokenizer.lisp and test-tokenizer.lisp)
```common-lisp
;; Source: src/parser/tokenizer.lisp lines 1-14
(token-type tok)   ; → :lbracket, :at, :bare-word, etc.
(token-value tok)  ; → "Burg", "state", nil for punctuation
(token-line tok)   ; → 1-based line number
(token-col tok)    ; → 1-based column number
```

### deftest and assert-signals usage (from tests/test-framework.lisp)
```common-lisp
;; Source: tests/test-framework.lisp lines 49-54
(deftest test-parse-error-on-unterminated-bracket
  (assert-signals innate-parse-error
    (parse (tokenize "[unclosed"))
    "unterminated bracket signals parse error"))
```

### Node kind constants (from types.lisp)
```common-lisp
;; Source: src/types.lisp lines 7-26
+node-program+     ; :program
+node-bracket+     ; :bracket
+node-reference+   ; :reference
+node-emission+    ; :emission
+node-fulfillment+ ; :fulfillment
+node-kv-pair+     ; :kv-pair
+node-lens+        ; :lens
+node-combinator+  ; :combinator
+node-prose+       ; :prose
+node-heading+     ; :heading
+node-decree+      ; :decree
+node-search+      ; :search
+node-wikilink+    ; :wikilink
+node-modifier+    ; :modifier
+node-bare-word+   ; :bare-word
+node-string-lit+  ; :string-lit
+node-number-lit+  ; :number-lit
+node-agent+       ; :agent
+node-bundle+      ; :bundle
+node-emoji-slot+  ; :emoji-slot
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Parser generator (esrap, cl-yacc) | Hand-rolled recursive descent | Decision recorded in CLAUDE.md | Full control over error messages, prose passthrough, no Quicklisp |
| `defclass` AST hierarchy | `defstruct` with `etypecase` on `node-kind` keyword | Phase 2 decision | No stale instances on REPL redefinition; `defconstant` keyword values are reload-safe |
| `cl:read` for input parsing | Hand-rolled `read-char`/`peek-char` loop | Decision recorded in CLAUDE.md | Handles `@`, `![]`, `->` syntax that CL reader rejects |

**Deprecated/outdated in this project:**
- `:serial t` in ASDF: rejected in Phase 1 — use explicit `:depends-on`
- `defpackage :use :cl-user`: rejected in Phase 1 — use `(:use :cl)` only
- `ql:quickload`: forbidden by AF64 zero-deps convention

---

## Open Questions

1. **Qualifier value type: bare-word sequence vs. string literal**
   - What we know: `@Alaran:generative hard prompt` has a multi-word bare sequence as the qualifier. `@type:"[[Burg]]"` has a string literal as the qualifier.
   - What's unclear: The qualifier accumulation loop must handle both `:bare-word` tokens (joining them with spaces) and `:string` tokens (taking value as-is).
   - Recommendation: Parse qualifier value as: if next token is `:string`, consume it as the qualifier value; if next token is `:bare-word`, accumulate all consecutive bare-words into a space-joined string. This handles both cases with one code path.

2. **`![image("emblem"+burg_name + png)]/wrapLef` — search with modifier**
   - What we know: The `/wrapLef` modifier attaches to the preceding search expression. The `+` inside the search is a combinator on the search expression, not a top-level operator.
   - What's unclear: The `/` for a modifier comes after the closing `]` of the search. This means `parse-search` returns a `:search` node, and the caller (expression parser) must check if the next token is `:slash` and wrap in a `:modifier` node.
   - Recommendation: After `parse-search` (and after `parse-bracket`) in the primary expression parser, if the next token is `:slash`, consume it, read the modifier bare-word, and wrap the preceding node in a `:modifier` node with the search result as child.

3. **`#header[burg_name]` in burg_pipeline.dpn — heading followed by bracket**
   - What we know: The tokenizer emits `:hash` then `:bare-word("header")` then `:lbracket`.
   - What's unclear: Is `#header[burg_name]` a heading with a bracket argument? Or a `#`-tagged bracket expression?
   - Recommendation: In `parse-primary` for `:hash`, read the bare-word as heading text, then check if the next token is `:lbracket`. If so, parse the bracket as a child of the heading. Produce `:heading` node with value = "header" and children including the bracket. This matches the burg_pipeline.dpn sample.

---

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | Hand-rolled (tests/test-framework.lisp) |
| Config file | None — driven by `run-tests.sh` |
| Quick run command | `sbcl --non-interactive --eval "(asdf:load-system :innatescript/tests)" --eval "(innate.tests:run-tests \"parser\")" --eval "(sb-ext:exit)"` |
| Full suite command | `bash run-tests.sh` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| PAR-01 | `[db[get_count[entry]]]` → 3-level nested AST | unit | `run-tests.sh` → `test-parser` | Wave 0 |
| PAR-02 | `[[["Hello"]]]` → 3 anonymous bracket nodes | unit | `run-tests.sh` → `test-parser` | Wave 0 |
| PAR-03 | Multiple top-level statements in one parse call | unit | `run-tests.sh` → `test-parser` | Wave 0 |
| PAR-04 | `(sylvia)` → `:agent` node with value "sylvia" | unit | `run-tests.sh` → `test-parser` | Wave 0 |
| PAR-05 | `(agent){instr}` → `:agent` and `:bundle` as siblings | unit | `run-tests.sh` → `test-parser` | Wave 0 |
| PAR-06 | `{burg_pipeline}` → `:bundle` node | unit | `run-tests.sh` → `test-parser` | Wave 0 |
| PAR-07 | `{state:==}` → `:lens` with `:kv-pair` child | unit | `run-tests.sh` → `test-parser` | Wave 0 |
| PAR-08 | `@name` → `:reference` node with value "name" | unit | `run-tests.sh` → `test-parser` | Wave 0 |
| PAR-09 | `@Alaran:generative hard prompt` → `:reference` with qualifier | unit | `run-tests.sh` → `test-parser` | Wave 0 |
| PAR-10 | `@type:"[[Burg]]"+all{state:==}` → compound `:reference` | unit | `run-tests.sh` → `test-parser` | Wave 0 |
| PAR-11 | `![search_expr]` → `:search` node | unit | `run-tests.sh` → `test-parser` | Wave 0 |
| PAR-12 | `expr \|\| (agent){instr}` → `:fulfillment` node | unit | `run-tests.sh` → `test-parser` | Wave 0 |
| PAR-13 | `-> a, b` → `:emission` with two children | unit | `run-tests.sh` → `test-parser` | Wave 0 |
| PAR-14 | `decree routing_rules` → `:decree` node | unit | `run-tests.sh` → `test-parser` | Wave 0 |
| PAR-15 | `key: value` inside bracket → `:kv-pair` node | unit | `run-tests.sh` → `test-parser` | Wave 0 |
| PAR-16 | `+all` attached to reference → `:combinator` child | unit | `run-tests.sh` → `test-parser` | Wave 0 |
| PAR-17 | `/wrapLef` after expression → `:modifier` node | unit | `run-tests.sh` → `test-parser` | Wave 0 |
| PAR-18 | `[[Burg]]` token → `:wikilink` node | unit | `run-tests.sh` → `test-parser` | Wave 0 |
| PAR-19 | `# text` → `:heading` node with value "text" | unit | `run-tests.sh` → `test-parser` | Wave 0 |
| PAR-20 | Prose token → `:prose` node with full line text | unit | `run-tests.sh` → `test-parser` | Wave 0 |
| PAR-21 | Bracket with mixed kv-pairs + nested + prose in body | unit | `run-tests.sh` → `test-parser` | Wave 0 |

**Success criteria tests (from phase description):**
- `[db[get_count[entry]]]` → 3-level nested with correct parent-child (PAR-01)
- `a -> b -> c` → left-associative chain (PAR-13)
- Prose lines appear as `:prose` nodes, not discarded (PAR-20)
- `@type:"[[Burg]]"+all{state:==}` → compound reference with type filter, combinator, lens (PAR-10)
- `innate-parse-error` with line/col on malformed input (implicit in all error tests)

### Sampling Rate
- **Per task commit:** `sbcl --non-interactive --eval "(asdf:load-system :innatescript/tests)" --eval "(innate.tests:run-tests \"parser\")" --eval "(sb-ext:exit)"`
- **Per wave merge:** `bash run-tests.sh`
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `tests/test-parser.lisp` — covers all PAR-xx requirements
- [ ] `tests/packages.lisp` — add `innate.tests.parser` package definition
- [ ] `innatescript.asd` — add `(:file "test-parser" :depends-on ("packages" "test-framework"))` to `innatescript/tests` system
- [ ] `src/packages.lisp` — update `innate.parser` package: add `parse` to exports; add specific `:import-from` symbols for `innate.parser.tokenizer` and `innate.types`

---

## Sources

### Primary (HIGH confidence)
- `src/parser/tokenizer.lisp` — Token struct definition, token types, `innate-parse-error` usage patterns — directly observed
- `src/types.lisp` — All 20 `+node-*+` constants, `make-node` constructor — directly observed
- `src/conditions.lisp` — `innate-parse-error` condition with `line`/`col`/`text` slots — directly observed
- `src/packages.lisp` — Current package namespace, import/export configuration — directly observed
- `.planning/phases/04-parser/04-CONTEXT.md` — All locked implementation decisions — directly observed
- `burg_pipeline.dpn` — Integration test target, real syntax to exercise — directly observed
- `dpn-lang-spec.md` — Formal grammar BNF and language design rationale — directly observed

### Secondary (MEDIUM confidence)
- `.planning/phases/03-tokenizer/03-RESEARCH.md` — Established patterns for this codebase (cursor-style, labels-local helpers, cond dispatch)
- `.planning/phases/03-tokenizer/03-01-PLAN.md` — Plan format and must_haves structure for Wave 0 gaps identification
- `tests/test-framework.lisp` — `deftest`, `assert-equal`, `assert-signals` API confirmed — directly observed

### Tertiary (LOW confidence)
- None — all claims derive from primary sources in the codebase.

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all libraries are project-internal, already implemented and loaded
- Architecture: HIGH — patterns derived directly from CONTEXT.md locked decisions and existing codebase conventions
- Pitfalls: HIGH — derived from specific token/AST interactions observed in existing code, not speculation

**Research date:** 2026-03-28
**Valid until:** 2026-04-28 (stable — project has no external dependencies; validity expires only if Phase 3 tokenizer changes)
