;;;; packages.lisp — all package definitions for the Innate interpreter
;;;; Loaded first by ASDF. Every cross-package import uses :import-from — never :use.

(defpackage :innate.types
  (:use :cl)
  (:export))

(defpackage :innate.conditions
  (:use :cl)
  (:import-from :innate.types)
  (:export))

(defpackage :innate.parser.tokenizer
  (:use :cl)
  (:export))

(defpackage :innate.parser
  (:use :cl)
  (:import-from :innate.parser.tokenizer)
  (:export))

(defpackage :innate.eval.resolver
  (:use :cl)
  (:import-from :innate.types)
  (:import-from :innate.conditions)
  (:export))

(defpackage :innate.eval
  (:use :cl)
  (:import-from :innate.eval.resolver)
  (:import-from :innate.types)
  (:import-from :innate.conditions)
  (:export))

(defpackage :innate.eval.stub-resolver
  (:use :cl)
  (:import-from :innate.eval.resolver)
  (:export))

(defpackage :innate.repl
  (:use :cl)
  (:import-from :innate.eval)
  (:import-from :innate.conditions)
  (:export))

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
