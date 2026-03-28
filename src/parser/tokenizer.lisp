(in-package :innate.parser.tokenizer)

;;; Token struct — flat positional data, NOT an AST node.
;;; type  — keyword from the 23-type vocabulary
;;; value — string (for :string/:number/:bare-word/:decree/:wikilink/:prose/:emoji-slot), nil for punctuation
;;; line  — 1-based line number of the first character
;;; col   — 1-based column number of the first character

(defstruct (token (:constructor make-token (&key type value line col)))
  "A single lexical token from Innate source text."
  (type  nil)
  (value nil)
  (line  1   :type integer)
  (col   1   :type integer))

;;; Main entry point
(defun tokenize (source)
  "Convert SOURCE string to a list of token structs.
   Signals innate-parse-error on unterminated strings or unexpected characters."
  (let ((tokens '())
        (pos    0)
        (line   1)
        (col    1)
        (len    (length source)))
    (labels
        ;; ── Character access ──────────────────────────────────────────────
        ((current ()
           "Return char at pos, or nil if at end."
           (when (< pos len) (char source pos)))

         (advance ()
           "Consume one char, update pos/line/col. Return the consumed char."
           (let ((c (char source pos)))
             (incf pos)
             (if (char= c #\Newline)
                 (progn (incf line) (setf col 1))
                 (incf col))
             c))

         (peek-next ()
           "Return char at pos+1, or nil if out of bounds."
           (when (< (1+ pos) len) (char source (1+ pos))))

         ;; ── Multi-char literal readers ─────────────────────────────────

         (%read-string ()
           "Called when current char is #\". Accumulates up to closing quote."
           (let ((start-line line)
                 (start-col  col))
             (advance) ; consume opening "
             (let ((buf '()))
               (loop
                 (cond
                   ;; EOF before closing quote
                   ((null (current))
                    (error 'innate-parse-error
                           :line start-line :col start-col
                           :text "Unterminated string literal"))
                   ;; Backslash escape
                   ((char= (current) #\\)
                    (advance) ; consume backslash
                    (case (current)
                      (#\" (push #\" buf) (advance))
                      (#\\ (push #\\ buf) (advance))
                      (t (error 'innate-parse-error
                                :line line :col col
                                :text (format nil "Unknown escape \\~a"
                                              (current))))))
                   ;; Closing quote
                   ((char= (current) #\")
                    (advance) ; consume closing "
                    (push (make-token :type :string
                                      :value (coerce (nreverse buf) 'string)
                                      :line start-line
                                      :col  start-col)
                          tokens)
                    (return))
                   ;; Ordinary character
                   (t
                    (push (current) buf)
                    (advance)))))))

         (%read-number ()
           "Called when current char satisfies digit-char-p."
           (let ((start-line line)
                 (start-col  col)
                 (buf '()))
             (loop while (and (current) (digit-char-p (current)))
                   do (push (current) buf)
                      (advance))
             (push (make-token :type  :number
                               :value (coerce (nreverse buf) 'string)
                               :line  start-line
                               :col   start-col)
                   tokens)))

         (%read-bare-word ()
           "Called when current char is alpha or underscore."
           (let ((start-line line)
                 (start-col  col)
                 (buf '()))
             (loop while (and (current)
                              (or (alphanumericp (current))
                                  (char= (current) #\_)))
                   do (push (current) buf)
                      (advance))
             (let ((word (coerce (nreverse buf) 'string)))
               (push (make-token :type  (if (string= word "decree")
                                            :decree
                                            :bare-word)
                                 :value word
                                 :line  start-line
                                 :col   start-col)
                     tokens))))

         (%try-emoji-slot ()
           "Called when current char is #\<. Tries to match literal <emoji>."
           (let ((start-line line)
                 (start-col  col))
             (if (and (>= (- len pos) 7)
                      (string= "<emoji>" source :start2 pos :end2 (+ pos 7)))
                 (progn
                   (dotimes (_ 7) (advance))
                   (push (make-token :type  :emoji-slot
                                     :value "<emoji>"
                                     :line  start-line
                                     :col   start-col)
                         tokens))
                 (error 'innate-parse-error
                        :line line :col col
                        :text (format nil "Unexpected character <"))))))

      ;; ── Main dispatch loop ─────────────────────────────────────────────
      (loop while (current)
            do (let ((c (current)))
                 (cond
                   ;; Whitespace — consume silently (not newlines)
                   ((or (char= c #\Space) (char= c #\Tab))
                    (advance))

                   ;; Newline — consume silently (Plan 03 adds :newline emission)
                   ((char= c #\Newline)
                    (advance))

                   ;; Single-char bracket tokens
                   ((char= c #\[)
                    (let ((sl line) (sc col))
                      (advance)
                      (push (make-token :type :lbracket :value nil :line sl :col sc) tokens)))

                   ((char= c #\])
                    (let ((sl line) (sc col))
                      (advance)
                      (push (make-token :type :rbracket :value nil :line sl :col sc) tokens)))

                   ((char= c #\()
                    (let ((sl line) (sc col))
                      (advance)
                      (push (make-token :type :lparen :value nil :line sl :col sc) tokens)))

                   ((char= c #\))
                    (let ((sl line) (sc col))
                      (advance)
                      (push (make-token :type :rparen :value nil :line sl :col sc) tokens)))

                   ((char= c #\{)
                    (let ((sl line) (sc col))
                      (advance)
                      (push (make-token :type :lbrace :value nil :line sl :col sc) tokens)))

                   ((char= c #\})
                    (let ((sl line) (sc col))
                      (advance)
                      (push (make-token :type :rbrace :value nil :line sl :col sc) tokens)))

                   ((char= c #\:)
                    (let ((sl line) (sc col))
                      (advance)
                      (push (make-token :type :colon :value nil :line sl :col sc) tokens)))

                   ((char= c #\,)
                    (let ((sl line) (sc col))
                      (advance)
                      (push (make-token :type :comma :value nil :line sl :col sc) tokens)))

                   ((char= c #\#)
                    (let ((sl line) (sc col))
                      (advance)
                      (push (make-token :type :hash :value nil :line sl :col sc) tokens)))

                   ((char= c #\/)
                    (let ((sl line) (sc col))
                      (advance)
                      (push (make-token :type :slash :value nil :line sl :col sc) tokens)))

                   ((char= c #\+)
                    (let ((sl line) (sc col))
                      (advance)
                      (push (make-token :type :plus :value nil :line sl :col sc) tokens)))

                   ((char= c #\@)
                    (let ((sl line) (sc col))
                      (advance)
                      (push (make-token :type :at :value nil :line sl :col sc) tokens)))

                   ;; Two-char operators
                   ((char= c #\!)
                    (let ((sl line) (sc col))
                      (if (and (peek-next) (char= (peek-next) #\[))
                          (progn
                            (advance) ; consume !
                            (advance) ; consume [
                            (push (make-token :type :bang-bracket :value nil :line sl :col sc) tokens))
                          (error 'innate-parse-error
                                 :line sl :col sc
                                 :text "! must be followed by [ (bang-bracket)"))))

                   ((char= c #\|)
                    (let ((sl line) (sc col))
                      (if (and (peek-next) (char= (peek-next) #\|))
                          (progn
                            (advance) ; consume first |
                            (advance) ; consume second |
                            (push (make-token :type :pipe-pipe :value nil :line sl :col sc) tokens))
                          (error 'innate-parse-error
                                 :line sl :col sc
                                 :text "| must be followed by | (pipe-pipe)"))))

                   ((char= c #\-)
                    (let ((sl line) (sc col))
                      (if (and (peek-next) (char= (peek-next) #\>))
                          (progn
                            (advance) ; consume -
                            (advance) ; consume >
                            (push (make-token :type :arrow :value nil :line sl :col sc) tokens))
                          (error 'innate-parse-error
                                 :line sl :col sc
                                 :text "- must be followed by > (arrow)"))))

                   ;; String literal
                   ((char= c #\")
                    (%read-string))

                   ;; Emoji slot
                   ((char= c #\<)
                    (%try-emoji-slot))

                   ;; Number literal
                   ((digit-char-p c)
                    (%read-number))

                   ;; Bare word or decree keyword
                   ((or (alpha-char-p c) (char= c #\_))
                    (%read-bare-word))

                   ;; Unexpected character
                   (t
                    (error 'innate-parse-error
                           :line line :col col
                           :text (format nil "Unexpected character: ~a" c))))))

      (nreverse tokens))))
