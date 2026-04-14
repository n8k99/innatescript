---
type: "[[InnateScript]]"
---

# Innate Language Design Spec

*Markdown that runs. A choreographic programming language for multi-agent coordination.*

---

## The Problem

A single AI agent can draft a document, generate an image, or assess a risk. But real work rarely requires a single agent. It requires several — each with different strengths, different knowledge, different judgment — coordinating toward a shared outcome. A trader's thesis needs risk assessment, regulatory compliance, and market sentiment analysis before it becomes an order. An editorial needs writing, fact-checking, and illustration before it becomes a publication. These are not single tasks. They are choreographies.

Today, multi-agent coordination is bolted on after the fact — ad-hoc chains of API calls, prompt templates piped between services, orchestration frameworks that centralize control in a single dispatcher. This approach breaks in predictable ways. Agents hallucinate. Agents respond lazily. There is no built-in mechanism to verify that one agent's output is not counterfactual before passing it to the next. There is no way to express that three agents should work concurrently and their results should be joined before proceeding. There is no language-level concept of time-bounded obligation, fallback on failure, or structured composition of agent strengths.

These are not engineering oversights. They are distributed systems problems. As Kiran Gopinathan has shown, multi-agent coordination is subject to the same impossibility results as any distributed consensus problem — FLP, Byzantine fault tolerance — regardless of how capable the individual agents are. Making agents smarter does not solve coordination. Formal protocols must be first-class concerns in the language itself, not afterthoughts.

Innate exists to solve this. It is a language where a single intention is expressed once as a repeatable process, the evaluator projects each agent's local slice, and the coordination primitives — verification, concurrency, synchronization, temporal bounds, fulfillment — are part of the grammar. The result is a structured series of prompts distributed across multiple agents that produces a well-detailed, expected, and dependable outcome. Multiple agents' strengths compound. The choreography guarantees the composition.

---

## What Innate Is

Innate is a choreographic programming language that lives inside markdown. An Innate expression can appear in a `.md` file, in the `content` column of a database record, or anywhere markdown is stored. When evaluated, references resolve, missing resources get commissioned, verification gates check agent output against reality, and what comes out is a rendered result, a workflow scope, or a coordinated multi-agent outcome. The same expression serves all purposes depending on evaluation context.

There is no special file extension. Innate expressions are markdown. A vault note is a choreography. A database document is a choreography. The evaluator finds Innate expressions wherever they appear — in `.md` files, in database fields, inline within prose. The boundary between "document" and "program" does not exist.

Innate is generic. The language knows nothing about any specific database, agent framework, or presentation layer. It defines a protocol for resolution, commission, and coordination. Specific systems (like the Dragonpunk noosphere) implement resolvers that connect Innate's symbols to their infrastructure.

The test of an Innate program: a human unfamiliar with any programming language should be able to make a reasonable guess at what it does.

---

## Core Syntax: The Symbol Vocabulary

### The Container Trinity

| Container | Syntax | Role | Feels Like |
|-----------|--------|------|------------|
| Brackets | `[name[...]]` | Context / navigation / invocation | *going somewhere* |
| Braces | `{name}` | Bundle / scope / lens | *bringing something / looking through something* |

**Place, Thing.** Agents are entities addressed by `@`, not a separate container. `(@name)` and `@name` are semantically identical (see *Agent Address and Commission* and *Choreographic Semantics: Agents Are Entities*).

### Resolution and Reference Symbols

| Symbol | Name | Role | Example |
|--------|------|------|---------|
| `@` | Direct reference | Resolve a known entity | `@boughrest` |
| `![]` | Search directive | Find something that may or may not exist | `![image("emblem" + name + png)]` |
| `[[]]` | Wikilink | Document reference in the vault | `[[Akar Ok]]` |
| `->` | Emission | Results flow forward to next stage or out | `-> "Seed"` |
| `<-` | Verification | Results checked against reality before advancing | `<- @RiskAgent{assess risk}` |
| `\|\|` | Fulfillment | If resolution fails, commission an agent | `![...] \|\| @vincent{create it}` |
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
[boughrest
    type: "[[Burg]]"
    Lifestage: "Seed"
    description: @Alaran:generative hard prompt
]

@boughrest.Lifestage -> "Seed"
```

The named bracket expression *is* the declaration. `boughrest` is both the name and the definition. When saved as `boughrest.dpn`, other choreographies reference it via `@boughrest`. The filesystem is the registry.

The `:` after an `@` reference is a natural-language qualifier, not a dot-accessor. `@Alaran:generative hard prompt` reads as "from Alaran, the generative hard prompt."

### The `![]` Search Directive

`![]` searches for something that may not exist. Unlike `@`, a failed `![]` is not an error — it's an opportunity for fulfillment.

```dpn
![image("emblem" + burg_name + png)] || @VincentDuskmantle{create emblem for burg_name}
```

If the image exists, it resolves. If not, the `||` fulfillment operator commissions Vincent to create it. Unresolved searches become work orders, not errors.

### The `[[]]` Wikilink

Document references in the vault/content graph. A native type. The resolver knows how to find documents by wikilink title.

---

## Agent Address and Commission

`(@SylviaInkweaver)` and `@SylviaInkweaver` are semantically identical — both resolve a named entity. There is no special "agent type." Any resolvable entity can be addressed and commissioned. An entity becomes a choreographic participant when the expression asks it to do something:

```dpn
@SylviaInkweaver{write editorial for [[Akar Ok]]}
```

Sylvia is not a function. She is addressed, not called. Whether an entity can *fulfill* a commission is a property of the entity, not of the language.

When combined with `||`, agent address becomes **fulfillment** — the world doesn't have what you need, so you commission someone to make it:

```dpn
![image("emblem" + @burg_name + png)] || @VincentDuskmantle{create emblem for @burg_name}
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
[noosphere[discuss_project @SylviaInkweaver{burg_pipeline}[type: "[[Burg]]", Lifestage: "Seed"]
                             advance[Lifestage]
                             process[yaml{follow wikilinks}+all, context]]
 append(entry)]
```

Operations in the body execute sequentially. The sequence is **purposive** — steps exist *in order to* accomplish the goal, not merely *after* it. This is "IN ORDER TO" semantics, not "AND THEN."

---

## Named Choreographies as Declarations

There is no special declaration keyword. A named bracket expression *is* a declaration:

```dpn
[burg_pipeline @burg_name
    type: "[[Burg]]"
    levels: ["Seed", "Sapling", "Tree"]
    on_advance: @SylviaInkweaver{review} || @SarahLin{escalate}
    presentation: #header[burg_name] ![emblem] /wrapLeft
]
```

When this lives in `burg_pipeline.md` — or in a database record titled `burg_pipeline` — it is a named, persistent, referenceable choreography. Other choreographies reference it via `@burg_pipeline`. The filesystem, the vault, and the database are all registries. The document is the declaration.

This replaces the earlier `decree` keyword. `decree` tried to solve a problem that named documents already solve: how do you make something persistent and referenceable? You give it a name and store it — as a vault note, as a database record, wherever markdown lives. The three-bracket limit (see *Choreographic Semantics*) reinforces this — when an expression gets too deep, you extract it as a named choreography. The language composes from itself.

---

## Living Templates

A `.dpn` file is a **living choreography** — a document that becomes complete when evaluated.

```dpn
# @burg_name
@burg_name:description

![image("emblem" + @burg_name + png)] || @VincentDuskmantle{create emblem for @burg_name}

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

## Choreographic Semantics

### The Choreographic Principle

A `.dpn` file is a **choreography** — a repeatable process that defines a single intention distributed across multiple agents. Each invocation takes new input; the structure stays the same. The expression can be simple or complex based on what the intention requires.

The choreography describes the whole dance from a global viewpoint. The evaluator's job is **projection** — decomposing the global intention into each agent's local slice. An agent receives only the parts that address it, with enough context to know what it's contributing to. It resolves locally: it doesn't need to understand the whole choreography.

This is not orchestration. An orchestrator is a central controller that tells each agent what to do step by step. A choreography is a score — each participant reads their part and plays. The coordination primitives in the language guarantee the parts fit together.

### Agents Are Entities

`(@SylviaInkweaver)` and `@SylviaInkweaver` are semantically identical. Both resolve a named entity. An entity becomes a choreographic participant when the expression commissions work from it — through a bundle `{task}`, a qualifier `:directive`, or by position within a coordination structure.

There is no special "agent type." Any resolvable entity can be addressed, commissioned, and projected onto. Whether an entity can *fulfill* a commission is a property of the entity, not of the language.

### Flow Operators

Three operators govern the direction of flow within a choreography:

| Operator | Direction | Purpose |
|----------|-----------|---------|
| `->` | Forward | **Emission** — results flow out to the next stage or the world |
| `<-` | Backward | **Verification** — results are checked against reality before advancing |
| `\|\|` | Lateral | **Fulfillment** — if this can't be done, someone else does it |

**Emission** (`->`) pushes results forward. A stage completes and its output advances to the next stage, or exits the choreography entirely.

**Verification** (`<-`) sends results back for factual checking. Agents hallucinate. Agents respond lazily. `<-` is the language's built-in quality gate — it says "this result must survive contact with verification before it advances." The verifying agent checks that what came before is not counterfactual. If it is, the agent corrects it. The corrected result then moves forward.

`<-` can appear standalone (sequential verification) or nested inside `concurrent` blocks (parallel verification against multiple facets of reality simultaneously).

**Fulfillment** (`||`) branches laterally. If one agent cannot fulfill a commission, another takes over. This is not error handling — it is the choreography expressing that more than one agent can serve a role, with a preference order.

### Coordination Primitives

Five structural keywords shape how agents interact within bracket expressions:

| Keyword | Purpose |
|---------|---------|
| `concurrent` | Multiple agents work simultaneously |
| `join` | Wait for all concurrent branches before proceeding — timing only, says nothing about truth |
| `until` | Time-bounded or condition-bounded waiting |
| `sync` | Side-channel action that runs alongside the main flow |
| `at` | Absolute or relative time trigger |

These keywords live inside bracket expressions at whatever nesting depth the expression requires. They are structural operators, not declarations.

**`concurrent` + `join`** — parallel execution with a synchronization barrier:

```dpn
[burg_pipeline @burg_name
    concurrent [
        @SylviaInkweaver{write editorial for @burg_name}
        @VincentDuskmantle{create emblem for @burg_name}
    ]
    join
    #header[burg_name] ![emblem] /wrapLeft
]
```

**`until`** — two forms with distinct semantics. Postfix bounds an agent's obligation; block form bounds a choreographic context:

```dpn
[@SylviaInkweaver{review @burg_name} until 3 days || @SarahLin{escalate}]

until 3 days [
    @SylviaInkweaver{review @burg_name}
    @VincentDuskmantle{illustrate @burg_name}
] || @SarahLin{escalate}
```

In the postfix form, the timeout belongs to Sylvia's commission — she has 3 days to fulfill her part. In the block form, the timeout belongs to the choreographic context — everyone inside must fulfill within the window.

**`sync`** — a side-channel that doesn't block the main flow:

```dpn
[campaign @burg_name
    @SylviaInkweaver{write editorial}
    sync @Archivist{log progress for @burg_name}
]
```

**`at`** — temporal trigger:

```dpn
at [[2026-04-15]] @SylviaInkweaver{publish @burg_name editorial}
```

### The Three-Bracket Limit

Bracket expressions nest to a maximum depth of three levels:

| Depth | Scope | Example |
|-------|-------|---------|
| `[...]` | **The choreography** — the process itself | `[forex_theorem @pair ...]` |
| `[...[...]...]` | **Coordination within** — concurrent blocks, verification groups | `concurrent [<- @RiskAgent{...}]` |
| `[...[...[...]...]...]` | **Detail within coordination** — sub-structure inside a coordination block | `<- [regulatory_check concurrent [...] join]` |

If an expression wants a fourth level of nesting, that is a signal: the inner expression should be extracted as its own named choreography — a separate `.md` file or database document — and referenced by `@`.

```dpn
[forex_theorem @pair
    @KathrynLyonne{set theorem for @pair}
    concurrent [
        <- @RiskAgent{assess risk exposure}
        <- @regulatory_compliance
        <- @SentimentAgent{verify market conditions}
    ]
    join
    @RubricAgent{evaluate @theorem against @criteria}
    -> approve || -> disapprove
    @KathrynLyonne{place order for @pair}
]
```

Where `@regulatory_compliance` is its own document — `regulatory_compliance.md` or a database record:

```dpn
[regulatory_compliance @pair
    concurrent [
        <- @CFTCAgent{check US compliance}
        <- @EUAgent{check MiFID compliance}
    ]
    join
]
```

This constraint is compositional pressure. It forces complex sub-processes to be named, extracted, and made reusable. A named choreography is a markdown document. A markdown document can be a choreography. The language composes from itself — InnateScript programs are built from other InnateScript programs, stored as vault notes or database records. The three-bracket limit makes self-composition not an aspiration but a structural inevitability.

### Projection and Distribution

The evaluator projects a choreography onto each participant. In the forex theorem example, Kathryn receives: set the theorem, wait, place the order. The risk agent receives: assess this theorem's risk exposure and report corrections. Neither needs to see the full choreography.

Local resolution order:
1. The agent's own knowledge and capabilities
2. Neighboring choreographies and shared scripts
3. The database or backing store

The language is agnostic to where agents live. The same choreography works within a single database, across a local network, or across the internet. Distribution is a property of the resolver, not of the expression.

### Composition Example: The Full Dance

A complete choreography composes flow operators, coordination primitives, and verification into a single repeatable process:

```dpn
[forex_theorem @pair
    @KathrynLyonne{set theorem for @pair}
    concurrent [
        <- @RiskAgent{assess risk exposure}
        <- @RegulatoryAgent{check compliance}
        <- @SentimentAgent{verify market conditions}
    ]
    join
    @RubricAgent{evaluate @theorem against @criteria}
    -> approve || -> disapprove
    @KathrynLyonne{place order for @pair}
]
```

1. Kathryn sets a theorem for a currency pair.
2. Three verification agents concurrently check it against risk, law, and market conditions — each `<-` feeding corrections back into the theorem.
3. The `join` waits for all three to finish.
4. The corrected theorem goes to a rubric agent for pass/fail evaluation.
5. The rubric emits approval or disapproval.
6. Kathryn places the order only on approval.

The same choreography runs for every currency pair. New input, same structure. The intention is expressed once; the agents each dance their part.

---

## Types

| Type | Example | Notes |
|------|---------|-------|
| Number | `52125` | No comma formatting |
| String | `"Hello World!"` | Double-quoted |
| Bare word | `entry`, `name`, `context` | Unquoted identifier |
| Wikilink | `[[Burg]]` | Document reference |
| Emoji slot | `<emoji>` | Emoji-typed values |
| Reference | `@boughrest` | Entity reference (agents and data alike) |
| Bundle | `{burg_pipeline}` | Script/scope reference |

---

## Error Model: Resistance and Fulfillment

Innate does not have exceptions. When the world pushes back, two things can happen:

### Fulfillment (recoverable)

A search directive fails to find what it's looking for. The `||` operator commissions an agent to create it:

```dpn
![image("emblem" + @burg_name + png)] || @VincentDuskmantle{create emblem for @burg_name}
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
    parser.lisp          # markdown with Innate expressions -> s-expressions
    evaluator.lisp       # walks AST, calls resolver protocol
    resolver-protocol.lisp  # defgeneric interface for backends
    types.lisp           # core type definitions
    repl.lisp            # interactive evaluator
  scripts/               # canonical choreographies
    burg_pipeline.md
  docs/
    specs/               # this file lives here
  tests/
    parser-tests.lisp
    evaluator-tests.lisp
```

### Noosphere Resolver (separate, in project-noosphere-ghosts)

Implements the resolver protocol for the Dragonpunk stack:
- `@` resolves against `master_chronicle` (Postgres) — agents and data alike
- `@agent{commission}` delivers commissions via the `conversations` table
- `{}` loads registered scripts from `innate_scripts` table or filesystem
- `![]` searches documents, images, vault notes
- `[[]]` resolves against the document graph
- `<-` routes verification requests to the verifying agent and returns corrections

### Droplet Integration

- Ghost tick engine loads innatescript as a dependency, uses noosphere resolver
- dpn-api gets `/api/innate/eval` and `/api/innate/register` endpoints
- Named choreographies registered in an `innate_scripts` table (name, source, created_at)

### Laptop CLI

A thin client (Rust or Python) that:
- Syntax-checks `.md` files with Innate expressions locally (light parser, no resolution)
- `innate eval '<expression>'` — one-shot via dpn-api
- `innate push choreography.md` — register on droplet
- `innate watch` — live-push on file save during development

---

## The Bootstrapping Arc

1. **Innate interpreter in Common Lisp** — parser, evaluator, resolver protocol. Language works, generic.
2. **Noosphere resolver** — connects Innate to master_chronicle and the ghosts. Ghosts can evaluate choreographies as part of their tick cycle.
3. **Ghosts rewrite dpn-api** — one route at a time, using Innate as the orchestration layer, migrating Rust routes to Lisp.
4. **dpn-core folds in** — DB access becomes part of the unified Lisp image.
5. **dpn-tui in Innate** — the terminal UI becomes markdown choreographies that render views.
6. **Innate interprets itself** — metacircular evaluator. The interpreter is written in Innate.

---

## Formal Grammar (Updated April 2026)

```
program         := statement*
statement       := expression | emission | verification | prose

expression      := '[' name? reference? bundle? args? body modifier* ']'
                 | reference
                 | search
                 | fulfillment
                 | coordination

reference       := '@' name (':' qualifier)*
search          := '![' search_expr ']'
fulfillment     := (search | expression) '||' reference bundle?
verification    := '<-' reference bundle?

coordination    := concurrent | join | until_expr | sync_expr | at_expr
concurrent      := 'concurrent' '[' body ']'
join            := 'join'
until_expr      := expression 'until' duration ('||' reference bundle?)?
                 | 'until' duration '[' body ']' ('||' reference bundle?)?
sync_expr       := 'sync' reference bundle?
at_expr         := 'at' (wikilink | duration) expression

duration        := number bare_word

bundle          := '{' (bare_word | prose) '}'
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
                 | emoji_slot | reference | bundle

prose           := line not matching any other rule (passed through)

bare_word       := [a-zA-Z_][a-zA-Z0-9_]*
number          := [0-9]+
string          := '"' [^"]* '"'
wikilink        := '[[' [^\]]* ']]'
emoji_slot      := '<emoji>'
name            := bare_word
```

**Nesting constraint:** Bracket expressions nest to a maximum depth of three levels. Expressions requiring deeper nesting must extract inner choreographies as named documents (`.md` files or database records) referenced by `@`.

---

## Open Questions (Carried Forward + New)

### Resolved

1. ~~**Inward flow**~~ — **RESOLVED (April 2026).** `<-` is the verification operator. It sends results back for factual checking before advancing. See *Choreographic Semantics: Flow Operators*.
6. ~~**Chained fulfillment**~~ — **RESOLVED (April 2026).** `||` chains as a fulfillment preference order. First agent tries, second is fallback. See *Choreographic Semantics: Flow Operators*.
7. ~~**Template parameters**~~ — **RESOLVED (April 2026).** A choreography receives its subject as an argument to the bracket expression: `[forex_theorem @pair ...]`. `@pair` is bound by the caller. See *Choreographic Semantics: Composition Example*.

### Open

2. **Anonymous bracket depth** — Does `["Hello"]` mean something different from `[[["Hello"]["World"]]]`? (Note: the three-bracket limit constrains this — maximum three levels of nesting.)
3. **Modifier vocabulary** — Are modifiers per-context dialects, or is there a universal set?
4. **Emoji slot** — Type annotation or literal placeholder? If annotation, emoji is a native type.
5. **Wikilink operations** — What can be done with `[[]]`-typed values beyond resolution?
8. **Script versioning** — When a named choreography changes, do running workflows use the old or new version?
9. **Resolver discovery** — How does the interpreter find its resolver? Config file, environment, or convention?
10. **Verification depth** — When `<-` sends corrections back, does the original agent revise, or does the correction amend the artifact directly? Or is this resolver-dependent?
11. **Coordination keyword extensibility** — Are `concurrent`, `join`, `until`, `sync`, `at` a closed set, or can resolvers introduce domain-specific coordination primitives?

---

## Related Work

- **Kiran Gopinathan** — [*Multi-Agentic Software Development as a Distributed Systems Problem*](https://kirancodes.me/posts/log-distributed-llms.html) (2026). Frames multi-agent LLM coordination as a distributed consensus problem subject to FLP and Byzantine impossibility results. Argues that formal coordination protocols must be first-class language concerns, not ad-hoc workarounds. Her forthcoming work on a choreographic language for multi-agent workflows converges with InnateScript's design — the `<-` verification operator addresses her Byzantine failure model (agents that misunderstand or hallucinate), `until` provides the liveness bounds that FLP demands, and the choreographic projection model ensures consensus is structural rather than negotiated.

- **Fabrizio Montesi** — [*Choreographic Programming*](https://www.fabriziomontesi.com/publication/choreographic-programming) (2013, PhD thesis). Formalized choreographic programming as a paradigm for deadlock-free distributed systems. The projection model (global choreography → per-participant local behavior) is the theoretical foundation for InnateScript's evaluator design.

- **Chorex** — [*Restartable, Language-Integrated Choreographies*](https://programming-journal.org/2025/10/20/) (Wiersdorf et al., 2025). Choreographic programming in Elixir with crash recovery and restartable choreographies. Demonstrates that choreographic languages can handle real-world agent failure — relevant to InnateScript's fulfillment (`||`) and verification (`<-`) mechanisms.

---

*Derived from design sessions, March–April 2026.*
*Language: Innate (markdown-native). Repository: innatescript.*