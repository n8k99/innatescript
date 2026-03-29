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

    ;; Reference — resolve against decrees first, then resolver (EVL-02)
    ((eql :reference)
     (let* ((name (node-value node))
            (decree (gethash name (eval-env-decrees env))))
       (if decree
           ;; Decree found — evaluate first child of decree body
           (let ((body (node-children decree)))
             (if body
                 (eval-node (first body) env)
                 nil))
           ;; No decree — fall through to resolver
           (let* ((qualifiers (getf (node-props node) :qualifiers))
                  (result (resolve-reference (eval-env-resolver env) name qualifiers)))
             (if (resistance-p result)
                 (signal 'innate-resistance
                         :message (resistance-message result)
                         :source (resistance-source result))
                 (innate-result-value result))))))

    ;; Bracket — evaluate via resolve-context (EVL-03)
    ((eql :bracket)
     (let ((children (node-children node)))
       (if (null children)
           nil
           ;; Extract context, verb, args from nested bracket structure
           (let* ((first-child (first children))
                  (rest-children (rest children)))
             (if (and (eq (node-kind first-child) :bracket)
                      (null rest-children))
                 ;; Single nested bracket child — unwrap one level
                 (eval-node first-child env)
                 ;; Multiple children or mixed: extract context/verb/args
                 (let ((context nil)
                       (verb nil)
                       (args nil))
                   (cond
                     ;; Pattern: [context[verb[args]]]
                     ;; Children: (bare-word "context", bracket (bare-word "verb", ...))
                     ((and (>= (length children) 2)
                           (eq (node-kind first-child) :bare-word)
                           (eq (node-kind (second children)) :bracket))
                      (setf context (node-value first-child))
                      (let ((inner (node-children (second children))))
                        (when inner
                          (setf verb (if (eq (node-kind (first inner)) :bare-word)
                                         (node-value (first inner))
                                         (eval-node (first inner) env)))
                          (setf args (mapcar (lambda (a) (eval-node a env))
                                             (rest inner))))))
                     ;; Flat bracket with bare-word children: treat first as context
                     ((eq (node-kind first-child) :bare-word)
                      (setf context (node-value first-child))
                      (when rest-children
                        (setf verb (if (eq (node-kind (first rest-children)) :bare-word)
                                       (node-value (first rest-children))
                                       (eval-node (first rest-children) env)))
                        (setf args (mapcar (lambda (a) (eval-node a env))
                                           (rest rest-children)))))
                     ;; KV-pair children (body content) — evaluate each
                     (t
                      (setf args (mapcar (lambda (c) (eval-node c env)) children))))
                   ;; Call resolve-context
                   (let ((result (resolve-context (eval-env-resolver env)
                                                  context verb args)))
                     (if (resistance-p result)
                         (signal 'innate-resistance
                                 :message (resistance-message result)
                                 :source (resistance-source result))
                         (innate-result-value result)))))))))

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
