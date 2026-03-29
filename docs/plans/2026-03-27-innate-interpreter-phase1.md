# Innate Interpreter Phase 1: Parser + Evaluator Core

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the Innate language core — a Common Lisp parser that reads `.dpn` files into an AST, an evaluator that walks the AST against a pluggable resolver protocol, and a REPL for interactive use.

**Architecture:** Single ASDF system (`innate`) with three modules: `parser/` (tokenizer + parser producing s-expression AST), `eval/` (evaluator + resolver protocol as CLOS generic functions), and `repl/` (interactive line reader). No external dependencies — follows AF64 conventions (hand-rolled everything, package-per-module). Tests use a built-in test runner (no library).

**Tech Stack:** Common Lisp (SBCL 2.4+), ASDF for system definition, no external dependencies.

**Reference:** Design spec at `docs/specs/2026-03-27-innate-language-design.md`

---

## File Structure

```
innatescript/
  innate.asd                    # ASDF system definition
  lisp/
    packages.lisp               # All package definitions
    types.lisp                  # AST node structs + core types
    parser/
      tokenizer.lisp            # .dpn text -> token stream
      parser.lisp               # token stream -> AST (s-expression tree)
    eval/
      resolver-protocol.lisp    # CLOS generic functions for resolution
      evaluator.lisp            # walks AST, calls resolver protocol
      stub-resolver.lisp        # in-memory resolver for testing
    repl/
      repl.lisp                 # interactive evaluator
    main.lisp                   # entry point (load + run)
  tests/
    test-runner.lisp            # minimal test framework
    test-tokenizer.lisp         # tokenizer tests
    test-parser.lisp            # parser tests
    test-evaluator.lisp         # evaluator tests
    test-integration.lisp       # end-to-end .dpn file tests
  scripts/                      # canonical .dpn files (already exists)
    burg_pipeline.dpn
```

---

### Task 1: Project Skeleton + Test Runner

**Files:**
- Create: `innate.asd`
- Create: `lisp/packages.lisp`
- Create: `lisp/main.lisp`
- Create: `tests/test-runner.lisp`

- [ ] **Step 1: Create ASDF system definition**

```lisp
;; innate.asd
(asdf:defsystem "innate"
  :description "Innate — a language of intention. Markdown that runs."
  :author "Eckenrode Muziekopname"
  :license "MIT"
  :serial t
  :components
  ((:module "lisp"
    :serial t
    :components
    ((:file "packages")
     (:file "types")
     (:module "parser"
      :serial t
      :components ((:file "tokenizer")
                   (:file "parser")))
     (:module "eval"
      :serial t
      :components ((:file "resolver-protocol")
                   (:file "evaluator")
                   (:file "stub-resolver")))
     (:module "repl"
      :components ((:file "repl")))
     (:file "main")))))
```

- [ ] **Step 2: Create packages.lisp with all package definitions**

```lisp
;; lisp/packages.lisp

(defpackage :innate.types
  (:use :cl)
  (:export
   ;; AST node constructors
   :make-node :node-kind :node-value :node-children :node-props
   ;; node kinds
   :+node-program+ :+node-bracket+ :+node-agent+ :+node-bundle+
   :+node-reference+ :+node-search+ :+node-fulfillment+ :+node-emission+
   :+node-decree+ :+node-wikilink+ :+node-combinator+ :+node-lens+
   :+node-kv-pair+ :+node-modifier+ :+node-prose+ :+node-heading+
   :+node-string+ :+node-number+ :+node-bare-word+ :+node-emoji-slot+
   ;; result types
   :make-innate-result :innate-result-value :innate-result-context
   :make-resistance :resistance-message :resistance-source))

(defpackage :innate.parser.tokenizer
  (:use :cl)
  (:import-from :innate.types :make-node)
  (:export :tokenize :token-kind :token-value :token-line :token-col
           :make-token))

(defpackage :innate.parser
  (:use :cl)
  (:import-from :innate.types
                :make-node :node-kind :node-value :node-children :node-props
                :+node-program+ :+node-bracket+ :+node-agent+ :+node-bundle+
                :+node-reference+ :+node-search+ :+node-fulfillment+ :+node-emission+
                :+node-decree+ :+node-wikilink+ :+node-combinator+ :+node-lens+
                :+node-kv-pair+ :+node-modifier+ :+node-prose+ :+node-heading+
                :+node-string+ :+node-number+ :+node-bare-word+ :+node-emoji-slot+)
  (:import-from :innate.parser.tokenizer
                :tokenize :token-kind :token-value :token-line :token-col)
  (:export :parse :parse-file))

(defpackage :innate.eval.resolver
  (:use :cl)
  (:import-from :innate.types
                :make-innate-result :make-resistance)
  (:export
   ;; resolver protocol (generic functions)
   :resolve-reference :resolve-search :deliver-commission
   :resolve-wikilink :resolve-context :load-bundle
   ;; resolver base class
   :resolver))

(defpackage :innate.eval
  (:use :cl)
  (:import-from :innate.types
                :make-node :node-kind :node-value :node-children :node-props
                :+node-program+ :+node-bracket+ :+node-agent+ :+node-bundle+
                :+node-reference+ :+node-search+ :+node-fulfillment+ :+node-emission+
                :+node-decree+ :+node-wikilink+ :+node-combinator+ :+node-lens+
                :+node-kv-pair+ :+node-modifier+ :+node-prose+ :+node-heading+
                :+node-string+ :+node-number+ :+node-bare-word+ :+node-emoji-slot+
                :make-innate-result :innate-result-value :innate-result-context
                :make-resistance :resistance-message :resistance-source)
  (:import-from :innate.eval.resolver
                :resolve-reference :resolve-search :deliver-commission
                :resolve-wikilink :resolve-context :load-bundle
                :resolver)
  (:export :evaluate :evaluate-file :make-eval-env :eval-env-decrees))

(defpackage :innate.eval.stub-resolver
  (:use :cl)
  (:import-from :innate.eval.resolver
                :resolver :resolve-reference :resolve-search :deliver-commission
                :resolve-wikilink :resolve-context :load-bundle)
  (:import-from :innate.types :make-innate-result :make-resistance)
  (:export :stub-resolver :make-stub-resolver :stub-add-entity :stub-add-document
           :stub-commissions))

(defpackage :innate.repl
  (:use :cl)
  (:import-from :innate.parser :parse)
  (:import-from :innate.eval :evaluate :make-eval-env)
  (:import-from :innate.eval.stub-resolver :make-stub-resolver)
  (:export :run-repl))

(defpackage :innate
  (:use :cl)
  (:import-from :innate.parser :parse :parse-file)
  (:import-from :innate.eval :evaluate :evaluate-file :make-eval-env)
  (:import-from :innate.repl :run-repl)
  (:export :parse :parse-file :evaluate :evaluate-file :make-eval-env :run-repl))
```

- [ ] **Step 3: Create minimal main.lisp**

```lisp
;; lisp/main.lisp
(in-package :innate)

(defun run-repl ()
  (innate.repl:run-repl))
```

- [ ] **Step 4: Create test runner**

```lisp
;; tests/test-runner.lisp
(defpackage :innate.tests
  (:use :cl)
  (:export :deftest :run-tests :assert-equal :assert-true :assert-nil
           :assert-signals :*test-results*))

(in-package :innate.tests)

(defvar *tests* (make-hash-table :test #'equal))
(defvar *test-results* nil)
(defvar *current-test* nil)
(defvar *pass-count* 0)
(defvar *fail-count* 0)

(defmacro deftest (name &body body)
  `(setf (gethash ,(string name) *tests*)
         (lambda ()
           (let ((*current-test* ,(string name)))
             ,@body))))

(defun assert-equal (expected actual &optional message)
  (if (equal expected actual)
      (progn (incf *pass-count*) t)
      (progn
        (incf *fail-count*)
        (format t "  FAIL ~a: expected ~s got ~s~@[ (~a)~]~%"
                *current-test* expected actual message)
        nil)))

(defun assert-true (value &optional message)
  (if value
      (progn (incf *pass-count*) t)
      (progn
        (incf *fail-count*)
        (format t "  FAIL ~a: expected truthy, got ~s~@[ (~a)~]~%"
                *current-test* value message)
        nil)))

(defun assert-nil (value &optional message)
  (if (null value)
      (progn (incf *pass-count*) t)
      (progn
        (incf *fail-count*)
        (format t "  FAIL ~a: expected nil, got ~s~@[ (~a)~]~%"
                *current-test* value message)
        nil)))

(defmacro assert-signals (condition-type &body body)
  `(let ((signaled nil))
     (handler-case (progn ,@body)
       (,condition-type () (setf signaled t)))
     (if signaled
         (progn (incf *pass-count*) t)
         (progn
           (incf *fail-count*)
           (format t "  FAIL ~a: expected ~a to be signaled~%"
                   *current-test* ',condition-type)
           nil))))

(defun run-tests (&optional prefix)
  (setf *pass-count* 0 *fail-count* 0)
  (let ((names (sort (loop for k being the hash-keys of *tests* collect k) #'string<)))
    (when prefix
      (setf names (remove-if-not (lambda (n) (search prefix n)) names)))
    (dolist (name names)
      (format t "~a ... " name)
      (handler-case
          (progn (funcall (gethash name *tests*))
                 (format t "ok~%"))
        (error (e)
          (incf *fail-count*)
          (format t "ERROR: ~a~%" e))))
    (format t "~%~a passed, ~a failed~%" *pass-count* *fail-count*)
    (zerop *fail-count*)))
```

- [ ] **Step 5: Verify the skeleton loads**

Run:
```bash
cd ~/Development/innatescript
sbcl --eval '(require :asdf)' --eval '(push #p"./" asdf:*central-registry*)' --eval '(asdf:load-system "innate")' --eval '(format t "~%LOADED OK~%")' --quit
```

Expected: compile warnings about missing files (tokenizer.lisp etc), but packages.lisp and test-runner.lisp should load. We'll create stubs next.

- [ ] **Step 6: Create stub files so ASDF loads cleanly**

Create each file with just its `in-package` form:

```lisp
;; lisp/types.lisp
(in-package :innate.types)

;; lisp/parser/tokenizer.lisp
(in-package :innate.parser.tokenizer)

;; lisp/parser/parser.lisp
(in-package :innate.parser)

;; lisp/eval/resolver-protocol.lisp
(in-package :innate.eval.resolver)

;; lisp/eval/evaluator.lisp
(in-package :innate.eval)

;; lisp/eval/stub-resolver.lisp
(in-package :innate.eval.stub-resolver)

;; lisp/repl/repl.lisp
(in-package :innate.repl)
```

- [ ] **Step 7: Verify clean load**

Run:
```bash
cd ~/Development/innatescript
sbcl --eval '(require :asdf)' --eval '(push #p"./" asdf:*central-registry*)' --eval '(asdf:load-system "innate")' --eval '(format t "~%LOADED OK~%")' --quit
```

Expected: `LOADED OK` with no errors.

- [ ] **Step 8: Commit**

```bash
cd ~/Development/innatescript
git init
git add innate.asd lisp/ tests/test-runner.lisp
git commit -m "feat: innate project skeleton with ASDF system, packages, and test runner"
```

---

### Task 2: AST Types

**Files:**
- Modify: `lisp/types.lisp`
- Create: `tests/test-types.lisp`

- [ ] **Step 1: Write tests for AST node construction**

```lisp
;; tests/test-types.lisp
(defpackage :innate.tests.types
  (:use :cl :innate.tests :innate.types))

(in-package :innate.tests.types)

(deftest "types/make-node-bare"
  (let ((n (make-node :kind +node-bare-word+ :value "hello")))
    (assert-equal +node-bare-word+ (node-kind n))
    (assert-equal "hello" (node-value n))
    (assert-nil (node-children n))
    (assert-nil (node-props n))))

(deftest "types/make-node-with-children"
  (let* ((child (make-node :kind +node-bare-word+ :value "entry"))
         (parent (make-node :kind +node-bracket+ :value "db" :children (list child))))
    (assert-equal "db" (node-value parent))
    (assert-equal 1 (length (node-children parent)))
    (assert-equal "entry" (node-value (first (node-children parent))))))

(deftest "types/make-node-with-props"
  (let ((n (make-node :kind +node-kv-pair+ :value "type" :props '(:rhs "[[Burg]]"))))
    (assert-equal "type" (node-value n))
    (assert-equal "[[Burg]]" (getf (node-props n) :rhs))))

(deftest "types/reference-node"
  (let ((n (make-node :kind +node-reference+ :value "boughrest"
                      :props '(:qualifiers ("generative hard prompt")))))
    (assert-equal +node-reference+ (node-kind n))
    (assert-equal "boughrest" (node-value n))
    (assert-equal '("generative hard prompt") (getf (node-props n) :qualifiers))))

(deftest "types/innate-result"
  (let ((r (make-innate-result :value 42 :context :query)))
    (assert-equal 42 (innate-result-value r))
    (assert-equal :query (innate-result-context r))))

(deftest "types/resistance"
  (let ((r (make-resistance :message "not found" :source "@missing")))
    (assert-equal "not found" (resistance-message r))
    (assert-equal "@missing" (resistance-source r))))
```

- [ ] **Step 2: Run tests to verify they fail**

Run:
```bash
cd ~/Development/innatescript
sbcl --eval '(require :asdf)' \
     --eval '(push #p"./" asdf:*central-registry*)' \
     --eval '(asdf:load-system "innate")' \
     --eval '(load "tests/test-runner.lisp")' \
     --eval '(load "tests/test-types.lisp")' \
     --eval '(innate.tests:run-tests "types/")' \
     --quit
```

Expected: errors because `make-node`, `+node-bare-word+`, etc. don't exist yet.

- [ ] **Step 3: Implement types.lisp**

```lisp
;; lisp/types.lisp
(in-package :innate.types)

;; ── Node kind constants ──────────────────────────────────────────────────────

(defconstant +node-program+    :program)
(defconstant +node-bracket+    :bracket)
(defconstant +node-agent+      :agent)
(defconstant +node-bundle+     :bundle)
(defconstant +node-reference+  :reference)
(defconstant +node-search+     :search)
(defconstant +node-fulfillment+ :fulfillment)
(defconstant +node-emission+   :emission)
(defconstant +node-decree+     :decree)
(defconstant +node-wikilink+   :wikilink)
(defconstant +node-combinator+ :combinator)
(defconstant +node-lens+       :lens)
(defconstant +node-kv-pair+    :kv-pair)
(defconstant +node-modifier+   :modifier)
(defconstant +node-prose+      :prose)
(defconstant +node-heading+    :heading)
(defconstant +node-string+     :string-lit)
(defconstant +node-number+     :number-lit)
(defconstant +node-bare-word+  :bare-word)
(defconstant +node-emoji-slot+ :emoji-slot)

;; ── AST node ─────────────────────────────────────────────────────────────────

(defstruct (node (:constructor make-node (&key kind value children props)))
  (kind nil :type keyword)
  (value nil)
  (children nil :type list)
  (props nil :type list))

;; ── Result types ─────────────────────────────────────────────────────────────

(defstruct (innate-result (:constructor make-innate-result (&key value context)))
  (value nil)
  (context :query :type keyword))

(defstruct (resistance (:constructor make-resistance (&key message source)))
  (message "" :type string)
  (source "" :type string))
```

- [ ] **Step 4: Run tests to verify they pass**

Run:
```bash
cd ~/Development/innatescript
sbcl --eval '(require :asdf)' \
     --eval '(push #p"./" asdf:*central-registry*)' \
     --eval '(asdf:load-system "innate")' \
     --eval '(load "tests/test-runner.lisp")' \
     --eval '(load "tests/test-types.lisp")' \
     --eval '(innate.tests:run-tests "types/")' \
     --quit
```

Expected: all tests pass.

- [ ] **Step 5: Commit**

```bash
cd ~/Development/innatescript
git add lisp/types.lisp tests/test-types.lisp
git commit -m "feat: AST node types and result structs"
```

---

### Task 3: Tokenizer

**Files:**
- Modify: `lisp/parser/tokenizer.lisp`
- Create: `tests/test-tokenizer.lisp`

The tokenizer reads `.dpn` text and produces a flat list of tokens. Each token has a kind, value, line, and column.

- [ ] **Step 1: Write tokenizer tests**

```lisp
;; tests/test-tokenizer.lisp
(defpackage :innate.tests.tokenizer
  (:use :cl :innate.tests :innate.parser.tokenizer))

(in-package :innate.tests.tokenizer)

(deftest "tok/open-bracket"
  (let ((tokens (tokenize "[")))
    (assert-equal 1 (length tokens))
    (assert-equal :lbracket (token-kind (first tokens)))))

(deftest "tok/close-bracket"
  (let ((tokens (tokenize "]")))
    (assert-equal 1 (length tokens))
    (assert-equal :rbracket (token-kind (first tokens)))))

(deftest "tok/parens"
  (let ((tokens (tokenize "(sylvia)")))
    (assert-equal 3 (length tokens))
    (assert-equal :lparen (token-kind (first tokens)))
    (assert-equal :bare-word (token-kind (second tokens)))
    (assert-equal "sylvia" (token-value (second tokens)))
    (assert-equal :rparen (token-kind (third tokens)))))

(deftest "tok/braces"
  (let ((tokens (tokenize "{burg_pipeline}")))
    (assert-equal 3 (length tokens))
    (assert-equal :lbrace (token-kind (first tokens)))
    (assert-equal :bare-word (token-kind (second tokens)))
    (assert-equal :rbrace (token-kind (third tokens)))))

(deftest "tok/at-reference"
  (let ((tokens (tokenize "@boughrest")))
    (assert-equal 1 (length tokens))
    (assert-equal :at-ref (token-kind (first tokens)))
    (assert-equal "boughrest" (token-value (first tokens)))))

(deftest "tok/at-reference-with-colon-qualifier"
  (let ((tokens (tokenize "@Alaran:generative hard prompt")))
    (assert-equal 1 (length tokens))
    (assert-equal :at-ref (token-kind (first tokens)))
    (assert-equal "Alaran" (token-value (first tokens)))))

(deftest "tok/search-directive"
  (let ((tokens (tokenize "![image(\"emblem\" + name + png)]")))
    (assert-equal :bang-lbracket (token-kind (first tokens)))))

(deftest "tok/string"
  (let ((tokens (tokenize "\"Hello World!\"")))
    (assert-equal 1 (length tokens))
    (assert-equal :string (token-kind (first tokens)))
    (assert-equal "Hello World!" (token-value (first tokens)))))

(deftest "tok/number"
  (let ((tokens (tokenize "52125")))
    (assert-equal 1 (length tokens))
    (assert-equal :number (token-kind (first tokens)))
    (assert-equal 52125 (token-value (first tokens)))))

(deftest "tok/wikilink"
  (let ((tokens (tokenize "[[Burg]]")))
    (assert-equal 1 (length tokens))
    (assert-equal :wikilink (token-kind (first tokens)))
    (assert-equal "Burg" (token-value (first tokens)))))

(deftest "tok/emission-arrow"
  (let ((tokens (tokenize "-> 52125")))
    (assert-equal 2 (length tokens))
    (assert-equal :arrow (token-kind (first tokens)))
    (assert-equal :number (token-kind (second tokens)))))

(deftest "tok/fulfillment-pipe"
  (let ((tokens (tokenize "||")))
    (assert-equal 1 (length tokens))
    (assert-equal :double-pipe (token-kind (first tokens)))))

(deftest "tok/combinator-plus"
  (let ((tokens (tokenize "+all")))
    (assert-equal 1 (length tokens))
    (assert-equal :combinator (token-kind (first tokens)))
    (assert-equal "all" (token-value (first tokens)))))

(deftest "tok/colon"
  (let ((tokens (tokenize "type: \"[[Burg]]\"")))
    (assert-equal 3 (length tokens))
    (assert-equal :bare-word (token-kind (first tokens)))
    (assert-equal :colon (token-kind (second tokens)))
    (assert-equal :string (token-kind (third tokens)))))

(deftest "tok/comma"
  (let ((tokens (tokenize "entry, tables")))
    (assert-equal 3 (length tokens))
    (assert-equal :comma (token-kind (second tokens)))))

(deftest "tok/emoji-slot"
  (let ((tokens (tokenize "<emoji>")))
    (assert-equal 1 (length tokens))
    (assert-equal :emoji-slot (token-kind (first tokens)))))

(deftest "tok/heading"
  (let ((tokens (tokenize "# Hello")))
    (assert-equal 1 (length tokens))
    (assert-equal :heading (token-kind (first tokens)))
    (assert-equal "Hello" (token-value (first tokens)))))

(deftest "tok/decree-keyword"
  (let ((tokens (tokenize "decree burg_pipeline")))
    (assert-equal 2 (length tokens))
    (assert-equal :decree (token-kind (first tokens)))
    (assert-equal :bare-word (token-kind (second tokens)))))

(deftest "tok/prose-line"
  (let ((tokens (tokenize "This is just plain text.")))
    (assert-equal 1 (length tokens))
    (assert-equal :prose (token-kind (first tokens)))
    (assert-equal "This is just plain text." (token-value (first tokens)))))

(deftest "tok/complex-expression"
  (let ((tokens (tokenize "[db[get_count[entry]]]")))
    (assert-true (>= (length tokens) 7) "should tokenize nested brackets")))

(deftest "tok/multiline"
  (let ((tokens (tokenize (format nil "[db[get[docs]]]~%-> 52125"))))
    (assert-true (find :arrow tokens :key #'token-kind) "should find arrow in multiline")))
```

- [ ] **Step 2: Run tests to verify they fail**

Run:
```bash
cd ~/Development/innatescript
sbcl --eval '(require :asdf)' \
     --eval '(push #p"./" asdf:*central-registry*)' \
     --eval '(asdf:load-system "innate")' \
     --eval '(load "tests/test-runner.lisp")' \
     --eval '(load "tests/test-tokenizer.lisp")' \
     --eval '(innate.tests:run-tests "tok/")' \
     --quit
```

Expected: errors because `tokenize`, `token-kind`, etc. don't exist.

- [ ] **Step 3: Implement tokenizer.lisp**

```lisp
;; lisp/parser/tokenizer.lisp
(in-package :innate.parser.tokenizer)

;; ── Token struct ─────────────────────────────────────────────────────────────

(defstruct (token (:constructor make-token (&key kind value line col)))
  (kind nil :type keyword)
  (value nil)
  (line 1 :type fixnum)
  (col 1 :type fixnum))

;; ── Character predicates ─────────────────────────────────────────────────────

(defun bare-word-start-p (ch)
  (or (alpha-char-p ch) (char= ch #\_)))

(defun bare-word-char-p (ch)
  (or (alphanumericp ch) (char= ch #\_)))

(defun whitespace-p (ch)
  (member ch '(#\Space #\Tab)))

;; ── Tokenizer ────────────────────────────────────────────────────────────────

(defun tokenize (text)
  "Tokenize .dpn text into a list of tokens. Processes line-by-line."
  (let ((lines (split-lines text))
        (tokens nil)
        (line-num 0))
    (dolist (line lines (nreverse tokens))
      (incf line-num)
      (setf tokens (nconc (nreverse (tokenize-line line line-num)) tokens)))))

(defun split-lines (text)
  (let ((lines nil)
        (start 0))
    (loop for i from 0 below (length text)
          when (char= (char text i) #\Newline)
            do (push (subseq text start i) lines)
               (setf start (1+ i)))
    (when (<= start (length text))
      (push (subseq text start) lines))
    (nreverse lines)))

(defun tokenize-line (line line-num)
  "Tokenize a single line. Returns tokens in order."
  (let ((tokens nil)
        (pos 0)
        (len (length line)))
    (flet ((peek () (when (< pos len) (char line pos)))
           (advance () (prog1 (char line pos) (incf pos)))
           (emit (kind value col)
             (push (make-token :kind kind :value value :line line-num :col col) tokens)))

      ;; Check for heading (# at start of line after optional whitespace)
      (let ((trimmed (string-left-trim '(#\Space #\Tab) line)))
        (when (and (> (length trimmed) 0)
                   (char= (char trimmed 0) #\#)
                   (or (= (length trimmed) 1)
                       (char= (char trimmed 1) #\Space)
                       (char= (char trimmed 1) #\#)))
          ;; Count heading level, extract text
          (let* ((hpos 0)
                 (hlen (length trimmed)))
            (loop while (and (< hpos hlen) (char= (char trimmed hpos) #\#))
                  do (incf hpos))
            (let ((text (string-trim '(#\Space #\Tab)
                                     (subseq trimmed hpos))))
              (emit :heading text 1)
              (return-from tokenize-line (nreverse tokens))))))

      ;; Check for decree keyword at start of significant content
      (let ((trimmed (string-left-trim '(#\Space #\Tab) line)))
        (when (and (>= (length trimmed) 7)
                   (string= "decree " (subseq trimmed 0 7)))
          (setf pos (+ (- (length line) (length trimmed)) 7))
          (emit :decree "decree" 1)
          ;; Fall through to tokenize the rest of the line
          ))

      ;; Check for emission arrow at start of line
      (when (and (null tokens)  ;; no decree was found
                 (let ((tp (string-left-trim '(#\Space #\Tab) line)))
                   (and (>= (length tp) 2)
                        (string= "->" (subseq tp 0 2)))))
        (setf pos (+ 2 (- (length line)
                           (length (string-left-trim '(#\Space #\Tab) line)))))
        (emit :arrow "->" 1))

      ;; Check for prose (line with no special starting characters)
      (when (and (null tokens)
                 (> len 0)
                 (let ((ch (char (string-left-trim '(#\Space #\Tab) line) 0)))
                   (and (not (member ch '(#\[ #\( #\{ #\@ #\! #\] #\) #\}
                                          #\- #\+ #\" #\,)))
                        (not (digit-char-p ch))
                        (not (and (>= (length (string-left-trim '(#\Space #\Tab) line)) 2)
                                  (string= "[[" (subseq (string-left-trim '(#\Space #\Tab) line) 0 2)))))))
          ;; Check if line contains any @refs or ![] — if so, tokenize inline
          (unless (or (find #\@ line) (find #\! line)
                      (find #\[ line) (find #\( line) (find #\{ line))
            (emit :prose (string-trim '(#\Space #\Tab) line) 1)
            (return-from tokenize-line (nreverse tokens))))

      ;; Main tokenization loop
      (loop while (< pos len)
            for ch = (peek)
            do (cond
                 ;; Whitespace — skip
                 ((whitespace-p ch) (advance))

                 ;; [ or ![
                 ((char= ch #\[)
                  (let ((col pos))
                    (advance)
                    (emit :lbracket "[" (1+ col))))

                 ((char= ch #\])
                  (let ((col pos))
                    (advance)
                    (emit :rbracket "]" (1+ col))))

                 ((char= ch #\()
                  (let ((col pos))
                    (advance)
                    (emit :lparen "(" (1+ col))))

                 ((char= ch #\))
                  (let ((col pos))
                    (advance)
                    (emit :rparen ")" (1+ col))))

                 ((char= ch #\{)
                  (let ((col pos))
                    (advance)
                    (emit :lbrace "{" (1+ col))))

                 ((char= ch #\})
                  (let ((col pos))
                    (advance)
                    (emit :rbrace "}" (1+ col))))

                 ;; @ reference
                 ((char= ch #\@)
                  (let ((col pos))
                    (advance)
                    (let ((name (read-bare-word line pos len)))
                      (setf pos (+ pos (length name)))
                      (emit :at-ref name (1+ col)))))

                 ;; ![ search directive
                 ((and (char= ch #\!)
                       (< (1+ pos) len)
                       (char= (char line (1+ pos)) #\[))
                  (let ((col pos))
                    (advance) (advance) ;; skip ![
                    (emit :bang-lbracket "![" (1+ col))))

                 ;; || fulfillment
                 ((and (char= ch #\|)
                       (< (1+ pos) len)
                       (char= (char line (1+ pos)) #\|))
                  (let ((col pos))
                    (advance) (advance)
                    (emit :double-pipe "||" (1+ col))))

                 ;; -> emission
                 ((and (char= ch #\-)
                       (< (1+ pos) len)
                       (char= (char line (1+ pos)) #\>))
                  (let ((col pos))
                    (advance) (advance)
                    (emit :arrow "->" (1+ col))))

                 ;; + combinator
                 ((char= ch #\+)
                  (let ((col pos))
                    (advance)
                    (let ((name (read-bare-word line pos len)))
                      (if (> (length name) 0)
                          (progn
                            (setf pos (+ pos (length name)))
                            (emit :combinator name (1+ col)))
                          (emit :plus "+" (1+ col))))))

                 ;; : colon
                 ((char= ch #\:)
                  (let ((col pos))
                    (advance)
                    (emit :colon ":" (1+ col))))

                 ;; , comma
                 ((char= ch #\,)
                  (let ((col pos))
                    (advance)
                    (emit :comma "," (1+ col))))

                 ;; [[ wikilink
                 ((and (char= ch #\[)
                       (< (1+ pos) len)
                       (char= (char line (1+ pos)) #\[))
                  ;; This case is handled by the double-[ check below
                  ;; but [ is already matched above. We need to handle
                  ;; wikilinks before single brackets. Reorder needed.
                  ;; For now, handle in the [ case above.
                  (advance))

                 ;; "string"
                 ((char= ch #\")
                  (let ((col pos))
                    (advance)
                    (let ((str (read-string-literal line pos len)))
                      (setf pos (cdr str))
                      (emit :string (car str) (1+ col)))))

                 ;; <emoji>
                 ((char= ch #\<)
                  (let ((col pos))
                    (if (and (< (+ pos 6) len)
                             (string= "<emoji>" (subseq line pos (min (+ pos 7) len))))
                        (progn
                          (setf pos (+ pos 7))
                          (emit :emoji-slot "<emoji>" (1+ col)))
                        (advance)))) ;; skip unknown <

                 ;; number
                 ((digit-char-p ch)
                  (let ((col pos)
                        (num (read-number line pos len)))
                    (setf pos (cdr num))
                    (emit :number (car num) (1+ col))))

                 ;; bare word
                 ((bare-word-start-p ch)
                  (let ((col pos)
                        (word (read-bare-word line pos len)))
                    (setf pos (+ pos (length word)))
                    (emit :bare-word word (1+ col))))

                 ;; / (presentation modifier like /wrapLeft)
                 ((char= ch #\/)
                  (let ((col pos))
                    (advance)
                    (let ((word (read-bare-word line pos len)))
                      (if (> (length word) 0)
                          (progn
                            (setf pos (+ pos (length word)))
                            (emit :modifier word (1+ col)))
                          (emit :slash "/" (1+ col))))))

                 ;; skip anything else
                 (t (advance)))))

    (nreverse tokens)))

;; ── Helper readers ───────────────────────────────────────────────────────────

(defun read-bare-word (text pos len)
  "Read a bare word starting at pos. Returns the word string."
  (let ((start pos))
    (loop while (and (< pos len) (bare-word-char-p (char text pos)))
          do (incf pos))
    (subseq text start pos)))

(defun read-string-literal (text pos len)
  "Read a string literal (after the opening quote). Returns (string . end-pos)."
  (let ((buf (make-string-output-stream))
        (start pos))
    (declare (ignore start))
    (loop while (< pos len)
          for ch = (char text pos)
          do (cond
               ((char= ch #\") (incf pos)
                (return-from read-string-literal
                  (cons (get-output-stream-string buf) pos)))
               ((char= ch #\\)
                (incf pos)
                (when (< pos len)
                  (write-char (char text pos) buf)
                  (incf pos)))
               (t (write-char ch buf) (incf pos))))
    ;; Unterminated string — return what we have
    (cons (get-output-stream-string buf) pos)))

(defun read-number (text pos len)
  "Read an integer starting at pos. Returns (number . end-pos)."
  (let ((start pos))
    (loop while (and (< pos len) (digit-char-p (char text pos)))
          do (incf pos))
    (cons (parse-integer (subseq text start pos)) pos)))
```

**Note:** The wikilink `[[...]]` case has a conflict with single `[` — both start with `[`. The tokenizer needs to peek ahead. Fix: in the `[` branch, check if the next char is also `[`:

Replace the `((char= ch #\[)` branch in the main loop with:

```lisp
                 ;; [[ wikilink or [ bracket
                 ((char= ch #\[)
                  (let ((col pos))
                    (if (and (< (1+ pos) len)
                             (char= (char line (1+ pos)) #\[))
                        ;; Wikilink [[...]]
                        (progn
                          (advance) (advance) ;; skip [[
                          (let ((content (read-until-closing-wikilink line pos len)))
                            (setf pos (cdr content))
                            (emit :wikilink (car content) (1+ col))))
                        ;; Single bracket
                        (progn
                          (advance)
                          (emit :lbracket "[" (1+ col))))))
```

And add the helper:

```lisp
(defun read-until-closing-wikilink (text pos len)
  "Read until ]]. Returns (content . end-pos)."
  (let ((start pos))
    (loop while (< (1+ pos) len)
          do (if (and (char= (char text pos) #\])
                      (char= (char text (1+ pos)) #\]))
                 (return-from read-until-closing-wikilink
                   (cons (subseq text start pos) (+ pos 2)))
                 (incf pos)))
    ;; Unterminated
    (cons (subseq text start) len)))
```

Remove the dead `((and (char= ch #\[) ...` wikilink branch that was a placeholder.

- [ ] **Step 4: Run tests**

Run:
```bash
cd ~/Development/innatescript
sbcl --eval '(require :asdf)' \
     --eval '(push #p"./" asdf:*central-registry*)' \
     --eval '(asdf:load-system "innate")' \
     --eval '(load "tests/test-runner.lisp")' \
     --eval '(load "tests/test-tokenizer.lisp")' \
     --eval '(innate.tests:run-tests "tok/")' \
     --quit
```

Expected: all tokenizer tests pass. If any fail, fix the tokenizer and re-run.

- [ ] **Step 5: Commit**

```bash
cd ~/Development/innatescript
git add lisp/parser/tokenizer.lisp tests/test-tokenizer.lisp
git commit -m "feat: tokenizer for .dpn syntax — brackets, agents, refs, search, fulfillment, wikilinks"
```

---

### Task 4: Parser

**Files:**
- Modify: `lisp/parser/parser.lisp`
- Create: `tests/test-parser.lisp`

The parser consumes a token list and produces an AST (tree of `node` structs).

- [ ] **Step 1: Write parser tests**

```lisp
;; tests/test-parser.lisp
(defpackage :innate.tests.parser
  (:use :cl :innate.tests :innate.types :innate.parser))

(in-package :innate.tests.parser)

(deftest "parse/hello-world"
  (let* ((ast (parse "[[[\"Hello World!\"]]]"))
         (prog ast))
    (assert-equal +node-program+ (node-kind prog))
    (assert-true (>= (length (node-children prog)) 1))))

(deftest "parse/db-get-count"
  (let* ((ast (parse "[db[get_count[entry]]]"))
         (outer (first (node-children ast))))
    (assert-equal +node-bracket+ (node-kind outer))
    (assert-equal "db" (node-value outer))))

(deftest "parse/agent-address"
  (let* ((ast (parse "(sylvia)"))
         (agent (first (node-children ast))))
    (assert-equal +node-agent+ (node-kind agent))
    (assert-equal "sylvia" (node-value agent))))

(deftest "parse/bundle"
  (let* ((ast (parse "{burg_pipeline}"))
         (bundle (first (node-children ast))))
    (assert-equal +node-bundle+ (node-kind bundle))
    (assert-equal "burg_pipeline" (node-value bundle))))

(deftest "parse/reference"
  (let* ((ast (parse "@boughrest"))
         (ref (first (node-children ast))))
    (assert-equal +node-reference+ (node-kind ref))
    (assert-equal "boughrest" (node-value ref))))

(deftest "parse/search-directive"
  (let* ((ast (parse "![image(\"emblem\" + name + png)]"))
         (search (first (node-children ast))))
    (assert-equal +node-search+ (node-kind search))))

(deftest "parse/fulfillment"
  (let* ((ast (parse "![missing] || (vincent){create it}"))
         (node (first (node-children ast))))
    (assert-equal +node-fulfillment+ (node-kind node))
    ;; Left side is search, right side has agent
    (assert-equal +node-search+ (node-kind (first (node-children node))))))

(deftest "parse/emission"
  (let* ((ast (parse "-> 52125"))
         (em (first (node-children ast))))
    (assert-equal +node-emission+ (node-kind em))
    (assert-equal 1 (length (node-children em)))
    (assert-equal 52125 (node-value (first (node-children em))))))

(deftest "parse/decree"
  (let* ((ast (parse "decree burg_pipeline [type: \"[[Burg]]\"]"))
         (dec (first (node-children ast))))
    (assert-equal +node-decree+ (node-kind dec))
    (assert-equal "burg_pipeline" (node-value dec))))

(deftest "parse/kv-pair"
  (let* ((ast (parse "[type: \"[[Burg]]\"]"))
         (bracket (first (node-children ast)))
         (kv (first (node-children bracket))))
    (assert-equal +node-kv-pair+ (node-kind kv))
    (assert-equal "type" (node-value kv))))

(deftest "parse/combinator"
  (let* ((ast (parse "@type:\"[[Burg]]\"+all"))
         (ref (first (node-children ast))))
    (assert-equal +node-reference+ (node-kind ref))
    ;; Should have combinator in props or children
    (assert-true (or (getf (node-props ref) :combinator)
                     (find +node-combinator+ (node-children ref) :key #'node-kind)))))

(deftest "parse/wikilink"
  (let* ((ast (parse "[[Akar Ok]]"))
         (wl (first (node-children ast))))
    (assert-equal +node-wikilink+ (node-kind wl))
    (assert-equal "Akar Ok" (node-value wl))))

(deftest "parse/heading"
  (let* ((ast (parse "# Boughrest"))
         (h (first (node-children ast))))
    (assert-equal +node-heading+ (node-kind h))
    (assert-equal "Boughrest" (node-value h))))

(deftest "parse/prose"
  (let* ((ast (parse "This is just plain text."))
         (p (first (node-children ast))))
    (assert-equal +node-prose+ (node-kind p))
    (assert-equal "This is just plain text." (node-value p))))

(deftest "parse/multiline-program"
  (let* ((ast (parse (format nil "[db[get_count[entry]]]~%-> 52125"))))
    (assert-equal +node-program+ (node-kind ast))
    (assert-equal 2 (length (node-children ast)))))
```

- [ ] **Step 2: Run tests to verify they fail**

Run:
```bash
cd ~/Development/innatescript
sbcl --eval '(require :asdf)' \
     --eval '(push #p"./" asdf:*central-registry*)' \
     --eval '(asdf:load-system "innate")' \
     --eval '(load "tests/test-runner.lisp")' \
     --eval '(load "tests/test-parser.lisp")' \
     --eval '(innate.tests:run-tests "parse/")' \
     --quit
```

Expected: errors because `parse` is not implemented.

- [ ] **Step 3: Implement parser.lisp**

```lisp
;; lisp/parser/parser.lisp
(in-package :innate.parser)

;; ── Parser state ─────────────────────────────────────────────────────────────

(defstruct (parser-state (:constructor make-parser-state (tokens)))
  (tokens nil :type list)
  (pos 0 :type fixnum))

(defun ps-peek (ps)
  (nth (parser-state-pos ps) (parser-state-tokens ps)))

(defun ps-advance (ps)
  (prog1 (ps-peek ps)
    (incf (parser-state-pos ps))))

(defun ps-at-end (ps)
  (>= (parser-state-pos ps) (length (parser-state-tokens ps))))

(defun ps-peek-kind (ps)
  (let ((tok (ps-peek ps)))
    (when tok (token-kind tok))))

(defun ps-expect (ps kind)
  (let ((tok (ps-advance ps)))
    (unless (and tok (eq (token-kind tok) kind))
      (error "Expected ~a, got ~a" kind (when tok (token-kind tok))))
    tok))

;; ── Public API ───────────────────────────────────────────────────────────────

(defun parse (text)
  "Parse .dpn text into an AST. Returns a program node."
  (let* ((tokens (tokenize text))
         (ps (make-parser-state tokens))
         (children nil))
    (loop until (ps-at-end ps)
          for node = (parse-statement ps)
          when node do (push node children))
    (make-node :kind +node-program+ :children (nreverse children))))

(defun parse-file (path)
  "Parse a .dpn file into an AST."
  (let ((text (uiop:read-file-string path)))
    (parse text)))

;; ── Statement parsing ────────────────────────────────────────────────────────

(defun parse-statement (ps)
  "Parse one top-level statement."
  (let ((kind (ps-peek-kind ps)))
    (case kind
      (:lbracket (parse-bracket-expr ps))
      (:bang-lbracket (maybe-parse-fulfillment ps))
      (:lparen (parse-agent-expr ps))
      (:lbrace (parse-bundle-expr ps))
      (:at-ref (maybe-parse-fulfillment-from-ref ps))
      (:arrow (parse-emission ps))
      (:decree (parse-decree ps))
      (:wikilink (parse-wikilink ps))
      (:heading (parse-heading ps))
      (:prose (parse-prose ps))
      (:string (parse-string-value ps))
      (:number (parse-number-value ps))
      (:bare-word (parse-bare-word ps))
      (:emoji-slot (parse-emoji-slot ps))
      ;; Skip tokens that don't start a statement
      (t (ps-advance ps) nil))))

;; ── Bracket expressions ──────────────────────────────────────────────────────

(defun parse-bracket-expr (ps)
  "Parse [name[verb[args]]] bracket expressions."
  (ps-expect ps :lbracket)
  (let ((name nil)
        (children nil))
    ;; Check for name
    (when (eq (ps-peek-kind ps) :bare-word)
      (setf name (token-value (ps-advance ps))))
    ;; Parse contents until ]
    (loop until (or (ps-at-end ps) (eq (ps-peek-kind ps) :rbracket))
          for child = (parse-bracket-content ps)
          when child do (push child children))
    (unless (ps-at-end ps) (ps-expect ps :rbracket))
    (make-node :kind +node-bracket+ :value name
               :children (nreverse children))))

(defun parse-bracket-content (ps)
  "Parse content inside brackets — could be nested brackets, kv pairs, args, etc."
  (let ((kind (ps-peek-kind ps)))
    (case kind
      (:lbracket (parse-bracket-expr ps))
      (:lparen (parse-agent-expr ps))
      (:lbrace (parse-bundle-expr ps))
      (:at-ref (parse-reference ps))
      (:bang-lbracket (parse-search-expr ps))
      (:wikilink (parse-wikilink ps))
      (:bare-word
       ;; Could be a kv-pair (word:) or just a bare word
       (if (and (< (1+ (parser-state-pos ps)) (length (parser-state-tokens ps)))
                (eq (token-kind (nth (1+ (parser-state-pos ps))
                                     (parser-state-tokens ps)))
                    :colon))
           (parse-kv-pair ps)
           (parse-bare-word ps)))
      (:string (parse-string-value ps))
      (:number (parse-number-value ps))
      (:emoji-slot (parse-emoji-slot ps))
      (:comma (ps-advance ps) nil) ;; skip commas
      (:colon (ps-advance ps) nil) ;; skip bare colons
      (:combinator (parse-combinator ps))
      (:modifier (parse-modifier ps))
      (:arrow (parse-emission ps))
      (t (ps-advance ps) nil))))

;; ── Agent, Bundle, Reference ─────────────────────────────────────────────────

(defun parse-agent-expr (ps)
  "Parse (agent_name) optionally followed by {bundle}."
  (ps-expect ps :lparen)
  (let ((name (token-value (ps-expect ps :bare-word))))
    (ps-expect ps :rparen)
    ;; Check for trailing bundle
    (let ((bundle nil))
      (when (eq (ps-peek-kind ps) :lbrace)
        (setf bundle (parse-bundle-expr ps)))
      (make-node :kind +node-agent+ :value name
                 :children (when bundle (list bundle))))))

(defun parse-bundle-expr (ps)
  "Parse {bundle_name} optionally as a lens {key:value}."
  (ps-expect ps :lbrace)
  (let ((first-tok (ps-advance ps)))
    (cond
      ;; Check if this is a lens {key:value} or {key:==}
      ((and (eq (token-kind first-tok) :bare-word)
            (eq (ps-peek-kind ps) :colon))
       (ps-advance ps) ;; skip colon
       (let ((rhs (when (not (eq (ps-peek-kind ps) :rbrace))
                    (let ((tok (ps-advance ps)))
                      (token-value tok)))))
         (ps-expect ps :rbrace)
         (make-node :kind +node-lens+
                    :value (token-value first-tok)
                    :props (list :rhs rhs))))
      ;; Regular bundle
      (t
       ;; Consume remaining tokens until }
       (let ((words (list (token-value first-tok))))
         (loop until (or (ps-at-end ps) (eq (ps-peek-kind ps) :rbrace))
               do (push (token-value (ps-advance ps)) words))
         (unless (ps-at-end ps) (ps-expect ps :rbrace))
         (make-node :kind +node-bundle+
                    :value (format nil "~{~a~^ ~}" (nreverse words))))))))

(defun parse-reference (ps)
  "Parse @name or @name:qualifier, optionally followed by +combinator and/or {lens}."
  (let* ((tok (ps-expect ps :at-ref))
         (name (token-value tok))
         (qualifiers nil)
         (combinator nil)
         (lens nil))
    ;; Collect colon-separated qualifiers
    (loop while (eq (ps-peek-kind ps) :colon)
          do (ps-advance ps) ;; skip colon
             ;; Read qualifier — could be a string, bare word, or sequence of bare words
             (let ((qual-parts nil))
               (loop while (and (not (ps-at-end ps))
                                (member (ps-peek-kind ps) '(:bare-word :string :wikilink)))
                     do (push (token-value (ps-advance ps)) qual-parts))
               (when qual-parts
                 (push (format nil "~{~a~^ ~}" (nreverse qual-parts)) qualifiers))))
    ;; Check for combinator
    (when (eq (ps-peek-kind ps) :combinator)
      (setf combinator (token-value (ps-advance ps))))
    ;; Check for lens
    (when (eq (ps-peek-kind ps) :lbrace)
      (setf lens (parse-bundle-expr ps)))
    (make-node :kind +node-reference+ :value name
               :children (when lens (list lens))
               :props (append
                       (when qualifiers (list :qualifiers (nreverse qualifiers)))
                       (when combinator (list :combinator combinator))))))

;; ── Search and Fulfillment ───────────────────────────────────────────────────

(defun parse-search-expr (ps)
  "Parse ![search expression]."
  (ps-expect ps :bang-lbracket)
  (let ((children nil))
    (loop until (or (ps-at-end ps) (eq (ps-peek-kind ps) :rbracket))
          for child = (parse-bracket-content ps)
          when child do (push child children))
    (unless (ps-at-end ps) (ps-expect ps :rbracket))
    (make-node :kind +node-search+ :children (nreverse children))))

(defun maybe-parse-fulfillment (ps)
  "Parse a search expression, then check for || fulfillment."
  (let ((search (parse-search-expr ps)))
    (if (eq (ps-peek-kind ps) :double-pipe)
        (progn
          (ps-advance ps) ;; skip ||
          (let ((right (parse-statement ps)))
            (make-node :kind +node-fulfillment+
                       :children (list search right))))
        search)))

(defun maybe-parse-fulfillment-from-ref (ps)
  "Parse a reference, then check for || fulfillment."
  (let ((ref (parse-reference ps)))
    (if (eq (ps-peek-kind ps) :double-pipe)
        (progn
          (ps-advance ps)
          (let ((right (parse-statement ps)))
            (make-node :kind +node-fulfillment+
                       :children (list ref right))))
        ref)))

;; ── Emission ─────────────────────────────────────────────────────────────────

(defun parse-emission (ps)
  "Parse -> value [, value]*."
  (ps-expect ps :arrow)
  (let ((values nil))
    (loop until (or (ps-at-end ps)
                    (member (ps-peek-kind ps) '(:lbracket :at-ref :decree
                                                 :heading :prose :bang-lbracket)))
          do (let ((kind (ps-peek-kind ps)))
               (case kind
                 (:comma (ps-advance ps)) ;; skip
                 (:number (push (parse-number-value ps) values))
                 (:string (push (parse-string-value ps) values))
                 (:bare-word (push (parse-bare-word ps) values))
                 (:wikilink (push (parse-wikilink ps) values))
                 (t (return)))))
    (make-node :kind +node-emission+ :children (nreverse values))))

;; ── Decree ───────────────────────────────────────────────────────────────────

(defun parse-decree (ps)
  "Parse decree name [body]."
  (ps-expect ps :decree)
  (let ((name (token-value (ps-expect ps :bare-word)))
        (body nil))
    ;; Optional bracket body
    (when (eq (ps-peek-kind ps) :lbracket)
      (let ((bracket (parse-bracket-expr ps)))
        (setf body (node-children bracket))))
    (make-node :kind +node-decree+ :value name :children body)))

;; ── Leaf nodes ───────────────────────────────────────────────────────────────

(defun parse-wikilink (ps)
  (let ((tok (ps-expect ps :wikilink)))
    (make-node :kind +node-wikilink+ :value (token-value tok))))

(defun parse-heading (ps)
  (let ((tok (ps-expect ps :heading)))
    (make-node :kind +node-heading+ :value (token-value tok))))

(defun parse-prose (ps)
  (let ((tok (ps-expect ps :prose)))
    (make-node :kind +node-prose+ :value (token-value tok))))

(defun parse-string-value (ps)
  (let ((tok (ps-expect ps :string)))
    (make-node :kind +node-string+ :value (token-value tok))))

(defun parse-number-value (ps)
  (let ((tok (ps-expect ps :number)))
    (make-node :kind +node-number+ :value (token-value tok))))

(defun parse-bare-word (ps)
  (let ((tok (ps-expect ps :bare-word)))
    (make-node :kind +node-bare-word+ :value (token-value tok))))

(defun parse-emoji-slot (ps)
  (let ((tok (ps-expect ps :emoji-slot)))
    (make-node :kind +node-emoji-slot+ :value (token-value tok))))

(defun parse-kv-pair (ps)
  "Parse key: value."
  (let ((key (token-value (ps-expect ps :bare-word))))
    (ps-expect ps :colon)
    (let ((val (parse-bracket-content ps)))
      (make-node :kind +node-kv-pair+ :value key
                 :children (when val (list val))))))

(defun parse-combinator (ps)
  (let ((tok (ps-expect ps :combinator)))
    (make-node :kind +node-combinator+ :value (token-value tok))))

(defun parse-modifier (ps)
  (let ((tok (ps-expect ps :modifier)))
    (make-node :kind +node-modifier+ :value (token-value tok))))
```

- [ ] **Step 4: Run tests**

Run:
```bash
cd ~/Development/innatescript
sbcl --eval '(require :asdf)' \
     --eval '(push #p"./" asdf:*central-registry*)' \
     --eval '(asdf:load-system "innate")' \
     --eval '(load "tests/test-runner.lisp")' \
     --eval '(load "tests/test-parser.lisp")' \
     --eval '(innate.tests:run-tests "parse/")' \
     --quit
```

Expected: all parser tests pass.

- [ ] **Step 5: Commit**

```bash
cd ~/Development/innatescript
git add lisp/parser/parser.lisp tests/test-parser.lisp
git commit -m "feat: parser — .dpn token stream to AST with brackets, agents, refs, decrees, fulfillment"
```

---

### Task 5: Resolver Protocol

**Files:**
- Modify: `lisp/eval/resolver-protocol.lisp`
- Create: `tests/test-resolver.lisp`

The resolver protocol defines CLOS generic functions that any backend must implement. Innate's evaluator calls these — it never touches a database or agent system directly.

- [ ] **Step 1: Write resolver protocol tests**

```lisp
;; tests/test-resolver.lisp
(defpackage :innate.tests.resolver
  (:use :cl :innate.tests :innate.eval.resolver :innate.eval.stub-resolver :innate.types))

(in-package :innate.tests.resolver)

(deftest "resolver/stub-resolve-reference"
  (let ((r (make-stub-resolver)))
    (stub-add-entity r "boughrest" '(:type "Burg" :lifestage "Seed"))
    (let ((result (resolve-reference r "boughrest" nil)))
      (assert-true (innate-result-value result))
      (assert-equal "Burg" (getf (innate-result-value result) :type)))))

(deftest "resolver/stub-resolve-reference-with-qualifier"
  (let ((r (make-stub-resolver)))
    (stub-add-entity r "boughrest" '(:type "Burg" :lifestage "Seed"))
    (let ((result (resolve-reference r "boughrest" '("lifestage"))))
      (assert-equal "Seed" (innate-result-value result)))))

(deftest "resolver/stub-resolve-missing-returns-resistance"
  (let ((r (make-stub-resolver)))
    (let ((result (resolve-reference r "nonexistent" nil)))
      (assert-true (resistance-p result)))))

(deftest "resolver/stub-resolve-search-found"
  (let ((r (make-stub-resolver)))
    (stub-add-entity r "emblem_boughrest_png" '(:path "/images/emblem_boughrest.png"))
    (let ((result (resolve-search r "image" '("emblem" "boughrest" "png"))))
      (assert-true (innate-result-value result)))))

(deftest "resolver/stub-resolve-search-not-found"
  (let ((r (make-stub-resolver)))
    (let ((result (resolve-search r "image" '("emblem" "missing" "png"))))
      (assert-true (resistance-p result)))))

(deftest "resolver/stub-deliver-commission"
  (let ((r (make-stub-resolver)))
    (deliver-commission r "vincent" "create emblem for boughrest")
    (assert-equal 1 (length (stub-commissions r)))
    (assert-equal "vincent" (first (first (stub-commissions r))))))

(deftest "resolver/stub-resolve-wikilink"
  (let ((r (make-stub-resolver)))
    (stub-add-document r "Akar Ok" '(:id 42 :content "The burg of Akar Ok"))
    (let ((result (resolve-wikilink r "Akar Ok")))
      (assert-true (innate-result-value result))
      (assert-equal 42 (getf (innate-result-value result) :id)))))

(deftest "resolver/stub-resolve-context"
  (let ((r (make-stub-resolver)))
    (let ((result (resolve-context r "db" "get_count" '("entry"))))
      ;; Stub just returns a generic result
      (assert-true (innate-result-p result)))))
```

- [ ] **Step 2: Run tests to verify they fail**

Run:
```bash
cd ~/Development/innatescript
sbcl --eval '(require :asdf)' \
     --eval '(push #p"./" asdf:*central-registry*)' \
     --eval '(asdf:load-system "innate")' \
     --eval '(load "tests/test-runner.lisp")' \
     --eval '(load "tests/test-resolver.lisp")' \
     --eval '(innate.tests:run-tests "resolver/")' \
     --quit
```

Expected: errors because the protocol and stub are not implemented.

- [ ] **Step 3: Implement resolver-protocol.lisp**

```lisp
;; lisp/eval/resolver-protocol.lisp
(in-package :innate.eval.resolver)

;; ── Base class ───────────────────────────────────────────────────────────────

(defclass resolver () ()
  (:documentation "Base class for Innate resolvers. Implement the generic
functions below to connect Innate to a backing store and agent system."))

;; ── Protocol generic functions ───────────────────────────────────────────────

(defgeneric resolve-reference (resolver name qualifiers)
  (:documentation "Resolve @name[:qualifier...]. Return an innate-result or resistance.
NAME is a string. QUALIFIERS is a list of qualifier strings (may be nil)."))

(defgeneric resolve-search (resolver search-type terms)
  (:documentation "Resolve ![type(terms)]. Return an innate-result or resistance.
SEARCH-TYPE is a string (e.g. \"image\"). TERMS is a list of strings."))

(defgeneric deliver-commission (resolver agent-name instruction)
  (:documentation "Deliver a commission to an agent. Called when || fulfillment fires.
AGENT-NAME is a string. INSTRUCTION is a string."))

(defgeneric resolve-wikilink (resolver title)
  (:documentation "Resolve [[title]]. Return an innate-result or resistance.
TITLE is a string."))

(defgeneric resolve-context (resolver context-name verb args)
  (:documentation "Resolve [context[verb[args]]]. Return an innate-result or resistance.
CONTEXT-NAME, VERB are strings. ARGS is a list."))

(defgeneric load-bundle (resolver name)
  (:documentation "Load a bundle {name}. Return the bundle's parsed AST or nil.
NAME is a string."))

;; ── Default methods (return resistance) ──────────────────────────────────────

(defmethod resolve-reference ((r resolver) name qualifiers)
  (declare (ignore qualifiers))
  (make-resistance :message (format nil "No resolver for @~a" name) :source (format nil "@~a" name)))

(defmethod resolve-search ((r resolver) search-type terms)
  (declare (ignore terms))
  (make-resistance :message (format nil "No resolver for ![~a]" search-type)
                   :source (format nil "![~a]" search-type)))

(defmethod deliver-commission ((r resolver) agent-name instruction)
  (declare (ignore instruction))
  (warn "Commission to ~a dropped — no resolver configured" agent-name))

(defmethod resolve-wikilink ((r resolver) title)
  (make-resistance :message (format nil "No resolver for [[~a]]" title) :source (format nil "[[~a]]" title)))

(defmethod resolve-context ((r resolver) context-name verb args)
  (declare (ignore verb args))
  (make-resistance :message (format nil "No resolver for [~a]" context-name)
                   :source (format nil "[~a]" context-name)))

(defmethod load-bundle ((r resolver) name)
  (declare (ignore name))
  nil)
```

- [ ] **Step 4: Implement stub-resolver.lisp**

```lisp
;; lisp/eval/stub-resolver.lisp
(in-package :innate.eval.stub-resolver)

;; ── Stub resolver for testing ────────────────────────────────────────────────

(defclass stub-resolver (resolver)
  ((entities :initform (make-hash-table :test #'equal) :accessor stub-entities)
   (documents :initform (make-hash-table :test #'equal) :accessor stub-documents)
   (commissions :initform nil :accessor stub-commissions)))

(defun make-stub-resolver ()
  (make-instance 'stub-resolver))

(defun stub-add-entity (resolver name plist)
  "Add a named entity to the stub store."
  (setf (gethash name (stub-entities resolver)) plist))

(defun stub-add-document (resolver title plist)
  "Add a document to the stub store."
  (setf (gethash title (stub-documents resolver)) plist))

;; ── Protocol implementations ─────────────────────────────────────────────────

(defmethod resolve-reference ((r stub-resolver) name qualifiers)
  (let ((entity (gethash name (stub-entities r))))
    (if entity
        (if qualifiers
            ;; Resolve qualifier chain
            (let ((val entity))
              (dolist (q qualifiers)
                (let ((key (intern (string-upcase q) :keyword)))
                  (setf val (getf val key))))
              (if val
                  (make-innate-result :value val :context :query)
                  (make-resistance :message (format nil "~a has no property ~a" name (first qualifiers))
                                   :source (format nil "@~a:~a" name (first qualifiers)))))
            (make-innate-result :value entity :context :query))
        (make-resistance :message (format nil "Entity @~a not found" name)
                         :source (format nil "@~a" name)))))

(defmethod resolve-search ((r stub-resolver) search-type terms)
  ;; Simple: concatenate terms with _ and look up as entity name
  (let* ((key (format nil "~a_~{~a~^_~}" search-type terms))
         (entity (gethash key (stub-entities r))))
    (if entity
        (make-innate-result :value entity :context :query)
        (make-resistance :message (format nil "Search ![~a] found nothing" search-type)
                         :source (format nil "![~a(~{~a~^, ~})]" search-type terms)))))

(defmethod deliver-commission ((r stub-resolver) agent-name instruction)
  (push (list agent-name instruction) (stub-commissions r))
  (make-innate-result :value (format nil "Commissioned ~a: ~a" agent-name instruction)
                      :context :commission))

(defmethod resolve-wikilink ((r stub-resolver) title)
  (let ((doc (gethash title (stub-documents r))))
    (if doc
        (make-innate-result :value doc :context :query)
        (make-resistance :message (format nil "Document [[~a]] not found" title)
                         :source (format nil "[[~a]]" title)))))

(defmethod resolve-context ((r stub-resolver) context-name verb args)
  ;; Stub returns a generic result
  (make-innate-result :value (list :context context-name :verb verb :args args)
                      :context :query))

(defmethod load-bundle ((r stub-resolver) name)
  (declare (ignore name))
  nil)
```

- [ ] **Step 5: Run tests**

Run:
```bash
cd ~/Development/innatescript
sbcl --eval '(require :asdf)' \
     --eval '(push #p"./" asdf:*central-registry*)' \
     --eval '(asdf:load-system "innate")' \
     --eval '(load "tests/test-runner.lisp")' \
     --eval '(load "tests/test-resolver.lisp")' \
     --eval '(innate.tests:run-tests "resolver/")' \
     --quit
```

Expected: all resolver tests pass.

- [ ] **Step 6: Commit**

```bash
cd ~/Development/innatescript
git add lisp/eval/resolver-protocol.lisp lisp/eval/stub-resolver.lisp tests/test-resolver.lisp
git commit -m "feat: resolver protocol — CLOS generic functions + stub resolver for testing"
```

---

### Task 6: Evaluator

**Files:**
- Modify: `lisp/eval/evaluator.lisp`
- Create: `tests/test-evaluator.lisp`

The evaluator walks the AST and calls the resolver protocol for each node type. It handles the two-pass design: first pass collects all decree definitions (hoisting `@` references), second pass evaluates.

- [ ] **Step 1: Write evaluator tests**

```lisp
;; tests/test-evaluator.lisp
(defpackage :innate.tests.evaluator
  (:use :cl :innate.tests :innate.types :innate.parser :innate.eval
        :innate.eval.stub-resolver))

(in-package :innate.tests.evaluator)

(deftest "eval/prose-passthrough"
  (let* ((r (make-stub-resolver))
         (env (make-eval-env :resolver r))
         (result (evaluate (parse "This is plain text.") env)))
    (assert-equal 1 (length result))
    (assert-equal "This is plain text." (first result))))

(deftest "eval/heading-passthrough"
  (let* ((r (make-stub-resolver))
         (env (make-eval-env :resolver r))
         (result (evaluate (parse "# My Title") env)))
    (assert-equal 1 (length result))
    (assert-true (search "My Title" (first result)))))

(deftest "eval/reference-resolves"
  (let* ((r (make-stub-resolver))
         (env (make-eval-env :resolver r)))
    (stub-add-entity r "boughrest" '(:type "Burg" :lifestage "Seed"))
    (let ((result (evaluate (parse "@boughrest") env)))
      (assert-equal 1 (length result))
      (assert-true (listp (first result)))
      (assert-equal "Burg" (getf (first result) :type)))))

(deftest "eval/reference-with-qualifier"
  (let* ((r (make-stub-resolver))
         (env (make-eval-env :resolver r)))
    (stub-add-entity r "boughrest" '(:type "Burg" :lifestage "Seed"))
    (let ((result (evaluate (parse "@boughrest:lifestage") env)))
      ;; Note: tokenizer reads @boughrest, then : lifestage as qualifier
      ;; This depends on the tokenizer handling colon after at-ref
      (assert-true (not (null result))))))

(deftest "eval/emission"
  (let* ((r (make-stub-resolver))
         (env (make-eval-env :resolver r))
         (result (evaluate (parse "-> 52125") env)))
    (assert-equal 1 (length result))
    (assert-equal 52125 (first result))))

(deftest "eval/bracket-context"
  (let* ((r (make-stub-resolver))
         (env (make-eval-env :resolver r))
         (result (evaluate (parse "[db[get_count[entry]]]") env)))
    ;; Stub returns generic result
    (assert-true (not (null result)))))

(deftest "eval/fulfillment-found"
  (let* ((r (make-stub-resolver))
         (env (make-eval-env :resolver r)))
    (stub-add-entity r "image_emblem_boughrest_png"
                     '(:path "/images/emblem_boughrest.png"))
    ;; When the search succeeds, no commission fires
    (let ((result (evaluate (parse "![image(\"emblem\" + \"boughrest\" + \"png\")] || (vincent){create it}") env)))
      (assert-true (not (null result)))
      (assert-equal 0 (length (stub-commissions r))))))

(deftest "eval/fulfillment-missing-commissions-agent"
  (let* ((r (make-stub-resolver))
         (env (make-eval-env :resolver r)))
    ;; Search will fail — no entity added
    (let ((result (evaluate (parse "![image(\"missing\")] || (vincent){create it}") env)))
      (declare (ignore result))
      (assert-equal 1 (length (stub-commissions r)))
      (assert-equal "vincent" (first (first (stub-commissions r)))))))

(deftest "eval/decree-registers"
  (let* ((r (make-stub-resolver))
         (env (make-eval-env :resolver r)))
    (evaluate (parse "decree boughrest [type: \"Burg\"]") env)
    (let ((decrees (eval-env-decrees env)))
      (assert-true (gethash "boughrest" decrees)))))

(deftest "eval/decree-hoisting"
  (let* ((r (make-stub-resolver))
         (env (make-eval-env :resolver r)))
    ;; Reference comes before decree — should still resolve via hoisting
    (let ((result (evaluate (parse (format nil "@boughrest~%decree boughrest [type: \"Burg\"]")) env)))
      (assert-true (not (null result))))))

(deftest "eval/agent-commission"
  (let* ((r (make-stub-resolver))
         (env (make-eval-env :resolver r)))
    (evaluate (parse "(sylvia){write editorial}") env)
    (assert-equal 1 (length (stub-commissions r)))
    (assert-equal "sylvia" (first (first (stub-commissions r))))))

(deftest "eval/wikilink"
  (let* ((r (make-stub-resolver))
         (env (make-eval-env :resolver r)))
    (stub-add-document r "Akar Ok" '(:id 42 :content "The burg of Akar Ok"))
    (let ((result (evaluate (parse "[[Akar Ok]]") env)))
      (assert-true (not (null result))))))

(deftest "eval/multiline-program"
  (let* ((r (make-stub-resolver))
         (env (make-eval-env :resolver r))
         (result (evaluate (parse (format nil "# Title~%Some prose~%-> 42")) env)))
    (assert-equal 3 (length result))))
```

- [ ] **Step 2: Run tests to verify they fail**

Run:
```bash
cd ~/Development/innatescript
sbcl --eval '(require :asdf)' \
     --eval '(push #p"./" asdf:*central-registry*)' \
     --eval '(asdf:load-system "innate")' \
     --eval '(load "tests/test-runner.lisp")' \
     --eval '(load "tests/test-evaluator.lisp")' \
     --eval '(innate.tests:run-tests "eval/")' \
     --quit
```

Expected: errors because `evaluate`, `make-eval-env`, etc. don't exist.

- [ ] **Step 3: Implement evaluator.lisp**

```lisp
;; lisp/eval/evaluator.lisp
(in-package :innate.eval)

;; ── Evaluation environment ───────────────────────────────────────────────────

(defstruct (eval-env (:constructor make-eval-env (&key resolver)))
  (resolver nil)
  (decrees (make-hash-table :test #'equal))
  (context :query :type keyword))

;; ── Public API ───────────────────────────────────────────────────────────────

(defun evaluate (ast env)
  "Evaluate an Innate AST against an environment. Returns a list of results.
Two-pass: first collects decrees (hoisting), then evaluates."
  ;; Pass 1: collect all decrees
  (when (eq (node-kind ast) +node-program+)
    (dolist (child (node-children ast))
      (when (eq (node-kind child) +node-decree+)
        (register-decree child env))))
  ;; Pass 2: evaluate everything
  (if (eq (node-kind ast) +node-program+)
      (let ((results nil))
        (dolist (child (node-children ast))
          (let ((r (eval-node child env)))
            (when r (push r results))))
        (nreverse results))
      (let ((r (eval-node ast env)))
        (when r (list r)))))

(defun evaluate-file (path env)
  "Parse and evaluate a .dpn file."
  (let ((ast (innate.parser:parse-file path)))
    (evaluate ast env)))

;; ── Decree registration ──────────────────────────────────────────────────────

(defun register-decree (node env)
  "Register a decree in the environment. Called during pass 1."
  (let ((name (node-value node))
        (body (node-children node)))
    ;; Store as a plist of kv-pairs
    (let ((plist nil))
      (dolist (child body)
        (when (eq (node-kind child) +node-kv-pair+)
          (let ((key (intern (string-upcase (node-value child)) :keyword))
                (val (when (node-children child)
                       (let ((val-node (first (node-children child))))
                         (node-value val-node)))))
            (setf plist (append plist (list key val))))))
      (setf (gethash name (eval-env-decrees env)) plist))))

;; ── Node evaluation dispatch ─────────────────────────────────────────────────

(defun eval-node (node env)
  "Evaluate a single AST node. Returns a result value or nil."
  (let ((kind (node-kind node)))
    (cond
      ((eq kind +node-prose+)     (eval-prose node env))
      ((eq kind +node-heading+)   (eval-heading node env))
      ((eq kind +node-reference+) (eval-reference node env))
      ((eq kind +node-emission+)  (eval-emission node env))
      ((eq kind +node-bracket+)   (eval-bracket node env))
      ((eq kind +node-fulfillment+) (eval-fulfillment node env))
      ((eq kind +node-search+)    (eval-search node env))
      ((eq kind +node-decree+)    (eval-decree node env))
      ((eq kind +node-agent+)     (eval-agent node env))
      ((eq kind +node-wikilink+)  (eval-wikilink node env))
      ((eq kind +node-bundle+)    (eval-bundle node env))
      ((eq kind +node-string+)    (node-value node))
      ((eq kind +node-number+)    (node-value node))
      ((eq kind +node-bare-word+) (node-value node))
      ((eq kind +node-kv-pair+)   (eval-kv-pair node env))
      ((eq kind +node-combinator+) (node-value node))
      ((eq kind +node-modifier+)  (node-value node))
      ((eq kind +node-emoji-slot+) (node-value node))
      ((eq kind +node-lens+)      (eval-lens node env))
      (t nil))))

;; ── Prose and headings — pass through ────────────────────────────────────────

(defun eval-prose (node env)
  (declare (ignore env))
  (node-value node))

(defun eval-heading (node env)
  (declare (ignore env))
  (format nil "# ~a" (node-value node)))

;; ── References ───────────────────────────────────────────────────────────────

(defun eval-reference (node env)
  "Evaluate @name[:qualifier]. Check decrees first, then resolver."
  (let* ((name (node-value node))
         (qualifiers (getf (node-props node) :qualifiers))
         ;; Check decree table first (hoisted)
         (decree (gethash name (eval-env-decrees env))))
    (if decree
        ;; Resolve from decree
        (if qualifiers
            (let ((key (intern (string-upcase (first qualifiers)) :keyword)))
              (or (getf decree key) decree))
            decree)
        ;; Fall through to resolver
        (let ((result (resolve-reference (eval-env-resolver env) name qualifiers)))
          (if (resistance-p result)
              result
              (innate-result-value result))))))

;; ── Emission ─────────────────────────────────────────────────────────────────

(defun eval-emission (node env)
  "Evaluate -> values. Returns the first value (or list if multiple)."
  (let ((values (mapcar (lambda (child) (eval-node child env))
                        (node-children node))))
    (if (= 1 (length values))
        (first values)
        values)))

;; ── Bracket expressions ──────────────────────────────────────────────────────

(defun eval-bracket (node env)
  "Evaluate [context[verb[args]]]. Delegates to resolver."
  (let* ((context-name (node-value node))
         (children (node-children node))
         ;; Try to extract verb and args from nested brackets
         (verb nil)
         (args nil)
         (other-children nil))
    ;; Walk children to find structure
    (dolist (child children)
      (if (and (eq (node-kind child) +node-bracket+) (null verb))
          (progn
            (setf verb (node-value child))
            ;; Args are the children of the verb bracket
            (setf args (mapcar (lambda (c) (eval-node c env))
                               (node-children child))))
          (push (eval-node child env) other-children)))
    (if context-name
        (let ((result (resolve-context (eval-env-resolver env)
                                       context-name
                                       (or verb "")
                                       (or args nil))))
          (if (resistance-p result)
              result
              (innate-result-value result)))
        ;; Anonymous bracket — evaluate children
        (mapcar (lambda (c) (eval-node c env)) children))))

;; ── Search and fulfillment ───────────────────────────────────────────────────

(defun eval-search (node env)
  "Evaluate ![search]. Extracts search type and terms, calls resolver."
  (let* ((children (node-children node))
         (terms (mapcar (lambda (c) (eval-node c env)) children))
         ;; First bare-word child is the search type
         (search-type (if (and children (member (node-kind (first children))
                                                (list +node-bare-word+ +node-string+)))
                          (node-value (first children))
                          "unknown"))
         (search-terms (remove nil (cdr terms))))
    (let ((result (resolve-search (eval-env-resolver env) search-type
                                  (mapcar #'princ-to-string search-terms))))
      (if (resistance-p result)
          result
          (innate-result-value result)))))

(defun eval-fulfillment (node env)
  "Evaluate expr || (agent){commission}. Try left side; if resistance, fire right."
  (let* ((children (node-children node))
         (left (first children))
         (right (second children))
         (left-result (eval-node left env)))
    (if (resistance-p left-result)
        ;; Left failed — fire the commission
        (eval-node right env)
        ;; Left succeeded — return its result
        left-result)))

;; ── Decree evaluation ────────────────────────────────────────────────────────

(defun eval-decree (node env)
  "Decrees were already registered in pass 1. Return the registered value."
  (let ((name (node-value node)))
    (gethash name (eval-env-decrees env))))

;; ── Agent ────────────────────────────────────────────────────────────────────

(defun eval-agent (node env)
  "Evaluate (agent){instruction}. Delivers a commission."
  (let* ((agent-name (node-value node))
         (bundle (first (node-children node)))
         (instruction (if bundle (node-value bundle) "")))
    (let ((result (deliver-commission (eval-env-resolver env)
                                      agent-name instruction)))
      (if (resistance-p result)
          result
          (innate-result-value result)))))

;; ── Wikilink ─────────────────────────────────────────────────────────────────

(defun eval-wikilink (node env)
  (let ((result (resolve-wikilink (eval-env-resolver env) (node-value node))))
    (if (resistance-p result)
        result
        (innate-result-value result))))

;; ── Bundle ───────────────────────────────────────────────────────────────────

(defun eval-bundle (node env)
  "Evaluate {name}. Tries to load from resolver."
  (let ((loaded (load-bundle (eval-env-resolver env) (node-value node))))
    (if loaded
        (evaluate loaded env)
        (node-value node))))

;; ── KV pair and lens ─────────────────────────────────────────────────────────

(defun eval-kv-pair (node env)
  (let ((val (when (node-children node)
               (eval-node (first (node-children node)) env))))
    (list (intern (string-upcase (node-value node)) :keyword) val)))

(defun eval-lens (node env)
  (declare (ignore env))
  (list :lens (node-value node) :rhs (getf (node-props node) :rhs)))
```

- [ ] **Step 4: Run tests**

Run:
```bash
cd ~/Development/innatescript
sbcl --eval '(require :asdf)' \
     --eval '(push #p"./" asdf:*central-registry*)' \
     --eval '(asdf:load-system "innate")' \
     --eval '(load "tests/test-runner.lisp")' \
     --eval '(load "tests/test-evaluator.lisp")' \
     --eval '(innate.tests:run-tests "eval/")' \
     --quit
```

Expected: all evaluator tests pass. Debug and fix any failures.

- [ ] **Step 5: Commit**

```bash
cd ~/Development/innatescript
git add lisp/eval/evaluator.lisp tests/test-evaluator.lisp
git commit -m "feat: evaluator — two-pass AST walker with decree hoisting and fulfillment"
```

---

### Task 7: REPL

**Files:**
- Modify: `lisp/repl/repl.lisp`
- Modify: `lisp/main.lisp`

- [ ] **Step 1: Implement repl.lisp**

```lisp
;; lisp/repl/repl.lisp
(in-package :innate.repl)

(defun run-repl (&optional resolver)
  "Start an interactive Innate REPL."
  (let* ((r (or resolver (make-stub-resolver)))
         (env (make-eval-env :resolver r)))
    (format t "~%innate repl v0.1 — type :quit to exit~%~%")
    (loop
      (format t "innate> ")
      (force-output)
      (let ((line (read-line *standard-input* nil :eof)))
        (when (or (eq line :eof) (string= line ":quit") (string= line ":q"))
          (format t "~%bye.~%")
          (return))
        (when (string= (string-trim '(#\Space #\Tab) line) "")
          (go continue))
        (handler-case
            (let* ((ast (parse line))
                   (results (evaluate ast env)))
              (dolist (r results)
                (format t "-> ~a~%" r)))
          (error (e)
            (format t "!! ~a~%" e)))
        continue))))
```

- [ ] **Step 2: Update main.lisp**

```lisp
;; lisp/main.lisp
(in-package :innate)

(defun run-repl (&optional resolver)
  (innate.repl:run-repl resolver))

(defun run-file (path &optional resolver)
  "Parse and evaluate a .dpn file."
  (let* ((r (or resolver (innate.eval.stub-resolver:make-stub-resolver)))
         (env (innate.eval:make-eval-env :resolver r)))
    (innate.eval:evaluate-file path env)))
```

- [ ] **Step 3: Test the REPL manually**

Run:
```bash
cd ~/Development/innatescript
sbcl --eval '(require :asdf)' \
     --eval '(push #p"./" asdf:*central-registry*)' \
     --eval '(asdf:load-system "innate")' \
     --eval '(innate:run-repl)'
```

At the `innate>` prompt, try:
```
innate> # Hello World
innate> -> 42
innate> This is prose
innate> :quit
```

Expected: headings and prose pass through, emission returns 42.

- [ ] **Step 4: Commit**

```bash
cd ~/Development/innatescript
git add lisp/repl/repl.lisp lisp/main.lisp
git commit -m "feat: interactive REPL and file runner entry points"
```

---

### Task 8: Integration Tests + Parse burg_pipeline.dpn

**Files:**
- Create: `tests/test-integration.lisp`

- [ ] **Step 1: Write integration tests that parse the real .dpn file**

```lisp
;; tests/test-integration.lisp
(defpackage :innate.tests.integration
  (:use :cl :innate.tests :innate.types :innate.parser :innate.eval
        :innate.eval.stub-resolver))

(in-package :innate.tests.integration)

(deftest "integration/parse-burg-pipeline"
  (let ((ast (parse-file "scripts/burg_pipeline.dpn")))
    (assert-equal +node-program+ (node-kind ast))
    (assert-true (> (length (node-children ast)) 0)
                 "burg_pipeline.dpn should have at least one statement")))

(deftest "integration/evaluate-with-stub"
  (let* ((r (make-stub-resolver))
         (env (make-eval-env :resolver r)))
    (stub-add-entity r "Alaran" '(:generative-hard-prompt "A mystical burg of ancient trade routes"))
    (let ((result (evaluate (parse-file "scripts/burg_pipeline.dpn") env)))
      (assert-true (not (null result))
                   "burg_pipeline.dpn should produce results"))))

(deftest "integration/decree-and-reference"
  (let* ((r (make-stub-resolver))
         (env (make-eval-env :resolver r))
         (program (format nil "decree testburg [type: \"Burg\", level: \"Seed\"]~%@testburg"))
         (result (evaluate (parse program) env)))
    ;; First result is the decree registration, second is the reference resolution
    (assert-true (>= (length result) 1))))

(deftest "integration/fulfillment-chain"
  (let* ((r (make-stub-resolver))
         (env (make-eval-env :resolver r))
         (program "![image(\"missing\")] || (vincent){create missing image}")
         (result (evaluate (parse program) env)))
    (declare (ignore result))
    (assert-equal 1 (length (stub-commissions r)))
    (assert-equal "vincent" (first (first (stub-commissions r))))
    (assert-true (search "create missing image"
                         (second (first (stub-commissions r)))))))

(deftest "integration/full-template"
  (let* ((r (make-stub-resolver))
         (env (make-eval-env :resolver r))
         (template (format nil "# Test Template~%Some description text~%@testref~%-> 100"))
         (result (evaluate (parse template) env)))
    (assert-equal 4 (length result))
    ;; First is heading, second is prose, third is resistance (unresolved ref), fourth is emission
    (assert-true (stringp (first result)))
    (assert-true (stringp (second result)))
    (assert-equal 100 (fourth result))))
```

- [ ] **Step 2: Copy burg_pipeline.dpn to scripts/ if not already there**

```bash
cp ~/Development/innatescript/burg_pipeline.dpn ~/Development/innatescript/scripts/burg_pipeline.dpn 2>/dev/null || true
```

- [ ] **Step 3: Run integration tests**

Run:
```bash
cd ~/Development/innatescript
sbcl --eval '(require :asdf)' \
     --eval '(push #p"./" asdf:*central-registry*)' \
     --eval '(asdf:load-system "innate")' \
     --eval '(load "tests/test-runner.lisp")' \
     --eval '(load "tests/test-types.lisp")' \
     --eval '(load "tests/test-tokenizer.lisp")' \
     --eval '(load "tests/test-parser.lisp")' \
     --eval '(load "tests/test-resolver.lisp")' \
     --eval '(load "tests/test-evaluator.lisp")' \
     --eval '(load "tests/test-integration.lisp")' \
     --eval '(innate.tests:run-tests)' \
     --quit
```

Expected: all tests pass. If `burg_pipeline.dpn` causes parse errors, fix the parser to handle its specific syntax and re-run.

- [ ] **Step 4: Commit**

```bash
cd ~/Development/innatescript
git add tests/test-integration.lisp scripts/
git commit -m "feat: integration tests — parses and evaluates burg_pipeline.dpn"
```

---

### Task 9: Run Script + Convenience Runner

**Files:**
- Create: `run-tests.sh`
- Create: `run-repl.sh`

- [ ] **Step 1: Create test runner script**

```bash
#!/usr/bin/env bash
# run-tests.sh — run all Innate tests
set -e
cd "$(dirname "$0")"

sbcl --eval '(require :asdf)' \
     --eval '(push #p"./" asdf:*central-registry*)' \
     --eval '(asdf:load-system "innate")' \
     --eval '(load "tests/test-runner.lisp")' \
     --eval '(load "tests/test-types.lisp")' \
     --eval '(load "tests/test-tokenizer.lisp")' \
     --eval '(load "tests/test-parser.lisp")' \
     --eval '(load "tests/test-resolver.lisp")' \
     --eval '(load "tests/test-evaluator.lisp")' \
     --eval '(load "tests/test-integration.lisp")' \
     --eval '(if (innate.tests:run-tests) (uiop:quit 0) (uiop:quit 1))'
```

- [ ] **Step 2: Create REPL runner script**

```bash
#!/usr/bin/env bash
# run-repl.sh — start the Innate REPL
cd "$(dirname "$0")"

if [ -n "$1" ]; then
    # Run a file
    sbcl --eval '(require :asdf)' \
         --eval '(push #p"./" asdf:*central-registry*)' \
         --eval '(asdf:load-system "innate")' \
         --eval "(innate:run-file \"$1\")" \
         --quit
else
    # Interactive REPL
    sbcl --eval '(require :asdf)' \
         --eval '(push #p"./" asdf:*central-registry*)' \
         --eval '(asdf:load-system "innate")' \
         --eval '(innate:run-repl)'
fi
```

- [ ] **Step 3: Make executable and test**

```bash
cd ~/Development/innatescript
chmod +x run-tests.sh run-repl.sh
./run-tests.sh
```

Expected: all tests pass, exit code 0.

- [ ] **Step 4: Commit**

```bash
cd ~/Development/innatescript
git add run-tests.sh run-repl.sh
git commit -m "feat: shell scripts for running tests and REPL"
```

---

## Summary

After all 9 tasks, you will have:

- A Common Lisp parser that reads `.dpn` files into an AST
- A pluggable resolver protocol (CLOS generic functions) that any backend can implement
- A stub resolver for testing that stores entities in memory
- A two-pass evaluator with decree hoisting and fulfillment (`||`) semantics
- An interactive REPL
- Integration tests that parse the real `burg_pipeline.dpn`
- Shell scripts for running tests and the REPL

**What comes next (not in this plan):**
- Noosphere resolver (connects `@` to master_chronicle, `()` to ghost conversations)
- `/api/innate/eval` endpoint in dpn-api
- Laptop CLI (`innate push`, `innate eval`)
- SBCL needs to be installed on the laptop
