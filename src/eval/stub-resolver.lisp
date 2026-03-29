(in-package :innate.eval.stub-resolver)

;;; Stub resolver — fully conforming in-memory implementation for testing
;;; Specializes all 6 Phase 5 defgenerics. NOT a mock — handles edge cases correctly.

(defclass stub-resolver (resolver)
  ((entities    :initform (make-hash-table :test 'equal)
                :accessor stub-entities)
   (commissions :initform nil
                :accessor stub-commissions)
   (wikilinks   :initform (make-hash-table :test 'equal)
                :accessor stub-wikilinks)
   (bundles     :initform (make-hash-table :test 'equal)
                :accessor stub-bundles)
   (contexts    :initform (make-hash-table :test 'equal)
                :accessor stub-contexts))
  (:documentation "In-memory resolver for testing. Stores entities as plists,
records commissions in delivery order, and resolves all 6 protocol generics
against hash-tables. This is a correct implementation, not a fixture."))

(defun make-stub-resolver ()
  "Create a fresh stub-resolver with empty stores."
  (make-instance 'stub-resolver))

;;; Seeding helpers

(defun stub-add-entity (resolver name plist)
  "Add an entity to the stub's entity store. NAME is a string, PLIST is a property list."
  (setf (gethash name (stub-entities resolver)) plist))

(defun stub-add-wikilink (resolver title content)
  "Add a wikilink resolution. TITLE and CONTENT are strings."
  (setf (gethash title (stub-wikilinks resolver)) content))

(defun stub-add-bundle (resolver name nodes)
  "Add a bundle. NAME is a string, NODES is a list of AST nodes."
  (setf (gethash name (stub-bundles resolver)) nodes))

(defun stub-add-context (resolver context verb result)
  "Add a context resolution. Builds compound key 'context.verb'."
  (setf (gethash (format nil "~a.~a" context verb) (stub-contexts resolver)) result))

;;; Protocol specializations

(defmethod resolve-reference ((r stub-resolver) name qualifiers)
  (let ((entity (gethash name (stub-entities r))))
    (if entity
        (if (null qualifiers)
            (make-innate-result :value entity :context :query)
            ;; Walk qualifier chain — single level for v1
            ;; Case-insensitive: intern as keyword using string-upcase
            (let* ((qual (first qualifiers))
                   (key (intern (string-upcase qual) :keyword))
                   (val (getf entity key)))
              (if val
                  (make-innate-result :value val :context :query)
                  (make-resistance
                   :message (format nil "Entity ~a has no property ~a" name qual)
                   :source (format nil "~a:~a" name qual)))))
        (make-resistance
         :message (format nil "Entity not found: ~a" name)
         :source name))))

(defmethod resolve-search ((r stub-resolver) search-type terms)
  (declare (ignore search-type))
  ;; Filter entities: each term is a cons pair (key . value) from kv-pair evaluation
  ;; Collect entities whose plists match all terms
  (let ((matches nil))
    (maphash (lambda (name entity)
               (declare (ignore name))
               (let ((match t))
                 (dolist (term terms)
                   (when (consp term)
                     (let* ((term-key (car term))
                            ;; Handle both (key . value) cons and (key value) list
                            (term-val (if (consp (cdr term))
                                          (cadr term)    ; list format
                                          (cdr term)))   ; cons format
                            (key (intern (string-upcase (if (stringp term-key) term-key (format nil "~a" term-key))) :keyword))
                            (val (getf entity key)))
                       (unless (and val (if (stringp term-val)
                                            (string-equal val term-val)
                                            (equal val term-val)))
                         (setf match nil)))))
                 (when match
                   (push entity matches))))
             (stub-entities r))
    (if matches
        (make-innate-result :value (nreverse matches) :context :query)
        (make-resistance
         :message (format nil "No entities match search: ~a" terms)
         :source (format nil "~a" terms)))))

(defmethod deliver-commission ((r stub-resolver) agent-name instruction)
  ;; Record in delivery order — append to end of list
  (setf (stub-commissions r)
        (append (stub-commissions r) (list (list agent-name instruction))))
  (make-innate-result :value t :context :commission))

(defmethod resolve-wikilink ((r stub-resolver) title)
  (let ((content (gethash title (stub-wikilinks r))))
    (if content
        (make-innate-result :value content :context :query)
        (make-resistance
         :message (format nil "Wikilink not found: ~a" title)
         :source title))))

(defmethod resolve-context ((r stub-resolver) context verb args)
  (declare (ignore args))
  (let* ((key (format nil "~a.~a" context verb))
         (result (gethash key (stub-contexts r))))
    (if result
        (make-innate-result :value result :context :query)
        (make-resistance
         :message (format nil "Context not found: ~a" key)
         :source key))))

(defmethod load-bundle ((r stub-resolver) name)
  (gethash name (stub-bundles r)))
