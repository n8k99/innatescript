#!/usr/bin/env bash
# run-repl.sh — start the Innate REPL or evaluate a .dpn file
# Usage:
#   ./run-repl.sh              — start interactive REPL
#   ./run-repl.sh file.dpn     — evaluate file and exit
#   rlwrap ./run-repl.sh       — REPL with line editing

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ -n "$1" ]; then
  # File mode: resolve path relative to current working directory if not absolute
  FILE_PATH="$1"
  if [[ "$FILE_PATH" != /* ]]; then
    FILE_PATH="$(pwd)/${FILE_PATH}"
  fi

  # Evaluate the file and print results, then exit
  sbcl --noinform \
    --non-interactive \
    --eval "(require :asdf)" \
    --eval "(push #p\"${SCRIPT_DIR}/\" asdf:*central-registry*)" \
    --eval "(let ((*standard-output* (make-broadcast-stream)) (*error-output* (make-broadcast-stream))) (asdf:load-system :innatescript))" \
    --eval "(let* ((env (innate.eval.resolver:make-eval-env :resolver (innate.eval.stub-resolver:make-stub-resolver))) (results (innate.repl:run-file \"${FILE_PATH}\" env))) (dolist (r results) (innate.repl:print-result r)) (sb-ext:exit :code 0))" \
    2>&1
else
  # Interactive mode: keep SBCL alive so read-line works from stdin
  # Do NOT use --non-interactive — that disables stdin read-line
  sbcl --noinform \
    --eval "(require :asdf)" \
    --eval "(push #p\"${SCRIPT_DIR}/\" asdf:*central-registry*)" \
    --eval "(let ((*standard-output* (make-broadcast-stream)) (*error-output* (make-broadcast-stream))) (asdf:load-system :innatescript))" \
    --eval "(innate.repl:repl)" \
    --eval "(sb-ext:exit :code 0)"
fi
