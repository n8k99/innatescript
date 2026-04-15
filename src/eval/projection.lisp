(in-package :innate.eval.projection)

;;; project — decompose a global choreography into a per-agent local slice
;;; Supports transparent composition: resolves @references against decree table
;;; and walks into named bracket bodies for full agent visibility.

(defvar *project-decrees* nil
  "Decree/named-bracket table for reference resolution during projection.")

(defun agent-relevant-p (node agent-name)
  "Return T if NODE contains operations relevant to AGENT-NAME."
  (let ((kind (node-kind node)))
    (cond
      ;; Agent node: relevant if it names this agent
      ((eq kind :agent)
       (string= (node-value node) agent-name))
      ;; Reference: resolve and check if the referenced body is relevant
      ((eq kind :reference)
       (when *project-decrees*
         (let ((entry (gethash (node-value node) *project-decrees*)))
           (when (and entry (eq (node-kind entry) :bracket))
             (some (lambda (child) (agent-relevant-p child agent-name))
                   (node-children entry))))))
      ;; Verification: relevant if agent is on either side
      ((eq kind :verification)
       (some (lambda (child) (agent-relevant-p child agent-name))
             (node-children node)))
      ;; Concurrent, sync, until, at: relevant if any child is relevant
      ((member kind '(:concurrent :sync :until :at))
       (some (lambda (child) (agent-relevant-p child agent-name))
             (node-children node)))
      ;; Bracket: relevant if any child is relevant
      ((eq kind :bracket)
       (some (lambda (child) (agent-relevant-p child agent-name))
             (node-children node)))
      ;; All other nodes: not agent-specific
      (t nil))))

(defun project-node (node agent-name)
  "Project NODE for AGENT-NAME. Returns a projected node, or nil if not relevant."
  (let ((kind (node-kind node)))
    (cond
      ;; Agent: keep if it names this agent
      ((eq kind :agent)
       (when (string= (node-value node) agent-name)
         node))
      ;; Bundle: always keep (adjacency with agent determined at list level)
      ((eq kind :bundle)
       node)
      ;; Reference: resolve against decree table, project the referenced body
      ((eq kind :reference)
       (if *project-decrees*
           (let ((entry (gethash (node-value node) *project-decrees*)))
             (if (and entry (eq (node-kind entry) :bracket))
                 ;; Inline the named bracket's children for projection
                 (let ((projected (project-children (node-children entry) agent-name)))
                   (when projected
                     ;; Return a bracket wrapping the projected children
                     (make-node :kind :bracket
                                :value (node-value entry)
                                :children projected)))
                 ;; Not a named bracket or not found — keep as-is
                 node))
           node))
      ;; Prose, heading: always keep (structural/documentary)
      ((member kind '(:prose :heading))
       node)
      ;; Verification: keep if agent is involved
      ((eq kind :verification)
       (when (agent-relevant-p node agent-name)
         (let ((projected-children
                 (mapcar (lambda (c) (or (project-node c agent-name) c))
                         (node-children node))))
           (make-node :kind :verification
                      :children projected-children
                      :props (node-props node)))))
      ;; Concurrent: filter to only relevant branches
      ((eq kind :concurrent)
       (let ((projected (project-children (node-children node) agent-name)))
         (when projected
           (make-node :kind :concurrent
                      :children projected
                      :props (node-props node)))))
      ;; Sync, until, at: keep if any child is relevant
      ((member kind '(:sync :until :at))
       (when (agent-relevant-p node agent-name)
         (let ((projected (project-children (node-children node) agent-name)))
           (make-node :kind kind
                      :value (node-value node)
                      :children (or projected (node-children node))
                      :props (node-props node)))))
      ;; Bracket: project children
      ((eq kind :bracket)
       (let ((projected (project-children (node-children node) agent-name)))
         (when projected
           (make-node :kind :bracket
                      :value (node-value node)
                      :children projected
                      :props (node-props node)))))
      ;; Fulfillment, emission, etc.: keep as-is if in relevant context
      (t node))))

(defun project-children (children agent-name)
  "Project a list of CHILDREN for AGENT-NAME, preserving agent-bundle adjacency.
Returns a list of projected nodes (nil entries removed)."
  (let ((result nil)
        (remaining children))
    (loop while remaining
          do (let* ((child (first remaining))
                    (next (second remaining)))
               (cond
                 ;; Agent-bundle adjacency: keep both if agent matches
                 ((and (eq (node-kind child) :agent)
                       next
                       (eq (node-kind next) :bundle))
                  (when (string= (node-value child) agent-name)
                    (push child result)
                    (push next result))
                  (setf remaining (cddr remaining)))
                 ;; Join markers: always keep (structural)
                 ((and (eq (node-kind child) :bare-word)
                       (getf (node-props child) :join-marker))
                  (push child result)
                  (setf remaining (rest remaining)))
                 ;; All other nodes: project individually
                 (t
                  (let ((projected (project-node child agent-name)))
                    (when projected
                      (push projected result)))
                  (setf remaining (rest remaining))))))
    (nreverse result)))

(defun project (ast agent-name &optional decrees)
  "Project a program AST for AGENT-NAME.
Returns a new :program node containing only operations relevant to that agent.
If DECREES is provided (hash-table), @references are resolved against it —
enabling transparent composition through named brackets and loaded bundles.
Structural nodes (prose, headings) are preserved. Commission pairs (agent+bundle)
are kept only when the agent name matches. Concurrent blocks are filtered to
relevant branches only."
  (let ((*project-decrees* decrees))
    ;; If no decrees provided, build one from the AST's named brackets
    (unless *project-decrees*
      (setf *project-decrees* (make-hash-table :test 'equal))
      (dolist (child (node-children ast))
        (when (and (eq (node-kind child) :bracket)
                   (node-value child))
          (setf (gethash (node-value child) *project-decrees*) child))))
    (let* ((children (node-children ast))
           (projected (project-children children agent-name)))
      (make-node :kind :program
                 :children projected))))
