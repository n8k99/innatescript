;;;; test-conditions.lisp — tests for the Innate condition hierarchy
;;;; Tests ERR-01 (innate-resistance), ERR-02 (innate-parse-error slots), ERR-03 (signal not error)

(in-package :innate.tests.conditions)

(deftest test-parse-error-has-line-slot
  (let ((e (make-condition 'innate-parse-error :line 5 :col 12 :text "unexpected @")))
    (assert-equal 5 (parse-error-line e) "parse-error-line returns :line initarg")))

(deftest test-parse-error-has-col-slot
  (let ((e (make-condition 'innate-parse-error :line 5 :col 12 :text "unexpected @")))
    (assert-equal 12 (parse-error-col e) "parse-error-col returns :col initarg")))

(deftest test-parse-error-is-error-subtype
  (assert-true (typep (make-condition 'innate-parse-error :line 0 :col 0 :text "")
                      'error)
               "innate-parse-error is a subtype of cl:error"))

(deftest test-resistance-has-message-slot
  (let ((r (make-condition 'innate-resistance :message "not found" :source "@ref")))
    (assert-equal "not found" (resistance-condition-message r)
                  "resistance-condition-message returns :message initarg")))

(deftest test-resistance-is-not-error-subtype
  (assert-nil (typep (make-condition 'innate-resistance :message "" :source "")
                     'error)
              "innate-resistance is NOT a subtype of cl:error"))

(deftest test-resistance-signal-caught-by-handler-case
  (let ((caught-message
          (handler-case
              (progn
                (signal 'innate-resistance :message "unresolved" :source "@thing")
                "not-caught")
            (innate-resistance (c) (resistance-condition-message c)))))
    (assert-equal "unresolved" caught-message
                  "handler-case catches innate-resistance signaled with (signal ...)")))
