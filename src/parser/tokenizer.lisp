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
  (let ((tokens         '())
        (pos            0)
        (line           1)
        (col            1)
        (len            (length source))
        (line-start-p   t)        ; T at start and after each newline
        (last-was-newline nil)    ; for consecutive newline collapse
        (nesting-depth  0))       ; bracket/paren/brace nesting depth
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

         ;; ── Helper: mark that a non-newline token was emitted ──────────
         (note-token-emitted ()
           "Called after pushing any non-newline token."
           (setf last-was-newline nil)
           (setf line-start-p nil))

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
                    (note-token-emitted)
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
                   tokens)
             (note-token-emitted)))

         (%read-bare-word ()
           "Called when current char is alpha, underscore, or = (operator words like ==).
            Returns the accumulated word string without emitting — caller decides token type.
            Includes '.' in bare-word chars to handle filenames like burg_pipeline.dpn.
            Includes '=' in bare-word chars to handle lens comparison operators like ==, >=, <=."
           (let ((buf '()))
             (loop while (and (current)
                              (or (alphanumericp (current))
                                  (char= (current) #\_)
                                  (char= (current) #\.)   ; file extension support
                                  (char= (current) #\=))) ; lens operator support (==, >=, <=)
                   do (push (current) buf)
                      (advance))
             (coerce (nreverse buf) 'string)))

         (%keyword-token-type (word)
           "Return keyword token type for WORD, or nil if not a keyword."
           (cond
             ((string= word "decree")     :decree)
             ((string= word "concurrent") :concurrent)
             ((string= word "join")       :join)
             ((string= word "until")      :until)
             ((string= word "sync")       :sync)
             ((string= word "at")         :at)
             (t nil)))

         (%emit-bare-word-or-keyword (word sl sc)
           "Emit keyword token or :bare-word for WORD at position SL/SC."
           (let ((kw (%keyword-token-type word)))
             (push (make-token :type  (or kw :bare-word)
                               :value word
                               :line  sl
                               :col   sc)
                   tokens)
             (note-token-emitted)))

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
                         tokens)
                   (note-token-emitted))
                 (error 'innate-parse-error
                        :line line :col col
                        :text (format nil "Unexpected character <")))))

         ;; ── Wikilink disambiguation (TOK-16) ──────────────────────────
         ;; Pure lookahead — does NOT advance pos. Returns values:
         ;;   :wikilink    + inner-text + end-pos-of-closing-]
         ;;   :nested      + nil        + scan-pos-of-first-[
         ;;   :unterminated + nil       + scan-pos
         (%scan-double-bracket ()
           "Lookahead from pos (pointing just past second [). Determine wikilink vs. nested.
            Returns (values kind inner-text close-scan-pos)."
           ;; At entry, pos points to the char after the second [
           ;; We scan forward to find the first ] or [
           (let ((scan pos)  ; start scanning from current pos
                 (buf  '()))
             (loop
               (when (>= scan len)
                 (return (values :unterminated nil scan)))
               (let ((c (char source scan)))
                 (cond
                   ((char= c #\])
                    ;; Found ] before [ — this is a wikilink
                    ;; inner text is everything from pos to scan
                    (return (values :wikilink
                                    (coerce (nreverse buf) 'string)
                                    scan)))
                   ((char= c #\[)
                    ;; Found [ before ] — nested brackets
                    (return (values :nested nil scan)))
                   (t
                    (push c buf)
                    (incf scan)))))))

         ;; ── Prose readers (TOK-17) ────────────────────────────────────

         (%read-to-eol ()
           "Read characters up to (not including) a newline or end of source.
            Return the accumulated string."
           (let ((buf '()))
             (loop
               (let ((c (current)))
                 (when (or (null c) (char= c #\Newline))
                   (return (coerce (nreverse buf) 'string)))
                 (push c buf)
                 (advance))))))

      ;; ── Main dispatch loop ─────────────────────────────────────────────
      (loop while (current)
            do (let ((c (current)))
                 (cond
                   ;; ── Whitespace on same line — consume silently ─────────
                   ((or (char= c #\Space) (char= c #\Tab))
                    (advance))

                   ;; ── Newline — emit :newline with collapse ─────────────
                   ((char= c #\Newline)
                    (let ((sl line) (sc col))
                      (advance)
                      (unless last-was-newline
                        (push (make-token :type :newline :value nil :line sl :col sc)
                              tokens)
                        (setf last-was-newline t))
                      (setf line-start-p t)))

                   ;; ── Prose detection — only at line start AND not inside brackets ──
                   ;; When line-start-p is T and nesting-depth is 0, we are at
                   ;; the top-level start of a new line in the source document.
                   ;; Inside brackets (nesting-depth > 0) all chars tokenize normally.
                   ((and line-start-p (zerop nesting-depth))
                    ;; Prose detection at line start.
                    ;; Executable sigils and all punctuation fall through to
                    ;; normal dispatch. Only alpha chars (not "decree") trigger prose.
                    (cond
                      ;; All punctuation and operator chars — fall through to
                      ;; normal dispatch regardless of line position.
                      ;; This preserves test behavior for standalone tokens.
                      ((member c '(#\[ #\] #\( #\) #\{ #\} #\@ #\! #\# #\/ #\|
                                   #\+ #\" #\< #\: #\, #\= #\*))
                       (setf line-start-p nil))

                      ;; Digits at line start — fall through to normal dispatch
                      ((digit-char-p c)
                       (setf line-start-p nil))

                      ;; - at line start: could be -> (executable) or list-item (prose)
                      ;; Spec gap: - without > treated as prose at line start (burg_pipeline.dpn compat)
                      ((char= c #\-)
                       (if (and (peek-next) (char= (peek-next) #\>))
                           ;; -> emission — executable, fall through
                           (setf line-start-p nil)
                           ;; bare - not followed by > — treat entire line as prose
                           (let ((sl line) (sc col))
                             (let ((rest (%read-to-eol)))
                               (push (make-token :type  :prose
                                                 :value (concatenate 'string "-" rest)
                                                 :line  sl
                                                 :col   sc)
                                     tokens)
                               (note-token-emitted)))))

                      ;; > at line start: in sigil set but no operator defined
                      ;; Spec gap: > without context treated as prose at line start
                      ((char= c #\>)
                       (let ((sl line) (sc col))
                         (let ((rest (%read-to-eol)))
                           (push (make-token :type  :prose
                                             :value (concatenate 'string ">" rest)
                                             :line  sl
                                             :col   sc)
                                 tokens)
                           (note-token-emitted))))

                      ;; Bare word at line start — check if it is a keyword
                      ((or (alpha-char-p c) (char= c #\_))
                       (let ((sl line) (sc col))
                         (let* ((word (%read-bare-word))
                                (kw   (%keyword-token-type word)))
                           (if kw
                               ;; keyword — executable, emit keyword token
                               (progn
                                 (push (make-token :type  kw
                                                   :value word
                                                   :line  sl
                                                   :col   sc)
                                       tokens)
                                 (note-token-emitted))
                               ;; Any other word — this whole line is prose
                               ;; Read remaining chars to EOL, prepend the word
                               (let ((rest (%read-to-eol)))
                                 (push (make-token :type  :prose
                                                   :value (if (string= rest "")
                                                              word
                                                              (concatenate 'string
                                                                           word
                                                                           rest))
                                                   :line  sl
                                                   :col   sc)
                                       tokens)
                                 (note-token-emitted))))))

                      ;; Any other non-sigil char at line start — prose
                      (t
                       (let ((sl line) (sc col))
                         (let ((buf (list c)))
                           (advance)
                           (loop
                             (let ((nc (current)))
                               (when (or (null nc) (char= nc #\Newline))
                                 (return))
                               (push nc buf)
                               (advance)))
                           (push (make-token :type  :prose
                                             :value (coerce (nreverse buf) 'string)
                                             :line  sl
                                             :col   sc)
                                 tokens)
                           (note-token-emitted))))))

                   ;; ── Normal (non-line-start) dispatch ──────────────────

                   ;; Double or single bracket — wikilink vs. lbracket
                   ((char= c #\[)
                    (let ((sl line) (sc col))
                      (advance) ; consume first [
                      (if (and (current) (char= (current) #\[))
                          ;; Double bracket — disambiguate
                          (progn
                            (advance) ; consume second [
                            (multiple-value-bind (kind inner-text close-pos)
                                (%scan-double-bracket)
                              (cond
                                ((eq kind :wikilink)
                                 ;; pos points at start of inner text.
                                 ;; close-pos is the index of the first closing ].
                                 ;; Advance pos through the inner text up to (not including)
                                 ;; the first ], then consume both ]].
                                 ;; All on one line, so no newline handling needed.
                                 (loop while (< pos close-pos)
                                       do (incf col) (incf pos))
                                 ;; Now at first ]
                                 (advance) ; consume first ]
                                 (when (and (current) (char= (current) #\]))
                                   (advance)) ; consume second ]
                                 (push (make-token :type  :wikilink
                                                   :value inner-text
                                                   :line  sl
                                                   :col   sc)
                                       tokens)
                                 (note-token-emitted))
                                ((eq kind :nested)
                                 ;; Two lbracket tokens; pos still at start of inner content
                                 (incf nesting-depth 2)
                                 (push (make-token :type :lbracket :value nil :line sl :col sc) tokens)
                                 (push (make-token :type :lbracket :value nil :line sl :col (1+ sc)) tokens)
                                 (note-token-emitted))
                                (t ; :unterminated
                                 (error 'innate-parse-error
                                        :line sl :col sc
                                        :text "Unterminated [[")))))
                          ;; Single bracket
                          (progn
                            (incf nesting-depth)
                            (push (make-token :type :lbracket :value nil :line sl :col sc) tokens)
                            (note-token-emitted)))))

                   ((char= c #\])
                    (let ((sl line) (sc col))
                      (advance)
                      (when (> nesting-depth 0) (decf nesting-depth))
                      (push (make-token :type :rbracket :value nil :line sl :col sc) tokens)
                      (note-token-emitted)))

                   ((char= c #\()
                    (let ((sl line) (sc col))
                      (advance)
                      (incf nesting-depth)
                      (push (make-token :type :lparen :value nil :line sl :col sc) tokens)
                      (note-token-emitted)))

                   ((char= c #\))
                    (let ((sl line) (sc col))
                      (advance)
                      (when (> nesting-depth 0) (decf nesting-depth))
                      (push (make-token :type :rparen :value nil :line sl :col sc) tokens)
                      (note-token-emitted)))

                   ((char= c #\{)
                    (let ((sl line) (sc col))
                      (advance)
                      (incf nesting-depth)
                      (push (make-token :type :lbrace :value nil :line sl :col sc) tokens)
                      (note-token-emitted)))

                   ((char= c #\})
                    (let ((sl line) (sc col))
                      (advance)
                      (when (> nesting-depth 0) (decf nesting-depth))
                      (push (make-token :type :rbrace :value nil :line sl :col sc) tokens)
                      (note-token-emitted)))

                   ((char= c #\:)
                    (let ((sl line) (sc col))
                      (advance)
                      (push (make-token :type :colon :value nil :line sl :col sc) tokens)
                      (note-token-emitted)))

                   ((char= c #\,)
                    (let ((sl line) (sc col))
                      (advance)
                      (push (make-token :type :comma :value nil :line sl :col sc) tokens)
                      (note-token-emitted)))

                   ((char= c #\#)
                    (let ((sl line) (sc col))
                      (advance)
                      (push (make-token :type :hash :value nil :line sl :col sc) tokens)
                      (note-token-emitted)))

                   ((char= c #\/)
                    (let ((sl line) (sc col))
                      (advance)
                      (push (make-token :type :slash :value nil :line sl :col sc) tokens)
                      (note-token-emitted)))

                   ((char= c #\+)
                    (let ((sl line) (sc col))
                      (advance)
                      (push (make-token :type :plus :value nil :line sl :col sc) tokens)
                      (note-token-emitted)))

                   ((char= c #\@)
                    (let ((sl line) (sc col))
                      (advance)
                      (push (make-token :type :at :value nil :line sl :col sc) tokens)
                      (note-token-emitted)))

                   ;; Two-char operators
                   ((char= c #\!)
                    (let ((sl line) (sc col))
                      (if (and (peek-next) (char= (peek-next) #\[))
                          (progn
                            (advance) ; consume !
                            (advance) ; consume [
                            (incf nesting-depth)
                            (push (make-token :type :bang-bracket :value nil :line sl :col sc) tokens)
                            (note-token-emitted))
                          (error 'innate-parse-error
                                 :line sl :col sc
                                 :text "! must be followed by [ (bang-bracket)"))))

                   ((char= c #\|)
                    (let ((sl line) (sc col))
                      (if (and (peek-next) (char= (peek-next) #\|))
                          (progn
                            (advance) ; consume first |
                            (advance) ; consume second |
                            (push (make-token :type :pipe-pipe :value nil :line sl :col sc) tokens)
                            (note-token-emitted))
                          (error 'innate-parse-error
                                 :line sl :col sc
                                 :text "| must be followed by | (pipe-pipe)"))))

                   ((char= c #\-)
                    (let ((sl line) (sc col))
                      (if (and (peek-next) (char= (peek-next) #\>))
                          (progn
                            (advance) ; consume -
                            (advance) ; consume >
                            (push (make-token :type :arrow :value nil :line sl :col sc) tokens)
                            (note-token-emitted))
                          ;; Spec gap: - without > inside expressions treated as prose
                          ;; (burg_pipeline.dpn compat — list items as - "text")
                          (let ((rest (%read-to-eol)))
                            (push (make-token :type  :prose
                                              :value (concatenate 'string "-" rest)
                                              :line  sl
                                              :col   sc)
                                  tokens)
                            (note-token-emitted)))))

                   ;; String literal
                   ((char= c #\")
                    (%read-string))

                   ;; < — verification operator or emoji slot
                   ((char= c #\<)
                    (if (and (peek-next) (char= (peek-next) #\-))
                        (let ((sl line) (sc col))
                          (advance) ; consume <
                          (advance) ; consume -
                          (push (make-token :type :verification :value nil :line sl :col sc) tokens)
                          (note-token-emitted))
                        (%try-emoji-slot)))

                   ;; Number literal
                   ((digit-char-p c)
                    (%read-number))

                   ;; Bare word or decree keyword
                   ((or (alpha-char-p c) (char= c #\_))
                    (let ((sl line) (sc col))
                      (let ((word (%read-bare-word)))
                        (%emit-bare-word-or-keyword word sl sc))))

                   ;; Operator bare-words starting with = (e.g. ==, >=, <=)
                   ((char= c #\=)
                    (let ((sl line) (sc col))
                      (let ((word (%read-bare-word)))
                        (push (make-token :type :bare-word :value word :line sl :col sc) tokens)
                        (note-token-emitted))))

                   ;; Unexpected character
                   (t
                    (error 'innate-parse-error
                           :line line :col col
                           :text (format nil "Unexpected character: ~a" c))))))

      (nreverse tokens))))
