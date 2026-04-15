;;;; test-default-resolver.lisp — tests for the file-based default resolver

(in-package :innate.tests.default-resolver)

;;; Helper: create temp directory with test files

(defun %make-temp-dir (name)
  (let ((dir (merge-pathnames (format nil "innate-test-~a/" name) "/tmp/")))
    (ensure-directories-exist dir)
    dir))

(defun %write-file (dir filename content)
  (let ((path (merge-pathnames filename dir)))
    (with-open-file (s path :direction :output :if-exists :supersede :if-does-not-exist :create)
      (write-string content s))
    path))

(defun %cleanup-dir (dir)
  (when (probe-file dir)
    (dolist (f (directory (merge-pathnames "*.*" dir)))
      (delete-file f))
    (ignore-errors (delete-file dir))))

;;; Constructor

(deftest test-make-default-resolver
  (let ((r (make-default-resolver :search-path '("/tmp/") :vault-path "/tmp/")))
    (assert-true (typep r 'default-resolver) "creates default-resolver instance")))

;;; load-bundle

(deftest test-load-bundle-finds-dpn
  "load-bundle finds .dpn files in search path"
  (let ((dir (%make-temp-dir "bundle-dpn")))
    (%write-file dir "greet.dpn" "\"hello from bundle\"")
    (let* ((r (make-default-resolver :search-path (list dir)))
           (nodes (load-bundle r "greet")))
      (assert-true (consp nodes) "bundle returns nodes")
      (assert-equal :string-lit (node-kind (first nodes)) "first node is string"))
    (%cleanup-dir dir)))

(deftest test-load-bundle-finds-md
  "load-bundle finds .md files when .dpn not present"
  (let ((dir (%make-temp-dir "bundle-md")))
    (%write-file dir "greet.md" "\"hello from md\"")
    (let* ((r (make-default-resolver :search-path (list dir)))
           (nodes (load-bundle r "greet")))
      (assert-true (consp nodes) "md bundle returns nodes"))
    (%cleanup-dir dir)))

(deftest test-load-bundle-dpn-before-md
  "load-bundle prefers .dpn over .md"
  (let ((dir (%make-temp-dir "bundle-prefer")))
    (%write-file dir "greet.dpn" "\"from dpn\"")
    (%write-file dir "greet.md" "\"from md\"")
    (let* ((r (make-default-resolver :search-path (list dir)))
           (nodes (load-bundle r "greet")))
      (assert-equal "from dpn" (node-value (first nodes)) "dpn wins over md"))
    (%cleanup-dir dir)))

(deftest test-load-bundle-not-found
  "load-bundle returns nil when file not in any search path"
  (let ((r (make-default-resolver :search-path '("/tmp/nonexistent/"))))
    (assert-nil (load-bundle r "missing") "missing bundle returns nil")))

;;; resolve-wikilink

(deftest test-resolve-wikilink-found
  "resolve-wikilink reads Title.md from vault path"
  (let ((dir (%make-temp-dir "wiki")))
    (%write-file dir "Burg.md" "The Burg entry")
    (let* ((r (make-default-resolver :vault-path dir))
           (result (resolve-wikilink r "Burg")))
      (assert-true (not (resistance-p result)) "wikilink resolved")
      (assert-true (search "Burg entry" (innate-result-value result)) "content matches"))
    (%cleanup-dir dir)))

(deftest test-resolve-wikilink-not-found
  "resolve-wikilink returns resistance when file missing"
  (let* ((r (make-default-resolver :vault-path "/tmp/"))
         (result (resolve-wikilink r "Nonexistent")))
    (assert-true (resistance-p result) "missing wikilink returns resistance")))

;;; deliver-commission

(deftest test-default-commission-records
  "deliver-commission records to in-memory log"
  (let ((r (make-default-resolver)))
    (deliver-commission r "sylvia" "investigate")
    (assert-equal 1 (length (default-commissions r)) "one commission recorded")
    (assert-equal "sylvia" (first (first (default-commissions r))) "agent name correct")))

;;; schedule-at

(deftest test-default-schedule-records
  "schedule-at records and returns handle"
  (let ((r (make-default-resolver)))
    (let ((result (schedule-at r "2026-04-15" "some-expr")))
      (assert-true (not (resistance-p result)) "schedule succeeds")
      (assert-equal 1 (innate-result-value result) "handle is 1")
      (assert-equal 1 (length (default-schedules r)) "one schedule recorded"))))

;;; deliver-verification

(deftest test-default-verification-passthrough
  "deliver-verification returns prior output as corrections"
  (let ((r (make-default-resolver)))
    (let ((result (deliver-verification r "reviewer" "draft text")))
      (assert-true (not (resistance-p result)) "verification succeeds")
      (assert-equal "draft text" (innate-result-value result) "prior output passed through"))))
