;;;; tests/packages.lisp — package definitions for the Innate test suite

(defpackage :innate.tests
  (:use :cl)
  (:export
   #:deftest
   #:assert-equal
   #:assert-true
   #:assert-nil
   #:assert-signals
   #:run-tests
   #:*test-registry*))

(defpackage :innate.tests.conditions
  (:use :cl)
  (:import-from :innate.tests
    #:deftest
    #:assert-equal
    #:assert-true
    #:assert-nil
    #:assert-signals
    #:run-tests)
  (:import-from :innate.conditions
    #:innate-condition
    #:innate-parse-error
    #:innate-resistance
    #:parse-error-line
    #:parse-error-col
    #:resistance-condition-message
    #:resistance-condition-source)
  (:export))

(defpackage :innate.tests.types
  (:use :cl)
  (:import-from :innate.tests
    #:deftest
    #:assert-equal
    #:assert-true
    #:assert-nil
    #:assert-signals
    #:run-tests)
  (:import-from :innate.types
    #:make-node
    #:node-kind
    #:node-value
    #:node-children
    #:node-props
    #:+node-program+
    #:+node-bracket+
    #:+node-agent+
    #:+node-bundle+
    #:+node-reference+
    #:+node-search+
    #:+node-fulfillment+
    #:+node-emission+
    #:+node-decree+
    #:+node-wikilink+
    #:+node-combinator+
    #:+node-lens+
    #:+node-kv-pair+
    #:+node-modifier+
    #:+node-prose+
    #:+node-heading+
    #:+node-string-lit+
    #:+node-number-lit+
    #:+node-bare-word+
    #:+node-emoji-slot+
    #:make-innate-result
    #:innate-result-value
    #:innate-result-context
    #:make-resistance
    #:resistance-p
    #:resistance-message
    #:resistance-source)
  (:export))

(defpackage :innate.tests.tokenizer
  (:use :cl)
  (:import-from :innate.tests
    #:deftest
    #:assert-equal
    #:assert-true
    #:assert-nil
    #:assert-signals
    #:run-tests)
  (:import-from :innate.parser.tokenizer
    #:make-token
    #:token-type
    #:token-value
    #:token-line
    #:token-col
    #:tokenize)
  (:import-from :innate.conditions
    #:innate-parse-error)
  (:export))

(defpackage :innate.tests.parser
  (:use :cl)
  (:import-from :innate.tests
    #:deftest #:assert-equal #:assert-true #:assert-nil #:assert-signals #:run-tests)
  (:import-from :innate.parser #:parse)
  (:import-from :innate.parser.tokenizer #:tokenize #:make-token #:token-type #:token-value)
  (:import-from :innate.types
    #:make-node #:node-kind #:node-value #:node-children #:node-props
    #:+node-program+ #:+node-bracket+ #:+node-kv-pair+ #:+node-prose+
    #:+node-heading+ #:+node-string-lit+ #:+node-number-lit+ #:+node-bare-word+
    #:+node-wikilink+ #:+node-emoji-slot+ #:+node-agent+ #:+node-bundle+
    #:+node-reference+ #:+node-search+ #:+node-fulfillment+ #:+node-emission+
    #:+node-decree+ #:+node-combinator+ #:+node-lens+ #:+node-modifier+)
  (:import-from :innate.conditions #:innate-parse-error)
  (:export))

(defpackage :innate.tests.resolver
  (:use :cl)
  (:import-from :innate.tests
    #:deftest #:assert-equal #:assert-true #:assert-nil #:assert-signals #:run-tests)
  (:import-from :innate.eval.resolver
    #:resolver
    #:resolve-reference
    #:resolve-search
    #:deliver-commission
    #:resolve-wikilink
    #:resolve-context
    #:load-bundle
    #:eval-env
    #:make-eval-env
    #:eval-env-resolver
    #:eval-env-decrees
    #:eval-env-bindings
    #:eval-env-scope)
  (:import-from :innate.types
    #:make-innate-result
    #:innate-result-value
    #:innate-result-context
    #:make-resistance
    #:resistance-p
    #:resistance-message
    #:resistance-source)
  (:export))
