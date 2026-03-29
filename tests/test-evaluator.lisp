;;;; tests/test-evaluator.lisp — Two-pass evaluator tests
;;;; Tests decree hoisting, passthrough nodes, and literal evaluation.

(in-package :innate.tests.evaluator)

;;; EVL-01: Two-pass - decree collected in pass 1
(deftest test-decree-collected-in-pass-1
  (let* ((env (make-eval-env :resolver (make-stub-resolver)))
         (ast (make-node :kind :program :children
                (list (make-node :kind :decree :value "greeting"
                        :children (list (make-node :kind :string-lit :value "hello")))))))
    (evaluate ast env)
    (assert-true (gethash "greeting" (eval-env-decrees env)))))

;;; EVL-01: Decree nodes skipped in pass 2 (not in results)
(deftest test-decree-not-in-results
  (let* ((env (make-eval-env :resolver (make-stub-resolver)))
         (ast (make-node :kind :program :children
                (list (make-node :kind :decree :value "x"
                        :children (list (make-node :kind :string-lit :value "val")))
                      (make-node :kind :prose :value "visible")))))
    (let ((results (evaluate ast env)))
      (assert-equal 1 (length results))
      (assert-equal "visible" (first results)))))

;;; EVL-08: Decree body stored as full node
(deftest test-decree-stores-full-node
  (let* ((env (make-eval-env :resolver (make-stub-resolver)))
         (decree-node (make-node :kind :decree :value "myvar"
                        :children (list (make-node :kind :number-lit :value "42"))))
         (ast (make-node :kind :program :children (list decree-node))))
    (evaluate ast env)
    (let ((stored (gethash "myvar" (eval-env-decrees env))))
      (assert-equal :decree (node-kind stored)))))

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

;;; EVL-12: Mixed decrees and passthrough nodes
(deftest test-mixed-decree-and-prose
  (let* ((env (make-eval-env :resolver (make-stub-resolver)))
         (ast (make-node :kind :program :children
                (list (make-node :kind :prose :value "intro")
                      (make-node :kind :decree :value "config"
                        :children (list (make-node :kind :string-lit :value "value")))
                      (make-node :kind :prose :value "body")))))
    (let ((results (evaluate ast env)))
      ;; Two prose nodes, no decree in results
      (assert-equal 2 (length results))
      (assert-equal "intro" (first results))
      (assert-equal "body" (second results))
      ;; Decree was hoisted
      (assert-true (gethash "config" (eval-env-decrees env))))))

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
