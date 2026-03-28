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
