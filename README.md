# Innate

**A scripting language of intention — markdown that runs.**

You write `.dpn` files that are simultaneously readable documents and executable programs. A human unfamiliar with any programming language should be able to make a reasonable guess at what an Innate program does — and that same program should execute.

```
[db[get_count[entry]]]
-> 52125
```

Read that as: *to db, regarding get_count, concerning entry.* Not a method call — a prepositional address. More like sending a letter than calling a function.

## What it looks like

Innate has three container types — **Place, Person, Thing**:

| Container | Syntax | Role | Feels like |
|-----------|--------|------|------------|
| Brackets | `[context[verb[args]]]` | context / navigation | *going somewhere* |
| Parentheses | `(name)` | agent address | *speaking to someone* |
| Braces | `{name}` | bundle / scope | *bringing something* |

Agents aren't functions. They get addressed, not called:

```
[noosphere[discuss_project(sylvia){burg_pipeline}]]
```

*To the noosphere: discuss the burg_pipeline project with Sylvia.*

Results flow out with `->`, prose passes through untouched, and `@` references connect documents to live data. The full syntax is in [`dpn-lang-spec.md`](dpn-lang-spec.md).

## Status

Early development, but the core interpreter is running.

Current state:

- Tokenizer, parser, evaluator, resolver protocol, stub resolver, REPL, and file runner are implemented.
- The project currently ships with a broad automated test suite covering tokenizer, parser, evaluator, resolver, and REPL behavior.
- The public API surface in `src/innate.lisp` is still minimal and should be expanded into a cleaner top-level entry point.

## Building

Requires [SBCL](http://www.sbcl.org/) (Steel Bank Common Lisp). No external dependencies — no Quicklisp, no third-party libraries.

```sh
# Load the system
sbcl --eval '(asdf:load-system "innatescript")' --quit

# Run tests
./run-tests.sh
```

## Project structure

```
innatescript.asd          # ASDF system definition
src/
  packages.lisp           # All package declarations
  types.lisp              # AST node/value/result structs and node-kind constants
  conditions.lisp         # Error/condition types
  parser/
    tokenizer.lisp        # Lexer — read-char/peek-char, no CL reader
    parser.lisp           # Hand-rolled recursive descent
  eval/
    resolver.lisp         # Pluggable resolver protocol (defgeneric)
    evaluator.lisp        # Two-pass: collect references, then resolve
    stub-resolver.lisp    # Default no-op resolver for testing
  repl.lisp               # Interactive REPL (read-line + handler-case)
  innate.lisp             # Top-level entry point
tests/
  test-framework.lisp     # Hand-rolled test harness
  smoke-test.lisp         # Harness verification tests
  test-tokenizer.lisp     # Tokenizer behavior and position tracking
  test-parser.lisp        # Parser structure and precedence
  test-resolver.lisp      # Resolver protocol defaults and eval-env
  test-stub-resolver.lisp # In-memory resolver conformance
  test-evaluator.lisp     # Two-pass evaluation semantics
  test-repl.lisp          # File runner and REPL integration
```

## Design decisions

- **Common Lisp (SBCL)** — Lisp is self-modifying by nature, which matters for a language designed to be written by its own agents. It's also a deliberate callback to AI's roots — the lineage from McCarthy through Minsky to modern agent systems. The current interpreter uses `defstruct` for AST/result types and `etypecase` dispatch in the evaluator.
- **Hand-rolled parser** — Innate's grammar mixes sigils, prose passthrough, and nested brackets. A recursive descent parser gives precise error messages and full control over whitespace handling. No parser generators.
- **Two-pass evaluation** — first pass collects `decree` definitions, second pass evaluates references and expressions. This allows forward references without declaration ordering.
- **Pluggable resolvers** — `defgeneric resolve-reference` lets any backend fulfill `@` references. The interpreter itself knows nothing about any specific substrate.
- **Zero dependencies** — follows AF64 conventions. ASDF + SBCL built-ins only. The test harness is three macros.

## Current priorities

The highest-value near-term work is:

1. Correct user-facing behavior in the REPL, especially resistance/error reporting.
2. Tighten the public API and documentation so they match the implementation.
3. Improve parser/evaluator data access patterns before larger inputs make list-based indexing expensive.
4. Narrow test-runner side effects such as wiping the full SBCL cache.

## License

MIT
