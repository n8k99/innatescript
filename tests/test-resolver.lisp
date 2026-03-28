;;;; test-resolver.lisp — tests for resolver protocol and eval-env struct
;;;; Tests RES-01 through RES-07 (generic signatures and default method contracts)
;;;; Tests EVL-13 (eval-env carries evaluation context)

(in-package :innate.tests.resolver)

;;; RES-07: Default methods return resistance (not errors, not signals)

(deftest test-resolve-reference-default-returns-resistance
  (let* ((r (make-instance 'resolver))
         (result (resolve-reference r "missing" nil)))
    (assert-true (resistance-p result))
    (assert-true (search "missing" (resistance-message result)))))

(deftest test-resolve-search-default-returns-resistance
  (let* ((r (make-instance 'resolver))
         (result (resolve-search r :full-text '("query"))))
    (assert-true (resistance-p result))))

(deftest test-deliver-commission-default-returns-result
  (let* ((r (make-instance 'resolver))
         (result (deliver-commission r "sylvia" "do it")))
    (assert-nil (resistance-p result))
    (assert-equal :commission (innate-result-context result))))

(deftest test-resolve-wikilink-default-returns-resistance
  (let* ((r (make-instance 'resolver))
         (result (resolve-wikilink r "Burg")))
    (assert-true (resistance-p result))
    (assert-true (search "Burg" (resistance-message result)))))

(deftest test-resolve-context-default-returns-resistance
  (let* ((r (make-instance 'resolver))
         (result (resolve-context r "db" "get_count" '("entry"))))
    (assert-true (resistance-p result))))

(deftest test-load-bundle-default-returns-nil
  (let* ((r (make-instance 'resolver))
         (result (load-bundle r "pipeline")))
    (assert-nil result)))

;;; RES-01 through RES-06: Generic function signatures

(deftest test-resolve-reference-accepts-qualifiers-list
  (let* ((r (make-instance 'resolver))
         (result (resolve-reference r "burg" '("type" "state"))))
    (assert-true (resistance-p result))
    (assert-true (search "burg" (resistance-message result)))))

(deftest test-deliver-commission-always-succeeds
  ;; Commissions are fire-and-forget — never return resistance
  (let* ((r (make-instance 'resolver))
         (result (deliver-commission r "arbitrary-agent" "any instruction")))
    (assert-equal nil (innate-result-value result))
    (assert-equal :commission (innate-result-context result))))

;;; EVL-13: eval-env struct carries evaluation context

(deftest test-eval-env-construction
  (let* ((r (make-instance 'resolver))
         (env (make-eval-env :resolver r :scope :render)))
    (assert-equal r (eval-env-resolver env))
    (assert-equal :render (eval-env-scope env))))

(deftest test-eval-env-decrees-defaults-to-hash-table
  (let ((env (make-eval-env)))
    (assert-true (hash-table-p (eval-env-decrees env)))))

(deftest test-eval-env-bindings-defaults-to-hash-table
  (let ((env (make-eval-env)))
    (assert-true (hash-table-p (eval-env-bindings env)))))

(deftest test-eval-env-scope-defaults-to-query
  (let ((env (make-eval-env)))
    (assert-equal :query (eval-env-scope env))))

(deftest test-eval-env-decrees-writable
  ;; Evaluator pass 1 writes decrees; verify hash-table is mutable
  (let ((env (make-eval-env)))
    (setf (gethash "my-decree" (eval-env-decrees env)) :some-node)
    (assert-equal :some-node (gethash "my-decree" (eval-env-decrees env)))))
