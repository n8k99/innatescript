;;;; smoke-test.lisp — verifies the test harness itself works
;;;; This test must pass before any other phase adds tests.

(in-package :innate.tests)

(deftest smoke-test-assert-equal-pass
  (assert-equal 42 42 "42 equals 42"))

(deftest smoke-test-assert-true
  ;; Verifies assert-true accepts non-nil values.
  (assert-true t "assert-true with t passes"))

(deftest smoke-test-assert-nil
  (assert-nil nil "nil is nil"))

(deftest smoke-test-assert-signals
  (assert-signals error (error "test error") "error signals error"))
