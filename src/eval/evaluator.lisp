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

    ;; Agent — standalone agent returns name; commission adjacency handled in evaluate loop
    ((eql :agent)
     (node-value node))
    ((eql :bundle)
     (let* ((name (node-value node))
            (nodes (load-bundle (eval-env-resolver env) name)))
       (if nodes
           ;; Evaluate returned AST nodes as sub-program, return last result (progn semantics)
           (let ((last-result nil))
             (dolist (n nodes)
               (setf last-result (eval-node n env)))
             last-result)
           ;; Bundle not found — signal resistance
           (signal 'innate-resistance
                   :message (format nil "Bundle not found: ~a" name)
                   :source (or name "bundle")))))
    ;; Search — evaluate children to extract search-type and terms, call resolve-search
    ((eql :search)
     (let* ((children (node-children node))
            (search-type (if children
                             (let ((first-child (first children)))
                               (if (eq (node-kind first-child) :kv-pair)
                                   (node-value first-child)
                                   (eval-node first-child env)))
                             "default"))
            (terms (mapcar (lambda (c) (eval-node c env)) children))
            (result (resolve-search (eval-env-resolver env) search-type terms)))
       (if (resistance-p result)
           (signal 'innate-resistance
                   :message (resistance-message result)
                   :source (resistance-source result))
           (innate-result-value result))))

    ;; Fulfillment — expr || fallback: try left, catch resistance, fire right
    ((eql :fulfillment)
     (let ((left (first (node-children node)))
           (right (second (node-children node))))
       (handler-case
           (eval-node left env)
         (innate-resistance ()
           (eval-node right env)))))
    ((eql :emission)
     (let ((children (node-children node)))
       (if (= (length children) 1)
           (eval-node (first children) env)
           (mapcar (lambda (child) (eval-node child env)) children))))
    ((eql :wikilink)
     (let* ((title (node-value node))
            (result (resolve-wikilink (eval-env-resolver env) title)))
       (if (resistance-p result)
           (signal 'innate-resistance
                   :message (resistance-message result)
                   :source (resistance-source result))
           (innate-result-value result))))

    ;; Program — should not be dispatched to eval-node directly
    ((eql :program)
     (error "BUG: :program node should not reach eval-node — use evaluate instead"))))

;;; evaluate — main entry point: two-pass evaluation
(defun evaluate (ast env)
  "Evaluate an AST (a :program node) in the given eval-env.
Pass 1: Collect all decree definitions into (eval-env-decrees env).
Pass 2: Evaluate each top-level child via eval-node, with commission adjacency
detection: when an :agent node is followed by a :bundle node, deliver a commission.
Returns a list of evaluation results in source order. Decree nodes produce no result."
  (let ((children (node-children ast)))
    ;; Pass 1: collect decrees
    (collect-decrees children env)
    ;; Pass 2: evaluate with index-based iteration for adjacency detection
    (let ((results nil)
          (len (length children))
          (i 0))
      (loop while (< i len)
            do (let ((child (nth i children)))
                 (cond
                   ;; Skip decree nodes
                   ((eq (node-kind child) :decree)
                    (incf i))
                   ;; Commission adjacency: :agent followed by :bundle
                   ((and (eq (node-kind child) :agent)
                         (< (1+ i) len)
                         (eq (node-kind (nth (1+ i) children)) :bundle))
                    (let* ((agent-name (node-value child))
                           (bundle-node (nth (1+ i) children))
                           (instruction (node-value bundle-node))
                           (result (deliver-commission
                                    (eval-env-resolver env)
                                    agent-name instruction)))
                      (push (innate-result-value result) results))
                    (incf i 2))  ; skip both agent and bundle
                   ;; Normal evaluation
                   (t
                    (let ((result (eval-node child env)))
                      (push result results))
                    (incf i)))))
      (nreverse results))))
