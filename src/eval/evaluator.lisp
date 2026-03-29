(in-package :innate.eval)

;;; collect-decrees — Pass 1: walk top-level children, store :decree nodes
(defun collect-decrees (children env)
  "Walk CHILDREN list. For each :decree node, store it in (eval-env-decrees env)
keyed by (node-value decree-node). Does not evaluate anything."
  (dolist (child children)
    (when (eq (node-kind child) :decree)
      (setf (gethash (node-value child) (eval-env-decrees env)) child))))

;;; eval-node — Pass 2: etypecase dispatch on (node-kind node)
(defun eval-node (node env)
  "Evaluate a single AST node. Dispatches on (node-kind node) via etypecase.
Returns the evaluation result value (not wrapped in innate-result for passthrough types)."
  (etypecase (node-kind node)
    ;; Passthrough types — return their value as-is
    ((eql :prose)      (node-value node))
    ((eql :heading)    (node-value node))
    ((eql :string-lit) (node-value node))
    ((eql :bare-word)  (node-value node))
    ((eql :emoji-slot) (node-value node))

    ;; Number literal — parse string to integer
    ((eql :number-lit) (parse-integer (node-value node)))

    ;; Decree — skip in pass 2 (already collected in pass 1)
    ((eql :decree) nil)

    ;; KV-pair — evaluate value child, return (key . value) cons
    ((eql :kv-pair)
     (let ((key (node-value node))
           (val-node (first (node-children node))))
       (cons key (if val-node (eval-node val-node env) nil))))

    ;; Combinator — return combinator value string
    ((eql :combinator) (node-value node))

    ;; Lens — evaluate lens children, return as list
    ((eql :lens)
     (mapcar (lambda (child) (eval-node child env))
             (node-children node)))

    ;; Modifier — return modifier value string
    ((eql :modifier) (node-value node))

    ;; Reference — resolve against decrees, then resolver (Plan 02)
    ((eql :reference)
     (signal 'innate-resistance
             :message (format nil "Reference evaluation not yet implemented: ~a" (node-value node))
             :source (or (node-value node) "unknown")))

    ;; Bracket — evaluate via resolve-context (Plan 02)
    ((eql :bracket)
     (signal 'innate-resistance
             :message (format nil "Bracket evaluation not yet implemented")
             :source "bracket"))

    ;; Phase 8 stubs — signal resistance with "not yet implemented"
    ((eql :agent)
     (signal 'innate-resistance
             :message "Agent commission evaluation not yet implemented"
             :source (or (node-value node) "agent")))
    ((eql :bundle)
     (signal 'innate-resistance
             :message "Bundle loading not yet implemented"
             :source (or (node-value node) "bundle")))
    ((eql :search)
     (signal 'innate-resistance
             :message "Search evaluation not yet implemented"
             :source "search"))
    ((eql :fulfillment)
     (signal 'innate-resistance
             :message "Fulfillment evaluation not yet implemented"
             :source "fulfillment"))
    ((eql :emission)
     (signal 'innate-resistance
             :message "Emission evaluation not yet implemented"
             :source "emission"))
    ((eql :wikilink)
     (signal 'innate-resistance
             :message "Wikilink evaluation not yet implemented"
             :source (or (node-value node) "wikilink")))

    ;; Program — should not be dispatched to eval-node directly
    ((eql :program)
     (error "BUG: :program node should not reach eval-node — use evaluate instead"))))

;;; evaluate — main entry point: two-pass evaluation
(defun evaluate (ast env)
  "Evaluate an AST (a :program node) in the given eval-env.
Pass 1: Collect all decree definitions into (eval-env-decrees env).
Pass 2: Evaluate each top-level child via eval-node, collecting results.
Returns a list of evaluation results in source order. Decree nodes produce no result."
  (let ((children (node-children ast)))
    ;; Pass 1: collect decrees
    (collect-decrees children env)
    ;; Pass 2: evaluate, skipping decree nodes
    (let ((results nil))
      (dolist (child children)
        (unless (eq (node-kind child) :decree)
          (let ((result (eval-node child env)))
            (push result results))))
      (nreverse results))))
