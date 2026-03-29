#!/usr/bin/env bash
# run-tests.sh — runs the full Innate test suite
# Usage: ./run-tests.sh [test-prefix]
#   test-prefix: optional string; only tests whose names contain this string are run
# Exit code: 0 = all tests pass, 1 = any failure

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CACHE_ROOT="${HOME}/.cache/common-lisp"
PROJECT_CACHE_SUFFIX="${SCRIPT_DIR#/}"

# Wipe only this project's FASL cache to ensure cold-load (RUN-05)
echo "Wiping project FASL cache entries under ${CACHE_ROOT} for ${SCRIPT_DIR}..."
if [ -d "${CACHE_ROOT}" ]; then
  find "${CACHE_ROOT}" -type d -path "*/${PROJECT_CACHE_SUFFIX}" -prune -exec rm -rf {} +
fi

PREFIX="${1:-}"

if [ -n "$PREFIX" ]; then
  PREFIX_FORM="\"${PREFIX}\""
else
  PREFIX_FORM="nil"
fi

echo "Loading innatescript/tests..."
sbcl --non-interactive \
  --eval "(require :asdf)" \
  --eval "(push #p\"${SCRIPT_DIR}/\" asdf:*central-registry*)" \
  --eval "(asdf:load-system :innatescript/tests)" \
  --eval "(let ((result (innate.tests:run-tests ${PREFIX_FORM})))
            (sb-ext:exit :code (if result 0 1)))" \
  2>&1
