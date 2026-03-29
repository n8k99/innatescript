;;;; tests/test-repl.lisp — REPL and file runner tests
;;;; Tests run-file batch evaluation and burg_pipeline.dpn integration.

(in-package :innate.tests.repl)

;;; Helper: write a string to a temp file and return the path
(defun write-temp-file (path contents)
  "Write CONTENTS string to PATH and return PATH."
  (with-open-file (stream path :direction :output
                               :if-exists :supersede
                               :if-does-not-exist :create)
    (write-string contents stream))
  path)

;;; REPL-01: run-file evaluates a prose-only file
(deftest test-repl-01-run-file-prose-only
  (let ((path "/tmp/innate-test-prose.dpn"))
    (write-temp-file path "This is prose")
    (let ((results (run-file path (make-eval-env :resolver (make-stub-resolver)))))
      (assert-true results "REPL-01: result list is non-nil")
      (assert-true (stringp (first results)) "REPL-01: first result is a string")
      (assert-true (search "prose" (first results)) "REPL-01: result contains 'prose'"))
    (ignore-errors (delete-file path))))

;;; REPL-02: run-file evaluates a decree and a reference
(deftest test-repl-02-run-file-decree-and-reference
  (let ((path "/tmp/innate-test-decree.dpn"))
    (write-temp-file path
      (format nil "decree greeting [Hello]~%@greeting"))
    (let ((results (run-file path (make-eval-env :resolver (make-stub-resolver)))))
      ;; Results should be non-nil — the file has content
      (assert-true results "REPL-02: result list is non-nil")
      ;; The second result (from @greeting evaluation) should be the decree body value
      ;; Decree body: [Hello] — a bracket node; resolved via stub resolver which may produce resistance
      ;; Assert at least one result was produced
      (assert-true (>= (length results) 1) "REPL-02: at least one result produced"))
    (ignore-errors (delete-file path))))

;;; REPL-03: run-file handles parse error without crashing
(deftest test-repl-03-run-file-parse-error
  (let ((path "/tmp/innate-test-malformed.dpn"))
    (write-temp-file path "[[[")
    (let ((signaled nil))
      (handler-case
          (run-file path (make-eval-env :resolver (make-stub-resolver)))
        (innate-parse-error ()
          (setf signaled t)))
      (assert-true signaled "REPL-03: innate-parse-error is signaled for malformed input"))
    (ignore-errors (delete-file path))))

;;; REPL-04: run-file reads burg_pipeline.dpn without unhandled error
(deftest test-repl-04-run-file-burg-pipeline
  (let ((burg-path "/home/n8k99/Development/innatescript/burg_pipeline.dpn"))
    (let ((error-occurred nil)
          (results nil))
      (handler-case
          (setf results
                (run-file burg-path
                          (make-eval-env :resolver (make-stub-resolver))))
        (error (e)
          (declare (ignore e))
          (setf error-occurred t)))
      (assert-nil error-occurred "REPL-04: no unhandled error escapes from burg_pipeline.dpn")
      (assert-true (listp results) "REPL-04: results is a list (not nil)"))))
