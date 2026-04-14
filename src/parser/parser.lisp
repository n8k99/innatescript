;;;; src/parser/parser.lisp — Innate recursive descent parser
;;;; Phase 04: Token stream → AST
;;;;
;;;; Entry point: (parse token-list) → :program node
;;;; Architecture: token-cursor struct for positional scan, hand-rolled recursive descent

(in-package :innate.parser)

;;; Bracket depth tracking (CHR-08: three-bracket limit)
(defvar *bracket-depth* 0
  "Current bracket nesting depth. Enforced at max 3 levels.")

;;; -----------------------------------------------------------------------
;;; Token cursor struct
;;; -----------------------------------------------------------------------

(defstruct (parse-cursor (:constructor make-parse-cursor (&key tokens (pos 0))))
  "Positional cursor over a flat token list.
   tokens — the token list from (tokenize source)
   pos    — current read position (zero-based index)"
  (tokens #())
  (pos    0   :type fixnum))

(defun cursor-peek (cursor)
  "Return the token at the current position without consuming it.
   Returns nil if at end of token list."
  (let ((pos (parse-cursor-pos cursor))
        (tokens (parse-cursor-tokens cursor)))
    (when (< pos (length tokens))
      (aref tokens pos))))

(defun cursor-peek-next (cursor)
  "Return the token at pos+1 without consuming it.
   Returns nil if pos+1 is past the end."
  (let ((next-pos (1+ (parse-cursor-pos cursor)))
        (tokens (parse-cursor-tokens cursor)))
    (when (< next-pos (length tokens))
      (aref tokens next-pos))))

(defun cursor-consume (cursor)
  "Return the token at the current position and advance pos by one.
   Returns nil (without error) when called at end of token list."
  (let ((tok (cursor-peek cursor)))
    (incf (parse-cursor-pos cursor))
    tok))

(defun cursor-expect (cursor expected-type)
  "Consume the current token if it matches EXPECTED-TYPE.
   Signals INNATE-PARSE-ERROR if the type does not match or if at EOF."
  (let ((tok (cursor-peek cursor)))
    (if tok
        (if (eq (token-type tok) expected-type)
            (cursor-consume cursor)
            (error 'innate-parse-error
                   :line (token-line tok)
                   :col  (token-col tok)
                   :text (format nil "Expected ~a, got ~a"
                                 expected-type (token-type tok))))
        ;; EOF
        (error 'innate-parse-error
               :line 0
               :col  0
               :text (format nil "Expected ~a, got end of input" expected-type)))))

;;; -----------------------------------------------------------------------
;;; Parse entry point
;;; -----------------------------------------------------------------------

(defun parse (tokens)
  "Parse a flat token list into a :program AST node.
   TOKENS is the list returned by (tokenize source).
   Returns a node of kind :program whose children are top-level statements."
  (let ((cursor (make-parse-cursor :tokens (coerce tokens 'vector))))
    (make-node :kind +node-program+
               :children (parse-statement-list cursor))))

;;; -----------------------------------------------------------------------
;;; Statement list
;;; -----------------------------------------------------------------------

(defun parse-statement-list (cursor)
  "Consume all remaining tokens, skipping :newline, collecting top-level statements.
   Returns a list of statement nodes in source order."
  (let ((stmts '()))
    (loop
      (let ((tok (cursor-peek cursor)))
        (cond
          ((null tok)
           (return))
          ((eq (token-type tok) :newline)
           (cursor-consume cursor))
          (t
           (let ((stmt (parse-statement cursor)))
             (when stmt
               (push stmt stmts)))))))
    (nreverse stmts)))

;;; -----------------------------------------------------------------------
;;; Statement dispatch
;;; -----------------------------------------------------------------------

(defun parse-statement (cursor)
  "Parse one top-level statement from the cursor.
   Dispatches based on the current token type.
   Prose, headings, and decrees bypass the precedence chain.
   Everything else routes through parse-fulfillment-expr (loosest binding)."
  (let ((tok (cursor-peek cursor)))
    (when tok
      (case (token-type tok)
        (:prose
         (cursor-consume cursor)
         (make-node :kind +node-prose+ :value (token-value tok)))
        (:hash
         (parse-heading cursor))
        (:decree
         (parse-decree cursor))
        (:concurrent
         (parse-concurrent-block cursor))
        (:sync
         (parse-sync-expr cursor))
        (:at-keyword
         (parse-at-expr cursor))
        (:until
         (parse-block-until cursor))
        ;; Named bracket at statement level: bare-word followed by [
        (:bare-word
         (let ((next (cursor-peek-next cursor)))
           (if (and next (eq (token-type next) :lbracket))
               (let* ((name-tok (cursor-consume cursor))
                      (name (token-value name-tok)))
                 (parse-bracket cursor name))
               (parse-fulfillment-expr cursor))))
        (:newline
         nil)
        (t
         (parse-fulfillment-expr cursor))))))

;;; -----------------------------------------------------------------------
;;; Fulfillment expression — loosest binding operator
;;; -----------------------------------------------------------------------

(defun parse-fulfillment-expr (cursor)
  "Parse a fulfillment expression: verification-expr (|| verification-expr)*.
   || is left-associative: a || b || c => (|| (|| a b) c).
   Returns a single node — either the left side or a :fulfillment node."
  (let ((left (parse-verification-expr cursor)))
    (loop
      (let ((tok (cursor-peek cursor)))
        (unless (and tok (eq (token-type tok) :pipe-pipe))
          (return left))
        (cursor-consume cursor) ; consume ||
        (let ((right (parse-verification-expr cursor)))
          (setf left (make-node :kind +node-fulfillment+
                                :children (list left right))))))
    left))

;;; -----------------------------------------------------------------------
;;; Verification expression — <- binds between || and ->
;;; -----------------------------------------------------------------------

(defun parse-verification-expr (cursor)
  "Parse a verification expression: emission-expr (<- emission-expr)*.
   <- is left-associative. Returns the left side or a :verification node."
  (let ((left (parse-emission-expr cursor)))
    ;; Check for postfix until after the expression
    (let ((tok (cursor-peek cursor)))
      (when (and tok (eq (token-type tok) :until))
        (setf left (parse-postfix-until cursor left))))
    (loop
      (let ((tok (cursor-peek cursor)))
        (unless (and tok (eq (token-type tok) :verification))
          (return left))
        (cursor-consume cursor) ; consume <-
        (let ((right (parse-emission-expr cursor)))
          (setf left (make-node :kind +node-verification+
                                :children (list left right))))))
    left))

;;; -----------------------------------------------------------------------
;;; Emission expression — binds tighter than ||, looser than expressions
;;; -----------------------------------------------------------------------

(defun parse-emission-expr (cursor)
  "Parse an emission expression.
   Two forms:
   1. Leading ->: -> value (, value)*  — emission at statement start
   2. Infix ->: expr -> value (, value)* (-> value (, value)*)*  — left-associative
   Returns a single node — either the left side or a :emission node."
  (let ((tok (cursor-peek cursor)))
    (if (and tok (eq (token-type tok) :arrow))
        ;; Leading -> form
        (progn
          (cursor-consume cursor) ; consume ->
          (let ((values (list (parse-expression cursor))))
            (loop
              (let ((t2 (cursor-peek cursor)))
                (unless (and t2 (eq (token-type t2) :comma))
                  (return))
                (cursor-consume cursor) ; consume comma
                (push (parse-expression cursor) values)))
            (make-node :kind +node-emission+
                       :children (nreverse values))))
        ;; Infix -> form: parse left side first
        (let ((left (parse-expression cursor)))
          (loop
            (let ((t2 (cursor-peek cursor)))
              (unless (and t2 (eq (token-type t2) :arrow))
                (return left))
              (cursor-consume cursor) ; consume ->
              (let ((values (list (parse-expression cursor))))
                (loop
                  (let ((t3 (cursor-peek cursor)))
                    (unless (and t3 (eq (token-type t3) :comma))
                      (return))
                    (cursor-consume cursor) ; consume comma
                    (push (parse-expression cursor) values)))
                (setf left (make-node :kind +node-emission+
                                      :children (cons left (nreverse values)))))))
          left))))

;;; -----------------------------------------------------------------------
;;; Expression dispatch
;;; -----------------------------------------------------------------------

(defun parse-expression (cursor)
  "Parse one expression from the cursor.
   Handles atoms, brackets, headings, references, agents, bundles/lenses, search, modifiers."
  (let ((tok (cursor-peek cursor)))
    (when tok
      (case (token-type tok)
        (:at
         (parse-reference cursor))
        (:lparen
         (parse-agent cursor))
        (:lbrace
         (parse-bundle-or-lens cursor))
        (:bang-bracket
         (parse-search cursor))
        (:slash
         (parse-modifier cursor))
        (:lbracket
         (parse-bracket cursor))
        (:hash
         (parse-heading cursor))
        (t
         (parse-atom cursor))))))

;;; -----------------------------------------------------------------------
;;; Atom dispatch
;;; -----------------------------------------------------------------------

(defun parse-atom (cursor)
  "Parse one atom token: bare-word, string, number, wikilink, or emoji-slot.
   Signals INNATE-PARSE-ERROR on any other token type."
  (let ((tok (cursor-peek cursor)))
    (if tok
        (case (token-type tok)
          (:bare-word
           (cursor-consume cursor)
           (make-node :kind +node-bare-word+ :value (token-value tok)))
          (:string
           (cursor-consume cursor)
           (make-node :kind +node-string-lit+ :value (token-value tok)))
          (:number
           (cursor-consume cursor)
           (make-node :kind +node-number-lit+ :value (token-value tok)))
          (:wikilink
           (cursor-consume cursor)
           (make-node :kind +node-wikilink+ :value (token-value tok)))
          (:emoji-slot
           (cursor-consume cursor)
           (make-node :kind +node-emoji-slot+ :value (token-value tok)))
          (t
           (error 'innate-parse-error
                  :line (token-line tok)
                  :col  (token-col tok)
                  :text (format nil "Unexpected token ~a" (token-type tok)))))
        (error 'innate-parse-error
               :line 0 :col 0
               :text "Unexpected end of input in atom"))))

;;; -----------------------------------------------------------------------
;;; Bracket parsing
;;; -----------------------------------------------------------------------

(defun parse-bracket (cursor &optional name)
  "Parse a bracket expression: [body].
   All tokens inside the brackets become children of the :bracket node.
   A lone bare-word followed by :rbracket or by other expressions is a child, not a name.
   Enforces three-bracket nesting limit (CHR-08).
   Returns a :bracket node with value NAME (nil if anonymous) and children from the body."
  (when (>= *bracket-depth* 3)
    (let ((tok (cursor-peek cursor)))
      (error 'innate-parse-error
             :line (if tok (token-line tok) 0)
             :col (if tok (token-col tok) 0)
             :text "Bracket nesting exceeds maximum depth of 3 — extract as a named document")))
  (cursor-expect cursor :lbracket)
  (let ((*bracket-depth* (1+ *bracket-depth*)))
    (let ((children (parse-bracket-body cursor)))
      (make-node :kind +node-bracket+ :value name :children children))))

(defun parse-bracket-body (cursor)
  "Parse the body of a bracket until RBRACKET or EOF.
   Returns a list of child nodes in source order.
   Signals INNATE-PARSE-ERROR on unterminated bracket (EOF before RBRACKET)."
  (let ((children '()))
    (loop
      (let ((tok (cursor-peek cursor)))
        (cond
          ;; EOF before closing bracket
          ((null tok)
           (error 'innate-parse-error
                  :line 0 :col 0
                  :text "Unterminated bracket expression"))
          ;; End of bracket body
          ((eq (token-type tok) :rbracket)
           (cursor-consume cursor)
           (return))
          ;; Skip newlines inside brackets
          ((eq (token-type tok) :newline)
           (cursor-consume cursor))
          ;; Inline prose
          ((eq (token-type tok) :prose)
           (cursor-consume cursor)
           (push (make-node :kind +node-prose+ :value (token-value tok)) children))
          ;; KV-pair: bare-word followed by colon
          ((and (eq (token-type tok) :bare-word)
                (let ((nn (cursor-peek-next cursor)))
                  (and nn (eq (token-type nn) :colon))))
           (push (parse-kv-pair cursor) children))
          ;; Named bracket: bare-word followed by [ (CHR-08 migration)
          ((and (eq (token-type tok) :bare-word)
                (let ((nn (cursor-peek-next cursor)))
                  (and nn (eq (token-type nn) :lbracket))))
           (let* ((name-tok (cursor-consume cursor))
                  (name (token-value name-tok)))
             (push (parse-bracket cursor name) children)))
          ;; Nested bracket
          ((eq (token-type tok) :lbracket)
           (push (parse-bracket cursor) children))
          ;; Heading inside bracket
          ((eq (token-type tok) :hash)
           (push (parse-heading cursor) children))
          ;; Choreographic keywords inside brackets
          ((eq (token-type tok) :concurrent)
           (push (parse-concurrent-block cursor) children))
          ((eq (token-type tok) :sync)
           (push (parse-sync-expr cursor) children))
          ((eq (token-type tok) :at-keyword)
           (push (parse-at-expr cursor) children))
          ((eq (token-type tok) :until)
           (push (parse-block-until cursor) children))
          ;; Everything else: call parse-fulfillment-expr (handles -> and || inside brackets)
          (t
           (let ((expr (parse-fulfillment-expr cursor)))
             (when expr
               (push expr children)))))))
    (nreverse children)))

;;; -----------------------------------------------------------------------
;;; KV-pair parsing
;;; -----------------------------------------------------------------------

(defun parse-kv-pair (cursor)
  "Parse a key-value pair: bare-word COLON expression.
   Returns a :kv-pair node with value = key-string, children = (value-node).
   Uses parse-fulfillment-expr to allow bracket expressions as values,
   e.g. description:[@Alaran:generative hard prompt]"
  (let* ((key-tok (cursor-consume cursor))   ; bare-word
         (key-name (token-value key-tok)))
    (cursor-expect cursor :colon)
    (let ((value-node (parse-fulfillment-expr cursor)))
      (make-node :kind +node-kv-pair+
                 :value key-name
                 :children (list value-node)))))

;;; -----------------------------------------------------------------------
;;; Heading parsing
;;; -----------------------------------------------------------------------

(defun parse-heading (cursor)
  "Parse a heading: HASH followed by bare-words (accumulated as heading text).
   Optionally followed by a bracket body which becomes the heading's children.
   Returns a :heading node with value = joined heading text."
  (cursor-expect cursor :hash)
  (let ((words '()))
    (loop
      (let ((tok (cursor-peek cursor)))
        (cond
          ((and tok (eq (token-type tok) :bare-word))
           (push (token-value (cursor-consume cursor)) words))
          (t
           (return)))))
    (let ((heading-text (format nil "~{~a~^ ~}" (nreverse words)))
          (bracket-children nil))
      ;; Check for optional bracket body after heading text
      (let ((tok (cursor-peek cursor)))
        (when (and tok (eq (token-type tok) :lbracket))
          (let ((bracket (parse-bracket cursor)))
            (setf bracket-children (node-children bracket)))))
      (make-node :kind +node-heading+
                 :value heading-text
                 :children bracket-children))))

;;; -----------------------------------------------------------------------
;;; Reference parsing — @name[:qualifier][+combinator][{lens}]
;;; -----------------------------------------------------------------------

(defun parse-reference (cursor)
  "Parse a reference expression: @name with optional qualifier, combinator, and lens postfix.
   Returns a :reference node."
  (cursor-expect cursor :at)
  (let* ((name-tok (cursor-expect cursor :bare-word))
         (name (token-value name-tok))
         (children '())
         (props '()))

    ;; Optional qualifier — if next token is :colon
    (let ((tok (cursor-peek cursor)))
      (when (and tok (eq (token-type tok) :colon))
        (cursor-consume cursor)  ; consume colon
        (let ((qtok (cursor-peek cursor)))
          (cond
            ;; String qualifier: @type:"[[Burg]]"
            ((and qtok (eq (token-type qtok) :string))
             (let* ((str-tok (cursor-consume cursor))
                    (qual-val (token-value str-tok)))
               (push (make-node :kind +node-string-lit+ :value qual-val) children)
               (setf props (list* :qualifiers (list qual-val) props))))
            ;; Bare-word qualifier: accumulate until terminator
            ((and qtok (eq (token-type qtok) :bare-word))
             (let ((words '()))
               (loop
                 (let ((t2 (cursor-peek cursor)))
                   (if (and t2 (eq (token-type t2) :bare-word))
                       (push (token-value (cursor-consume cursor)) words)
                       (return))))
               (let ((qual-val (format nil "~{~a~^ ~}" (nreverse words))))
                 (push (make-node :kind +node-string-lit+ :value qual-val) children)
                 (setf props (list* :qualifiers (list qual-val) props)))))))))

    ;; Optional combinator — if next token is :plus
    (let ((tok (cursor-peek cursor)))
      (when (and tok (eq (token-type tok) :plus))
        (cursor-consume cursor)  ; consume plus
        (let* ((comb-tok (cursor-expect cursor :bare-word))
               (comb-name (token-value comb-tok)))
          (push (make-node :kind +node-combinator+ :value comb-name) children)
          (setf props (list* :combinator comb-name props)))))

    ;; Optional lens — if next token is :lbrace
    (let ((tok (cursor-peek cursor)))
      (when (and tok (eq (token-type tok) :lbrace))
        (push (parse-lens cursor) children)))

    (make-node :kind +node-reference+
               :value name
               :children (if children (nreverse children) nil)
               :props (if props props nil))))

;;; -----------------------------------------------------------------------
;;; Agent parsing — (agent_name) or (expr ...) group
;;; -----------------------------------------------------------------------

(defun parse-agent (cursor)
  "Parse an agent address or paren group.
   (bare-word) → :agent node with value = agent name
   (anything else ...) → :bundle node with expression children (function-call-like syntax in search)
   Returns an :agent node or :bundle node."
  (cursor-expect cursor :lparen)
  (let ((tok (cursor-peek cursor))
        (next (cursor-peek-next cursor)))
    (if (and tok
             (eq (token-type tok) :bare-word)
             next
             (eq (token-type next) :rparen))
        ;; Simple (agent_name) form
        (let* ((name-tok (cursor-consume cursor))
               (name (token-value name-tok)))
          (cursor-expect cursor :rparen)
          (make-node :kind +node-agent+ :value name))
        ;; Complex paren group: (expr ...) — parse until rparen
        ;; Handles function-call-like syntax: image("emblem"+burg_name + png)
        ;; PLUS tokens between expressions become :combinator nodes
        (let ((exprs '()))
          (loop
            (let ((t2 (cursor-peek cursor)))
              (cond
                ((null t2)
                 (error 'innate-parse-error
                        :line 0 :col 0
                        :text "Unterminated paren expression"))
                ((eq (token-type t2) :rparen)
                 (cursor-consume cursor)
                 (return))
                ((eq (token-type t2) :newline)
                 (cursor-consume cursor))
                ;; PLUS between expressions in paren group: emit as combinator
                ((eq (token-type t2) :plus)
                 (let ((plus-tok (cursor-consume cursor)))
                   (push (make-node :kind +node-combinator+
                                    :value "+"
                                    :props (list :line (token-line plus-tok)
                                                 :col (token-col plus-tok)))
                         exprs)))
                (t
                 (let ((expr (parse-expression cursor)))
                   (when expr (push expr exprs)))))))
          (make-node :kind +node-bundle+ :children (nreverse exprs))))))

;;; -----------------------------------------------------------------------
;;; Bundle/Lens parsing — {name} or {key:value}
;;; -----------------------------------------------------------------------

(defun parse-bundle-or-lens (cursor)
  "Parse a brace expression: {name} or {key:value}.
   If the content is bare-word followed by colon, parse as :lens with kv-pairs.
   If the content is bare-word followed by rbrace, parse as :bundle.
   Returns :bundle or :lens node."
  (cursor-expect cursor :lbrace)
  (let ((tok (cursor-peek cursor))
        (next (cursor-peek-next cursor)))
    (cond
      ;; {key:value} — lens: bare-word followed by colon
      ((and tok
            (eq (token-type tok) :bare-word)
            next
            (eq (token-type next) :colon))
       ;; Parse kv-pairs until rbrace
       (let ((kv-pairs '()))
         (loop
           (let ((t2 (cursor-peek cursor)))
             (cond
               ((null t2)
                (error 'innate-parse-error
                       :line 0 :col 0
                       :text "Unterminated lens expression"))
               ((eq (token-type t2) :rbrace)
                (cursor-consume cursor)
                (return))
               ((eq (token-type t2) :newline)
                (cursor-consume cursor))
               ((and (eq (token-type t2) :bare-word)
                     (let ((t3 (cursor-peek-next cursor)))
                       (and t3 (eq (token-type t3) :colon))))
                (push (parse-kv-pair cursor) kv-pairs))
               (t
                (error 'innate-parse-error
                       :line (token-line t2) :col (token-col t2)
                       :text (format nil "Unexpected token in lens: ~a" (token-type t2)))))))
         (make-node :kind +node-lens+ :children (nreverse kv-pairs))))

      ;; {name} — bundle: bare-word followed by rbrace (or any bare-word-only content)
      ((and tok (eq (token-type tok) :bare-word))
       (let* ((name-tok (cursor-consume cursor))
              (name (token-value name-tok)))
         (cursor-expect cursor :rbrace)
         (make-node :kind +node-bundle+ :value name)))

      ;; Empty braces or other content — parse as bundle with expression children
      ;; e.g. {"fix"} or {42} or {} (empty)
      (t
       (let ((children '()))
         (loop
           (let ((t2 (cursor-peek cursor)))
             (cond
               ((null t2)
                (error 'innate-parse-error
                       :line 0 :col 0
                       :text "Unterminated brace expression"))
               ((eq (token-type t2) :rbrace)
                (cursor-consume cursor)
                (return))
               ((eq (token-type t2) :newline)
                (cursor-consume cursor))
               (t
                (let ((expr (parse-expression cursor)))
                  (when expr (push expr children)))))))
         (make-node :kind +node-bundle+ :children (nreverse children)))))))

(defun parse-lens (cursor)
  "Parse a lens expression: {key:value ...}.
   Expects opening brace to be the next token.
   Returns a :lens node with kv-pair children."
  (cursor-expect cursor :lbrace)
  (let ((kv-pairs '()))
    (loop
      (let ((tok (cursor-peek cursor)))
        (cond
          ((null tok)
           (error 'innate-parse-error
                  :line 0 :col 0
                  :text "Unterminated lens expression"))
          ((eq (token-type tok) :rbrace)
           (cursor-consume cursor)
           (return))
          ((eq (token-type tok) :newline)
           (cursor-consume cursor))
          ((and (eq (token-type tok) :bare-word)
                (let ((nn (cursor-peek-next cursor)))
                  (and nn (eq (token-type nn) :colon))))
           (push (parse-kv-pair cursor) kv-pairs))
          (t
           (error 'innate-parse-error
                  :line (token-line tok) :col (token-col tok)
                  :text (format nil "Unexpected token in lens: ~a" (token-type tok)))))))
    (make-node :kind +node-lens+ :children (nreverse kv-pairs))))

;;; -----------------------------------------------------------------------
;;; Search directive — ![expr]
;;; -----------------------------------------------------------------------

(defun parse-search (cursor)
  "Parse a search directive: ![expressions].
   Returns a :search node with expression children."
  (cursor-expect cursor :bang-bracket)
  (let ((exprs '()))
    (loop
      (let ((tok (cursor-peek cursor)))
        (cond
          ((null tok)
           (error 'innate-parse-error
                  :line 0 :col 0
                  :text "Unterminated search directive"))
          ((eq (token-type tok) :rbracket)
           (cursor-consume cursor)
           (return))
          ((eq (token-type tok) :newline)
           (cursor-consume cursor))
          (t
           (let ((expr (parse-expression cursor)))
             (when expr (push expr exprs)))))))
    (make-node :kind +node-search+ :children (nreverse exprs))))

;;; -----------------------------------------------------------------------
;;; Modifier parsing — /modifier
;;; -----------------------------------------------------------------------

(defun parse-modifier (cursor)
  "Parse a presentation modifier: /modifier-name.
   Returns a :modifier node with value = modifier name."
  (cursor-expect cursor :slash)
  (let* ((name-tok (cursor-expect cursor :bare-word))
         (name (token-value name-tok)))
    (make-node :kind +node-modifier+ :value name)))

;;; -----------------------------------------------------------------------
;;; Decree parsing — decree name [body]
;;; -----------------------------------------------------------------------

(defun parse-decree (cursor)
  "Parse a decree declaration: decree name or decree name [body].
   Returns a :decree node with value = name and optional children from body."
  (cursor-expect cursor :decree)
  (let* ((name-tok (cursor-expect cursor :bare-word))
         (name (token-value name-tok)))
    (let ((tok (cursor-peek cursor)))
      (if (and tok (eq (token-type tok) :lbracket))
          (let ((body-bracket (parse-bracket cursor)))
            (make-node :kind +node-decree+
                       :value name
                       :children (node-children body-bracket)))
          (make-node :kind +node-decree+ :value name)))))

;;; -----------------------------------------------------------------------
;;; Choreographic parsing (Milestone 10)
;;; -----------------------------------------------------------------------

(defun parse-concurrent-block (cursor)
  "Parse: concurrent [expr1 expr2 ...]. The bracket body may contain join markers.
   Returns a :concurrent node with expression children."
  (let ((tok (cursor-peek cursor)))
    (cursor-consume cursor) ; consume 'concurrent'
    (let ((next (cursor-peek cursor)))
      (unless (and next (eq (token-type next) :lbracket))
        (error 'innate-parse-error
               :line (if tok (token-line tok) 0)
               :col  (if tok (token-col tok) 0)
               :text "concurrent must be followed by ["))
      ;; Parse the bracket body, but recognize :join tokens as join markers
      (cursor-expect cursor :lbracket)
      (let ((children '()))
        (loop
          (let ((t2 (cursor-peek cursor)))
            (cond
              ((null t2)
               (error 'innate-parse-error
                      :line 0 :col 0
                      :text "Unterminated concurrent block"))
              ((eq (token-type t2) :rbracket)
               (cursor-consume cursor)
               (return))
              ((eq (token-type t2) :newline)
               (cursor-consume cursor))
              ((eq (token-type t2) :join)
               (cursor-consume cursor)
               (push (make-node :kind +node-bare-word+ :value "join"
                                :props '(:join-marker t))
                     children))
              (t
               (let ((expr (parse-fulfillment-expr cursor)))
                 (when expr (push expr children)))))))
        (make-node :kind +node-concurrent+ :children (nreverse children))))))

(defun parse-sync-expr (cursor)
  "Parse: sync expression. Dispatches expression alongside main flow.
   Returns a :sync node with the expression as sole child."
  (let ((tok (cursor-peek cursor)))
    (cursor-consume cursor) ; consume 'sync'
    (let ((next (cursor-peek cursor)))
      (unless next
        (error 'innate-parse-error
               :line (if tok (token-line tok) 0)
               :col  (if tok (token-col tok) 0)
               :text "sync must be followed by an expression"))
      (let ((expr (parse-fulfillment-expr cursor)))
        (make-node :kind +node-sync+ :children (list expr))))))

(defun parse-at-expr (cursor)
  "Parse: at time expression. Schedules expression at a time.
   Time is a wikilink (absolute date) or a number+bare-word duration.
   Returns an :at node with time in props and expression as child."
  (let ((at-tok (cursor-consume cursor))) ; consume 'at'
    (let ((next (cursor-peek cursor)))
      (unless next
        (error 'innate-parse-error
               :line (token-line at-tok) :col (token-col at-tok)
               :text "at must be followed by a time"))
      (let ((time-node
              (cond
                ;; Wikilink date: at [[2026-04-15]]
                ((eq (token-type next) :wikilink)
                 (cursor-consume cursor)
                 (make-node :kind +node-wikilink+ :value (token-value next)))
                ;; Duration: at 3 days
                ((eq (token-type next) :number)
                 (let* ((num-tok (cursor-consume cursor))
                        (unit-tok (cursor-peek cursor))
                        (unit (if (and unit-tok (eq (token-type unit-tok) :bare-word))
                                  (token-value (cursor-consume cursor))
                                  nil)))
                   (make-node :kind +node-number-lit+
                              :value (token-value num-tok)
                              :props (when unit (list :unit unit)))))
                (t
                 (error 'innate-parse-error
                        :line (token-line next) :col (token-col next)
                        :text (format nil "at expects a time (wikilink or duration), got ~a"
                                      (token-type next)))))))
        (let ((expr (parse-fulfillment-expr cursor)))
          (make-node :kind +node-at+
                     :children (list time-node expr)))))))

(defun parse-block-until (cursor)
  "Parse block until: until duration [body] (|| fulfillment)?.
   Returns an :until node with duration in props, body as children."
  (let ((until-tok (cursor-consume cursor))) ; consume 'until'
    (let ((next (cursor-peek cursor)))
      (unless next
        (error 'innate-parse-error
               :line (token-line until-tok) :col (token-col until-tok)
               :text "until must be followed by a duration"))
      ;; Parse duration: number + optional unit bare-word
      (let* ((num-tok (cursor-expect cursor :number))
             (unit-tok (cursor-peek cursor))
             (unit (if (and unit-tok (eq (token-type unit-tok) :bare-word))
                       (token-value (cursor-consume cursor))
                       nil))
             (duration-props (list :duration (token-value num-tok)
                                   :unit unit)))
        ;; Body must be a bracket
        (let ((body-tok (cursor-peek cursor)))
          (unless (and body-tok (eq (token-type body-tok) :lbracket))
            (error 'innate-parse-error
                   :line (token-line until-tok) :col (token-col until-tok)
                   :text "block until must be followed by duration and [body]"))
          (let ((bracket (parse-bracket cursor))
                (fulfillment nil))
            ;; Optional || fulfillment
            (let ((pipe (cursor-peek cursor)))
              (when (and pipe (eq (token-type pipe) :pipe-pipe))
                (cursor-consume cursor)
                (setf fulfillment (parse-fulfillment-expr cursor))))
            (make-node :kind +node-until+
                       :children (if fulfillment
                                     (append (node-children bracket) (list fulfillment))
                                     (node-children bracket))
                       :props (if fulfillment
                                  (list* :fulfillment t duration-props)
                                  duration-props))))))))

(defun parse-postfix-until (cursor left)
  "Parse postfix until: left-expr until duration (|| fulfillment)?.
   Called when :until follows a completed expression.
   Returns an :until node wrapping the left expression."
  (let ((until-tok (cursor-consume cursor))) ; consume 'until'
    (declare (ignore until-tok))
    ;; Parse duration: number + optional unit bare-word
    (let* ((num-tok (cursor-expect cursor :number))
           (unit-tok (cursor-peek cursor))
           (unit (if (and unit-tok (eq (token-type unit-tok) :bare-word))
                     (token-value (cursor-consume cursor))
                     nil))
           (duration-props (list :duration (token-value num-tok)
                                 :unit unit))
           (fulfillment nil))
      ;; Optional || fulfillment
      (let ((pipe (cursor-peek cursor)))
        (when (and pipe (eq (token-type pipe) :pipe-pipe))
          (cursor-consume cursor)
          (setf fulfillment (parse-fulfillment-expr cursor))))
      (make-node :kind +node-until+
                 :children (if fulfillment
                               (list left fulfillment)
                               (list left))
                 :props (list* :postfix t
                               (if fulfillment
                                   (list* :fulfillment t duration-props)
                                   duration-props))))))
