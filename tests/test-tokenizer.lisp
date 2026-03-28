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
  (let ((toks (tokenize (format nil "[~%["))))
    (assert-equal 2 (length toks) "two brackets across newline")
    (assert-equal 1 (token-line (first toks)) "first bracket on line 1")
    (assert-equal 2 (token-line (second toks)) "second bracket on line 2")))

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
  ;; TOK-13: bare words tokenize as :bare-word
  (let ((toks (tokenize "entry")))
    (assert-equal 1 (length toks) "entry: one token")
    (assert-equal :bare-word (token-type (first toks)) "entry type")
    (assert-equal "entry" (token-value (first toks)) "entry value")))

(deftest test-decree-keyword
  ;; TOK-15: "decree" tokenizes as :decree
  (let ((toks (tokenize "decree")))
    (assert-equal 1 (length toks) "decree: one token")
    (assert-equal :decree (token-type (first toks)) "decree type"))
  ;; "decrement" tokenizes as :bare-word (not :decree)
  (let ((toks (tokenize "decrement")))
    (assert-equal 1 (length toks) "decrement: one token")
    (assert-equal :bare-word (token-type (first toks)) "decrement is :bare-word not :decree")
    (assert-equal "decrement" (token-value (first toks)) "decrement value")))

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
