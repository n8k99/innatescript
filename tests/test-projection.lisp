;;;; test-projection.lisp — tests for choreographic projection (M12)

(in-package :innate.tests.projection)

;;; Single-agent projection

(deftest test-project-keeps-agents-commission
  "projection for agent 'a' keeps only a's commissions"
  (let* ((ast (parse (tokenize "(a){task1} (b){task2}")))
         (projected (project ast "a"))
         (children (node-children projected)))
    ;; Only (a){task1} should remain — agent + bundle
    (assert-equal 2 (length children) "two nodes: agent + bundle for a")
    (assert-equal :agent (node-kind (first children)) "first is agent")
    (assert-equal "a" (node-value (first children)) "agent is a")))

(deftest test-project-removes-irrelevant-agent
  "projection for agent 'c' removes all commissions for a and b"
  (let* ((ast (parse (tokenize "(a){task1} (b){task2}")))
         (projected (project ast "c"))
         (children (node-children projected)))
    (assert-equal 0 (length children) "no children for uninvolved agent")))

(deftest test-project-keeps-prose
  "projection preserves prose nodes"
  (let* ((ast (parse (tokenize (format nil "this is context~%(a){task}"))))
         (projected (project ast "a"))
         (children (node-children projected)))
    (assert-true (find :prose children :key #'node-kind) "prose preserved")))

;;; Concurrent projection

(deftest test-project-concurrent-filters-branches
  "projection inside concurrent keeps only relevant branches"
  (let* ((ast (parse (tokenize "concurrent [(a){x} (b){y}]")))
         (projected (project ast "a"))
         (children (node-children projected)))
    ;; Should have a concurrent with only a's branch
    (let ((conc (find :concurrent children :key #'node-kind)))
      (assert-true conc "concurrent node present")
      ;; Should contain agent a + bundle x only
      (let ((conc-children (node-children conc)))
        (assert-equal 2 (length conc-children) "only a's agent+bundle")
        (assert-equal "a" (node-value (first conc-children)) "agent is a")))))

(deftest test-project-concurrent-removes-if-no-relevant
  "projection removes concurrent if no branches match"
  (let* ((ast (parse (tokenize "concurrent [(a){x} (b){y}]")))
         (projected (project ast "c"))
         (children (node-children projected)))
    (assert-nil (find :concurrent children :key #'node-kind)
                "no concurrent for uninvolved agent")))

;;; Verification projection

(deftest test-project-verification-keeps-if-relevant
  "projection keeps verification if agent is involved"
  (let* ((ast (parse (tokenize "[\"draft\" <- (reviewer)]")))
         (projected (project ast "reviewer"))
         (children (node-children projected)))
    (assert-true (find :bracket children :key #'node-kind)
                 "bracket with verification preserved")))

;;; Named bracket projection

(deftest test-project-preserves-named-brackets
  "projection preserves named bracket nodes"
  (let* ((ast (parse (tokenize "pipeline[(a){step1}]")))
         (projected (project ast "a"))
         (children (node-children projected)))
    (let ((bracket (find :bracket children :key #'node-kind)))
      (assert-true bracket "named bracket preserved")
      (assert-equal "pipeline" (node-value bracket) "name preserved"))))

;;; Transparent composition — projection resolves @references

(deftest test-project-resolves-reference-into-named-bracket
  "projection resolves @pipeline and walks into its body for agent visibility"
  (let* ((ast (parse (tokenize (format nil "pipeline[(a){step1} (b){step2}]~%concurrent [@pipeline]"))))
         (projected (project ast "a")))
    ;; The concurrent block should contain a's operations from the resolved @pipeline
    (let ((conc (find :concurrent (node-children projected) :key #'node-kind)))
      (assert-true conc "concurrent present in projection for agent a"))))

(deftest test-project-reference-filters-irrelevant-agent
  "projection of @pipeline for uninvolved agent returns nothing from the reference"
  (let* ((ast (parse (tokenize (format nil "pipeline[(a){step1}]~%concurrent [@pipeline]"))))
         (projected (project ast "c"))
         (children (node-children projected)))
    (assert-nil (find :concurrent children :key #'node-kind)
                "no concurrent for uninvolved agent")))
