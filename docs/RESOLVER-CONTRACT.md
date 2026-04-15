# Resolver Protocol Contract

The resolver protocol defines the boundary between Innate (the language) and the substrate (whatever system agents live in). Every resolver is a CLOS subclass of `resolver` that specializes 8 generic functions.

## Architecture

```
Innate Evaluator
    |
    v
resolver (base class, 8 defgenerics)
    |
    +-- stub-resolver     (in-memory, for testing)
    +-- default-resolver   (file-based, for standalone use)
    +-- your-resolver      (your substrate — Postgres, APIs, etc.)
```

## Building a Resolver

1. Define a CLOS class that inherits from `resolver`
2. Specialize the 8 generic functions
3. Load your resolver's ASDF system alongside innatescript
4. Pass your resolver to `make-eval-env`

```lisp
(let* ((my-resolver (make-instance 'my-project:my-resolver))
       (env (innate.eval.resolver:make-eval-env :resolver my-resolver)))
  (innate.eval:evaluate ast env))
```

## The 8 Generics

### resolve-reference (resolver name qualifiers) -> result | resistance

Resolve a `@name` or `@name:qualifier` reference.

- **name**: string — the reference name (e.g., `"burg"` from `@burg`)
- **qualifiers**: list of strings — colon-separated qualifiers (e.g., `("type" "state")` from `@burg:type:state`)
- **Found**: return `(make-innate-result :value <data> :context :query)`
- **Not found**: return `(make-resistance :message "..." :source name)`
- **Note**: The evaluator checks named brackets first. Only unresolved references reach the resolver.

### resolve-search (resolver search-type terms) -> result | resistance

Resolve a `![search_expr]` search directive.

- **search-type**: keyword or string identifying the search kind
- **terms**: list of evaluated search term values (strings, cons pairs from kv-pairs)
- **Found**: return `(make-innate-result :value <list-of-matches> :context :query)`
- **Not found**: return resistance

### deliver-commission (resolver agent-name instruction) -> result

Deliver a `(agent){instruction}` commission to an agent.

- **agent-name**: string — the agent name
- **instruction**: string — the commission body
- **Always succeeds**: commissions are fire-and-forget. Return `(make-innate-result :value t :context :commission)`
- **Never returns resistance**: the agent handles success/failure internally

### resolve-wikilink (resolver title) -> result | resistance

Resolve a `[[Title]]` wikilink to its target.

- **title**: string — the wikilink title text
- **Found**: return `(make-innate-result :value <content> :context :query)`
- **Not found**: return resistance

### resolve-context (resolver context verb args) -> result | resistance

Resolve a `[context[verb[args]]]` bracket expression.

- **context**: string — the outermost bracket context
- **verb**: string — the verb/action
- **args**: list of evaluated argument values
- **Found**: return `(make-innate-result :value <result> :context :query)`
- **Not found**: return resistance
- **Note**: Context resolution is deeply substrate-specific. The default resolver returns resistance for all contexts.

### load-bundle (resolver name) -> nodes | nil

Load a `{bundle_name}` bundle by name.

- **name**: string — the bundle name
- **Found**: return a list of AST nodes (the bundle's parsed contents)
- **Not found**: return `nil` (not resistance)
- **Note**: The default resolver searches for `name.dpn` then `name.md` in the search path

### deliver-verification (resolver agent-name prior-output) -> result | resistance

Route verification to an agent via the `<-` operator.

- **agent-name**: string — the verifying agent
- **prior-output**: the output from the prior stage to be verified
- **Success**: return `(make-innate-result :value <corrections> :context :commission)`
- **Failure**: return resistance
- **Note**: The default resolver passes through prior-output as-is. A real resolver would route to the agent and return their corrections.

### schedule-at (resolver time expression) -> result | resistance

Schedule an expression for future evaluation via the `at` operator.

- **time**: string — the target time (wikilink date string or duration)
- **expression**: AST node — the expression to evaluate at that time
- **Success**: return `(make-innate-result :value <handle> :context :query)` where handle identifies the scheduled item
- **Failure**: return resistance

## Resolver Comparison

| Behavior | stub-resolver | default-resolver | your-resolver |
|----------|--------------|------------------|---------------|
| resolve-reference | Hash-table lookup | Internal registry | Your DB/API |
| load-bundle | Hash-table lookup | .dpn/.md file search | Your storage |
| resolve-wikilink | Hash-table lookup | vault-path file read | Your wiki/vault |
| deliver-commission | Records to list | Records to list | Your agent system |
| resolve-context | Hash-table lookup | Returns resistance | Your substrate |
| deliver-verification | Records to list | Pass-through | Your verification flow |
| schedule-at | Records to list | Records to list | Your scheduler |

## Loading an External Resolver

Your resolver lives in its own ASDF system. It depends on `:innatescript` for the protocol:

```lisp
(defsystem "my-resolver"
  :depends-on ("innatescript")
  :components ((:file "my-resolver")))
```

Your resolver file imports from `:innate.eval.resolver`:

```lisp
(defpackage :my-project.resolver
  (:use :cl)
  (:import-from :innate.eval.resolver
    #:resolver #:resolve-reference #:resolve-search
    #:deliver-commission #:resolve-wikilink #:resolve-context
    #:load-bundle #:deliver-verification #:schedule-at)
  (:import-from :innate.types
    #:make-innate-result #:make-resistance))
```

See `docs/examples/skeleton-resolver.lisp` for a complete minimal example.
