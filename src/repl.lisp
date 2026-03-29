;;;; src/repl.lisp — Innate interactive REPL and file runner
;;;; Phase 09: Connects tokenizer -> parser -> evaluator in an interactive loop.
;;;;
;;;; Exported: repl, run-file

(in-package :innate.repl)

;;; -----------------------------------------------------------------------
;;; run-file — batch evaluation of a .dpn file
;;; -----------------------------------------------------------------------

(defun run-file (path env)
  "Read the file at PATH into a string, tokenize, parse, and evaluate it in ENV.
Returns a list of evaluation results in source order.
Signals innate-parse-error on syntax errors; other conditions propagate normally."
  (let ((source
         (with-open-file (stream path :direction :input :external-format :utf-8)
           (let ((contents (make-string (file-length stream))))
             (read-sequence contents stream)
             contents))))
    (evaluate (parse (tokenize source)) env)))

;;; -----------------------------------------------------------------------
;;; print-result — format a single evaluation result to *standard-output*
;;; -----------------------------------------------------------------------

(defun print-result (result)
  "Print a single evaluation result. Handles resistance structs, innate-result
values, strings, and arbitrary Lisp objects."
  (cond
    ;; Resistance struct — show commission queued message
    ((resistance-p result)
     (format t "= [resistance] ~a~%" (resistance-message result)))
    ;; Innate result — unwrap the value
    ((typep result 'structure-object)
     ;; innate-result is a defstruct; try to access its value slot gracefully
     (handler-case
         (format t "= ~a~%" (innate-result-value result))
       (error ()
         (format t "= ~S~%" result))))
    ;; Plain string
    ((stringp result)
     (format t "= ~a~%" result))
    ;; Number
    ((numberp result)
     (format t "= ~a~%" result))
    ;; NIL (e.g. from decree nodes returning nil — skip silently)
    ((null result)
     nil)
    ;; Cons or list
    ((listp result)
     (format t "= ~S~%" result))
    ;; Fallback
    (t
     (format t "= ~S~%" result))))

;;; -----------------------------------------------------------------------
;;; repl — interactive read-eval-print loop
;;; -----------------------------------------------------------------------

(defun repl (&optional env)
  "Start an interactive Innate REPL.
If ENV is nil, creates a fresh eval-env with a stub resolver.
The same ENV persists across all input lines so decrees accumulate.
Exits on EOF, (quit), (exit), or :quit."
  (let ((env (or env (make-eval-env :resolver (make-stub-resolver)))))
    (format t "Innate v0.1.0~%")
    (loop
      ;; Print prompt
      (format t "innate> ")
      (finish-output)
      ;; Read a line — on EOF, return cleanly
      (multiple-value-bind (line eof-p)
          (handler-case (read-line *standard-input* nil nil)
            (error (e)
              (declare (ignore e))
              (values nil t)))
        (when eof-p
          (format t "~%")
          (return))
        ;; Quit commands
        (when (or (string= line "(quit)")
                  (string= line "(exit)")
                  (string= line ":quit"))
          (return))
        ;; Skip empty or whitespace-only lines — only eval non-empty input
        (unless (zerop (length (string-trim " " line)))
          ;; Eval pipeline with error handling
          (handler-case
              (let ((results (evaluate (parse (tokenize line)) env)))
                (dolist (result results)
                  (print-result result)))
            (innate-parse-error (e)
              (format t "Parse error at line ~D, col ~D: ~A~%"
                      (parse-error-line e)
                      (parse-error-col e)
                      e))
            (innate-resistance (e)
              (format t "[commission queued] ~A~%"
                      (resistance-condition-source e)))
            (error (e)
              (format t "Error: ~A~%" e))))))))
