;;;; tests/test-parser.lisp — Parser test suite for the Innate interpreter
;;;; Phase 04 Plan 01: cursor struct, bracket parsing, kv-pairs, prose, statements

(in-package :innate.tests.parser)

;;; -----------------------------------------------------------------------
;;; Task 1: Token cursor struct tests
;;; -----------------------------------------------------------------------

(deftest test-cursor-peek-empty
  "cursor-peek on empty token list returns nil"
  (let ((result (parse '())))
    ;; parse on empty list must return :program node — confirms cursor-peek-empty works
    (assert-equal :program (node-kind result) "empty parse returns :program node")))

(deftest test-cursor-peek-next
  "cursor-peek-next lookahead is used for kv-pair disambiguation"
  ;; Indirect test: [key: value] requires peek-next to detect colon after bare-word
  ;; If lookahead fails, the bare-word would be parsed as a bare-word atom not a kv-pair key
  (let* ((tokens (tokenize "[key: val]"))
         (result (parse tokens))
         (bracket (first (node-children result)))
         (first-child (first (node-children bracket))))
    (assert-equal :bracket (node-kind bracket) "first program child is bracket")
    (assert-equal :kv-pair (node-kind first-child) "first bracket child is kv-pair (lookahead worked)")))

(deftest test-parse-empty-returns-program
  "parse on empty token list returns :program node with no children"
  (let ((result (parse '())))
    (assert-equal :program (node-kind result) "node kind is :program")
    (assert-nil (node-children result) "empty program has no children")))

(deftest test-cursor-expect-mismatch-signals
  "cursor-expect with wrong type signals innate-parse-error"
  ;; Unterminated bracket triggers expect of :rbracket, which fails
  (assert-signals innate-parse-error
                  (parse (tokenize "["))
                  "unterminated bracket signals parse error"))

;;; -----------------------------------------------------------------------
;;; Task 2: Bracket parsing, kv-pairs, atoms, prose, statements
;;; -----------------------------------------------------------------------

(deftest test-simple-bracket
  "simple bracket with one bare-word child"
  (let* ((result (parse (tokenize "[hello]")))
         (bracket (first (node-children result))))
    (assert-equal :bracket (node-kind bracket) "child is :bracket node")
    (let ((body (node-children bracket)))
      (assert-true (consp body) "bracket has children")
      (assert-equal :bare-word (node-kind (first body)) "bracket child is bare-word")
      (assert-equal "hello" (node-value (first body)) "bare-word value is hello"))))

(deftest test-nested-brackets
  "PAR-01: [a[b[c]]] parses as three-level nested brackets"
  (let* ((result (parse (tokenize "[a[b[c]]]")))
         (outer (first (node-children result))))
    (assert-equal :bracket (node-kind outer) "outer is bracket")
    ;; outer children: bare-word "a" and inner bracket
    (let* ((outer-children (node-children outer))
           (inner (find-if (lambda (n) (eq :bracket (node-kind n))) outer-children)))
      (assert-true inner "outer bracket has an inner bracket child")
      (let* ((inner-children (node-children inner))
             (innermost (find-if (lambda (n) (eq :bracket (node-kind n))) inner-children)))
        (assert-true innermost "inner bracket has innermost bracket child")
        (let ((leaf-children (node-children innermost)))
          (assert-true (consp leaf-children) "innermost bracket has children")
          (assert-equal :bare-word (node-kind (first leaf-children)) "innermost child is bare-word")
          (assert-equal "c" (node-value (first leaf-children)) "innermost bare-word is c"))))))

(deftest test-anonymous-bracket-depth
  "PAR-02: [[[\"Hello\"]]] parses as anonymous nested brackets with :string-lit leaf"
  (let* ((result (parse (tokenize "[[[\"Hello\"]]]")))
         (outer (first (node-children result))))
    (assert-equal :bracket (node-kind outer) "outer is bracket")
    (let* ((mid (first (node-children outer))))
      (assert-equal :bracket (node-kind mid) "mid is bracket")
      (let* ((inner (first (node-children mid))))
        (assert-equal :bracket (node-kind inner) "inner is bracket")
        (let* ((leaf (first (node-children inner))))
          (assert-equal :string-lit (node-kind leaf) "leaf is string-lit")
          (assert-equal "Hello" (node-value leaf) "leaf value is Hello"))))))

(deftest test-multiple-statements
  "PAR-03: two statements separated by newline both appear as :program children"
  (let* ((result (parse (tokenize (format nil "[a]~%[b]"))))
         (children (node-children result)))
    (assert-equal 2 (length children) "program has two children")
    (assert-equal :bracket (node-kind (first children)) "first child is bracket")
    (assert-equal :bracket (node-kind (second children)) "second child is bracket")))

(deftest test-kv-pair
  "PAR-15: [key: \"value\"] parses as bracket with :kv-pair child"
  (let* ((result (parse (tokenize "[key: \"value\"]")))
         (bracket (first (node-children result)))
         (kv (first (node-children bracket))))
    (assert-equal :bracket (node-kind bracket) "outer is bracket")
    (assert-equal :kv-pair (node-kind kv) "child is kv-pair")
    (assert-equal "key" (node-value kv) "kv-pair key is 'key'")
    (let ((val-node (first (node-children kv))))
      (assert-equal :string-lit (node-kind val-node) "kv value is string-lit")
      (assert-equal "value" (node-value val-node) "kv string value is 'value'"))))

(deftest test-kv-pair-bare-word-value
  "PAR-15: [key: value] where value is bare-word parses correctly"
  (let* ((result (parse (tokenize "[key: value]")))
         (bracket (first (node-children result)))
         (kv (first (node-children bracket))))
    (assert-equal :kv-pair (node-kind kv) "child is kv-pair")
    (assert-equal "key" (node-value kv) "kv key is 'key'")
    (let ((val-node (first (node-children kv))))
      (assert-equal :bare-word (node-kind val-node) "kv value is bare-word")
      (assert-equal "value" (node-value val-node) "kv bare-word value is 'value'"))))

(deftest test-prose-node
  "PAR-20: prose token in program becomes :prose node"
  (let* ((result (parse (tokenize "this is some prose")))
         (children (node-children result)))
    (assert-true (consp children) "program has children")
    (assert-equal :prose (node-kind (first children)) "first child is prose node")))

(deftest test-bracket-body-sequence
  "PAR-21: [a b c] bracket body contains three :bare-word children in order"
  (let* ((result (parse (tokenize "[a b c]")))
         (bracket (first (node-children result)))
         (children (node-children bracket)))
    (assert-equal 3 (length children) "bracket has 3 children")
    (assert-equal :bare-word (node-kind (first children)) "first is bare-word")
    (assert-equal "a" (node-value (first children)) "first value is a")
    (assert-equal :bare-word (node-kind (second children)) "second is bare-word")
    (assert-equal "b" (node-value (second children)) "second value is b")
    (assert-equal :bare-word (node-kind (third children)) "third is bare-word")
    (assert-equal "c" (node-value (third children)) "third value is c")))

(deftest test-bare-word-atom
  "bare-word atom in bracket parses as :bare-word node"
  (let* ((result (parse (tokenize "[hello]")))
         (bracket (first (node-children result)))
         (atom (first (node-children bracket))))
    (assert-equal :bare-word (node-kind atom) "atom is bare-word")
    (assert-equal "hello" (node-value atom) "atom value is hello")))

(deftest test-string-literal-atom
  "string literal parses as :string-lit node"
  (let* ((result (parse (tokenize "[\"world\"]")))
         (bracket (first (node-children result)))
         (atom (first (node-children bracket))))
    (assert-equal :string-lit (node-kind atom) "atom is string-lit")
    (assert-equal "world" (node-value atom) "atom value is world")))

(deftest test-number-literal-atom
  "number literal parses as :number-lit node"
  (let* ((result (parse (tokenize "[42]")))
         (bracket (first (node-children result)))
         (atom (first (node-children bracket))))
    (assert-equal :number-lit (node-kind atom) "atom is number-lit")
    (assert-equal "42" (node-value atom) "atom value is 42")))

(deftest test-wikilink-atom
  "PAR-18: wikilink token [[MyPage]] parses as :wikilink node inside bracket"
  ;; Inside a bracket body, [[MyPage]] tokenizes as a single :wikilink token
  ;; x is before so wikilink isn't at position 0 (avoiding any edge cases)
  (let* ((result (parse (tokenize "[x [[MyPage]] y]")))
         (bracket (first (node-children result)))
         (children (node-children bracket))
         ;; children: bare-word "x", wikilink "MyPage", bare-word "y"
         (wikilink (second children)))
    (assert-equal 3 (length children) "bracket has 3 children")
    (assert-equal :wikilink (node-kind wikilink) "second child is wikilink")
    (assert-equal "MyPage" (node-value wikilink) "wikilink value is MyPage")))

(deftest test-unterminated-bracket-signals-error
  "unterminated bracket signals innate-parse-error"
  (assert-signals innate-parse-error
                  (parse (tokenize "[hello"))
                  "unterminated bracket signals parse error"))
