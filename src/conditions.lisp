;;;; conditions.lisp — Innate condition hierarchy
;;;; Three condition types: innate-condition (base), innate-parse-error (error subtype),
;;;; innate-resistance (condition subtype, NOT error — uses signal not error)

(in-package :innate.conditions)

;;; Base condition — parent of all Innate conditions
(define-condition innate-condition (condition)
  ()
  (:documentation "Base condition for all Innate interpreter conditions."))

;;; Parse error — syntax error, IS an error, unrecoverable
(define-condition innate-parse-error (innate-condition error)
  ((line :initarg :line :reader parse-error-line :initform 0
         :documentation "Line number where the parse error occurred.")
   (col  :initarg :col  :reader parse-error-col  :initform 0
         :documentation "Column number where the parse error occurred.")
   (text :initarg :text :reader parse-error-text :initform ""
         :documentation "The problematic input text."))
  (:report (lambda (condition stream)
             (format stream "Innate parse error at line ~a, col ~a: ~a"
                     (parse-error-line condition)
                     (parse-error-col condition)
                     (parse-error-text condition))))
  (:documentation "Signaled for unrecoverable syntax errors. Carries line and column numbers."))

;;; Resistance — resolution failure, NOT an error, uses signal not error
(define-condition innate-resistance (innate-condition condition)
  ((resistance-condition-message :initarg :message
                                  :reader resistance-condition-message
                                  :initform ""
                                  :documentation "Human-readable description of what failed to resolve.")
   (resistance-condition-source  :initarg :source
                                  :reader resistance-condition-source
                                  :initform ""
                                  :documentation "The expression string that could not be resolved."))
  (:report (lambda (condition stream)
             (format stream "Innate resistance: ~a (from: ~a)"
                     (resistance-condition-message condition)
                     (resistance-condition-source condition))))
  (:documentation "Signaled (not errored) when a reference cannot be resolved and no fulfillment exists.
Use (signal ...) not (error ...) — resistance is not unrecoverable."))
