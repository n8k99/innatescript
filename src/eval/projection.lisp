(in-package :innate.eval.projection)

;;; project — decompose a global choreography into a per-agent local slice

(defun agent-relevant-p (node agent-name)
  "Return T if NODE contains operations relevant to AGENT-NAME."
  (let ((kind (node-kind node)))
    (cond
      ;; Agent node: relevant if it names this agent
      ((eq kind :agent)
       (string= (node-value node) agent-name))
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
      ;; Bundle following an agent: check the preceding context (handled at list level)
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
      ;; Prose, heading, decree: always keep (structural/documentary)
      ((member kind '(:prose :heading :decree))
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
      ;; Fulfillment, emission, reference, etc.: keep as-is if in relevant context
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

(defun project (ast agent-name)
  "Project a program AST for AGENT-NAME.
Returns a new :program node containing only operations relevant to that agent.
Structural nodes (prose, headings) are preserved. Commission pairs (agent+bundle)
are kept only when the agent name matches. Concurrent blocks are filtered to
relevant branches only."
  (let* ((children (node-children ast))
         (projected (project-children children agent-name)))
    (make-node :kind :program
               :children projected)))
