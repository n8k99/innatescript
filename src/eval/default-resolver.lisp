(in-package :innate.eval.default-resolver)

;;; Default resolver — file-based resolver for standalone Innate use
;;; Loads .dpn and .md files as bundles, resolves wikilinks to markdown files

(defclass default-resolver (resolver)
  ((search-path  :initarg :search-path
                 :initform (list (truename "."))
                 :accessor resolver-search-path
                 :documentation "List of directory pathnames to search for bundle files")
   (vault-path   :initarg :vault-path
                 :initform nil
                 :accessor resolver-vault-path
                 :documentation "Directory pathname for wikilink resolution")
   (commissions  :initform nil
                 :accessor default-commissions
                 :documentation "In-memory log of delivered commissions")
   (verifications :initform nil
                  :accessor default-verifications)
   (schedules    :initform nil
                 :accessor default-schedules)
   (registry     :initform (make-hash-table :test 'equal)
                 :accessor default-registry
                 :documentation "Named bracket registry for reference resolution"))
  (:documentation "File-based resolver for standalone Innate use. Loads bundles from
search-path directories, resolves wikilinks from vault-path."))

(defun make-default-resolver (&key (search-path (list ".")) vault-path)
  "Create a default resolver with configurable search path and vault path."
  (make-instance 'default-resolver
                 :search-path (mapcar #'truename
                                      (if (listp search-path) search-path (list search-path)))
                 :vault-path (when vault-path (truename vault-path))))

;;; Helper: find a file in search path

(defun %find-file-in-path (name extensions search-path)
  "Search SEARCH-PATH directories for NAME with any of EXTENSIONS.
Returns the first matching pathname, or nil."
  (dolist (dir search-path)
    (dolist (ext extensions)
      (let ((path (merge-pathnames (concatenate 'string name ext) dir)))
        (when (probe-file path)
          (return-from %find-file-in-path (probe-file path))))))
  nil)

(defun %read-file-to-string (path)
  "Read entire file at PATH into a string."
  (with-open-file (stream path :direction :input :external-format :utf-8)
    (let ((contents (make-string (file-length stream))))
      (read-sequence contents stream)
      contents)))

;;; Protocol specializations

(defmethod load-bundle ((r default-resolver) name)
  "Load a bundle by searching for name.dpn or name.md in the search path."
  (let ((path (%find-file-in-path name '(".dpn" ".md") (resolver-search-path r))))
    (when path
      (let* ((source (%read-file-to-string path))
             (tokens (tokenize source))
             (ast (parse tokens)))
        (node-children ast)))))

(defmethod resolve-wikilink ((r default-resolver) title)
  "Resolve a [[wikilink]] by reading Title.md from vault-path."
  (let ((vault (resolver-vault-path r)))
    (if vault
        (let ((path (merge-pathnames (concatenate 'string title ".md") vault)))
          (if (probe-file path)
              (make-innate-result :value (%read-file-to-string (probe-file path))
                                 :context :query)
              (make-resistance :message (format nil "Wikilink not found: ~a" title)
                               :source title)))
        (make-resistance :message (format nil "No vault-path configured for wikilink: ~a" title)
                         :source title))))

(defmethod resolve-reference ((r default-resolver) name qualifiers)
  "Resolve a @reference: check internal registry first, then try loading name.dpn/.md from search path."
  (declare (ignore qualifiers))
  (let ((entry (gethash name (default-registry r))))
    (if entry
        (make-innate-result :value entry :context :query)
        ;; Fall through: try loading as a file (same as load-bundle)
        (let ((nodes (load-bundle r name)))
          (if nodes
              (make-innate-result :value nodes :context :query)
              (make-resistance :message (format nil "Reference not found: ~a" name)
                               :source name))))))

(defmethod resolve-search ((r default-resolver) search-type terms)
  "Search vault-path for files matching terms."
  (declare (ignore search-type))
  (let ((vault (resolver-vault-path r)))
    (if vault
        (let ((matches nil))
          (dolist (term terms)
            (when (stringp term)
              (let ((path (merge-pathnames (concatenate 'string term ".md") vault)))
                (when (probe-file path)
                  (push (%read-file-to-string (probe-file path)) matches)))))
          (if matches
              (make-innate-result :value (nreverse matches) :context :query)
              (make-resistance :message (format nil "No files match search: ~a" terms)
                               :source (format nil "~a" terms))))
        (make-resistance :message "No vault-path configured for search"
                         :source (format nil "~a" terms)))))

(defmethod deliver-commission ((r default-resolver) agent-name instruction)
  "Record commission to in-memory log."
  (setf (default-commissions r)
        (append (default-commissions r) (list (list agent-name instruction))))
  (make-innate-result :value t :context :commission))

(defmethod deliver-verification ((r default-resolver) agent-name prior-output)
  "Pass-through verification — return prior output as corrections."
  (setf (default-verifications r)
        (append (default-verifications r) (list (list agent-name prior-output))))
  (make-innate-result :value prior-output :context :commission))

(defmethod schedule-at ((r default-resolver) time expression)
  "Record schedule to in-memory list."
  (let ((handle (1+ (length (default-schedules r)))))
    (setf (default-schedules r)
          (append (default-schedules r) (list (list time expression handle))))
    (make-innate-result :value handle :context :query)))

(defmethod resolve-context ((r default-resolver) context verb args)
  "Context resolution is substrate-specific — return resistance."
  (declare (ignore verb args))
  (make-resistance :message (format nil "Context resolution not available in default resolver: ~a" context)
                   :source (format nil "~a" context)))
