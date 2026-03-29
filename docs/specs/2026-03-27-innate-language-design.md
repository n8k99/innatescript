# Innate Language Design Spec

*Markdown that runs. A language of intention for sovereign infrastructure.*

---

## What Innate Is

Innate is a scripting language where the script is a living template. A `.dpn` file is a document that *becomes complete* when evaluated — references resolve, missing resources get commissioned, and what comes out is a rendered result, a workflow scope, or a UI definition. The same expression serves all three purposes depending on evaluation context.

Innate is generic. The language knows nothing about any specific database, agent framework, or presentation layer. It defines a protocol for resolution and commission. Specific systems (like the Dragonpunk noosphere) implement resolvers that connect Innate's symbols to their infrastructure.

The test of an Innate program: a human unfamiliar with any programming language should be able to make a reasonable guess at what it does.

---

## Core Syntax: The Symbol Vocabulary

### The Container Trinity

| Container | Syntax | Role | Feels Like |
|-----------|--------|------|------------|
| Brackets | `[name[...]]` | Context / navigation / invocation | *going somewhere* |
| Parentheses | `(name)` | Agent address / commission | *speaking to someone* |
| Braces | `{name}` | Bundle / scope / lens | *bringing something / looking through something* |

**Place, Person, Thing.**

### Resolution and Reference Symbols

| Symbol | Name | Role | Example |
|--------|------|------|---------|
| `@` | Direct reference | Resolve a known entity | `@boughrest` |
| `![]` | Search directive | Find something that may or may not exist | `![image("emblem" + name + png)]` |
| `[[]]` | Wikilink | Document reference in the vault | `[[Akar Ok]]` |
| `->` | Emission | Results flow out | `-> "Seed"` |
| `\|\|` | Fulfillment | If resolution fails, commission an agent | `![...] \|\| (vincent){create it}` |
| `+` | Combinator | Extend scope | `+all` |
| `:` | Property / qualifier | Natural-language delimiter on references | `@Alaran:generative hard prompt` |
| `#` | Heading / display | Presentation directive | `#header[burg_name]` |

### How Symbols Compose

```dpn
@type:"[[Burg]]"+all{state:==}
```

Reads as: "All entities of type Burg, full set, grouped by matching state."

- `@type:"[[Burg]]"` — resolve all entities typed as Burg
- `+all` — combinator: expand to full set
- `{state:==}` — lens: group by identical state values

This single expression is simultaneously:
- A **query** (at a REPL: show me Burgs grouped by state)
- A **scope** (in a template: apply the following to each group)
- A **presentation** (as a file: this is a kanban board)

---

## Reference Resolution

### The `@` Symbol

`@` resolves a named entity. References are **hoisted** — an `@` can refer to something defined later in the same script, earlier, or in the database. The interpreter fully parses a `.dpn` file before resolving any references.

Resolution order:
1. Current script's declarations (any position)
2. Other loaded/registered scripts
3. Database (or whatever backing store the resolver is configured for)

```dpn
decree boughrest [
    type: "[[Burg]]"
    Lifestage: "Seed"
    description: @Alaran:generative hard prompt
]

@boughrest.Lifestage -> "Seed"
```

The `:` after an `@` reference is a natural-language qualifier, not a dot-accessor. `@Alaran:generative hard prompt` reads as "from Alaran, the generative hard prompt."

### The `![]` Search Directive

`![]` searches for something that may not exist. Unlike `@`, a failed `![]` is not an error — it's an opportunity for fulfillment.

```dpn
![image("emblem" + burg_name + png)] || (vincent){create emblem for burg_name}
```

If the image exists, it resolves. If not, the `||` fulfillment operator commissions Vincent to create it. Unresolved searches become work orders, not errors.

### The `[[]]` Wikilink

Document references in the vault/content graph. A native type. The resolver knows how to find documents by wikilink title.

---

## Agent Address and Commission

Parentheses designate an agent — a named entity with judgment:

```dpn
(sylvia){write editorial for [[Akar Ok]]}
```

Sylvia is not a function. She is addressed, not called. The parenthesis syntax marks delegation.

When combined with `||`, agent address becomes **fulfillment** — the world doesn't have what you need, so you commission someone to make it:

```dpn
![image("emblem" + @burg_name + png)] || (vincent){create emblem for @burg_name}
```

The commission is delivered through whatever messaging system the resolver provides (in the noosphere: the `conversations` table).

---

## Bundles and Lenses

Braces carry a bundle — something brought into an expression:

```dpn
{burg_pipeline}
```

Resolves to a registered `.dpn` script. When evaluated, the bundle loads and runs that script.

Braces also act as **lenses** — filters or groupings applied to a result set:

| Pattern | Meaning |
|---------|---------|
| `{state:==}` | Group by matching state |
| `{state:"Seed"}` | Filter: state equals "Seed" |
| `{follow wikilinks}` | Qualifier: traverse wikilink references |

The `:` inside braces uses YAML-style key-value syntax.

---

## Bracket Expressions

Brackets are the universal container and address mechanism:

```dpn
[context[verb[args]]]
```

### Prepositional Addressing

```dpn
[db[get_count[entry]]]
```

Reads as: *to db, regarding get_count, concerning entry.*

Not a method call. A prepositional address. More like sending a letter than calling a function.

### Key-Value Arguments

```dpn
[type: "[[Burg]]", Lifestage: "Seed"]
```

### Block Body (Purposive Sequence)

```dpn
[noosphere[discuss_project(sylvia){burg_pipeline}[type: "[[Burg]]", Lifestage: "Seed"]
                             advance[Lifestage]
                             process[yaml{follow wikilinks}+all, context]]
 append(entry)]
```

Operations in the body execute sequentially. The sequence is **purposive** — steps exist *in order to* accomplish the goal, not merely *after* it. This is "IN ORDER TO" semantics, not "AND THEN."

---

## Declarations

### `decree`

Defines persistent structure — types, workflows, routing rules, presentation templates. Decrees are law. They define how things *are*, not what to do right now.

```dpn
decree burg_pipeline [
    type: "[[Burg]]"
    levels: ["Seed", "Sapling", "Tree"]
    on_advance: (sylvia){review} || (sarah_lin){escalate}
    presentation: #header[burg_name] ![emblem] /wrapLeft
]
```

A decree is registered with the interpreter and persists across evaluations. Ghosts (or any agent) can reference decrees as bundles: `{burg_pipeline}`.

---

## Living Templates

A `.dpn` file is a **living template** — a document that becomes complete when evaluated.

```dpn
# @burg_name
@burg_name:description

![image("emblem" + @burg_name + png)] || (vincent){create emblem for @burg_name}

## Lifestage: @burg_name:Lifestage
- Seed
- Sapling
- Tree
```

When evaluated against `@boughrest`:
- `@burg_name` resolves to "Boughrest"
- `@burg_name:description` resolves to the entity's description
- `![image(...)]` searches for the emblem, commissions Vincent if missing
- The output is a rendered document about Boughrest

The template *is* the workflow *is* the document *is* the UI.

---

## Evaluation Contexts

The same expression means different things depending on where it runs:

| Context | What happens | Example use |
|---------|-------------|-------------|
| **Render** | Expression resolves and produces a document/view | TUI display, document generation |
| **Scope** | Expression defines what following operations apply to | Inside a decree or template |
| **Commission** | Unresolved references become work orders | Ghost tick engine, fulfillment chains |
| **Query** | Expression resolves and emits results | REPL, one-shot evaluation |

Context is an argument to the evaluator, not a mode switch. The expression itself is the same.

---

## Types

| Type | Example | Notes |
|------|---------|-------|
| Number | `52125` | No comma formatting |
| String | `"Hello World!"` | Double-quoted |
| Bare word | `entry`, `name`, `context` | Unquoted identifier |
| Wikilink | `[[Burg]]` | Document reference |
| Emoji slot | `<emoji>` | Emoji-typed values |
| Reference | `@boughrest` | Entity reference |
| Agent | `(sylvia)` | Agent address |
| Bundle | `{burg_pipeline}` | Script/scope reference |

---

## Error Model: Resistance and Fulfillment

Innate does not have exceptions. When the world pushes back, two things can happen:

### Fulfillment (recoverable)

A search directive fails to find what it's looking for. The `||` operator commissions an agent to create it:

```dpn
![image("emblem" + @burg_name + png)] || (vincent){create emblem for @burg_name}
```

This is not error handling. It is the language expressing demand — "this should exist, and if it doesn't, here's who makes it so."

### Resistance (structural)

A reference that cannot resolve and has no fulfillment path. `@nonexistent_thing` with no matching entity in script, registry, or database, and no `||` clause. This is a genuine error — the commandment is internally inconsistent or the world is not yet ready for it.

Resistance propagates upward through bracket nesting. The containing context decides what to do — ignore, log, escalate, or halt.

---

## Architecture

### Innate Is Generic

The interpreter core contains:
- **Parser**: `.dpn` text -> AST
- **Evaluator**: walks AST, calls resolver protocol for each symbol type
- **Resolver protocol**: interface that specific backends implement

The interpreter knows nothing about Postgres, the noosphere, or any specific infrastructure. It knows: "this is a reference, resolve it" and "this is an agent address, deliver it." *How* is configuration.

### Repository: `innatescript/`

Innate lives in its own repo. It is the language, not any particular deployment of it.

```
innatescript/
  lisp/
    parser.lisp          # .dpn text -> s-expressions
    evaluator.lisp       # walks AST, calls resolver protocol
    resolver-protocol.lisp  # defgeneric interface for backends
    types.lisp           # core type definitions
    repl.lisp            # interactive evaluator
  scripts/               # canonical .dpn files
    burg_pipeline.dpn
  docs/
    specs/               # this file lives here
  tests/
    parser-tests.lisp
    evaluator-tests.lisp
```

### Noosphere Resolver (separate, in project-noosphere-ghosts)

Implements the resolver protocol for the Dragonpunk stack:
- `@` resolves against `master_chronicle` (Postgres)
- `()` delivers commissions via the `conversations` table
- `{}` loads registered scripts from `innate_scripts` table or filesystem
- `![]` searches documents, images, vault notes
- `[[]]` resolves against the document graph

### Droplet Integration

- Ghost tick engine loads innatescript as a dependency, uses noosphere resolver
- dpn-api gets `/api/innate/eval` and `/api/innate/register` endpoints
- Scripts registered in an `innate_scripts` table (name, source, decrees, created_at)

### Laptop CLI

A thin client (Rust or Python) that:
- Syntax-checks `.dpn` files locally (light parser, no resolution)
- `innate eval '<expression>'` — one-shot via dpn-api
- `innate push script.dpn` — register on droplet
- `innate watch` — live-push on file save during development

---

## The Bootstrapping Arc

1. **Innate interpreter in Common Lisp** — parser, evaluator, resolver protocol. Language works, generic.
2. **Noosphere resolver** — connects Innate to master_chronicle and the ghosts. Ghosts can evaluate `.dpn` scripts as part of their tick cycle.
3. **Ghosts rewrite dpn-api** — one route at a time, using Innate as the orchestration layer, migrating Rust routes to Lisp.
4. **dpn-core folds in** — DB access becomes part of the unified Lisp image.
5. **dpn-tui in Innate** — the terminal UI becomes `.dpn` templates that render views.
6. **Innate interprets itself** — metacircular evaluator. The interpreter is written in Innate.

---

## Formal Grammar (Updated)

```
program         := statement*
statement       := expression | emission | decree | prose

decree          := 'decree' name '[' body ']'

expression      := '[' name? agent? bundle? args? body modifier* ']'
                 | reference
                 | search
                 | fulfillment

reference       := '@' name (':' qualifier)*
search          := '![' search_expr ']'
fulfillment     := (search | expression) '||' agent bundle?

agent           := '(' bare_word ')'
bundle          := '{' bare_word '}'
lens            := '{' kv_pair '}'
args            := '[' arg_list ']'
arg_list        := arg (',' arg)*
arg             := bare_word | string | kv_pair | qualified | reference
kv_pair         := bare_word ':' value
qualified       := bare_word (bundle | lens) combinator?
combinator      := '+' bare_word
body            := statement*
modifier        := bare_word
qualifier       := bare_word+

emission        := '->' emission_value+
emission_value  := value (',' value)* | bare_word

value           := number | string | bare_word | wikilink
                 | emoji_slot | reference | agent | bundle

prose           := line not matching any other rule (passed through)

bare_word       := [a-zA-Z_][a-zA-Z0-9_]*
number          := [0-9]+
string          := '"' [^"]* '"'
wikilink        := '[[' [^\]]* ']]'
emoji_slot      := '<emoji>'
name            := bare_word
```

---

## Open Questions (Carried Forward + New)

1. **Inward flow** — `->` is emission outward. Is there a `<-` for explicit inward binding, or does nesting and `@` handle all inward flow?
2. **Anonymous bracket depth** — Does `[[["Hello"]]]` mean something different from `[[["Hello"]["World"]]]`?
3. **Modifier vocabulary** — Are modifiers per-context dialects, or is there a universal set?
4. **Emoji slot** — Type annotation or literal placeholder? If annotation, emoji is a native type.
5. **Wikilink operations** — What can be done with `[[]]`-typed values beyond resolution?
6. **Chained fulfillment** — Can `||` chain? `![...] || (vincent){...} || (sarah_lin){escalate}` — first agent tries, second is fallback?
7. **Template parameters** — How does a template receive its subject? Is `@burg_name` a free variable that the caller binds, or is there explicit parameter syntax?
8. **Script versioning** — When a decree changes, do running workflows use the old or new version?
9. **Resolver discovery** — How does the interpreter find its resolver? Config file, environment, or convention?

---

*Derived from design sessions, March 2026.*
*Language: Innate (.dpn). Repository: innatescript.*
