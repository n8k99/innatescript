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

(defun capture-repl-output (input env)
  "Run REPL with INPUT string and capture stdout as a string."
  (with-input-from-string (*standard-input* input)
    (with-output-to-string (*standard-output*)
      (repl env))))

;;; REPL-01: run-file evaluates a prose-only file
(deftest test-repl-01-run-file-prose-only
  (let ((path "/tmp/innate-test-prose.dpn"))
    (write-temp-file path "This is prose")
    (let ((results (run-file path (make-eval-env :resolver (make-stub-resolver)))))
      (assert-true results "REPL-01: result list is non-nil")
      (assert-true (stringp (first results)) "REPL-01: first result is a string")
      (assert-true (search "prose" (first results)) "REPL-01: result contains 'prose'"))
    (ignore-errors (delete-file path))))

;;; REPL-02: run-file evaluates a named bracket and a reference
(deftest test-repl-02-run-file-named-bracket-and-reference
  (let ((path "/tmp/innate-test-named-bracket.dpn"))
    (write-temp-file path
      (format nil "greeting[Hello]~%@greeting"))
    (let ((results (run-file path (make-eval-env :resolver (make-stub-resolver)))))
      ;; Results should be non-nil — the file has content
      (assert-true results "REPL-02: result list is non-nil")
      ;; The named bracket greeting[Hello] is hoisted; @greeting resolves to its body
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

;;; REPL-05: unresolved reference prints resistance, not commission text
(deftest test-repl-05-resistance-output-is-accurate
  (let* ((env (make-eval-env :resolver (make-stub-resolver)))
         (output (capture-repl-output "@missing
(quit)
" env)))
    (assert-true (search "[resistance]" output) "REPL-05: output labels resistance")
    (assert-true (search "Entity not found: missing" output) "REPL-05: output includes actual resistance message")
    (assert-true (search "from: missing" output) "REPL-05: output includes resistance source")
    (assert-nil (search "[commission queued]" output) "REPL-05: output no longer mislabels resistance as commission")))

;;; REPL-06: successful commission stays on the normal result path
(deftest test-repl-06-commission-does-not-print-resistance
  (let* ((env (make-eval-env :resolver (make-stub-resolver)))
         (output (capture-repl-output "(sylvia){investigate}
(quit)
" env)))
    (assert-true (search "= T" output) "REPL-06: commission success prints normal result")
    (assert-nil (search "[resistance]" output) "REPL-06: commission success is not printed as resistance")))

;;; Milestone 12: Choreographic pipeline integration test

(deftest test-repl-07-run-file-choreographic-pipeline
  "REPL-07: choreographic_pipeline.dpn evaluates without unhandled errors"
  (let ((env (make-eval-env :resolver (make-stub-resolver))))
    ;; run-file should not signal any unhandled error
    (handler-case
        (progn
          (run-file "choreographic_pipeline.dpn" env)
          (assert-true t "REPL-07: no unhandled error from choreographic_pipeline.dpn"))
      (error (e)
        (assert-true nil (format nil "REPL-07: unexpected error: ~a" e))))))

;;; Milestone 13: .md extension support

(deftest test-repl-08-run-file-md-extension
  "REPL-08: .md files evaluate identically to .dpn files"
  (let ((dpn-path "/tmp/innate-test-ext.dpn")
        (md-path "/tmp/innate-test-ext.md")
        (content "\"hello from markdown\""))
    (write-temp-file dpn-path content)
    (write-temp-file md-path content)
    (let* ((env1 (make-eval-env :resolver (make-stub-resolver)))
           (env2 (make-eval-env :resolver (make-stub-resolver)))
           (dpn-results (run-file dpn-path env1))
           (md-results (run-file md-path env2)))
      (assert-equal (length dpn-results) (length md-results) "REPL-08: same result count")
      (assert-equal (first dpn-results) (first md-results) "REPL-08: same result value"))
    (ignore-errors (delete-file dpn-path))
    (ignore-errors (delete-file md-path))))
