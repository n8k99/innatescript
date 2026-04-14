;;;; test-stub-resolver.lisp — conformance tests for the in-memory stub resolver
;;;; Tests RES-08 (all 6 generics), RES-09 (commission recording), RES-10 (qualifier chains)

(in-package :innate.tests.stub-resolver)

;;; RES-08: Stub resolver is a fully conforming implementation

(deftest test-make-stub-resolver-creates-instance
  (let ((r (make-stub-resolver)))
    (assert-true (typep r 'stub-resolver))))

(deftest test-stub-resolver-is-a-resolver
  (let ((r (make-stub-resolver)))
    (assert-true (typep r 'innate.eval.resolver:resolver))))

;; resolve-reference

(deftest test-resolve-reference-found
  (let ((r (make-stub-resolver)))
    (stub-add-entity r "burg" '(:type "Burg" :state "Seed"))
    (let ((result (resolve-reference r "burg" nil)))
      (assert-nil (resistance-p result))
      (assert-equal '(:type "Burg" :state "Seed") (innate-result-value result)))))

(deftest test-resolve-reference-not-found
  (let ((r (make-stub-resolver)))
    (let ((result (resolve-reference r "missing" nil)))
      (assert-true (resistance-p result))
      (assert-true (search "missing" (resistance-message result))))))

;; RES-10: Qualifier chain resolution

(deftest test-resolve-reference-with-qualifier
  (let ((r (make-stub-resolver)))
    (stub-add-entity r "burg" '(:type "Burg" :state "Seed"))
    (let ((result (resolve-reference r "burg" '("state"))))
      (assert-nil (resistance-p result))
      (assert-equal "Seed" (innate-result-value result)))))

(deftest test-resolve-reference-qualifier-not-found
  (let ((r (make-stub-resolver)))
    (stub-add-entity r "burg" '(:type "Burg"))
    (let ((result (resolve-reference r "burg" '("missing-prop"))))
      (assert-true (resistance-p result))
      (assert-true (search "missing-prop" (resistance-message result))))))

(deftest test-resolve-reference-qualifier-case-insensitive
  (let ((r (make-stub-resolver)))
    (stub-add-entity r "burg" '(:type "Burg"))
    (let ((result (resolve-reference r "burg" '("TYPE"))))
      (assert-nil (resistance-p result))
      (assert-equal "Burg" (innate-result-value result)))))

;; resolve-search

(deftest test-resolve-search-matches
  (let ((r (make-stub-resolver)))
    (stub-add-entity r "burg" '(:type "Burg" :state "Seed"))
    (stub-add-entity r "sylvia" '(:type "Agent" :state "Active"))
    (let ((result (resolve-search r :filter '(("type" "Burg")))))
      (assert-nil (resistance-p result))
      (assert-equal 1 (length (innate-result-value result))))))

(deftest test-resolve-search-no-matches
  (let ((r (make-stub-resolver)))
    (stub-add-entity r "burg" '(:type "Burg"))
    (let ((result (resolve-search r :filter '(("type" "Agent")))))
      (assert-true (resistance-p result)))))

;; RES-09: Commission recording

(deftest test-deliver-commission-records
  (let ((r (make-stub-resolver)))
    (deliver-commission r "sylvia" "investigate")
    (assert-equal '(("sylvia" "investigate")) (stub-commissions r))))

(deftest test-deliver-commission-returns-result
  (let ((r (make-stub-resolver)))
    (let ((result (deliver-commission r "sylvia" "investigate")))
      (assert-nil (resistance-p result))
      (assert-equal :commission (innate-result-context result))
      (assert-equal t (innate-result-value result)))))

(deftest test-deliver-commission-preserves-order
  (let ((r (make-stub-resolver)))
    (deliver-commission r "sylvia" "first")
    (deliver-commission r "aria" "second")
    (deliver-commission r "sylvia" "third")
    (let ((comms (stub-commissions r)))
      (assert-equal 3 (length comms))
      (assert-equal '("sylvia" "first") (first comms))
      (assert-equal '("aria" "second") (second comms))
      (assert-equal '("sylvia" "third") (third comms)))))

;; resolve-wikilink

(deftest test-resolve-wikilink-found
  (let ((r (make-stub-resolver)))
    (stub-add-wikilink r "Burg" "The Burg entity page")
    (let ((result (resolve-wikilink r "Burg")))
      (assert-nil (resistance-p result))
      (assert-equal "The Burg entity page" (innate-result-value result)))))

(deftest test-resolve-wikilink-not-found
  (let ((r (make-stub-resolver)))
    (let ((result (resolve-wikilink r "Missing")))
      (assert-true (resistance-p result)))))

;; resolve-context

(deftest test-resolve-context-found
  (let ((r (make-stub-resolver)))
    (stub-add-context r "db" "get_count" 42)
    (let ((result (resolve-context r "db" "get_count" '("entry"))))
      (assert-nil (resistance-p result))
      (assert-equal 42 (innate-result-value result)))))

(deftest test-resolve-context-not-found
  (let ((r (make-stub-resolver)))
    (let ((result (resolve-context r "db" "missing" nil)))
      (assert-true (resistance-p result)))))

;; load-bundle

(deftest test-load-bundle-found
  (let ((r (make-stub-resolver)))
    (let ((nodes (list (make-node :kind +node-prose+ :value "line 1"))))
      (stub-add-bundle r "pipeline" nodes)
      (let ((result (load-bundle r "pipeline")))
        (assert-equal 1 (length result))))))

(deftest test-load-bundle-not-found
  (let ((r (make-stub-resolver)))
    (assert-nil (load-bundle r "missing"))))

;; Fresh instance has empty stores

(deftest test-fresh-stub-has-no-commissions
  (let ((r (make-stub-resolver)))
    (assert-nil (stub-commissions r))))

;;; Milestone 10: Choreographic stub resolver tests (RES-11, RES-12)

(deftest test-deliver-verification-records
  (let ((r (make-stub-resolver)))
    (deliver-verification r "reviewer" "draft output")
    (let ((vfs (stub-verifications r)))
      (assert-equal 1 (length vfs))
      (assert-equal '("reviewer" "draft output") (first vfs)))))

(deftest test-deliver-verification-returns-result
  (let* ((r (make-stub-resolver))
         (result (deliver-verification r "reviewer" "draft")))
    (assert-nil (resistance-p result))
    (assert-equal t (innate-result-value result))))

(deftest test-schedule-at-records
  (let ((r (make-stub-resolver)))
    (schedule-at r "2026-04-15" "some-expression")
    (let ((scheds (stub-schedules r)))
      (assert-equal 1 (length scheds))
      (assert-equal '("2026-04-15" "some-expression") (first scheds)))))

(deftest test-schedule-at-returns-handle
  (let* ((r (make-stub-resolver))
         (result (schedule-at r "2026-04-15" "expr")))
    (assert-nil (resistance-p result))
    (assert-equal 1 (innate-result-value result) "handle is schedule count")))

(deftest test-stub-verifications-accessor
  (let ((r (make-stub-resolver)))
    (assert-nil (stub-verifications r) "fresh stub has no verifications")
    (deliver-verification r "a" "x")
    (deliver-verification r "b" "y")
    (assert-equal 2 (length (stub-verifications r)))))

(deftest test-stub-schedules-accessor
  (let ((r (make-stub-resolver)))
    (assert-nil (stub-schedules r) "fresh stub has no schedules")
    (schedule-at r "t1" "e1")
    (schedule-at r "t2" "e2")
    (assert-equal 2 (length (stub-schedules r)))))
