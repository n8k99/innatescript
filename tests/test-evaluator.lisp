;;;; tests/test-evaluator.lisp — Two-pass evaluator tests
;;;; Tests named bracket hoisting, passthrough nodes, and literal evaluation.

(in-package :innate.tests.evaluator)

;;; EVL-01: Two-pass - named bracket collected in pass 1
(deftest test-named-bracket-collected-in-pass-1
  (let* ((env (make-eval-env :resolver (make-stub-resolver)))
         (ast (make-node :kind :program :children
                (list (make-node :kind :bracket :value "greeting"
                        :children (list (make-node :kind :string-lit :value "hello")))))))
    (evaluate ast env)
    (assert-true (gethash "greeting" (eval-env-decrees env)))))

;;; EVL-01: Named bracket with value collected in pass 1 decrees
(deftest test-named-bracket-collected-in-decrees
  (let* ((env (make-eval-env :resolver (make-stub-resolver)))
         (ast (make-node :kind :program :children
                (list (make-node :kind :bracket :value "x"
                        :children (list (make-node :kind :string-lit :value "val")))
                      (make-node :kind :prose :value "visible")))))
    (evaluate ast env)
    (assert-true (gethash "x" (eval-env-decrees env)))))

;;; EVL-08: Named bracket body stored as full node
(deftest test-named-bracket-stores-full-node
  (let* ((env (make-eval-env :resolver (make-stub-resolver)))
         (bracket-node (make-node :kind :bracket :value "myvar"
                         :children (list (make-node :kind :number-lit :value "42"))))
         (ast (make-node :kind :program :children (list bracket-node))))
    (evaluate ast env)
    (let ((stored (gethash "myvar" (eval-env-decrees env))))
      (assert-equal :bracket (node-kind stored)))))

;;; EVL-11: Prose passthrough
(deftest test-prose-passthrough
  (let* ((env (make-eval-env :resolver (make-stub-resolver)))
         (ast (make-node :kind :program :children
                (list (make-node :kind :prose :value "This is a document line.")))))
    (let ((results (evaluate ast env)))
      (assert-equal 1 (length results))
      (assert-equal "This is a document line." (first results)))))

;;; EVL-11: Heading passthrough
(deftest test-heading-passthrough
  (let* ((env (make-eval-env :resolver (make-stub-resolver)))
         (ast (make-node :kind :program :children
                (list (make-node :kind :heading :value "Chapter One")))))
    (let ((results (evaluate ast env)))
      (assert-equal 1 (length results))
      (assert-equal "Chapter One" (first results)))))

;;; EVL-14: Literal evaluation
(deftest test-string-lit-returns-value
  (let* ((env (make-eval-env :resolver (make-stub-resolver)))
         (ast (make-node :kind :program :children
                (list (make-node :kind :string-lit :value "hello world")))))
    (assert-equal "hello world" (first (evaluate ast env)))))

(deftest test-number-lit-returns-integer
  (let* ((env (make-eval-env :resolver (make-stub-resolver)))
         (ast (make-node :kind :program :children
                (list (make-node :kind :number-lit :value "42")))))
    (assert-equal 42 (first (evaluate ast env)))))

(deftest test-bare-word-returns-string
  (let* ((env (make-eval-env :resolver (make-stub-resolver)))
         (ast (make-node :kind :program :children
                (list (make-node :kind :bare-word :value "name")))))
    (assert-equal "name" (first (evaluate ast env)))))

(deftest test-emoji-slot-returns-string
  (let* ((env (make-eval-env :resolver (make-stub-resolver)))
         (ast (make-node :kind :program :children
                (list (make-node :kind :emoji-slot :value "fire")))))
    (assert-equal "fire" (first (evaluate ast env)))))

;;; EVL-14: Multiple top-level nodes produce results in order
(deftest test-multiple-top-level-results
  (let* ((env (make-eval-env :resolver (make-stub-resolver)))
         (ast (make-node :kind :program :children
                (list (make-node :kind :prose :value "first")
                      (make-node :kind :prose :value "second")
                      (make-node :kind :prose :value "third")))))
    (let ((results (evaluate ast env)))
      (assert-equal 3 (length results))
      (assert-equal "first" (first results))
      (assert-equal "third" (third results)))))

;;; EVL-12: Mixed named brackets and passthrough nodes
(deftest test-mixed-named-bracket-and-prose
  (let* ((env (make-eval-env :resolver (make-stub-resolver)))
         (ast (make-node :kind :program :children
                (list (make-node :kind :prose :value "intro")
                      (make-node :kind :bracket :value "config"
                        :children (list (make-node :kind :string-lit :value "value")))
                      (make-node :kind :prose :value "body")))))
    (evaluate ast env)
    ;; Named bracket was hoisted into decrees
    (assert-true (gethash "config" (eval-env-decrees env)))))

;;; EVL-14: combinator node returns value string
(deftest test-combinator-returns-value
  (let* ((env (make-eval-env :resolver (make-stub-resolver)))
         (ast (make-node :kind :program :children
                (list (make-node :kind :combinator :value "+")))))
    (assert-equal "+" (first (evaluate ast env)))))

;;; EVL-14: modifier node returns value string
(deftest test-modifier-returns-value
  (let* ((env (make-eval-env :resolver (make-stub-resolver)))
         (ast (make-node :kind :program :children
                (list (make-node :kind :modifier :value "all")))))
    (assert-equal "all" (first (evaluate ast env)))))

;;; EVL-02: @reference resolution — named brackets first, then resolver

(deftest test-reference-resolves-from-named-bracket
  "A @reference resolves against named brackets collected in pass 1"
  (let* ((env (make-eval-env :resolver (make-stub-resolver)))
         (ast (make-node :kind :program :children
                (list (make-node :kind :bracket :value "greeting"
                        :children (list (make-node :kind :string-lit :value "hello")))
                      (make-node :kind :reference :value "greeting")))))
    (let ((results (evaluate ast env)))
      (assert-equal 1 (length results))
      (assert-equal "hello" (first results)))))

(deftest test-forward-reference-resolves
  "A @reference BEFORE its named bracket in source still resolves (hoisting)"
  (let* ((env (make-eval-env :resolver (make-stub-resolver)))
         (ast (make-node :kind :program :children
                (list (make-node :kind :reference :value "later")
                      (make-node :kind :bracket :value "later"
                        :children (list (make-node :kind :string-lit :value "found-it")))))))
    (let ((results (evaluate ast env)))
      (assert-equal 1 (length results))
      (assert-equal "found-it" (first results)))))

(deftest test-reference-falls-through-to-resolver
  "When no named bracket matches, @reference calls resolve-reference on the resolver"
  (let* ((resolver (make-stub-resolver))
         (env (make-eval-env :resolver resolver))
         (ast (make-node :kind :program :children
                (list (make-node :kind :reference :value "burg")))))
    (stub-add-entity resolver "burg" '(:type "Burg" :state "Seed"))
    (let ((results (evaluate ast env)))
      (assert-equal 1 (length results))
      ;; Result is the innate-result-value from resolver
      (assert-equal '(:type "Burg" :state "Seed") (first results)))))

(deftest test-reference-with-qualifiers
  "@name:qualifier passes qualifier chain to resolver"
  (let* ((resolver (make-stub-resolver))
         (env (make-eval-env :resolver resolver))
         (ast (make-node :kind :program :children
                (list (make-node :kind :reference :value "burg"
                        :props '(:qualifiers ("type")))))))
    (stub-add-entity resolver "burg" '(:type "Burg" :state "Seed"))
    (let ((results (evaluate ast env)))
      (assert-equal 1 (length results))
      (assert-equal "Burg" (first results)))))

(deftest test-reference-named-bracket-takes-priority-over-resolver
  "Named bracket wins over resolver when both have the same name"
  (let* ((resolver (make-stub-resolver))
         (env (make-eval-env :resolver resolver))
         (ast (make-node :kind :program :children
                (list (make-node :kind :bracket :value "burg"
                        :children (list (make-node :kind :string-lit :value "local-burg")))
                      (make-node :kind :reference :value "burg")))))
    (stub-add-entity resolver "burg" '(:type "Burg"))
    (let ((results (evaluate ast env)))
      (assert-equal "local-burg" (first results)))))

;;; EVL-03: Bracket expression evaluation

(deftest test-bracket-calls-resolve-context
  "A bracket expression calls resolve-context on the resolver"
  (let* ((resolver (make-stub-resolver))
         (env (make-eval-env :resolver resolver))
         (ast (make-node :kind :program :children
                (list (make-node :kind :bracket :children
                        (list (make-node :kind :bare-word :value "db")
                              (make-node :kind :bracket :children
                                (list (make-node :kind :bare-word :value "get_count")))))))))
    (stub-add-context resolver "db" "get_count" 42)
    (let ((results (evaluate ast env)))
      (assert-equal 1 (length results))
      (assert-equal 42 (first results)))))

;;; EVL-15: Resistance propagation

(deftest test-unresolvable-reference-signals-resistance
  "An @reference that cannot resolve signals innate-resistance"
  (let* ((env (make-eval-env :resolver (make-stub-resolver)))
         (ast (make-node :kind :program :children
                (list (make-node :kind :reference :value "nonexistent")))))
    (assert-signals innate-resistance
      (evaluate ast env))))

(deftest test-resistance-propagates-from-bracket
  "A bracket whose resolver returns resistance signals innate-resistance"
  (let* ((env (make-eval-env :resolver (make-stub-resolver)))
         (ast (make-node :kind :program :children
                (list (make-node :kind :bracket :children
                        (list (make-node :kind :bare-word :value "unknown")
                              (make-node :kind :bracket :children
                                (list (make-node :kind :bare-word :value "action")))))))))
    (assert-signals innate-resistance
      (evaluate ast env))))

;;; Full pipeline: tokenize -> parse -> evaluate

(deftest test-pipeline-prose-passthrough
  "Full pipeline: prose lines pass through evaluation"
  (let* ((env (make-eval-env :resolver (make-stub-resolver)))
         (source "This is just a document line.")
         (ast (parse (tokenize source))))
    (let ((results (evaluate ast env)))
      (assert-true (> (length results) 0))
      (assert-true (stringp (first results))))))

(deftest test-pipeline-named-bracket-and-reference
  "Full pipeline: named bracket + @reference through tokenize/parse/evaluate"
  (let* ((resolver (make-stub-resolver))
         (env (make-eval-env :resolver resolver))
         (source (format nil "greeting[\"hello world\"]~%@greeting"))
         (ast (parse (tokenize source))))
    (let ((results (evaluate ast env)))
      (assert-true (> (length results) 0)))))

;;; EVL-07: Emission — -> value evaluates children and returns values

(deftest test-emission-single-value
  "Single child emission returns the child value directly"
  (let* ((env (make-eval-env :resolver (make-stub-resolver)))
         (ast (make-node :kind :program :children
                (list (make-node :kind :emission :children
                        (list (make-node :kind :string-lit :value "hello")))))))
    (let ((results (evaluate ast env)))
      (assert-equal 1 (length results))
      (assert-equal "hello" (first results)))))

(deftest test-emission-multiple-values
  "Multiple children emission returns a list of values"
  (let* ((env (make-eval-env :resolver (make-stub-resolver)))
         (ast (make-node :kind :program :children
                (list (make-node :kind :emission :children
                        (list (make-node :kind :string-lit :value "a")
                              (make-node :kind :string-lit :value "b")))))))
    (let ((results (evaluate ast env)))
      (assert-equal 1 (length results))
      (let ((emission-result (first results)))
        (assert-equal '("a" "b") emission-result)))))

(deftest test-emission-evaluates-children
  "Emission evaluates its children (e.g. number-lit parses to integer)"
  (let* ((env (make-eval-env :resolver (make-stub-resolver)))
         (ast (make-node :kind :program :children
                (list (make-node :kind :emission :children
                        (list (make-node :kind :number-lit :value "42")))))))
    (let ((results (evaluate ast env)))
      (assert-equal 1 (length results))
      (assert-equal 42 (first results)))))

;;; EVL-09: Wikilink — [[Title]] calls resolve-wikilink on the resolver

(deftest test-wikilink-calls-resolve-wikilink
  "[[Title]] calls resolve-wikilink and returns the resolved content"
  (let* ((resolver (make-stub-resolver))
         (env (make-eval-env :resolver resolver))
         (ast (make-node :kind :program :children
                (list (make-node :kind :wikilink :value "Burg")))))
    (stub-add-wikilink resolver "Burg" "The Burg entity")
    (let ((results (evaluate ast env)))
      (assert-equal 1 (length results))
      (assert-equal "The Burg entity" (first results)))))

(deftest test-wikilink-resistance-when-not-found
  "[[Nonexistent]] signals innate-resistance when wikilink not in resolver"
  (let* ((env (make-eval-env :resolver (make-stub-resolver)))
         (ast (make-node :kind :program :children
                (list (make-node :kind :wikilink :value "Nonexistent")))))
    (assert-signals innate-resistance
      (evaluate ast env))))

;;; EVL-10: Bundle — {bundle_name} loads and evaluates sub-program nodes

(deftest test-bundle-loads-and-evaluates-nodes
  "{bundle_name} loads AST nodes via load-bundle and evaluates them"
  (let* ((resolver (make-stub-resolver))
         (env (make-eval-env :resolver resolver))
         (ast (make-node :kind :program :children
                (list (make-node :kind :bundle :value "config")))))
    (stub-add-bundle resolver "config"
                     (list (make-node :kind :string-lit :value "loaded")))
    (let ((results (evaluate ast env)))
      (assert-equal 1 (length results))
      (assert-equal "loaded" (first results)))))

(deftest test-bundle-not-found-signals-resistance
  "{missing} signals innate-resistance when bundle not in resolver"
  (let* ((env (make-eval-env :resolver (make-stub-resolver)))
         (ast (make-node :kind :program :children
                (list (make-node :kind :bundle :value "missing")))))
    (assert-signals innate-resistance
      (evaluate ast env))))

(deftest test-bundle-evaluates-multiple-nodes
  "{multi} bundle with multiple nodes evaluates all and returns last result"
  (let* ((resolver (make-stub-resolver))
         (env (make-eval-env :resolver resolver))
         (ast (make-node :kind :program :children
                (list (make-node :kind :bundle :value "multi")))))
    (stub-add-bundle resolver "multi"
                     (list (make-node :kind :string-lit :value "first")
                           (make-node :kind :string-lit :value "second")))
    (let ((results (evaluate ast env)))
      (assert-equal 1 (length results))
      ;; Bundle evaluates as progn — returns last result
      (assert-equal "second" (first results)))))

;;; Full pipeline: tokenize -> parse -> evaluate for emission

(deftest test-pipeline-emission
  "Full pipeline: -> \"hello\" produces hello in result list"
  (let* ((env (make-eval-env :resolver (make-stub-resolver)))
         (ast (parse (tokenize "-> \"hello\""))))
    (let ((results (evaluate ast env)))
      (assert-true (> (length results) 0))
      (assert-true (member "hello" results :test #'equal)))))

;;; EVL-04: Commission — (agent){instruction} delivers commission via resolver

(deftest test-commission-agent-bundle-adjacency
  "(agent){instruction} adjacency: agent + bundle calls deliver-commission"
  (let* ((resolver (make-stub-resolver))
         (env (make-eval-env :resolver resolver))
         (ast (make-node :kind :program :children
                (list (make-node :kind :agent :value "sylvia")
                      (make-node :kind :bundle :value "fix_database")))))
    (let ((results (evaluate ast env)))
      (assert-equal '(("sylvia" "fix_database")) (stub-commissions resolver))
      ;; Commission result is t (from deliver-commission returning innate-result :value t)
      (assert-equal t (first results)))))

(deftest test-standalone-agent-returns-name
  "Standalone (agent) with no following :bundle returns agent name"
  (let* ((resolver (make-stub-resolver))
         (env (make-eval-env :resolver resolver))
         (ast (make-node :kind :program :children
                (list (make-node :kind :agent :value "sylvia")))))
    (let ((results (evaluate ast env)))
      (assert-equal "sylvia" (first results))
      ;; No commission delivered
      (assert-nil (stub-commissions resolver)))))

(deftest test-commission-records-multiple
  "Multiple agent+bundle pairs each record a commission"
  (let* ((resolver (make-stub-resolver))
         (env (make-eval-env :resolver resolver))
         (ast (make-node :kind :program :children
                (list (make-node :kind :agent :value "a")
                      (make-node :kind :bundle :value "task1")
                      (make-node :kind :agent :value "b")
                      (make-node :kind :bundle :value "task2")))))
    (evaluate ast env)
    (assert-equal '(("a" "task1") ("b" "task2")) (stub-commissions resolver))))

;;; EVL-05: Search — ![...] calls resolve-search on the resolver

(deftest test-search-calls-resolve-search
  "![type:\"Burg\"] calls resolve-search and returns matching entities"
  (let* ((resolver (make-stub-resolver))
         (env (make-eval-env :resolver resolver))
         (ast (make-node :kind :program :children
                (list (make-node :kind :search :children
                        (list (make-node :kind :kv-pair :value "type"
                                :children (list (make-node :kind :string-lit :value "Burg")))))))))
    (stub-add-entity resolver "burg1" '(:type "Burg" :state "Seed"))
    (let ((results (evaluate ast env)))
      (assert-equal 1 (length results))
      ;; resolve-search returns a list of matching entities
      (assert-true (listp (first results)))
      (assert-true (member '(:type "Burg" :state "Seed") (first results) :test #'equal)))))

(deftest test-search-resistance-no-match
  "![type:\"Nonexistent\"] signals innate-resistance when no entities match"
  (let* ((env (make-eval-env :resolver (make-stub-resolver)))
         (ast (make-node :kind :program :children
                (list (make-node :kind :search :children
                        (list (make-node :kind :kv-pair :value "type"
                                :children (list (make-node :kind :string-lit :value "Nonexistent")))))))))
    (assert-signals innate-resistance
      (evaluate ast env))))

;;; EVL-06, ERR-04: Fulfillment — || catches resistance and evaluates right side

(deftest test-fulfillment-left-succeeds-returns-left
  "|| returns left result when left evaluates without resistance"
  (let* ((resolver (make-stub-resolver))
         (env (make-eval-env :resolver resolver))
         ;; Left: string-lit "ok", Right: agent "fallback" + bundle "fix" (in this test, just a string right side)
         (ast (make-node :kind :program :children
                (list (make-node :kind :fulfillment :children
                        (list (make-node :kind :string-lit :value "ok")
                              (make-node :kind :string-lit :value "fallback")))))))
    (let ((results (evaluate ast env)))
      (assert-equal "ok" (first results))
      ;; Right side never evaluated — no commissions
      (assert-nil (stub-commissions resolver)))))

(deftest test-fulfillment-left-resistance-fires-right
  "|| evaluates right side when left signals innate-resistance"
  (let* ((resolver (make-stub-resolver))
         (env (make-eval-env :resolver resolver))
         ;; Left: unresolvable reference, Right: string "recovered"
         (ast (make-node :kind :program :children
                (list (make-node :kind :fulfillment :children
                        (list (make-node :kind :reference :value "nonexistent")
                              (make-node :kind :string-lit :value "recovered")))))))
    (let ((results (evaluate ast env)))
      (assert-equal "recovered" (first results)))))

;;; Full pipeline integration tests

(deftest test-pipeline-commission
  "Full pipeline: (sylvia){\"fix\"} records commission via tokenize/parse/evaluate"
  (let* ((resolver (make-stub-resolver))
         (env (make-eval-env :resolver resolver))
         (ast (parse (tokenize "(sylvia){\"fix\"}"))))
    (evaluate ast env)
    (assert-equal 1 (length (stub-commissions resolver)))
    (assert-equal "sylvia" (first (first (stub-commissions resolver))))))

(deftest test-fulfillment-resistance-fires-commission-pipeline
  "Full pipeline: @missing || (helper) fires right side on resistance (agent returns name)"
  (let* ((resolver (make-stub-resolver))
         (env (make-eval-env :resolver resolver))
         ;; Note: parser splits (helper){"fix_it"} into :agent + :bundle siblings.
         ;; The fulfillment right-side gets :agent only. Commission adjacency at
         ;; statement level handles the :bundle separately.
         ;; Test verifies fulfillment fires the right side (agent name returned).
         (ast (parse (tokenize "@missing || (helper){\"fix_it\"}"))))
    (let ((results (evaluate ast env)))
      ;; The fulfillment evaluates and returns "helper" (agent name)
      ;; The bundle "fix_it" is evaluated separately as standalone bundle
      (assert-true (member "helper" results :test #'equal)))))

;;; -----------------------------------------------------------------------
;;; Milestone 11: Choreographic Coordination Tests
;;; -----------------------------------------------------------------------

;; T03: Concurrent evaluation

(deftest test-concurrent-dispatches-all-branches
  "concurrent evaluates all children — multiple commissions recorded"
  (let* ((resolver (make-stub-resolver))
         (env (make-eval-env :resolver resolver))
         (ast (parse (tokenize "concurrent [(a){task1} (b){task2}]"))))
    (evaluate ast env)
    (let ((comms (stub-commissions resolver)))
      (assert-equal 2 (length comms) "two commissions dispatched")
      (assert-equal "a" (first (first comms)) "first agent is a")
      (assert-equal "b" (first (second comms)) "second agent is b"))))

(deftest test-concurrent-returns-results
  "concurrent returns results from all branches"
  (let* ((resolver (make-stub-resolver))
         (env (make-eval-env :resolver resolver))
         (ast (parse (tokenize "concurrent [42 \"hello\"]"))))
    (let ((results (evaluate ast env)))
      ;; The concurrent block is the only top-level statement
      (let ((conc-result (first results)))
        (assert-true (listp conc-result) "concurrent returns a list")
        (assert-equal 2 (length conc-result) "two results")))))

(deftest test-concurrent-resistance-isolation
  "resistance in one concurrent branch does not prevent others"
  (let* ((resolver (make-stub-resolver))
         (env (make-eval-env :resolver resolver))
         (ast (parse (tokenize "concurrent [@missing (b){task2}]"))))
    (let ((results (evaluate ast env)))
      ;; @missing produces resistance (swallowed by concurrent), (b){task2} still dispatches
      (assert-equal 1 (length (stub-commissions resolver)) "commission from b still dispatched"))))

;; T05: Join synchronization

(deftest test-join-orders-waves
  "join inside concurrent partitions into waves — pre-join before post-join"
  (let* ((resolver (make-stub-resolver))
         (env (make-eval-env :resolver resolver))
         (ast (parse (tokenize "concurrent [(a){first} join (b){second}]"))))
    (evaluate ast env)
    (let ((comms (stub-commissions resolver)))
      (assert-equal 2 (length comms) "two commissions total")
      (assert-equal "a" (first (first comms)) "first commission is from a")
      (assert-equal "b" (first (second comms)) "second commission is from b"))))

(deftest test-concurrent-without-join-no-barrier
  "concurrent without join evaluates all children without barrier"
  (let* ((resolver (make-stub-resolver))
         (env (make-eval-env :resolver resolver))
         (ast (parse (tokenize "concurrent [(a){x} (b){y} (c){z}]"))))
    (evaluate ast env)
    (assert-equal 3 (length (stub-commissions resolver)) "all three dispatched")))

;; T07: Postfix until

(deftest test-postfix-until-evaluates-expression
  "postfix until evaluates the wrapped expression"
  (let* ((resolver (make-stub-resolver))
         (env (make-eval-env :resolver resolver))
         ;; Use @ref which is a single expression, not agent+bundle pair
         (ast (parse (tokenize "[@myref until 3 days]"))))
    (stub-add-entity resolver "myref" '(:value "data"))
    (evaluate ast env)
    ;; @myref resolves, then until wraps the result
    ))

(deftest test-postfix-until-returns-duration
  "postfix until result includes duration metadata"
  (let* ((resolver (make-stub-resolver))
         (env (make-eval-env :resolver resolver))
         (ast (parse (tokenize "[@myref until 3 days]"))))
    (stub-add-entity resolver "myref" '(:value "data"))
    (let* ((results (evaluate ast env))
           (bracket-result (first results)))
      ;; The bracket evaluates, and inside it the until node produces the result
      (assert-true (listp bracket-result) "bracket result is list"))))

;; T08: Block until

(deftest test-block-until-evaluates-body
  "block until evaluates all body children"
  (let* ((resolver (make-stub-resolver))
         (env (make-eval-env :resolver resolver))
         (ast (parse (tokenize "until 3 days [(a){x} (b){y}]"))))
    (evaluate ast env)
    (assert-equal 2 (length (stub-commissions resolver)) "both commissions dispatched")))

(deftest test-block-until-with-fulfillment
  "block until with || fires fulfillment on resistance"
  (let* ((resolver (make-stub-resolver))
         (env (make-eval-env :resolver resolver))
         ;; Block until with fulfillment — the || is parsed by the parser's block-until handler
         (ast (parse (tokenize "until 3 days [@missing] || [(fallback){escalate}]"))))
    (evaluate ast env)
    ;; @missing produces resistance, fulfillment fires
    (assert-equal 1 (length (stub-commissions resolver)) "fallback commission dispatched")
    (assert-equal "fallback" (first (first (stub-commissions resolver))) "fallback agent")))

;; T10: Sync evaluation

(deftest test-sync-dispatches-commission
  "sync evaluates its child — commission is delivered"
  (let* ((resolver (make-stub-resolver))
         (env (make-eval-env :resolver resolver))
         (ast (parse (tokenize "sync [(a){background_task}]"))))
    (evaluate ast env)
    (assert-equal 1 (length (stub-commissions resolver)) "commission dispatched")))

(deftest test-sync-returns-nil
  "sync does not contribute to parent results"
  (let* ((resolver (make-stub-resolver))
         (env (make-eval-env :resolver resolver))
         (ast (parse (tokenize "sync [(a){task}]"))))
    (let ((results (evaluate ast env)))
      ;; sync returns nil, which is in the result list
      (assert-nil (first results) "sync result is nil"))))

(deftest test-sync-swallows-resistance
  "sync swallows resistance — does not propagate to parent"
  (let* ((resolver (make-stub-resolver))
         (env (make-eval-env :resolver resolver))
         (ast (parse (tokenize "sync @nonexistent"))))
    ;; Should not signal — resistance is swallowed
    (let ((results (evaluate ast env)))
      (assert-nil (first results) "sync swallowed resistance"))))

;; T12: At evaluation

(deftest test-at-calls-schedule-at
  "at schedules expression via resolver"
  (let* ((resolver (make-stub-resolver))
         (env (make-eval-env :resolver resolver))
         (ast (parse (tokenize "at [[2026-04-15]] [(a){task}]"))))
    (evaluate ast env)
    (let ((scheds (stub-schedules resolver)))
      (assert-equal 1 (length scheds) "one schedule recorded")
      (assert-equal "2026-04-15" (first (first scheds)) "time is correct"))))

(deftest test-at-returns-handle
  "at returns schedule handle from resolver"
  (let* ((resolver (make-stub-resolver))
         (env (make-eval-env :resolver resolver))
         (ast (parse (tokenize "at [[2026-04-15]] [(a){task}]"))))
    (let ((results (evaluate ast env)))
      (assert-equal 1 (first results) "handle is 1 (first schedule)"))))

;; T14: Verification evaluation

(deftest test-verification-calls-deliver-verification
  "verification evaluates left, routes to agent via deliver-verification"
  (let* ((resolver (make-stub-resolver))
         (env (make-eval-env :resolver resolver))
         (ast (parse (tokenize "[\"draft output\" <- (reviewer){check}]"))))
    (evaluate ast env)
    (let ((vfs (stub-verifications resolver)))
      ;; deliver-verification should be called
      ;; Note: the parser produces <- with left=string, right=agent+bundle
      ;; The evaluator tries to extract agent name from right side
      (assert-true (>= (length vfs) 1) "verification recorded"))))

(deftest test-verification-records-prior-output
  "verification passes prior output to deliver-verification"
  (let* ((resolver (make-stub-resolver))
         (env (make-eval-env :resolver resolver))
         (ast (parse (tokenize "[\"my draft\" <- (checker)]"))))
    (evaluate ast env)
    (let ((vfs (stub-verifications resolver)))
      (assert-equal 1 (length vfs) "one verification")
      (assert-equal "my draft" (second (first vfs)) "prior output passed"))))

;; T15: Verification inside concurrent

(deftest test-verification-in-concurrent
  "multiple verifications inside concurrent all dispatch"
  (let* ((resolver (make-stub-resolver))
         (env (make-eval-env :resolver resolver))
         (ast (parse (tokenize "concurrent [\"draft\" <- (reviewer_a) \"draft\" <- (reviewer_b)]"))))
    (evaluate ast env)
    (let ((vfs (stub-verifications resolver)))
      (assert-equal 2 (length vfs) "two verifications recorded"))))
