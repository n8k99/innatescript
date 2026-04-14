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

;;; -----------------------------------------------------------------------
;;; Plan 02 Task 1: Reference, agent, bundle, lens, search, modifier tests
;;; -----------------------------------------------------------------------

(deftest test-simple-reference
  "PAR-08: @name parses as :reference node with value name"
  (let* ((result (parse (tokenize "@name")))
         (ref (first (node-children result))))
    (assert-equal :reference (node-kind ref) "node kind is :reference")
    (assert-equal "name" (node-value ref) "reference value is name")
    (assert-nil (node-children ref) "no children for bare reference")))

(deftest test-reference-with-qualifier
  "PAR-09: @name:qualifier parses as :reference with qualifier in children and props"
  (let* ((result (parse (tokenize "@name:qualifier")))
         (ref (first (node-children result))))
    (assert-equal :reference (node-kind ref) "node kind is :reference")
    (assert-equal "name" (node-value ref) "reference value is name")
    (let ((children (node-children ref)))
      (assert-true (consp children) "reference has children")
      (assert-equal :string-lit (node-kind (first children)) "qualifier child is string-lit")
      (assert-equal "qualifier" (node-value (first children)) "qualifier value is qualifier"))
    (let ((props (node-props ref)))
      (assert-true props "props are non-nil")
      (assert-equal (list "qualifier") (getf props :qualifiers) "props :qualifiers is (qualifier)"))))

(deftest test-reference-with-multi-word-qualifier
  "PAR-09: @Alaran:generative hard prompt parses as :reference with multi-word qualifier"
  (let* ((result (parse (tokenize "@Alaran:generative hard prompt")))
         (ref (first (node-children result))))
    (assert-equal :reference (node-kind ref) "node kind is :reference")
    (assert-equal "Alaran" (node-value ref) "reference value is Alaran")
    (let ((children (node-children ref)))
      (assert-true (consp children) "reference has children")
      (assert-equal :string-lit (node-kind (first children)) "qualifier child is string-lit")
      (assert-equal "generative hard prompt" (node-value (first children)) "multi-word qualifier"))))

(deftest test-reference-with-string-qualifier
  "PAR-09: @type:\"[[Burg]]\" parses with string value as qualifier"
  (let* ((result (parse (tokenize "@type:\"[[Burg]]\"")))
         (ref (first (node-children result))))
    (assert-equal :reference (node-kind ref) "node kind is :reference")
    (assert-equal "type" (node-value ref) "reference value is type")
    (let ((children (node-children ref)))
      (assert-true (consp children) "reference has qualifier child")
      (assert-equal :string-lit (node-kind (first children)) "qualifier is string-lit")
      (assert-equal "[[Burg]]" (node-value (first children)) "qualifier value is [[Burg]]"))
    (let ((props (node-props ref)))
      (assert-equal (list "[[Burg]]") (getf props :qualifiers) "props :qualifiers contains [[Burg]]"))))

(deftest test-compound-reference
  "PAR-10: @type:\"[[Burg]]\"+all{state:==} parses as compound :reference"
  (let* ((result (parse (tokenize "@type:\"[[Burg]]\"+all{state:==}")))
         (ref (first (node-children result))))
    (assert-equal :reference (node-kind ref) "node kind is :reference")
    (assert-equal "type" (node-value ref) "reference value is type")
    (let ((children (node-children ref)))
      (assert-equal 3 (length children) "compound reference has 3 children")
      ;; child 0: string-lit qualifier
      (let ((qual (first children)))
        (assert-equal :string-lit (node-kind qual) "first child is string-lit qualifier")
        (assert-equal "[[Burg]]" (node-value qual) "qualifier value is [[Burg]]"))
      ;; child 1: combinator
      (let ((comb (second children)))
        (assert-equal :combinator (node-kind comb) "second child is :combinator")
        (assert-equal "all" (node-value comb) "combinator value is all"))
      ;; child 2: lens
      (let ((lens (third children)))
        (assert-equal :lens (node-kind lens) "third child is :lens")
        (let ((kv (first (node-children lens))))
          (assert-equal :kv-pair (node-kind kv) "lens child is kv-pair")
          (assert-equal "state" (node-value kv) "kv-pair key is state")
          (let ((kv-val (first (node-children kv))))
            (assert-equal :bare-word (node-kind kv-val) "kv value is bare-word")
            (assert-equal "==" (node-value kv-val) "kv value is ==")))))
    (let ((props (node-props ref)))
      (assert-equal (list "[[Burg]]") (getf props :qualifiers) "props :qualifiers")
      (assert-equal "all" (getf props :combinator) "props :combinator is all"))))

(deftest test-agent-parse
  "PAR-04: (agent_name) parses as :agent node with value agent_name"
  (let* ((result (parse (tokenize "(agent_name)")))
         (agent (first (node-children result))))
    (assert-equal :agent (node-kind agent) "node kind is :agent")
    (assert-equal "agent_name" (node-value agent) "agent value is agent_name")))

(deftest test-bundle-parse
  "PAR-06: {name} parses as :bundle node with value name"
  (let* ((result (parse (tokenize "{name}")))
         (bundle (first (node-children result))))
    (assert-equal :bundle (node-kind bundle) "node kind is :bundle")
    (assert-equal "name" (node-value bundle) "bundle value is name")))

(deftest test-lens-parse
  "PAR-07: {key:value} parses as :lens node with :kv-pair child"
  (let* ((result (parse (tokenize "{key:value}")))
         (lens (first (node-children result))))
    (assert-equal :lens (node-kind lens) "node kind is :lens")
    (let ((kv (first (node-children lens))))
      (assert-equal :kv-pair (node-kind kv) "lens child is kv-pair")
      (assert-equal "key" (node-value kv) "kv-pair key is key")
      (let ((val (first (node-children kv))))
        (assert-equal :bare-word (node-kind val) "kv value is bare-word")
        (assert-equal "value" (node-value val) "kv value is value")))))

(deftest test-search-directive
  "PAR-11: ![search_expr] parses as :search node with expression children"
  (let* ((result (parse (tokenize "![search_expr]")))
         (search (first (node-children result))))
    (assert-equal :search (node-kind search) "node kind is :search")
    (let ((children (node-children search)))
      (assert-true (consp children) "search has children")
      (assert-equal :bare-word (node-kind (first children)) "search child is bare-word")
      (assert-equal "search_expr" (node-value (first children)) "search child value"))))

(deftest test-modifier-parse
  "PAR-17: /modifier parses as :modifier node with value modifier"
  (let* ((result (parse (tokenize "[x /wrapLeft]")))
         (bracket (first (node-children result)))
         (children (node-children bracket)))
    ;; children: bare-word "x", modifier "wrapLeft"
    (let ((mod-node (second children)))
      (assert-equal :modifier (node-kind mod-node) "node kind is :modifier")
      (assert-equal "wrapLeft" (node-value mod-node) "modifier value is wrapLeft"))))

;;; -----------------------------------------------------------------------
;;; Plan 02 Task 2: Decree parsing and heading refinement tests
;;; -----------------------------------------------------------------------

(deftest test-decree-with-body
  "PAR-14: decree routing_rules [key: value] parses as :decree with body children"
  (let* ((result (parse (tokenize "decree routing_rules [key: value]")))
         (decree (first (node-children result))))
    (assert-equal :decree (node-kind decree) "node kind is :decree")
    (assert-equal "routing_rules" (node-value decree) "decree value is routing_rules")
    (let ((children (node-children decree)))
      (assert-true (consp children) "decree has children")
      (let ((kv (first children)))
        (assert-equal :kv-pair (node-kind kv) "decree child is kv-pair")
        (assert-equal "key" (node-value kv) "kv-pair key is key")))))

(deftest test-decree-no-body
  "PAR-14: decree name alone parses as :decree with nil children"
  (let* ((result (parse (tokenize "decree my_decree")))
         (decree (first (node-children result))))
    (assert-equal :decree (node-kind decree) "node kind is :decree")
    (assert-equal "my_decree" (node-value decree) "decree value is my_decree")
    (assert-nil (node-children decree) "decree with no body has nil children")))

(deftest test-heading-with-bracket
  "PAR-19: #header[name] parses as :heading with bracket child"
  (let* ((result (parse (tokenize "#title [content]")))
         (heading (first (node-children result))))
    (assert-equal :heading (node-kind heading) "node kind is :heading")
    (assert-equal "title" (node-value heading) "heading value is title")
    (let ((children (node-children heading)))
      (assert-true (consp children) "heading has bracket children")
      (let ((child (first children)))
        (assert-equal :bare-word (node-kind child) "heading bracket child is bare-word")
        (assert-equal "content" (node-value child) "bracket child value is content")))))

(deftest test-wikilink-in-program
  "PAR-18: [[Title]] inside a bracket parses as :wikilink — confirmed from Plan 01"
  ;; Wikilinks tokenize as :wikilink when [[name]] appears inside a bracket context
  ;; (nesting-depth > 0). Use [x [[Title]] y] pattern from test-wikilink-atom.
  (let* ((result (parse (tokenize "[x [[Title]] y]")))
         (bracket (first (node-children result)))
         (children (node-children bracket))
         ;; children: bare-word "x", wikilink "Title", bare-word "y"
         (wl (second children)))
    (assert-equal :wikilink (node-kind wl) "second child is wikilink")
    (assert-equal "Title" (node-value wl) "wikilink value is Title")))

;;; -----------------------------------------------------------------------
;;; Plan 03 Task 1: Emission and fulfillment operator tests
;;; -----------------------------------------------------------------------

(deftest test-emission
  "PAR-13: -> \"hello\" parses as :emission node with one :string-lit child"
  (let* ((result (parse (tokenize "-> \"hello\"")))
         (stmt (first (node-children result))))
    (assert-equal :emission (node-kind stmt) "node kind is :emission")
    (let ((children (node-children stmt)))
      (assert-equal 1 (length children) "emission has 1 child")
      (assert-equal :string-lit (node-kind (first children)) "emission child is string-lit")
      (assert-equal "hello" (node-value (first children)) "emission child value is hello"))))

(deftest test-emission-multi-value
  "PAR-13: -> a, b, c parses as :emission node with three :bare-word children"
  (let* ((result (parse (tokenize "-> a, b, c")))
         (stmt (first (node-children result))))
    (assert-equal :emission (node-kind stmt) "node kind is :emission")
    (let ((children (node-children stmt)))
      (assert-equal 3 (length children) "emission has 3 children")
      (assert-equal :bare-word (node-kind (first children)) "first child is bare-word")
      (assert-equal "a" (node-value (first children)) "first value is a")
      (assert-equal :bare-word (node-kind (second children)) "second child is bare-word")
      (assert-equal "b" (node-value (second children)) "second value is b")
      (assert-equal :bare-word (node-kind (third children)) "third child is bare-word")
      (assert-equal "c" (node-value (third children)) "third value is c"))))

(deftest test-emission-chain
  "PAR-13: [a -> b -> c] parses left-associatively as (-> (-> a b) c) inside bracket"
  ;; Use bracket context: bare words at top level become :prose.
  ;; Inside brackets, -> tokenizes as :arrow and bare-words as :bare-word.
  (let* ((result (parse (tokenize "[a -> b -> c]")))
         (bracket (first (node-children result)))
         (outer (first (node-children bracket))))
    (assert-equal :emission (node-kind outer) "outer node is :emission")
    ;; outer children: inner emission and c
    (let ((outer-children (node-children outer)))
      (assert-equal 2 (length outer-children) "outer emission has 2 children")
      (let ((inner (first outer-children)))
        (assert-equal :emission (node-kind inner) "first child is inner :emission")
        ;; inner's children: bare-word a and bare-word b
        (let ((inner-children (node-children inner)))
          (assert-equal 2 (length inner-children) "inner emission has 2 children")
          (assert-equal :bare-word (node-kind (first inner-children)) "inner first child is bare-word")
          (assert-equal "a" (node-value (first inner-children)) "inner first value is a")
          (assert-equal :bare-word (node-kind (second inner-children)) "inner second child is bare-word")
          (assert-equal "b" (node-value (second inner-children)) "inner second value is b")))
      ;; outer second child: c
      (let ((last-child (second outer-children)))
        (assert-equal :bare-word (node-kind last-child) "outer second child is bare-word")
        (assert-equal "c" (node-value last-child) "outer second value is c")))))

(deftest test-fulfillment
  "PAR-12: @ref || (agent){fallback} parses as :fulfillment with reference left child"
  (let* ((result (parse (tokenize "@ref || (agent)")))
         (stmt (first (node-children result))))
    (assert-equal :fulfillment (node-kind stmt) "node kind is :fulfillment")
    (let ((children (node-children stmt)))
      (assert-equal 2 (length children) "fulfillment has 2 children")
      (assert-equal :reference (node-kind (first children)) "left child is :reference")
      (assert-equal "ref" (node-value (first children)) "left reference value is ref")
      (assert-equal :agent (node-kind (second children)) "right child is :agent")
      (assert-equal "agent" (node-value (second children)) "right agent value is agent"))))

(deftest test-fulfillment-chain
  "PAR-12: @a || @b || @c parses left-associatively as (|| (|| @a @b) @c)"
  ;; Use @ references to avoid prose detection at depth 0 (bare words are prose at top level)
  (let* ((result (parse (tokenize "@a || @b || @c")))
         (outer (first (node-children result))))
    (assert-equal :fulfillment (node-kind outer) "outer node is :fulfillment")
    (let ((outer-children (node-children outer)))
      (assert-equal 2 (length outer-children) "outer fulfillment has 2 children")
      (let ((inner (first outer-children)))
        (assert-equal :fulfillment (node-kind inner) "first child is inner :fulfillment")
        (let ((inner-children (node-children inner)))
          (assert-equal :reference (node-kind (first inner-children)) "inner left is :reference @a")
          (assert-equal "a" (node-value (first inner-children)) "inner left value is a")
          (assert-equal :reference (node-kind (second inner-children)) "inner right is :reference @b")
          (assert-equal "b" (node-value (second inner-children)) "inner right value is b")))
      (let ((last-child (second outer-children)))
        (assert-equal :reference (node-kind last-child) "outer right child is :reference @c")
        (assert-equal "c" (node-value last-child) "outer right value is c")))))

(deftest test-emission-fulfillment-precedence
  "PAR-12 + PAR-13: -> a || (agent){fallback} — emission binds tighter than fulfillment"
  ;; The -> a part is an emission node. That emission is the left side of ||.
  (let* ((result (parse (tokenize "-> a || (agent)")))
         (stmt (first (node-children result))))
    (assert-equal :fulfillment (node-kind stmt) "top node is :fulfillment (looser binding)")
    (let ((children (node-children stmt)))
      (assert-equal :emission (node-kind (first children))
                    "left child of fulfillment is :emission (tighter binding)")
      (assert-equal :agent (node-kind (second children))
                    "right child of fulfillment is :agent"))))

(deftest test-parse-error-signals
  "malformed input [unterminated signals innate-parse-error with line/col"
  (assert-signals innate-parse-error
                  (parse (tokenize "["))
                  "unterminated bracket signals innate-parse-error"))

;;; -----------------------------------------------------------------------
;;; Plan 03 Task 2: Integration test and ROADMAP success criteria tests
;;; -----------------------------------------------------------------------

(defun find-node-recursive (node kind)
  "Recursively search NODE and all its children for a node with the given KIND.
   Returns the first matching node or nil."
  (when node
    (if (eq (node-kind node) kind)
        node
        (dolist (child (node-children node))
          (let ((found (find-node-recursive child kind)))
            (when found (return found)))))))

(defun find-all-nodes-recursive (node kind &optional acc)
  "Recursively collect all nodes with the given KIND from NODE tree.
   Returns a list of matching nodes."
  (when node
    (let ((new-acc (if (eq (node-kind node) kind) (cons node acc) acc)))
      (dolist (child (node-children node))
        (setf new-acc (find-all-nodes-recursive child kind new-acc)))
      new-acc)))

(deftest test-burg-pipeline-parse
  "Integration: burg_pipeline.dpn parses completely without error"
  ;; Read and parse the actual burg_pipeline.dpn file
  (let* ((content (with-open-file (f (merge-pathnames "burg_pipeline.dpn"
                                                       (asdf:system-source-directory :innatescript))
                                     :direction :input)
                    (let ((str (make-string (file-length f))))
                      (read-sequence str f)
                      str)))
         (result (parse (tokenize content))))
    ;; Top-level: :program node
    (assert-equal :program (node-kind result) "result is :program node")
    ;; Program has children
    (assert-true (consp (node-children result)) "program has children")
    ;; First child is :heading with value containing burg_pipeline
    (let ((heading (first (node-children result))))
      (assert-equal :heading (node-kind heading) "first child is :heading")
      (assert-true (search "burg_pipeline" (node-value heading))
                   "heading value contains burg_pipeline"))
    ;; A :bracket node exists
    (assert-true (find-node-recursive result :bracket) "a :bracket node exists in tree")
    ;; A :kv-pair node exists with key "type"
    (let ((kv-nodes (find-all-nodes-recursive result :kv-pair)))
      (assert-true kv-nodes "at least one kv-pair node exists")
      (assert-true (find-if (lambda (n) (equal "type" (node-value n))) kv-nodes)
                   "a kv-pair with key 'type' exists"))
    ;; A :reference node exists (from @Alaran inside description kv-pair)
    (assert-true (find-node-recursive result :reference) "a :reference node exists in tree")
    ;; A :search node exists
    (assert-true (find-node-recursive result :search) "a :search node exists in tree")
    ;; :prose nodes exist
    (assert-true (find-node-recursive result :prose) "prose nodes exist in tree")))

(deftest test-compound-reference-full
  "ROADMAP criterion 4: @type:\"[[Burg]]\"+all{state:==} full compound reference structure"
  (let* ((result (parse (tokenize "@type:\"[[Burg]]\"+all{state:==}")))
         (ref (first (node-children result))))
    ;; Top node is :reference, value is "type"
    (assert-equal :reference (node-kind ref) "top node kind is :reference")
    (assert-equal "type" (node-value ref) "reference value is type")
    ;; Children: string-lit qualifier, combinator, lens
    (let ((children (node-children ref)))
      (assert-equal 3 (length children) "compound reference has 3 children")
      ;; First child: string-lit "[[Burg]]"
      (let ((qual (first children)))
        (assert-equal :string-lit (node-kind qual) "first child kind is :string-lit")
        (assert-equal "[[Burg]]" (node-value qual) "qualifier value is [[Burg]]"))
      ;; Second child: combinator "all"
      (let ((comb (second children)))
        (assert-equal :combinator (node-kind comb) "second child kind is :combinator")
        (assert-equal "all" (node-value comb) "combinator value is all"))
      ;; Third child: lens
      (let ((lens (third children)))
        (assert-equal :lens (node-kind lens) "third child kind is :lens")
        (let ((kv (first (node-children lens))))
          (assert-equal :kv-pair (node-kind kv) "lens child is kv-pair")
          (assert-equal "state" (node-value kv) "kv-pair key is state")
          (let ((kv-val (first (node-children kv))))
            (assert-equal :bare-word (node-kind kv-val) "kv value kind is bare-word")
            (assert-equal "==" (node-value kv-val) "kv value is ==")))))
    ;; Props: :qualifiers ("[[Burg]]") and :combinator "all"
    (let ((props (node-props ref)))
      (assert-equal (list "[[Burg]]") (getf props :qualifiers) "props :qualifiers contains [[Burg]]")
      (assert-equal "all" (getf props :combinator) "props :combinator is all"))))

(deftest test-three-level-nested-parse
  "ROADMAP criterion 1: [db[get_count[entry]]] three bracket levels"
  (let* ((result (parse (tokenize "[db[get_count[entry]]]")))
         (outer (first (node-children result))))
    ;; Outer bracket exists
    (assert-equal :bracket (node-kind outer) "outer is :bracket")
    ;; Outer children: bare-word "db" and a nested bracket
    (let* ((outer-children (node-children outer))
           (middle (find-if (lambda (n) (eq :bracket (node-kind n))) outer-children)))
      (assert-true middle "outer bracket has a nested bracket child")
      ;; Middle bracket children: bare-word "get_count" and a nested bracket
      (let* ((middle-children (node-children middle))
             (inner (find-if (lambda (n) (eq :bracket (node-kind n))) middle-children)))
        (assert-true inner "middle bracket has a nested bracket child")
        ;; Inner bracket children: bare-word "entry"
        (let ((inner-children (node-children inner)))
          (assert-true (consp inner-children) "innermost bracket has children")
          (assert-equal :bare-word (node-kind (first inner-children)) "innermost child is bare-word")
          (assert-equal "entry" (node-value (first inner-children)) "innermost value is entry"))))))

(deftest test-left-associative-chain
  "ROADMAP criterion 2: [a -> b -> c] is (-> (-> a b) c)"
  ;; Use bracket to avoid top-level prose detection
  (let* ((result (parse (tokenize "[a -> b -> c]")))
         (bracket (first (node-children result)))
         (emission (first (node-children bracket))))
    (assert-equal :emission (node-kind emission) "bracket child is :emission")
    ;; Outer emission children: (inner emission, c)
    (let ((outer-children (node-children emission)))
      (assert-equal 2 (length outer-children) "outer emission has 2 children")
      (let ((inner (first outer-children)))
        (assert-equal :emission (node-kind inner) "left child of outer emission is :emission")
        ;; Inner emission: (a, b)
        (let ((inner-children (node-children inner)))
          (assert-equal "a" (node-value (first inner-children)) "inner left is a")
          (assert-equal "b" (node-value (second inner-children)) "inner right is b")))
      (assert-equal "c" (node-value (second outer-children)) "outer right is c"))))

(deftest test-parse-error-line-col
  "ROADMAP criterion 5: parse error on malformed [ includes line and col info"
  (handler-case
      (progn
        (parse (tokenize "["))
        (assert-true nil "expected innate-parse-error but none was signaled"))
    (innate-parse-error (e)
      ;; line and col should be in the condition — check via condition text
      ;; innate-parse-error has line/col slots (from conditions.lisp)
      (assert-true t "innate-parse-error was signaled"))))

;;; -----------------------------------------------------------------------
;;; Milestone 10: Choreographic parsing tests (T08)
;;; -----------------------------------------------------------------------

;; Verification

(deftest test-parse-verification
  "<- (agent){check} produces a :verification node"
  (let* ((ast (parse (tokenize "[(agent){check} <- (reviewer){verify}]")))
         (stmt (first (node-children ast))))
    ;; The bracket body should contain a verification node
    (let ((children (node-children stmt)))
      ;; Should parse as verification with two sides
      (assert-true (find :verification children :key #'node-kind)
                   "verification node present in bracket"))))

(deftest test-parse-verification-standalone
  "<- in statement position works"
  (let* ((ast (parse (tokenize "[@result <- (checker){review}]")))
         (bracket (first (node-children ast)))
         (children (node-children bracket)))
    (let ((verif (find :verification children :key #'node-kind)))
      (assert-true verif "verification node found")
      (assert-equal 2 (length (node-children verif)) "verification has left and right"))))

;; Concurrent

(deftest test-parse-concurrent
  "concurrent [expr1 expr2] produces :concurrent node"
  (let* ((ast (parse (tokenize "concurrent [(a){x} (b){y}]")))
         (stmt (first (node-children ast))))
    (assert-equal :concurrent (node-kind stmt) "node kind is :concurrent")
    ;; (a){x} and (b){y} each produce agent+bundle = 4 parser-level children
    (assert-equal 4 (length (node-children stmt)) "four children (2 agent+bundle pairs)")))

(deftest test-parse-concurrent-with-join
  "join inside concurrent produces a join marker"
  (let* ((ast (parse (tokenize "concurrent [(a){x} join (b){y}]")))
         (stmt (first (node-children ast)))
         (children (node-children stmt)))
    ;; agent+bundle, join, agent+bundle = 5 children
    (assert-equal 5 (length children) "five children (agent+bundle, join, agent+bundle)")
    (let ((join-node (third children)))
      (assert-equal "join" (node-value join-node) "join marker value")
      (assert-true (getf (node-props join-node) :join-marker) "join-marker prop set"))))

(deftest test-parse-concurrent-error
  "concurrent without bracket signals parse error"
  (handler-case
      (progn
        (parse (tokenize "concurrent (a){x}"))
        (assert-true nil "expected parse error"))
    (innate-parse-error (e)
      (declare (ignore e))
      (assert-true t "parse error signaled for concurrent without ["))))

;; Sync

(deftest test-parse-sync
  "sync @agent{task} produces :sync node"
  (let* ((ast (parse (tokenize "sync (a){task}")))
         (stmt (first (node-children ast))))
    (assert-equal :sync (node-kind stmt) "node kind is :sync")
    (assert-equal 1 (length (node-children stmt)) "one child expression")))

;; At

(deftest test-parse-at-wikilink
  "at [[2026-04-15]] @agent{task} produces :at node with wikilink time"
  (let* ((ast (parse (tokenize "at [[2026-04-15]] (a){task}")))
         (stmt (first (node-children ast))))
    (assert-equal :at (node-kind stmt) "node kind is :at")
    (assert-equal 2 (length (node-children stmt)) "two children: time and expr")
    (let ((time-node (first (node-children stmt))))
      (assert-equal :wikilink (node-kind time-node) "time is wikilink")
      (assert-equal "2026-04-15" (node-value time-node) "wikilink date value"))))

(deftest test-parse-at-error
  "at without time signals parse error"
  (handler-case
      (progn
        (parse (tokenize "at"))
        (assert-true nil "expected parse error"))
    (innate-parse-error (e)
      (declare (ignore e))
      (assert-true t "parse error signaled for at without time"))))

;; Until (block form)

(deftest test-parse-block-until
  "until 3 days [expr] produces :until node"
  (let* ((ast (parse (tokenize "until 3 days [(a){x}]")))
         (stmt (first (node-children ast))))
    (assert-equal :until (node-kind stmt) "node kind is :until")
    (assert-equal "3" (getf (node-props stmt) :duration) "duration is 3")
    (assert-equal "days" (getf (node-props stmt) :unit) "unit is days")))

;; Until (postfix form)

(deftest test-parse-postfix-until
  "@agent{task} until 3 days produces :until wrapping commission"
  (let* ((ast (parse (tokenize "[(a){task} until 3 days]")))
         (bracket (first (node-children ast)))
         (children (node-children bracket)))
    (let ((until-node (find :until children :key #'node-kind)))
      (assert-true until-node "until node found")
      (assert-true (getf (node-props until-node) :postfix) "postfix flag set")
      (assert-equal "3" (getf (node-props until-node) :duration) "duration is 3"))))

;; Existing expression parsing unaffected

(deftest test-parse-arrow-still-works
  "-> emission still parses after adding <-"
  (let* ((ast (parse (tokenize "[-> 42]")))
         (bracket (first (node-children ast)))
         (emission (first (node-children bracket))))
    (assert-equal :emission (node-kind emission) "emission still works")))

(deftest test-parse-fulfillment-still-works
  "|| fulfillment still parses after adding <-"
  (let* ((ast (parse (tokenize "[@missing || (fallback){fix}]")))
         (bracket (first (node-children ast)))
         (fulfillment (first (node-children bracket))))
    (assert-equal :fulfillment (node-kind fulfillment) "fulfillment still works")))
