# Architecture Research

**Domain:** Common Lisp language interpreter with pluggable resolver protocol
**Researched:** 2026-03-27
**Confidence:** HIGH

## Standard Architecture

### System Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                        Entry Points                             │
│   ┌───────────────┐              ┌──────────────────────┐       │
│   │    REPL       │              │  Script Runner       │       │
│   │ (innate:repl) │              │ (innate:run-file)    │       │
│   └──────┬────────┘              └──────────┬───────────┘       │
└──────────┼───────────────────────────────────┼───────────────────┘
           │                                   │
           ▼                                   ▼
┌──────────────────────────────────────────────────────────────────┐
│                       Interpreter Pipeline                       │
│                                                                  │
│  ┌────────────┐    ┌────────────┐    ┌───────────────────────┐   │
│  │ Tokenizer  │───▶│  Parser   │───▶│      Evaluator        │   │
│  │(innate/    │    │(innate/   │    │  (innate/evaluator)   │   │
│  │ tokenizer) │    │ parser)   │    │                       │   │
│  │            │    │           │    │  Pass 1: decree scan  │   │
│  │ .dpn text  │    │  token    │    │  Pass 2: full eval    │   │
│  │     ↓      │    │  stream   │    │                       │   │
│  │  tokens    │    │     ↓     │    └──────────┬────────────┘   │
│  └────────────┘    │   AST    │               │                 │
│                    └────────────┘               │                 │
└─────────────────────────────────────────────────┼───────────────┘
                                                  │
                                                  ▼
┌─────────────────────────────────────────────────────────────────┐
│                     Resolver Protocol                           │
│              (innate/resolver — defgenerics only)               │
│                                                                  │
│   resolve-reference   resolve-search   fulfill-commission       │
│   resolve-decree      emit-result      ...                      │
└──────────────┬────────────────────────────────────┬────────────┘
               │                                    │
               ▼                                    ▼
┌──────────────────────┐              ┌─────────────────────────┐
│   Stub Resolver      │              │  Noosphere Resolver     │
│ (innate/stub-        │              │  (separate repo,        │
│  resolver)           │              │   not in this system)   │
│                      │              │                         │
│  In-memory alists,   │              │  Postgres + ghost       │
│  hashtables. For     │              │  roster. Implements     │
│  tests and docs.     │              │  same defgenerics.      │
└──────────────────────┘              └─────────────────────────┘
```

### Component Responsibilities

| Component | Responsibility | Implementation |
|-----------|----------------|----------------|
| `innate/tokenizer` | `.dpn` text → flat token stream. Recognizes `@`, `![]`, `\|\|`, `->`, `[]`, `()`, `{}`, `[[]]`, `decree`, `#`, `:`, `+` as distinct token types. No interpretation — only recognition. | Pure functions, no state. Single `tokenize` entry point taking a string. |
| `innate/ast` | Defines all AST node types via `defstruct`. The parser and evaluator share these structures. | `defstruct` for each node kind: `reference-node`, `search-node`, `fulfillment-node`, `emission-node`, `decree-node`, `wikilink-node`, `container-node`, `prose-node`, `qualifier-node`, `combinator-node`. |
| `innate/parser` | Token stream → AST. Recursive descent. Produces a list of top-level nodes. Reports syntax errors as `innate-parse-error` conditions. | One `parse-tokens` function, one `parse-<form>` function per grammar rule. No evaluator imports. |
| `innate/resolver` | Declares the resolver protocol via `defgeneric`. No implementations live here — only the contracts. | One `defgeneric` per protocol operation with full `:documentation` strings. Defines `innate-resolver` base class that all resolvers `defclass` from. |
| `innate/stub-resolver` | In-memory implementation of the resolver protocol. Used by tests and the default REPL. Stores entities in hashtables. | `defclass stub-resolver (innate-resolver)` + `defmethod` for every generic. No external dependencies. |
| `innate/evaluator` | Walks the AST. Two-pass: first collect all `decree` nodes (hoisting), then full evaluation. Holds the evaluation environment (bindings, current resolver, current scope). | `defgeneric eval-node (node environment)`. One `defmethod eval-node` per node type. `environment` is a struct carrying the resolver instance, decree table, and binding alist. |
| `innate/environment` | Defines the evaluation environment structure passed through the evaluator. Provides constructors and accessors. | `defstruct innate-environment` with slots: `resolver`, `decrees` (hashtable), `bindings` (alist), `scope`. |
| `innate/conditions` | All custom condition types for the system: parse errors, resolution errors, fulfillment signals, resistance errors. | `define-condition` forms. No other imports except `cl`. |
| `innate/repl` | Interactive read-eval-print loop. Reads `.dpn` expressions from stdin, runs the full pipeline, prints results. Manages REPL state (current resolver, history). | Calls `innate/tokenizer`, `innate/parser`, `innate/evaluator` in sequence. Handles conditions gracefully. Provides `:quit`, `:resolver`, `:reset` meta-commands. |
| `innate` (top-level) | Re-exports the public API: `run-file`, `run-string`, `make-repl`, `make-stub-resolver`. The only package external consumers need to `:use` or `:import-from`. | `packages.lisp` + re-export only. No implementation logic. |

## Recommended Project Structure

```
innatescript/
├── innatescript.asd          # ASDF system definition (explicit :depends-on, not :serial t)
├── packages.lisp             # All defpackage forms in load order
├── src/
│   ├── conditions.lisp       # innate/conditions — define-condition forms
│   ├── ast.lisp              # innate/ast — defstruct node types
│   ├── tokenizer.lisp        # innate/tokenizer — text → tokens
│   ├── parser.lisp           # innate/parser — tokens → AST
│   ├── environment.lisp      # innate/environment — evaluation env struct
│   ├── resolver.lisp         # innate/resolver — defgeneric protocol
│   ├── evaluator.lisp        # innate/evaluator — AST walker, two-pass
│   ├── stub-resolver.lisp    # innate/stub-resolver — in-memory impl
│   ├── repl.lisp             # innate/repl — interactive loop
│   └── api.lisp              # innate — public re-export surface
├── tests/
│   ├── package.lisp          # innate/tests package
│   ├── tokenizer-tests.lisp
│   ├── parser-tests.lisp
│   ├── evaluator-tests.lisp
│   └── stub-resolver-tests.lisp
├── scripts/
│   ├── run-repl.sh           # sbcl --load ... (invoke innate:start-repl)
│   └── run-tests.sh          # sbcl --load ... (invoke innate:run-tests)
└── examples/
    └── burg_pipeline.dpn
```

### Structure Rationale

- **`packages.lisp` at root:** All `defpackage` forms in a single file loaded first. This is idiomatic for explicit-component ASDF systems and avoids circular package definition issues. Load order is: conditions → ast → tokenizer → parser → environment → resolver → evaluator → stub-resolver → repl → api.
- **`src/` flat:** No subdirectories inside `src/`. The system is small enough that flat is clearer than nested. Subdirectories add ASDF module complexity with no benefit at this scale.
- **`tests/` as separate ASDF secondary system:** `innatescript/tests` depends on `innatescript`. Avoids loading test infrastructure in production loads. Tests import the stub resolver — no mocking needed because the stub IS the test backend.
- **`scripts/` shell scripts:** Per PROJECT.md constraints — no external Lisp dependencies. Shell scripts drive SBCL directly rather than requiring Quicklisp/Roswell/etc.
- **`api.lisp` as re-export surface:** External consumers (the noosphere resolver, future tools) import from `innate` only. The sub-packages `innate/evaluator`, `innate/parser`, etc. are internal. This preserves the ability to refactor internals without breaking consumers.

## Architectural Patterns

### Pattern 1: Protocol-First Generic Functions

**What:** The resolver protocol is declared entirely in `innate/resolver` as `defgeneric` forms with no `defmethod`. Implementations live in separate packages. The evaluator calls generics; it imports `innate/resolver` but no concrete resolver.

**When to use:** Whenever you need pluggable behavior — the evaluator must not know whether it's talking to the stub resolver or the noosphere resolver.

**Trade-offs:** Requires discipline: adding a new protocol operation means updating `innate/resolver` (the contract) and every implementation. Payoff is that a new resolver can be added without touching the evaluator.

**Example:**
```lisp
;; innate/resolver
(defgeneric resolve-reference (resolver reference-node environment)
  (:documentation "Look up a direct @reference. Return an innate value or signal
  innate-resolution-error if the reference cannot be resolved."))

(defgeneric resolve-search (resolver search-node environment)
  (:documentation "Execute a ![] search directive. Return a (possibly empty) list
  of innate values. Never signals an error — empty results trigger fulfillment."))

;; innate/stub-resolver
(defclass stub-resolver (innate-resolver)
  ((store :initform (make-hash-table :test #'equal))))

(defmethod resolve-reference ((r stub-resolver) node env)
  (gethash (reference-node-name node) (slot-value r 'store)))
```

### Pattern 2: Two-Pass Evaluation via Separate Scan

**What:** The evaluator makes two passes over the top-level AST node list. Pass 1 (`collect-decrees`) walks only looking for `decree-node` instances, populating the `environment-decrees` hashtable. Pass 2 (`eval-toplevel-list`) evaluates all nodes in order, with decrees already available.

**When to use:** Required for hoisting — `@type:"[[Burg]]"` can appear before the `decree burg-pipeline ...` that defines the `Burg` type in the same file.

**Trade-offs:** Slightly more complex evaluator entry point. Does not require a full two-pass compiler — just a linear scan for decree nodes before evaluation. Decree bodies are evaluated lazily on first reference, not during the scan.

**Example:**
```lisp
(defun evaluate-program (ast-nodes resolver)
  (let ((env (make-innate-environment :resolver resolver
                                      :decrees (make-hash-table :test #'equal)
                                      :bindings nil)))
    ;; Pass 1: hoist decree definitions
    (dolist (node ast-nodes)
      (when (decree-node-p node)
        (setf (gethash (decree-node-name node)
                       (innate-environment-decrees env))
              node)))
    ;; Pass 2: full evaluation
    (mapcar (lambda (node) (eval-node node env)) ast-nodes)))
```

### Pattern 3: Environment Threading (Not Dynamic Variables)

**What:** The evaluation environment is threaded explicitly through every `eval-node` call as a parameter, not stored in a `defvar` or `*special-variable*`. Scope extension creates a new environment struct with an extended bindings alist.

**When to use:** Required for the `+` combinator which extends scope — `@thing + @otherthing` creates a combined scope that only lasts for the expression. Dynamic variables would make scope management error-prone across recursive calls.

**Trade-offs:** More verbose call signatures. Every `defmethod eval-node` takes `(node env)`. Payoff is that scope is always explicit and testable without mocking globals.

**Example:**
```lisp
(defmethod eval-node ((node combinator-node) env)
  (let* ((left-val  (eval-node (combinator-node-left  node) env))
         (right-val (eval-node (combinator-node-right node) env))
         (extended-env (extend-environment env left-val right-val)))
    (eval-node (combinator-node-body node) extended-env)))
```

### Pattern 4: Conditions for Resistance Error Model

**What:** Innate's "resistance" error model (structural failures propagate; missing resources trigger fulfillment rather than errors) maps cleanly onto Common Lisp's condition system. `innate-resolution-error` is a `serious-condition`. `innate-fulfillment-signal` is a `condition` (not an error) — it signals that a `||` fulfillment is needed.

**When to use:** Everywhere in the evaluator and resolver. This is the mechanism that distinguishes `![]` search (returns empty, triggers fulfillment) from `@reference` failure (propagates as an error).

**Trade-offs:** Requires callers to use `handler-case` or `handler-bind` appropriately. The REPL must handle both conditions gracefully. Well worth it — the condition system is one of Common Lisp's major advantages over exception-only languages.

## Data Flow

### Script Evaluation Flow

```
.dpn file on disk
    |
    | (read-file-into-string)
    v
Raw string
    |
    | (innate/tokenizer:tokenize string)
    v
List of token structs: (type value position)
    |
    | (innate/parser:parse-tokens tokens)
    v
List of AST node structs (defstruct instances)
    |
    | (innate/evaluator:evaluate-program nodes resolver)
    |
    |-- Pass 1: scan for decree-node → populate environment-decrees hashtable
    |
    |-- Pass 2: (eval-node node env) for each node
    |            |
    |            | dispatch via CLOS on node type
    |            |
    |            +-- reference-node → (resolve-reference resolver node env)
    |            +-- search-node   → (resolve-search resolver node env)
    |            +-- decree-node   → install in env (already hoisted, idempotent)
    |            +-- emission-node → collect result, return via →
    |            +-- prose-node    → passthrough, return nil
    |            +-- fulfillment-node → (resolve-search ...) → if empty, signal
    |                                   innate-fulfillment-signal
    v
List of evaluation results (innate values or nil for prose)
    |
    | (format-results results)
    v
Output to stdout or caller
```

### REPL Flow

```
User input (one expression or block)
    |
    | tokenize → parse → evaluate-program (single-expression mode)
    v
Result value
    |
    | print result
    v
Prompt again (loop)
    |
    | Condition handlers around eval:
    |   innate-parse-error      → print error, continue loop
    |   innate-resolution-error → print error, continue loop
    |   innate-fulfillment-signal → print "commission queued: X", continue
```

### Resolver Protocol Data Flow

```
evaluator calls (resolve-reference resolver node env)
    |
    +── stub-resolver defmethod:
    |       lookup name in hashtable
    |       return value or nil
    |
    +── noosphere-resolver defmethod (external repo):
            call dpn-api-client via IPC
            deserialize response
            return innate value
```

## Suggested Build Order

Dependencies flow strictly upward. Each layer can be built and tested before the next.

```
1. innate/conditions     (no imports from this system)
        |
2. innate/ast            (imports: innate/conditions)
        |
3. innate/tokenizer      (imports: innate/conditions)
        |
4. innate/parser         (imports: innate/ast, innate/conditions, innate/tokenizer)
        |
5. innate/environment    (imports: innate/ast)
        |
6. innate/resolver       (imports: innate/ast, innate/environment, innate/conditions)
        |
7. innate/evaluator      (imports: innate/resolver, innate/environment, innate/ast,
        |                          innate/conditions)
        |
8. innate/stub-resolver  (imports: innate/resolver, innate/ast, innate/conditions)
        |
9. innate/repl           (imports: innate/tokenizer, innate/parser, innate/evaluator,
        |                          innate/stub-resolver, innate/conditions)
        |
10. innate (api.lisp)    (re-exports from all above — no new logic)
```

**Rationale for this order:**
- `conditions` and `ast` first because everything depends on them. You cannot define a `parse-error` in `tokenizer.lisp` if `innate/conditions` isn't loaded.
- `resolver` before `evaluator`: the evaluator calls protocol generics. The generics must be defined before the call sites.
- `stub-resolver` after `evaluator` (not before): the evaluator imports the protocol, not any implementation. The stub can come after because the evaluator never imports `innate/stub-resolver`.
- `repl` last among implementation files: it assembles the full pipeline. It is the only component that imports both the tokenizer and the evaluator.

**Testability at each layer:**
- Tokenizer: test with raw strings, no resolver needed.
- Parser: test with token lists from the tokenizer, no resolver needed.
- Evaluator: test with stub-resolver and hand-crafted AST nodes.
- Stub-resolver: test independently with resolver protocol calls.
- REPL: integration test with .dpn strings end-to-end.

## ASDF System Definition Pattern

```lisp
;; innatescript.asd
(asdf:defsystem "innatescript"
  :description "Innate — a scripting language of intention"
  :author "Nathan Eckenrode"
  :license "TBD"
  :version "0.1.0"
  :components
  ((:file "packages")
   (:file "src/conditions"       :depends-on ("packages"))
   (:file "src/ast"              :depends-on ("packages" "src/conditions"))
   (:file "src/tokenizer"        :depends-on ("packages" "src/conditions"))
   (:file "src/parser"           :depends-on ("packages" "src/ast"
                                               "src/tokenizer" "src/conditions"))
   (:file "src/environment"      :depends-on ("packages" "src/ast"))
   (:file "src/resolver"         :depends-on ("packages" "src/ast"
                                               "src/environment" "src/conditions"))
   (:file "src/evaluator"        :depends-on ("packages" "src/resolver"
                                               "src/environment" "src/ast"
                                               "src/conditions"))
   (:file "src/stub-resolver"    :depends-on ("packages" "src/resolver"
                                               "src/ast" "src/conditions"))
   (:file "src/repl"             :depends-on ("packages" "src/tokenizer"
                                               "src/parser" "src/evaluator"
                                               "src/stub-resolver" "src/conditions"))
   (:file "src/api"              :depends-on ("packages" "src/repl"
                                               "src/evaluator" "src/stub-resolver"))))

(asdf:defsystem "innatescript/tests"
  :depends-on ("innatescript")
  :components
  ((:file "tests/package")
   (:file "tests/tokenizer-tests" :depends-on ("tests/package"))
   (:file "tests/parser-tests"    :depends-on ("tests/package"))
   (:file "tests/evaluator-tests" :depends-on ("tests/package"))
   (:file "tests/stub-resolver-tests" :depends-on ("tests/package"))))
```

**Why explicit `:depends-on` not `:serial t`:** With `:serial t`, any reordering breaks the build silently. Explicit dependencies make the load graph visible and allow ASDF to parallelize if ever needed. The cost is verbosity; it is worth it.

**Why not `package-inferred-system`:** The PROJECT.md constraint "no external dependencies / AF64 conventions / hand-rolled everything" aligns with explicit component ASDF, not the package-inferred extension. Package-inferred-system is convenient but requires careful attention to package naming conventions. The explicit style is simpler for a focused single-purpose system.

## Anti-Patterns

### Anti-Pattern 1: Evaluator Importing a Concrete Resolver

**What people do:** `(defpackage :innate/evaluator (:use :cl :innate/stub-resolver))` — importing the stub directly into the evaluator so it "just works."

**Why it's wrong:** Locks the evaluator to one backend. The point of the resolver protocol is that the evaluator is backend-agnostic. Now you cannot swap in the noosphere resolver without modifying the evaluator.

**Do this instead:** Evaluator imports only `innate/resolver` (the protocol). The resolver instance is passed in at runtime via `evaluate-program`'s `resolver` parameter.

### Anti-Pattern 2: Using `*special-variable*` for Evaluation State

**What people do:** `(defvar *current-resolver* nil)` and `(defvar *current-environment* nil)` set by the REPL before calling eval functions.

**Why it's wrong:** Makes the evaluator non-reentrant. A future where two REPL sessions run in the same image, or where the evaluator calls itself recursively (evaluation of decree bodies, for example), breaks with mysterious variable-binding bugs. Common Lisp's dynamic variables are global in ways that hurt here.

**Do this instead:** Thread the `innate-environment` struct explicitly through every `eval-node` call. The struct is immutable except for the decree hashtable (populated in pass 1 only). Scope extension creates new structs with `copy-innate-environment` and an extended bindings alist.

### Anti-Pattern 3: Mixing Parse Errors and Resolution Errors into One Condition Type

**What people do:** One `innate-error` condition with a `:phase` slot to distinguish tokenizer errors from resolver errors.

**Why it's wrong:** Callers (especially the REPL) need to handle parse errors differently from resolution errors. A parse error means the input was malformed — show a syntax hint and reprompt. A resolution error means the script was valid but referenced something unavailable — possibly trigger fulfillment. One condition type forces callers to inspect slots rather than using condition hierarchy dispatch.

**Do this instead:** Define a condition hierarchy: `innate-error` (base) → `innate-parse-error`, `innate-resolution-error`, `innate-fulfillment-signal` (not an error at all — a signal). The REPL uses separate `handler-case` clauses for each.

### Anti-Pattern 4: Prose Passthrough as a Special Case in the Evaluator

**What people do:** Check `(stringp node)` or `(eq (node-type node) :prose)` inline throughout the evaluator's main dispatch.

**Why it's wrong:** Scatters the prose decision across every eval path. `prose-node` is a first-class AST node type — it deserves a `defmethod eval-node ((node prose-node) env)` that simply returns `nil` (or the prose string if the caller wants it). CLOS dispatch handles it cleanly.

**Do this instead:** Define `prose-node` as a `defstruct` in `innate/ast`. Add `(defmethod eval-node ((node prose-node) env) nil)` in the evaluator. Every node type is treated uniformly.

## Integration Points

### Internal Boundaries

| Boundary | Communication | Notes |
|----------|---------------|-------|
| tokenizer → parser | List of token structs (defstruct) | Parser does not call back into tokenizer; takes a pre-computed list. |
| parser → evaluator | List of AST node structs (defstruct) | Evaluator does not call back into parser. AST is complete before evaluation starts. |
| evaluator ↔ resolver | CLOS generic function calls | Evaluator holds a resolver instance in the environment struct. Calls generics. Resolver methods can signal conditions that evaluator handlers catch. |
| evaluator → environment | Struct slot access via generated accessors | No setter calls during pass 2 evaluation except for emission collection. |
| REPL → pipeline | Function calls: `tokenize` → `parse-tokens` → `evaluate-program` | REPL is the only component that assembles the full pipeline. |
| public api → internals | Re-export only; no new logic in `api.lisp` | External consumers (noosphere resolver) import `innate`, not `innate/evaluator` directly. |

### External Boundaries

| Boundary | How Crossed | Notes |
|----------|-------------|-------|
| Noosphere resolver (separate repo) | Implements `innate/resolver` defgenerics. Imports `innatescript` as an ASDF dependency. | This is the intended extension point. The resolver calls dpn-api-client IPC. |
| SBCL runtime | `sbcl --load` in shell scripts | No SBCL-specific APIs used inside the interpreter itself. Should be portable Common Lisp, but SBCL is the target. |
| `.dpn` files | `read-file-into-string`, then tokenize | Files are UTF-8 strings. No binary reading. |

## Sources

- [ASDF Package-Inferred-System Extension](https://asdf.common-lisp.dev/asdf/The-package_002dinferred_002dsystem-extension.html) — HIGH confidence, official documentation
- [ASDF Best Practices](https://github.com/fare/asdf/blob/master/doc/best_practices.md) — HIGH confidence, official ASDF repository
- [Common Lisp Cookbook: Defining Systems](https://lispcookbook.github.io/cl-cookbook/systems.html) — HIGH confidence, widely maintained community reference
- [CL Crafting Interpreters (cl-crafting-interpreters)](https://github.com/gwangjinkim/cl-crafting-interpreters) — MEDIUM confidence, implementation reference showing CLOS-based AST evaluation pattern
- [Common Lisp Cookbook: Fundamentals of CLOS](https://lispcookbook.github.io/cl-cookbook/clos.html) — HIGH confidence, authoritative CLOS reference
- [ASDF Manual](https://asdf.common-lisp.dev/asdf.html) — HIGH confidence, official documentation

---
*Architecture research for: Innate language interpreter (Common Lisp)*
*Researched: 2026-03-27*
