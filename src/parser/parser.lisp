;;;; src/parser/parser.lisp — Innate recursive descent parser
;;;; Phase 04: Token stream → AST
;;;;
;;;; Entry point: (parse token-list) → :program node
;;;; Architecture: token-cursor struct for positional scan, hand-rolled recursive descent

(in-package :innate.parser)

;;; -----------------------------------------------------------------------
;;; Token cursor struct
;;; -----------------------------------------------------------------------

(defstruct (parse-cursor (:constructor make-parse-cursor (&key tokens (pos 0))))
  "Positional cursor over a flat token list.
   tokens — the token list from (tokenize source)
   pos    — current read position (zero-based index)"
  (tokens nil)
  (pos    0   :type fixnum))

(defun cursor-peek (cursor)
  "Return the token at the current position without consuming it.
   Returns nil if at end of token list."
  (nth (parse-cursor-pos cursor) (parse-cursor-tokens cursor)))

(defun cursor-peek-next (cursor)
  "Return the token at pos+1 without consuming it.
   Returns nil if pos+1 is past the end."
  (nth (1+ (parse-cursor-pos cursor)) (parse-cursor-tokens cursor)))

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
  (let ((cursor (make-parse-cursor :tokens tokens)))
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
   Dispatches based on the current token type."
  (let ((tok (cursor-peek cursor)))
    (when tok
      (case (token-type tok)
        (:prose
         (cursor-consume cursor)
         (make-node :kind +node-prose+ :value (token-value tok)))
        (:hash
         (parse-heading cursor))
        (:lbracket
         (parse-bracket cursor))
        (:arrow
         ;; Stub for Plan 03 — consume and return nil
         (cursor-consume cursor)
         nil)
        (:decree
         ;; Stub for Plan 02 — consume and return nil
         (cursor-consume cursor)
         nil)
        (t
         (parse-expression cursor))))))

;;; -----------------------------------------------------------------------
;;; Expression dispatch
;;; -----------------------------------------------------------------------

(defun parse-expression (cursor)
  "Parse one expression from the cursor.
   Handles atoms, brackets, headings, and stubs for Plans 02/03."
  (let ((tok (cursor-peek cursor)))
    (when tok
      (case (token-type tok)
        (:at
         ;; Stub: Plan 02 — parse-reference
         (error 'innate-parse-error
                :line (token-line tok) :col (token-col tok)
                :text "Not yet implemented: reference (@)"))
        (:lparen
         ;; Stub: Plan 02 — parse-agent
         (error 'innate-parse-error
                :line (token-line tok) :col (token-col tok)
                :text "Not yet implemented: agent (())"))
        (:lbrace
         ;; Stub: Plan 02 — parse-bundle-or-lens
         (error 'innate-parse-error
                :line (token-line tok) :col (token-col tok)
                :text "Not yet implemented: bundle/lens ({})"))
        (:bang-bracket
         ;; Stub: Plan 02 — parse-search
         (error 'innate-parse-error
                :line (token-line tok) :col (token-col tok)
                :text "Not yet implemented: search (![]"))
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

(defun parse-bracket (cursor)
  "Parse a bracket expression: [body].
   All tokens inside the brackets become children of the :bracket node.
   A lone bare-word followed by :rbracket or by other expressions is a child, not a name.
   Returns a :bracket node with nil value (anonymous) and children from the body."
  (cursor-expect cursor :lbracket)
  (let ((children (parse-bracket-body cursor)))
    (make-node :kind +node-bracket+ :value nil :children children)))

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
          ;; Nested bracket
          ((eq (token-type tok) :lbracket)
           (push (parse-bracket cursor) children))
          ;; Heading inside bracket
          ((eq (token-type tok) :hash)
           (push (parse-heading cursor) children))
          ;; Everything else: call parse-expression
          (t
           (let ((expr (parse-expression cursor)))
             (when expr
               (push expr children)))))))
    (nreverse children)))

;;; -----------------------------------------------------------------------
;;; KV-pair parsing
;;; -----------------------------------------------------------------------

(defun parse-kv-pair (cursor)
  "Parse a key-value pair: bare-word COLON expression.
   Returns a :kv-pair node with value = key-string, children = (value-node)."
  (let* ((key-tok (cursor-consume cursor))   ; bare-word
         (key-name (token-value key-tok)))
    (cursor-expect cursor :colon)
    (let ((value-node (parse-expression cursor)))
      (make-node :kind +node-kv-pair+
                 :value key-name
                 :children (list value-node)))))

;;; -----------------------------------------------------------------------
;;; Heading parsing
;;; -----------------------------------------------------------------------

(defun parse-heading (cursor)
  "Parse a heading: HASH followed by bare-words (accumulated as heading text).
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
    (make-node :kind +node-heading+
               :value (format nil "~{~a~^ ~}" (nreverse words)))))
