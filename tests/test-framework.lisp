;;;; test-framework.lisp — hand-rolled test harness for the Innate project
;;;; Pattern: Practical Common Lisp chapter 9 (deftest/check/combine-results)
;;;; No external dependencies. Zero Quicklisp.

(in-package :innate.tests)

;;; Global test registry — alist of (name . function)
(defvar *test-registry* '()
  "Alist of (test-name-string . test-function) registered by deftest.")

;;; Internals

(defvar *test-failures* 0
  "Count of assertion failures in the current run.")

(defvar *current-test* nil
  "Name of the currently executing test, for failure messages.")

(defun %report-failure (description expected actual)
  "Print a failure line and increment the failure counter."
  (incf *test-failures*)
  (format t "  FAIL ~a~%    expected: ~s~%    got:      ~s~%"
          description expected actual))

;;; Public macros

(defmacro assert-equal (expected actual &optional (description "assert-equal"))
  "Assert that ACTUAL is EQUAL to EXPECTED."
  (let ((e (gensym "EXPECTED-"))
        (a (gensym "ACTUAL-")))
    `(let ((,e ,expected)
           (,a ,actual))
       (if (equal ,e ,a)
           t
           (%report-failure ,description ,e ,a)))))

(defmacro assert-true (form &optional (description "assert-true"))
  "Assert that FORM evaluates to a non-nil value."
  `(if ,form
       t
       (%report-failure ,description t nil)))

(defmacro assert-nil (form &optional (description "assert-nil"))
  "Assert that FORM evaluates to nil."
  `(if (null ,form)
       t
       (%report-failure ,description nil ,form)))

(defmacro assert-signals (condition-type form &optional (description "assert-signals"))
  "Assert that evaluating FORM signals a condition of CONDITION-TYPE."
  `(handler-case
       (progn ,form
              (%report-failure ,description ',condition-type :no-signal-raised))
     (,condition-type () t)))

(defmacro deftest (name &body body)
  "Define a named test. Registers it in *test-registry*.
   NAME is a symbol. BODY is a sequence of assertions.
   The test function prints its name before running."
  `(progn
     (defun ,name ()
       (let ((*current-test* ,(symbol-name name)))
         (format t "  ~a ... " ,(symbol-name name))
         (let ((*test-failures* 0))
           ,@body
           (if (zerop *test-failures*)
               (format t "PASS~%")
               (format t "FAIL (~a failure~:p)~%" *test-failures*))
           (zerop *test-failures*))))
     (pushnew (cons ,(symbol-name name) #',name) *test-registry*
              :key #'car :test #'string=)
     ',name))

(defun run-tests (&optional prefix)
  "Run all registered tests, optionally filtering by PREFIX string.
   Prints each test name as it runs. Returns T if all pass, NIL if any fail.
   PREFIX is a string — only tests whose names contain PREFIX are run."
  (let ((tests (if prefix
                   (remove-if-not (lambda (entry)
                                    (search prefix (car entry) :test #'char-equal))
                                  *test-registry*)
                   *test-registry*))
        (total 0)
        (passed 0))
    (dolist (entry tests)
      (incf total)
      (when (funcall (cdr entry))
        (incf passed)))
    (format t "~%Results: ~a/~a tests passed~%" passed total)
    (= passed total)))
