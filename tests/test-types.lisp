;;;; test-types.lisp — tests for AST node types, result types, and resistance struct
;;;; Tests PAR-22: defstruct nodes with kind/value/children/props round-trip correctly

(in-package :innate.tests.types)

;;; Node kind constants

(deftest test-node-kind-constant-value
  (assert-true (eql +node-bracket+ :bracket)
               "+node-bracket+ constant equals :bracket keyword"))

(deftest test-node-kind-constant-prose
  (assert-true (eql +node-prose+ :prose)
               "+node-prose+ constant equals :prose keyword"))

;;; make-node construction and slot access

(deftest test-make-node-kind-slot
  (let ((n (make-node :kind :bracket)))
    (assert-equal :bracket (node-kind n) "node-kind returns :kind initarg")))

(deftest test-make-node-value-slot
  (let ((n (make-node :kind :prose :value "hello world")))
    (assert-equal "hello world" (node-value n) "node-value returns :value initarg")))

(deftest test-make-node-children-slot
  (let* ((child (make-node :kind :bare-word :value "get"))
         (parent (make-node :kind :bracket :children (list child))))
    (assert-equal 1 (length (node-children parent))
                  "node-children returns list with one child")))

(deftest test-make-node-props-slot
  (let ((n (make-node :kind :reference :props '(:qualifiers ("generative")))))
    (assert-equal '(:qualifiers ("generative")) (node-props n)
                  "node-props returns :props initarg plist")))

(deftest test-make-node-default-slots
  (let ((n (make-node)))
    (assert-nil (node-kind n)     "default node-kind is nil")
    (assert-nil (node-value n)    "default node-value is nil")
    (assert-nil (node-children n) "default node-children is nil")
    (assert-nil (node-props n)    "default node-props is nil")))

(deftest test-node-kind-matches-constant
  (let ((n (make-node :kind +node-bracket+)))
    (assert-true (eql (node-kind n) +node-bracket+)
                 "node-kind eql to the +node-bracket+ constant")))

;;; innate-result struct

(deftest test-innate-result-value-slot
  (let ((r (make-innate-result :value 42 :context :query)))
    (assert-equal 42 (innate-result-value r) "innate-result-value returns :value initarg")))

(deftest test-innate-result-context-slot
  (let ((r (make-innate-result :value "x" :context :commission)))
    (assert-equal :commission (innate-result-context r)
                  "innate-result-context returns :context initarg")))

;;; Resistance struct (data value, not condition)

(deftest test-resistance-predicate-true
  (assert-true (resistance-p (make-resistance :message "failed" :source "@ref"))
               "resistance-p returns T for a resistance struct"))

(deftest test-resistance-predicate-false
  (assert-nil (resistance-p "not-a-resistance")
              "resistance-p returns NIL for a non-resistance value"))

(deftest test-resistance-message-slot
  (let ((r (make-resistance :message "could not resolve" :source "@burg")))
    (assert-equal "could not resolve" (resistance-message r)
                  "resistance-message returns :message initarg")))
