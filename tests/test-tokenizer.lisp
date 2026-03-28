;;;; test-tokenizer.lisp — tests for the Innate tokenizer (Phase 3)
;;;; Covers TOK-01 through TOK-18

(in-package :innate.tests.tokenizer)

;;; Token struct round-trip tests (TOK-18 — line/col tracking foundation)

(deftest test-token-struct-round-trip
  (let ((tok (make-token :type :lbracket :value nil :line 1 :col 1)))
    (assert-equal :lbracket (token-type tok) "token-type accessor")
    (assert-nil (token-value tok) "token-value nil for punctuation")
    (assert-equal 1 (token-line tok) "token-line accessor")
    (assert-equal 1 (token-col tok) "token-col accessor")))

(deftest test-token-with-string-value
  (let ((tok (make-token :type :string :value "hello" :line 3 :col 5)))
    (assert-equal :string (token-type tok) "string token type")
    (assert-equal "hello" (token-value tok) "string token value")
    (assert-equal 3 (token-line tok) "string token line")
    (assert-equal 5 (token-col tok) "string token col")))

(deftest test-token-with-number-value
  (let ((tok (make-token :type :number :value "42" :line 10 :col 20)))
    (assert-equal :number (token-type tok) "number token type")
    (assert-equal "42" (token-value tok) "number token value")
    (assert-equal 10 (token-line tok) "number token line")))

;;; ─── Task 1: Single-character token tests (TOK-01 through TOK-10) ───

(deftest test-single-bracket-tokens
  ;; TOK-01: all bracket types emit correct token with correct type
  (let ((lbrak (tokenize "[")))
    (assert-equal 1 (length lbrak) "lbracket: one token")
    (assert-equal :lbracket (token-type (first lbrak)) "lbracket type"))
  (let ((rbrak (tokenize "]")))
    (assert-equal 1 (length rbrak) "rbracket: one token")
    (assert-equal :rbracket (token-type (first rbrak)) "rbracket type"))
  (let ((lparen (tokenize "(")))
    (assert-equal 1 (length lparen) "lparen: one token")
    (assert-equal :lparen (token-type (first lparen)) "lparen type"))
  (let ((rparen (tokenize ")")))
    (assert-equal 1 (length rparen) "rparen: one token")
    (assert-equal :rparen (token-type (first rparen)) "rparen type"))
  (let ((lbrace (tokenize "{")))
    (assert-equal 1 (length lbrace) "lbrace: one token")
    (assert-equal :lbrace (token-type (first lbrace)) "lbrace type"))
  (let ((rbrace (tokenize "}")))
    (assert-equal 1 (length rbrace) "rbrace: one token")
    (assert-equal :rbrace (token-type (first rbrace)) "rbrace type")))

(deftest test-single-punctuation-tokens
  ;; TOK-07, TOK-08, TOK-09, TOK-10 and friends
  (assert-equal :colon  (token-type (first (tokenize ":"))) "colon")
  (assert-equal :comma  (token-type (first (tokenize ","))) "comma")
  (assert-equal :hash   (token-type (first (tokenize "#"))) "hash")
  (assert-equal :slash  (token-type (first (tokenize "/"))) "slash")
  (assert-equal :plus   (token-type (first (tokenize "+"))) "plus")
  (assert-equal :at     (token-type (first (tokenize "@"))) "at"))

(deftest test-single-char-position-tracking
  ;; Tokens on same line: position col should reflect source position
  (let ((tokens (tokenize "[ ]")))
    (assert-equal 2 (length tokens) "two tokens from '[ ]'")
    (assert-equal :lbracket (token-type (first tokens)) "first is lbracket")
    (assert-equal 1 (token-col (first tokens)) "lbracket at col 1")
    (assert-equal :rbracket (token-type (second tokens)) "second is rbracket")
    (assert-equal 3 (token-col (second tokens)) "rbracket at col 3")))

(deftest test-two-char-operators
  ;; TOK-03: ![ emits single :bang-bracket
  (let ((toks (tokenize "![")))
    (assert-equal 1 (length toks) "bang-bracket: one token")
    (assert-equal :bang-bracket (token-type (first toks)) "bang-bracket type"))
  ;; TOK-04: || emits single :pipe-pipe
  (let ((toks (tokenize "||")))
    (assert-equal 1 (length toks) "pipe-pipe: one token")
    (assert-equal :pipe-pipe (token-type (first toks)) "pipe-pipe type"))
  ;; TOK-05: -> emits single :arrow
  (let ((toks (tokenize "->")))
    (assert-equal 1 (length toks) "arrow: one token")
    (assert-equal :arrow (token-type (first toks)) "arrow type")))

(deftest test-at-reference
  ;; TOK-02: @foo emits :at then :bare-word with value "foo"
  (let ((toks (tokenize "@foo")))
    (assert-equal 2 (length toks) "@foo: two tokens")
    (assert-equal :at (token-type (first toks)) "@foo first token is :at")
    (assert-equal :bare-word (token-type (second toks)) "@foo second token is :bare-word")
    (assert-equal "foo" (token-value (second toks)) "@foo bare-word value is foo")
    (assert-equal 1 (token-col (first toks)) "@ at col 1")
    (assert-equal 2 (token-col (second toks)) "bare-word after @ at col 2")))

(deftest test-at-reference-with-space
  ;; @ followed by space then name: both tokens emitted, space consumed
  (let ((toks (tokenize "@ foo")))
    (assert-equal 2 (length toks) "@ space foo: two tokens")
    (assert-equal :at (token-type (first toks)) "first is :at")
    (assert-equal :bare-word (token-type (second toks)) "second is :bare-word")
    (assert-equal "foo" (token-value (second toks)) "value is foo")
    (assert-equal 3 (token-col (second toks)) "bare-word at col 3 after space")))

(deftest test-plus-bare-word
  ;; TOK-06: +word emits :plus then :bare-word
  (let ((toks (tokenize "+all")))
    (assert-equal 2 (length toks) "+all: two tokens")
    (assert-equal :plus (token-type (first toks)) "+all first is :plus")
    (assert-equal :bare-word (token-type (second toks)) "+all second is :bare-word")
    (assert-equal "all" (token-value (second toks)) "+all bare-word value")))

(deftest test-newline-position-tracking
  ;; TOK-18: token on second line has line=2
  ;; Now that :newline tokens are emitted, "[<newline>[" produces 3 tokens:
  ;; :lbracket(1,1) :newline(1,2) :lbracket(2,1)
  (let ((toks (tokenize (format nil "[~%["))))
    (assert-equal 3 (length toks) "three tokens: lbracket newline lbracket")
    (assert-equal :lbracket (token-type (first toks)) "first is :lbracket")
    (assert-equal 1 (token-line (first toks)) "first bracket on line 1")
    (assert-equal :newline (token-type (second toks)) "second is :newline")
    (assert-equal :lbracket (token-type (third toks)) "third is :lbracket")
    (assert-equal 2 (token-line (third toks)) "second bracket on line 2")))

;;; ─── Task 2: Literal token tests (TOK-11 through TOK-15) ───

(deftest test-string-literal
  ;; TOK-11: basic string literal
  (let ((toks (tokenize "\"hello\"")))
    (assert-equal 1 (length toks) "string: one token")
    (assert-equal :string (token-type (first toks)) "string type")
    (assert-equal "hello" (token-value (first toks)) "string value"))
  ;; escaped quote inside string
  (let ((toks (tokenize "\"he\\\"llo\"")))
    (assert-equal 1 (length toks) "escaped-quote string: one token")
    (assert-equal "he\"llo" (token-value (first toks)) "escaped quote in value"))
  ;; escaped backslash
  (let ((toks (tokenize "\"back\\\\slash\"")))
    (assert-equal 1 (length toks) "escaped-backslash string: one token")
    (assert-equal "back\\slash" (token-value (first toks)) "escaped backslash in value")))

(deftest test-string-unterminated
  ;; Unterminated string signals innate-parse-error
  (assert-signals innate-parse-error
    (tokenize "\"hello")
    "unterminated string signals parse error"))

(deftest test-number-literal
  ;; TOK-12: integer sequences tokenize as :number
  (let ((toks (tokenize "42")))
    (assert-equal 1 (length toks) "42: one token")
    (assert-equal :number (token-type (first toks)) "42 type is :number")
    (assert-equal "42" (token-value (first toks)) "42 value is string"))
  (let ((toks (tokenize "0")))
    (assert-equal 1 (length toks) "0: one token")
    (assert-equal :number (token-type (first toks)) "0 type is :number")
    (assert-equal "0" (token-value (first toks)) "0 value is string")))

(deftest test-bare-word
  ;; TOK-13: bare words tokenize as :bare-word inside expressions
  ;; At line start a bare word (not "decree") is emitted as :prose per TOK-17.
  ;; Inside brackets it is :bare-word. Test inside brackets:
  (let ((toks (tokenize "[entry]")))
    (assert-equal 3 (length toks) "[entry]: three tokens")
    (assert-equal :lbracket (token-type (first toks)) "first is :lbracket")
    (assert-equal :bare-word (token-type (second toks)) "entry inside brackets type")
    (assert-equal "entry" (token-value (second toks)) "entry value")
    (assert-equal :rbracket (token-type (third toks)) "last is :rbracket"))
  ;; Bare word at line start is prose (TOK-17)
  (let ((toks (tokenize "entry")))
    (assert-equal 1 (length toks) "entry at line start: one prose token")
    (assert-equal :prose (token-type (first toks)) "entry at line start is :prose")
    (assert-equal "entry" (token-value (first toks)) "prose value is entry")))

(deftest test-decree-keyword
  ;; TOK-15: "decree" at line start tokenizes as :decree (not prose)
  (let ((toks (tokenize "decree")))
    (assert-equal 1 (length toks) "decree: one token")
    (assert-equal :decree (token-type (first toks)) "decree type"))
  ;; "decrement" at line start tokenizes as :prose (not :decree, not :bare-word)
  ;; because it is not the exact "decree" keyword, so the whole line is prose (TOK-17)
  (let ((toks (tokenize "decrement")))
    (assert-equal 1 (length toks) "decrement at line start: one prose token")
    (assert-equal :prose (token-type (first toks)) "decrement at line start is :prose")
    (assert-equal "decrement" (token-value (first toks)) "prose value is decrement"))
  ;; "decree" inside brackets tokenizes as :decree
  (let ((toks (tokenize "[decree foo]")))
    (assert-equal 4 (length toks) "[decree foo]: four tokens")
    (assert-equal :decree (token-type (second toks)) "decree inside brackets is :decree")))

(deftest test-emoji-slot
  ;; TOK-14: <emoji> tokenizes as :emoji-slot
  (let ((toks (tokenize "<emoji>")))
    (assert-equal 1 (length toks) "<emoji>: one token")
    (assert-equal :emoji-slot (token-type (first toks)) "<emoji> type")
    (assert-equal "<emoji>" (token-value (first toks)) "<emoji> value"))
  ;; <other is not a valid emoji slot — signals innate-parse-error
  (assert-signals innate-parse-error
    (tokenize "<other")
    "non-emoji-slot < signals parse error"))

;;; ─── Task 1 (Plan 03): Wikilink disambiguation (TOK-16) ───

(deftest test-wikilink-simple
  ;; TOK-16: [[Burg]] emits one :wikilink token with value "Burg"
  (let ((toks (tokenize "[[Burg]]")))
    (assert-equal 1 (length toks) "[[Burg]]: one token")
    (assert-equal :wikilink (token-type (first toks)) "type is :wikilink")
    (assert-equal "Burg" (token-value (first toks)) "value is Burg")
    (assert-equal 1 (token-line (first toks)) "wikilink on line 1")
    (assert-equal 1 (token-col (first toks)) "wikilink at col 1")))

(deftest test-wikilink-longer-title
  ;; TOK-16: [[Longer Title Here]] emits :wikilink with full inner text
  (let ((toks (tokenize "[[Longer Title Here]]")))
    (assert-equal 1 (length toks) "longer wikilink: one token")
    (assert-equal :wikilink (token-type (first toks)) "type is :wikilink")
    (assert-equal "Longer Title Here" (token-value (first toks)) "full title preserved")))

(deftest test-wikilink-vs-nested-brackets
  ;; TOK-16: [[sylvia[command]]] is nested brackets, NOT a wikilink
  ;; Expected: :lbracket :lbracket :bare-word("sylvia") :lbracket :bare-word("command") :rbracket :rbracket :rbracket
  (let* ((toks (tokenize "[[sylvia[command]]]"))
         (types (mapcar #'token-type toks)))
    (assert-equal 8 (length toks) "nested brackets: 8 tokens")
    (assert-equal :lbracket (first types) "token 1 is :lbracket")
    (assert-equal :lbracket (second types) "token 2 is :lbracket")
    (assert-equal :bare-word (third types) "token 3 is :bare-word")
    (assert-equal "sylvia" (token-value (third toks)) "bare-word value is sylvia")
    (assert-equal :lbracket (fourth types) "token 4 is :lbracket")
    (assert-equal :bare-word (fifth types) "token 5 is :bare-word")
    (assert-equal "command" (token-value (fifth toks)) "bare-word value is command")
    (assert-equal :rbracket (sixth types) "token 6 is :rbracket")
    (assert-equal :rbracket (seventh types) "token 7 is :rbracket")
    (assert-equal :rbracket (eighth types) "token 8 is :rbracket")))

;;; ─── Task 1 (Plan 03): Prose detection (TOK-17) ───

(deftest test-prose-line
  ;; TOK-17: plain text line emits one :prose token
  (let ((toks (tokenize "This is plain text")))
    (assert-equal 1 (length toks) "prose: one token")
    (assert-equal :prose (token-type (first toks)) "type is :prose")
    (assert-equal "This is plain text" (token-value (first toks)) "prose value is full line")))

(deftest test-prose-not-decree
  ;; TOK-17: "decree foo" at line start is NOT prose — emits :decree then :bare-word
  (let* ((toks (tokenize "decree foo"))
         (types (mapcar #'token-type toks)))
    (assert-equal 2 (length toks) "decree foo: two tokens")
    (assert-equal :decree (first types) "first token is :decree")
    (assert-equal :bare-word (second types) "second token is :bare-word")
    (assert-equal "foo" (token-value (second toks)) "bare-word value is foo")))

(deftest test-prose-not-lbracket
  ;; TOK-17: "[foo]" at line start is NOT prose — starts with executable sigil
  (let* ((toks (tokenize "[foo]"))
         (types (mapcar #'token-type toks)))
    (assert-equal 3 (length toks) "[foo]: three tokens")
    (assert-equal :lbracket (first types) "first is :lbracket")
    (assert-equal :bare-word (second types) "second is :bare-word")
    (assert-equal :rbracket (third types) "third is :rbracket")))

(deftest test-prose-not-arrow
  ;; TOK-17: "-> value" at line start is NOT prose — starts with ->
  (let* ((toks (tokenize "-> value"))
         (types (mapcar #'token-type toks)))
    (assert-equal 2 (length toks) "-> value: two tokens")
    (assert-equal :arrow (first types) "first is :arrow")
    (assert-equal :bare-word (second types) "second is :bare-word")))

;;; ─── Task 1 (Plan 03): Newline emission and collapse (TOK-18) ───

(deftest test-newline-between-prose
  ;; Newline between two lines emits :newline token between prose tokens
  (let* ((toks (tokenize (format nil "a~%b")))
         (types (mapcar #'token-type toks)))
    (assert-equal 3 (length toks) "a NL b: three tokens")
    (assert-equal :prose (first types) "first is :prose")
    (assert-equal :newline (second types) "second is :newline")
    (assert-equal :prose (third types) "third is :prose")))

(deftest test-newline-collapse
  ;; TOK-18: consecutive newlines collapse to one :newline token
  (let* ((toks (tokenize (format nil "a~%~%b")))
         (types (mapcar #'token-type toks)))
    (assert-equal 3 (length toks) "a NL NL b collapses to 3 tokens")
    (assert-equal :prose (first types) "first is :prose(a)")
    (assert-equal :newline (second types) "second is :newline (collapsed)")
    (assert-equal :prose (third types) "third is :prose(b)")))

(deftest test-newline-position
  ;; Newline token has correct position; bracket on line 2 has line=2 col=1
  (let* ((toks (tokenize (format nil "[~%]")))
         (types (mapcar #'token-type toks)))
    ;; Expect: :lbracket(1,1), :newline(1,2), :rbracket(2,1)
    (assert-equal 3 (length toks) "[NL]: three tokens")
    (assert-equal :lbracket (first types) "first is :lbracket")
    (assert-equal 1 (token-line (first toks)) "lbracket on line 1")
    (assert-equal 1 (token-col (first toks)) "lbracket at col 1")
    (assert-equal :newline (second types) "second is :newline")
    (assert-equal :rbracket (third types) "third is :rbracket")
    (assert-equal 2 (token-line (third toks)) "rbracket on line 2")
    (assert-equal 1 (token-col (third toks)) "rbracket at col 1")))

;;; ─── Task 2 (Plan 03): Integration tests ────────────────────────────────

(defun %read-file-to-string (path)
  "Read entire file at PATH into a string."
  (with-open-file (stream path :direction :input)
    (let ((contents (make-string (file-length stream))))
      (read-sequence contents stream)
      contents)))

(deftest test-burg-pipeline-tokenizes
  "burg_pipeline.dpn tokenizes without error and produces tokens."
  (let* ((source (%read-file-to-string "burg_pipeline.dpn"))
         (tokens (tokenize source)))
    (assert-true (> (length tokens) 0) "token list is non-empty")
    ;; Verify key token types appear in the output
    (assert-true (find :lbracket tokens :key #'token-type) "contains :lbracket")
    (assert-true (find :string tokens :key #'token-type) "contains :string")
    (assert-true (find :colon tokens :key #'token-type) "contains :colon")
    (assert-true (find :hash tokens :key #'token-type) "contains :hash")
    (assert-true (find :at tokens :key #'token-type) "contains :at")
    (assert-true (find :bang-bracket tokens :key #'token-type) "contains :bang-bracket")
    (assert-true (find :slash tokens :key #'token-type) "contains :slash")
    (assert-true (find :bare-word tokens :key #'token-type) "contains :bare-word")))

(deftest test-multiline-position-tracking
  "Tokens on different lines have correct line/col values."
  (let* ((source (format nil "[~%]~%@foo"))
         (tokens (tokenize source)))
    ;; Line 1: [ at col 1
    (let ((first-tok (first tokens)))
      (assert-equal :lbracket (token-type first-tok) "first token type")
      (assert-equal 1 (token-line first-tok) "first token line")
      (assert-equal 1 (token-col first-tok) "first token col"))
    ;; Find ] token — should be on line 2
    (let ((rbracket (find :rbracket tokens :key #'token-type)))
      (assert-equal 2 (token-line rbracket) "] on line 2")
      (assert-equal 1 (token-col rbracket) "] at col 1"))
    ;; Find :at token — should be on line 3
    (let ((at-tok (find :at tokens :key #'token-type)))
      (assert-equal 3 (token-line at-tok) "@ on line 3")
      (assert-equal 1 (token-col at-tok) "@ at col 1"))))

(deftest test-wikilink-inside-string-is-literal
  "[[Burg]] inside a string is preserved as literal text, not a :wikilink token."
  (let* ((tokens (tokenize "\"[[Burg]]\""))
         (tok (first tokens)))
    (assert-equal :string (token-type tok) "type is :string not :wikilink")
    (assert-equal "[[Burg]]" (token-value tok) "string value preserves [[]]")))

(deftest test-combined-expression
  "@type:\"[[Burg]]\"+all tokenizes into correct token sequence."
  (let* ((tokens (tokenize "@type:\"[[Burg]]\"+all"))
         (types (mapcar #'token-type tokens)))
    (assert-equal '(:at :bare-word :colon :string :plus :bare-word) types
                  "combined expression token sequence")))
