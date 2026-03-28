# Stack Research

**Domain:** DSL/scripting language interpreter in Common Lisp (SBCL), zero external dependencies
**Researched:** 2026-03-27
**Confidence:** HIGH (core techniques); MEDIUM (REPL implementation patterns)

---

## Recommended Stack

### Core Technologies

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| SBCL | 2.x (current) | Implementation runtime | Native compilation, fast, standard in the CL ecosystem; ghosts already run on it — no impedance mismatch |
| ASDF | 3.3+ (bundled with SBCL) | Build and system definition | Bundled with SBCL — zero install friction; `package-inferred-system` eliminates `.asd` boilerplate as the codebase grows |
| Hand-rolled recursive descent parser | N/A | Lexer + parser | No parser generator needed; Innate's grammar is small and irregular enough that hand-rolling gives precise error messages and full control over whitespace/prose passthrough |
| CLOS `defclass` + `defmethod` | N/A | AST node representation + evaluator dispatch | Dynamic dispatch via `defmethod` on node type eliminates Visitor pattern boilerplate; nodes are redefinable at the REPL during development |
| Hand-rolled test harness | N/A | Test runner | Three macros cover everything (see Testing section); no Quicklisp, no fiveam dependency — consistent with AF64 zero-deps convention |

### Supporting Patterns (not libraries)

| Pattern | Purpose | When to Use |
|---------|---------|-------------|
| Two-pass evaluation (collect-then-resolve) | Hoisting `@` references | Always — Innate semantics require it; first pass builds symbol table, second pass resolves references |
| `handler-case` / `restart-case` for error model | Resistance error propagation | In the evaluator; structural failures propagate, missing-resource conditions trigger restarts for fulfillment |
| `with-gensyms` (hand-rolled) | Macro hygiene in test harness | Whenever writing macros that introduce bindings |
| Dynamic variables (`*current-script*`, `*resolver*`) | Context threading | Avoid passing resolver everywhere; dynamic binding keeps the evaluator clean |
| Pluggable protocol via `defgeneric` | Resolver abstraction | One `defgeneric resolve-reference` that any resolver can specialize |

### Development Tools

| Tool | Purpose | Notes |
|------|---------|-------|
| SBCL `--load` / `--eval` flags | Run tests and REPL non-interactively | Shell scripts call `sbcl --non-interactive --load run-tests.lisp` |
| `rlwrap sbcl` | Line editing in interactive REPL | Zero Lisp deps — `rlwrap` is a Unix wrapper; handles history/editing outside the Lisp image |
| Helix + SBCL subprocess | Development workflow | Consistent with n8k99 machine profile |

---

## Parsing Techniques

### Use: Hand-Rolled Recursive Descent

**Rationale:** Innate is not a conventional programming language. It has mixed prose/code content (non-executable lines pass through unchanged), unusual sigil syntax (`@`, `![]`, `||`, `->`, `[[]]`), and context-sensitive semantics (same expression is a query, a scope, or a file depending on context). Parser generators like `esrap` or `cl-yacc` would fight the irregular grammar rather than help.

Recursive descent gives:
- Full control over error messages (critical for a "human-readable" language)
- Easy prose passthrough (if no recognized sigil on a line, emit it as `:prose` node)
- Straightforward two-pass architecture (parse pass returns AST, resolve pass walks it)

**Recommended structure:**

```
lexer.lisp     — character stream → token stream
               - peek/advance/match on character positions
               - returns tagged token structs: (:token TYPE VALUE START END)

parser.lisp    — token stream → AST
               - one parse-X function per grammar rule
               - uses labels for local recursive functions
               - prose lines fall through to :prose node

ast.lisp       — defclass hierarchy for AST nodes
               - base class: innate-node (with source-location slot)
               - subclasses per node type: @-ref, search-directive, etc.
```

**Pattern for lexer state management (no global state):**

```lisp
(defun make-lexer (input)
  "Returns a closure over the input string with position state."
  (let ((pos 0)
        (len (length input)))
    (labels ((peek () (when (< pos len) (char input pos)))
             (advance () (prog1 (peek) (incf pos)))
             (match (ch) (when (eql (peek) ch) (advance) t)))
      (lambda (msg)
        (ecase msg
          (:peek (peek))
          (:advance (advance))
          (:match (lambda (ch) (match ch)))
          (:pos pos))))))
```

This closure-based approach has no global state — safe for concurrent or nested parses.

### Do NOT Use: esrap, cl-yacc, or any parser generator

These require Quicklisp and external loading. They also assume a regular, unambiguous grammar. Innate's prose passthrough and context-sensitive operator meanings would require grammar contortions that make the result harder to read than hand-rolled code.

---

## AST Representation

### Use: `defclass` hierarchy

```lisp
(defclass innate-node ()
  ((source-start :initarg :source-start :reader source-start)
   (source-end   :initarg :source-end   :reader source-end)))

(defclass prose-node (innate-node)
  ((text :initarg :text :reader prose-text)))

(defclass ref-node (innate-node)
  ((name      :initarg :name      :reader ref-name)
   (qualifier :initarg :qualifier :reader ref-qualifier :initform nil)))

(defclass search-node (innate-node)
  ((query :initarg :query :reader search-query)))
```

**Why `defclass` over `defstruct`:** During development you will redefine node classes repeatedly at the REPL. `defstruct` makes old instances incompatible after redefinition, forcing image rebuilds. `defclass` handles live redefinition transparently. Performance difference is negligible for an interpreter (not a hot inner loop per se). The CLOS dispatch on node type in the evaluator (`defmethod evaluate ((node ref-node) resolver)`) is the canonical Lisp idiom here — no Visitor pattern, no `typecase` dispatch.

---

## Evaluator Architecture

### Two-Pass Design

```
Pass 1: COLLECT
  Walk AST, build symbol table: all @-ref names → AST positions
  Result: environment hash-table mapping symbol → node

Pass 2: RESOLVE
  Walk AST again with environment
  For each ref-node: look up in environment, call resolver if not found locally
  For each search-node: call resolver's search protocol
  ||  operator: if search returns nil, emit commission to resolver
  ->  operator: emit result to current output stream
```

This two-pass design is the correct pattern for hoisting (Innate explicitly requires it per PROJECT.md). The collect pass is purely structural — no resolver calls. The resolve pass calls `(resolve resolver name)` for each unresolvable reference.

### Resolver Protocol

```lisp
(defgeneric resolve (resolver symbol &key context)
  (:documentation "Look up SYMBOL in the backing store. Return NIL if not found."))

(defgeneric search-resources (resolver query)
  (:documentation "Execute QUERY against the backing store. Return list of results."))

(defgeneric commission (resolver unfulfilled-search)
  (:documentation "Create an agent task for an unfulfilled search."))
```

These three generics are the entire external surface. The stub resolver implements all three with in-memory hash-tables. The noosphere resolver (separate private repo) specializes them against Postgres.

---

## Testing

### Use: Hand-Rolled Three-Macro Framework

Based on Peter Seibel's pattern from Practical Common Lisp, adapted for AF64 zero-deps convention. The entire framework is ~40 lines, lives in `test/test-framework.lisp`.

```lisp
;; In test/test-framework.lisp

(defvar *test-name* nil)
(defvar *pass-count* 0)
(defvar *fail-count* 0)

(defun report-result (result form)
  (if result
      (progn (incf *pass-count*)
             (format t "~&  PASS ~{~a~^ / ~}: ~a~%" *test-name* form))
      (progn (incf *fail-count*)
             (format t "~&  FAIL ~{~a~^ / ~}: ~a~%" *test-name* form)))
  result)

(defmacro check (&body forms)
  `(combine-results
     ,@(loop for f in forms collect `(report-result ,f ',f))))

(defmacro combine-results (&body forms)
  (let ((result (gensym "RESULT")))
    `(let ((,result t))
       ,@(loop for f in forms collect `(unless ,f (setf ,result nil)))
       ,result)))

(defmacro deftest (name &body body)
  `(defun ,name ()
     (let ((*test-name* (append *test-name* (list ',name))))
       ,@body)))

(defun run-all-tests (&rest test-fns)
  (let ((*pass-count* 0) (*fail-count* 0))
    (dolist (fn test-fns)
      (funcall fn))
    (format t "~&~%Results: ~a passed, ~a failed~%" *pass-count* *fail-count*)
    (zerop *fail-count*)))
```

**Why not fiveam or parachute:** Both require Quicklisp. fiveam's suite/test/is macro set is 5x more API surface than needed. The hand-rolled framework is readable in 5 minutes and produces exactly the output required. 1am (the minimal external alternative) even suggests copying it into your project — the hand-rolled version is that philosophy taken to its logical end.

### Test file organization

```
test/
  test-framework.lisp   — the 40-line framework above
  test-lexer.lisp       — lexer tests
  test-parser.lisp      — parser tests
  test-evaluator.lisp   — evaluator tests
  test-stub-resolver.lisp — stub resolver tests
  run-tests.lisp        — loads all, calls run-all-tests
```

Shell entry point: `./test.sh` calls `sbcl --non-interactive --load test/run-tests.lisp`.

---

## ASDF System Organization

### Pattern: Explicit dependency graph, separate test system

```lisp
;; innatescript.asd

(defsystem "innatescript"
  :description "Innate scripting language interpreter"
  :version "0.1.0"
  :author "n8k99"
  :licence "MIT"
  :serial nil          ;; explicit deps, not serial load order
  :components
  ((:file "packages")  ;; all defpackage forms, no code
   (:file "ast"        :depends-on ("packages"))
   (:file "lexer"      :depends-on ("packages" "ast"))
   (:file "parser"     :depends-on ("packages" "ast" "lexer"))
   (:file "environment":depends-on ("packages" "ast"))
   (:file "evaluator"  :depends-on ("packages" "ast" "environment"))
   (:file "resolver"   :depends-on ("packages" "ast" "evaluator"))
   (:file "stub-resolver" :depends-on ("packages" "resolver"))
   (:file "repl"       :depends-on ("packages" "evaluator" "resolver")))
  :in-order-to ((test-op (test-op "innatescript/tests"))))

(defsystem "innatescript/tests"
  :depends-on ("innatescript")
  :components
  ((:file "test/test-framework")
   (:file "test/test-lexer"     :depends-on ("test/test-framework"))
   (:file "test/test-parser"    :depends-on ("test/test-framework"))
   (:file "test/test-evaluator" :depends-on ("test/test-framework"))
   (:file "test/run-tests"      :depends-on ("test/test-lexer"
                                              "test/test-parser"
                                              "test/test-evaluator"))))
```

**Why `packages.lisp` first:** All `defpackage` forms in one file, nothing else. Every other file starts with `(in-package :innate.MODULE)`. This eliminates circular package dependency issues during compile. It is the canonical ASDF best practice for projects above trivial size.

**Why `serial nil` with explicit deps:** `:serial t` is fine for toy projects but becomes a maintenance trap as the system grows. Explicit `:depends-on` makes the dependency graph visible, allows parallel compilation where possible, and documents intent.

**Package naming convention (AF64):** One package per file, named `innate.COMPONENT`. Packages do not use-list each other — they qualify symbols explicitly. This prevents namespace pollution and makes grep-ability perfect.

---

## REPL Implementation

### Pattern: `read-line` loop with `handler-case`

Since no external readline is permitted, use `rlwrap` at the shell level for line editing. The Lisp REPL loop is intentionally minimal.

```lisp
;; repl.lisp

(defun run-repl (&key (resolver (make-stub-resolver)))
  (format t "~&Innate REPL. :quit to exit.~%~%")
  (loop
    (format t "innate> ")
    (force-output)
    (let ((line (handler-case (read-line)
                  (end-of-file () (return)))))
      (when (string= line ":quit") (return))
      (handler-case
          (let* ((ast      (parse-string line))
                 (result   (evaluate ast resolver)))
            (when result
              (format t "~&=> ~a~%" result)))
        (innate-parse-error (e)
          (format t "~&Parse error: ~a~%" e))
        (innate-resolve-error (e)
          (format t "~&Resolve error: ~a~%" e))
        (error (e)
          (format t "~&Error: ~a~%" e))))))
```

**Why `read-line` not `read`:** `read` is CL's S-expression reader and will mangle `.dpn` syntax. Innate is not Lisp — its syntax must be parsed by Innate's own lexer, not the host reader.

**Why `rlwrap` at shell level:** `rlwrap sbcl` or `rlwrap ./innate-repl` gives full readline history/editing with zero Lisp code. Implementing readline in Lisp without `cl-readline` (an external dep binding to GNU readline) would require raw terminal escape sequences — a significant detour with no language design value.

**Shell entry point:** `./repl.sh` contains `exec rlwrap sbcl --load repl-entry.lisp`.

---

## File Structure

```
innatescript/
  innatescript.asd       — system definition
  packages.lisp          — all defpackage, nothing else
  ast.lisp               — node class hierarchy
  lexer.lisp             — character stream → tokens
  parser.lisp            — tokens → AST
  environment.lisp       — symbol table for two-pass evaluation
  evaluator.lisp         — AST walker, resolver dispatch
  resolver.lisp          — defgeneric protocol (resolve, search-resources, commission)
  stub-resolver.lisp     — in-memory hash-table resolver for testing
  repl.lisp              — interactive loop
  test/
    test-framework.lisp  — 40-line hand-rolled harness
    test-lexer.lisp
    test-parser.lisp
    test-evaluator.lisp
    test-stub-resolver.lisp
    run-tests.lisp
  scripts/
    test.sh              — sbcl --non-interactive --load test/run-tests.lisp
    repl.sh              — rlwrap sbcl --load repl-entry.lisp
  samples/
    burg_pipeline.dpn    — reference sample from spec
```

---

## Alternatives Considered

| Recommended | Alternative | Why Not |
|-------------|-------------|---------|
| Hand-rolled recursive descent | esrap (PEG parser generator) | External dep via Quicklisp; PEG fights prose passthrough; less control over error messages |
| Hand-rolled recursive descent | cl-yacc | External dep; LALR grammar not natural for Innate's mixed-syntax format |
| `defclass` + `defmethod` for AST | `defstruct` + `typecase` | `defstruct` instances become stale after redefinition; `typecase` is an anti-pattern (add a node type → must update every typecase) |
| Hand-rolled 40-line test harness | fiveam | External dep; 5x API surface with no benefit for this scope |
| Hand-rolled 40-line test harness | parachute | External dep; designed for library-quality test suites, not interpreter development |
| `rlwrap` at shell level for REPL | cl-readline bindings | External dep binding GNU readline C library; same functionality at zero Lisp cost |
| Dynamic `*resolver*` variable | Pass resolver as explicit arg everywhere | Pollutes every evaluator function signature; dynamic var is the Lisp convention for implicit context |

---

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| `read` (CL reader) for parsing Innate input | CL reader expects S-expressions; will error on `@`, `![]`, `->` and other Innate syntax | Hand-rolled lexer calling `read-char`/`peek-char` on input string |
| `:serial t` in ASDF for non-trivial systems | Hides dependency graph, serializes compilation unnecessarily | Explicit `:depends-on` per component |
| `defpackage :use :common-lisp-user` | Inherits a large, browser-namespaced package; symbol conflicts | `(defpackage :innate.FOO (:use :common-lisp))` only |
| `cl:eval` inside the evaluator | Conflates Innate evaluation with CL evaluation; impossible to sandbox | Walk the AST with `defmethod evaluate (node resolver)` |
| Printing directly from evaluator | Couples evaluation to output, prevents embedding | Return values; let REPL and `->` operator handle output |
| Any `ql:quickload` or Quicklisp | Violates AF64 zero-deps convention; adds network/disk dependency to builds | ASDF + SBCL built-ins only |

---

## Version Compatibility

| Component | SBCL version | Notes |
|-----------|--------------|-------|
| ASDF package-inferred-system | Bundled with SBCL 1.3.4+ | Safe on any current SBCL |
| `defclass` / `defgeneric` / MOP | All current SBCL | Standard ANSI CL; no version constraints |
| `handler-case` / `restart-case` | All SBCL | Standard ANSI CL |
| `rlwrap` | System package (not Lisp) | `pacman -S rlwrap` on Arch; already likely installed |

---

## Sources

- [Simple recursive descent generator in Common Lisp (GitHub Gist)](https://gist.github.com/c7cfb77a8d7a2ec99a75) — technique confirmation, MEDIUM confidence
- [CL Crafting Interpreters (cl-crafting-interpreters)](https://github.com/gwangjinkim/cl-crafting-interpreters) — CLOS-based evaluator pattern, MEDIUM confidence
- [Practical Common Lisp: Building a Unit Test Framework](https://gigamonkeys.com/book/practical-building-a-unit-test-framework.html) — `deftest`/`check`/`combine-results` macros, HIGH confidence (authoritative primary source)
- [CL Cookbook: Testing](https://lispcookbook.github.io/cl-cookbook/testing.html) — framework comparison, MEDIUM confidence
- [Comparison of CL Testing Frameworks (2023)](https://sabracrolleton.github.io/testing-framework) — 1am/fiveam performance data, MEDIUM confidence
- [CL Cookbook: Defining Systems](https://lispcookbook.github.io/cl-cookbook/systems.html) — ASDF patterns, HIGH confidence
- [ASDF Best Practices (fare/asdf)](https://github.com/fare/asdf/blob/master/doc/best_practices.md) — explicit deps, test system separation, HIGH confidence
- [Abstract Heresies: defclass vs defstruct (2025)](http://funcall.blogspot.com/2025/03/defclass-vs-defstruct.html) — performance tradeoff analysis, MEDIUM confidence
- [SBCL User Manual 2.6.2](https://www.sbcl.org/manual/) — runtime reference, HIGH confidence
- [awesome-cl](https://github.com/CodyReichert/awesome-cl) — ecosystem survey, MEDIUM confidence

---

*Stack research for: Innate scripting language interpreter (Common Lisp, zero external dependencies)*
*Researched: 2026-03-27*
