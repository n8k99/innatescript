;;;; packages.lisp — all package definitions for the Innate interpreter
;;;; Loaded first by ASDF. Every cross-package import uses :import-from — never :use.

(defpackage :innate.types
  (:use :cl)
  (:export
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
   #:resistance-source))

(defpackage :innate.conditions
  (:use :cl)
  (:import-from :innate.types)
  (:export
   #:innate-condition
   #:innate-parse-error
   #:innate-resistance
   #:parse-error-line
   #:parse-error-col
   #:resistance-condition-message
   #:resistance-condition-source))

(defpackage :innate.parser.tokenizer
  (:use :cl)
  (:import-from :innate.conditions
    #:innate-parse-error)
  (:export
   #:make-token
   #:token-type
   #:token-value
   #:token-line
   #:token-col
   #:tokenize))

(defpackage :innate.parser
  (:use :cl)
  (:import-from :innate.parser.tokenizer
    #:token-type #:token-value #:token-line #:token-col #:tokenize)
  (:import-from :innate.types
    #:make-node #:node-kind #:node-value #:node-children #:node-props
    #:+node-program+ #:+node-bracket+ #:+node-kv-pair+ #:+node-prose+
    #:+node-heading+ #:+node-string-lit+ #:+node-number-lit+ #:+node-bare-word+
    #:+node-wikilink+ #:+node-emoji-slot+ #:+node-agent+ #:+node-bundle+
    #:+node-reference+ #:+node-search+ #:+node-fulfillment+ #:+node-emission+
    #:+node-decree+ #:+node-combinator+ #:+node-lens+ #:+node-modifier+)
  (:import-from :innate.conditions
    #:innate-parse-error)
  (:export #:parse))

(defpackage :innate.eval.resolver
  (:use :cl)
  (:import-from :innate.types
    #:make-innate-result
    #:innate-result-value
    #:innate-result-context
    #:make-resistance
    #:resistance-p)
  (:import-from :innate.conditions)
  (:export
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
   #:eval-env-scope))

(defpackage :innate.eval
  (:use :cl)
  (:import-from :innate.eval.resolver
    #:resolver
    #:eval-env
    #:make-eval-env
    #:eval-env-resolver
    #:eval-env-decrees
    #:eval-env-bindings
    #:eval-env-scope
    #:resolve-reference
    #:resolve-search
    #:deliver-commission
    #:resolve-wikilink
    #:resolve-context
    #:load-bundle)
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
  (:import-from :innate.conditions
    #:innate-resistance
    #:resistance-condition-message
    #:resistance-condition-source)
  (:export
   #:evaluate))

(defpackage :innate.eval.stub-resolver
  (:use :cl)
  (:import-from :innate.eval.resolver
    #:resolver
    #:resolve-reference
    #:resolve-search
    #:deliver-commission
    #:resolve-wikilink
    #:resolve-context
    #:load-bundle)
  (:import-from :innate.types
    #:make-innate-result
    #:innate-result-value
    #:innate-result-context
    #:make-resistance
    #:resistance-p
    #:resistance-message
    #:resistance-source)
  (:export
   #:stub-resolver
   #:make-stub-resolver
   #:stub-add-entity
   #:stub-add-wikilink
   #:stub-add-bundle
   #:stub-add-context
   #:stub-commissions))

(defpackage :innate.repl
  (:use :cl)
  (:import-from :innate.parser.tokenizer #:tokenize)
  (:import-from :innate.parser #:parse)
  (:import-from :innate.eval #:evaluate)
  (:import-from :innate.eval.resolver
    #:make-eval-env
    #:eval-env-resolver
    #:eval-env-decrees)
  (:import-from :innate.eval.stub-resolver
    #:make-stub-resolver
    #:stub-commissions)
  (:import-from :innate.types
    #:innate-result-value
    #:resistance-p
    #:resistance-message
    #:resistance-source)
  (:import-from :innate.conditions
    #:innate-parse-error
    #:innate-resistance
    #:parse-error-line
    #:parse-error-col
    #:resistance-condition-message
    #:resistance-condition-source)
  (:export #:repl #:run-file))

(defpackage :innate
  (:use :cl)
  (:import-from :innate.types)
  (:import-from :innate.conditions)
  (:import-from :innate.parser.tokenizer)
  (:import-from :innate.parser)
  (:import-from :innate.eval.resolver)
  (:import-from :innate.eval)
  (:import-from :innate.eval.stub-resolver)
  (:import-from :innate.repl)
  (:export))
