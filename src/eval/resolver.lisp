(in-package :innate.eval.resolver)

;;; Base resolver class — empty, exists only as dispatch target
(defclass resolver ()
  ()
  (:documentation "Base resolver protocol class. Concrete resolvers subclass this
and specialize the generic functions. Has no slots — concrete resolvers add their own state."))

;;; Generic function protocol

(defgeneric resolve-reference (resolver name qualifiers)
  (:documentation "Resolve a @ reference by name with optional qualifier chain.
RESOLVER — a resolver instance
NAME — string, the reference name (e.g. \"burg\" from @burg)
QUALIFIERS — list of strings, colon-separated qualifiers (e.g. (\"type\" \"state\") from @burg:type:state)
Returns: innate-result on success, resistance struct on failure.
The evaluator decides whether to signal innate-resistance based on fulfillment context."))

(defgeneric resolve-search (resolver search-type terms)
  (:documentation "Resolve a ![] search directive.
RESOLVER — a resolver instance
SEARCH-TYPE — keyword or string identifying the search kind
TERMS — list of search term nodes/values
Returns: innate-result on success, resistance struct on failure."))

(defgeneric deliver-commission (resolver agent-name instruction)
  (:documentation "Deliver a (agent){instruction} commission to an agent.
RESOLVER — a resolver instance
AGENT-NAME — string, the agent name
INSTRUCTION — string or AST node, the commission body
Returns: innate-result always. Commissions are fire-and-forget from the resolver's
perspective — the agent handles success/failure internally. Never returns resistance."))

(defgeneric resolve-wikilink (resolver title)
  (:documentation "Resolve a [[Title]] wikilink to its target.
RESOLVER — a resolver instance
TITLE — string, the wikilink title text
Returns: innate-result on success, resistance struct on failure."))

(defgeneric resolve-context (resolver context verb args)
  (:documentation "Resolve a [context[verb[args]]] bracket expression.
RESOLVER — a resolver instance
CONTEXT — string or node, the outermost bracket context
VERB — string or node, the verb/action
ARGS — list of nodes, the arguments
Returns: innate-result on success, resistance struct on failure."))

(defgeneric load-bundle (resolver name)
  (:documentation "Load a {bundle_name} bundle by name.
RESOLVER — a resolver instance
NAME — string, the bundle name
Returns: list of AST nodes (the bundle's parsed contents) on success, NIL if not found.
Does NOT return a resistance struct — NIL is sufficient for bundle-not-found."))

;;; Default methods — base resolver returns resistance for all except deliver-commission and load-bundle

(defmethod resolve-reference ((r resolver) name qualifiers)
  (declare (ignore qualifiers))
  (make-resistance :message (format nil "No resolver for reference: ~a" name)
                   :source name))

(defmethod resolve-search ((r resolver) search-type terms)
  (declare (ignore terms))
  (make-resistance :message (format nil "No resolver for search: ~a" search-type)
                   :source (format nil "~a" search-type)))

(defmethod deliver-commission ((r resolver) agent-name instruction)
  (declare (ignore instruction))
  (make-innate-result :value nil :context :commission))

(defmethod resolve-wikilink ((r resolver) title)
  (make-resistance :message (format nil "No resolver for wikilink: ~a" title)
                   :source title))

(defmethod resolve-context ((r resolver) context verb args)
  (declare (ignore verb args))
  (make-resistance :message (format nil "No resolver for context: ~a" context)
                   :source (format nil "~a" context)))

(defmethod load-bundle ((r resolver) name)
  (declare (ignore name))
  nil)

;;; Evaluation environment struct

(defstruct (eval-env (:constructor make-eval-env (&key resolver decrees bindings scope)))
  "Evaluation environment passed through all evaluator dispatch.
  resolver — the resolver instance (CLOS object)
  decrees  — hash-table mapping decree names (strings) to AST nodes
  bindings — hash-table mapping variable names to values (for future <- inward flow)
  scope    — keyword: :query, :scope, :render, :commission"
  (resolver nil)
  (decrees  (make-hash-table :test 'equal))
  (bindings (make-hash-table :test 'equal))
  (scope    :query))
