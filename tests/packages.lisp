;;;; tests/packages.lisp — package definitions for the Innate test suite

(defpackage :innate.tests
  (:use :cl)
  (:export
   #:deftest
   #:assert-equal
   #:assert-true
   #:assert-nil
   #:assert-signals
   #:run-tests
   #:*test-registry*))
