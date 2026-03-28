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

;;; Main entry point — stub for Plan 02
(defun tokenize (source)
  "Convert SOURCE string to a list of token structs.
   Signals innate-parse-error on unterminated strings or unexpected characters."
  (declare (ignore source))
  nil)
