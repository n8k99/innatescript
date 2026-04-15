;;;; skeleton-resolver.lisp — Minimal resolver template for external projects
;;;; Copy this file to your project and specialize each method for your substrate.

(defpackage :my-project.resolver
  (:use :cl)
  (:import-from :innate.eval.resolver
    #:resolver
    #:resolve-reference
    #:resolve-search
    #:deliver-commission
    #:resolve-wikilink
    #:resolve-context
    #:load-bundle
    #:deliver-verification
    #:schedule-at)
  (:import-from :innate.types
    #:make-innate-result
    #:make-resistance)
  (:export #:my-resolver #:make-my-resolver))

(in-package :my-project.resolver)

;;; Your resolver class — add slots for your substrate connections
(defclass my-resolver (resolver)
  ((connection :initarg :connection
               :accessor resolver-connection
               :documentation "Your substrate connection (DB handle, API client, etc.)"))
  (:documentation "Resolver for my-project. Connects Innate to my substrate."))

(defun make-my-resolver (&key connection)
  (make-instance 'my-resolver :connection connection))

;;; Specialize each generic for your substrate

(defmethod resolve-reference ((r my-resolver) name qualifiers)
  ;; Look up @name in your data store
  ;; qualifiers is a list of strings from @name:qual1:qual2
  (declare (ignore qualifiers))
  (make-resistance :message (format nil "TODO: resolve ~a in my substrate" name)
                   :source name))

(defmethod resolve-search ((r my-resolver) search-type terms)
  ;; Execute a search against your data
  (declare (ignore search-type terms))
  (make-resistance :message "TODO: implement search" :source "search"))

(defmethod deliver-commission ((r my-resolver) agent-name instruction)
  ;; Route commission to your agent system
  ;; Always return innate-result (commissions never fail at protocol level)
  (format t "Commission: ~a -> ~a~%" agent-name instruction)
  (make-innate-result :value t :context :commission))

(defmethod resolve-wikilink ((r my-resolver) title)
  ;; Resolve [[Title]] against your wiki/vault/knowledge base
  (make-resistance :message (format nil "TODO: resolve wikilink ~a" title)
                   :source title))

(defmethod resolve-context ((r my-resolver) context verb args)
  ;; Evaluate [context[verb[args]]] against your substrate
  (declare (ignore verb args))
  (make-resistance :message (format nil "TODO: resolve context ~a" context)
                   :source (format nil "~a" context)))

(defmethod load-bundle ((r my-resolver) name)
  ;; Load a named bundle (script/procedure) from your storage
  ;; Return a list of AST nodes, or nil if not found
  nil)

(defmethod deliver-verification ((r my-resolver) agent-name prior-output)
  ;; Route verification to agent, return corrections
  (declare (ignore prior-output))
  (make-resistance :message (format nil "TODO: verification by ~a" agent-name)
                   :source agent-name))

(defmethod schedule-at ((r my-resolver) time expression)
  ;; Schedule expression for future evaluation
  (declare (ignore expression))
  (make-resistance :message (format nil "TODO: schedule at ~a" time)
                   :source (format nil "~a" time)))
