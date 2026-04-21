# Resolver Protocol Contract

The resolver protocol defines the boundary between Innate (the language) and the substrate (whatever system agents live in). Every resolver is a CLOS subclass of `resolver` that specializes a small set of generic functions.

This document is rewritten against the **Rosetta Stone second pass** — 130 `.dpn` files at `~/Development/projects/innatescript/` that exercise the protocol across nine domains and universally use `where` and `IN ORDER TO`. Every requirement below points to at least one corpus file that demands it; the first pass of this contract was written before the corpus existed and missed the two load-bearing features.

---

## Architecture

```
Innate Evaluator
    |
    v
resolver  (base class, 10 defgenerics)
    |
    +-- stub-resolver     (in-memory, for testing)
    +-- default-resolver  (file-based, for standalone use)
    +-- your-resolver     (your substrate — Postgres, APIs, agents)
```

Concrete resolvers hold state in CLOS slots. The evaluator threads one resolver instance through an `eval-env` for the duration of a choreography.

---

## Building a Resolver

1. Define a CLOS class that inherits from `resolver`. Give it slots for any state it needs to carry across calls.
2. Specialize the generics your substrate supports. Unspecialized generics fall through to the base methods (which return resistance for reads and no-op for commissions).
3. Load your resolver's ASDF system alongside `innatescript`.
4. Pass your resolver to `make-eval-env`.

```lisp
(let* ((my-resolver (make-instance 'my-project:my-resolver))
       (env (innate.eval.resolver:make-eval-env :resolver my-resolver)))
  (innate.eval:evaluate ast env))
```

---

## Argument Conventions

### Keyword plists are the universal argument shape

Every choreographic case in the corpus passes arguments by name:

```
[bank[transfer {from-id: @a, to-id: @b, amount-cents: @n}]]
[media[tick {player: @p, delta-ms: 100}]]
[vm[commit {repo: @r, files: @fs, message: @m, timestamp: @t}]]
```

The parser produces kv-pair nodes; `resolve-context` must receive them as an alist or plist and match on keys, not positions. Positional arguments are supported but discouraged — keyword form is what the corpus teaches as idiomatic.

**Contract:** when `args` contains kv-pair nodes, the resolver method receives `'((:from-id . @a-value) (:to-id . @b-value) ...)`.

### Resistance is structured, not a string

The corpus uses resistance as signal kinds, not error messages:

```
|| -> #invalid-parent @resistance:reason
|| -> #auto-locked
|| -> #rename-blocked @resistance:reason
```

A `resistance` carries a **kind** (the `#signal-name`), optional **detail** (the `@resistance:reason` payload), and a **source**. The base struct today has only `message` and `source`; this should extend to `(kind detail source message)` so choreographies can dispatch on kind rather than parse strings.

**Migration note:** existing `message`-only resistance remains valid; new resistance should set `kind` as a keyword (`:unknown-entry`, `:cycle-detected`, `:frozen`, ...) and optionally attach detail.

### `where` clauses are arguments the resolver interprets

This is the biggest shift from the first pass. The corpus repeatedly hands the resolver a filter/constraint clause rather than a pre-filtered value:

```
[tag-store[query {store: @s, query: @q}]]
    @s:tags where @q:field is none  -> include

[bookmarks[sorted {collection: @c, by: @key, order: @ord}]]
    @c:entries ordered by @key in direction @ord

[contacts[find-duplicates {book: @b}
    where two contacts are duplicates iff they share a canonical email]]
```

`where` expressions parse into a **predicate AST** that the resolver receives alongside the verb's keyword args. The resolver is expected to:

1. Recognize the predicate structure (boolean combinators, field access, comparison).
2. Either evaluate the predicate against candidate items in CL (default behavior), or translate it into the substrate's query language (e.g. SQL) for delegated evaluation.

**Contract:** `resolve-context` receives an optional `:where` key in its args whose value is a predicate AST node. Verbs that can interpret constraints do so; verbs that can't ignore it and the evaluator filters at the outer layer.

### `IN ORDER TO` blocks are purpose annotations

Every choreographic case opens with `IN ORDER TO`. These are metadata — they don't change behavior but they give the resolver information useful for logging, verb selection when multiple candidates exist, and operator diagnostics.

**Contract:** a choreographic block's `IN ORDER TO` body parses into a purpose string attached to the block's AST node. The resolver receives it in `eval-env` or via an auxiliary generic (see `resolve-context` below) and is free to use it or ignore it. Do not make behavior load-bearing on purpose content — the purpose is narrative, the verbs are operational.

---

## The 10 Generics

### 1. resolve-reference (resolver name qualifiers [where]) -> result | resistance

Resolve a `@name` or `@name:qualifier:qualifier` reference.

- **name**: string — the reference name (e.g. `"burg"` from `@burg`)
- **qualifiers**: list of strings — colon-separated qualifiers (e.g. `("type" "state")` from `@burg:type:state`)
- **where**: optional predicate AST — when the reference is filtered (`@entries where is-read is false`)
- **Found**: return `(make-innate-result :value <data> :context :query)`
- **Not found**: return `(make-resistance :kind :unknown-reference :message "..." :source name)`

Named brackets are checked first by the evaluator; only unresolved references reach the resolver.

**Corpus examples:** `@laune`, `@bank:transactions-since`, `@my-strokes where author is @client:name` (from web/whiteboard.dpn).

### 2. resolve-search (resolver search-type terms [where]) -> result | resistance

Resolve a `![search_expr]` search directive.

- **search-type**: keyword or string identifying the search kind
- **terms**: list of evaluated search term values (strings, kv-pairs)
- **where**: optional predicate AST for structured filtering
- **Found**: return `(make-innate-result :value <list-of-matches> :context :query)`
- **Not found**: return resistance with kind `:no-match` or `:unknown-search-type`

**Corpus examples:** `![image("emblem"+burg_name + png)]` (burg_pipeline.dpn).

### 3. deliver-commission (resolver agent-name instruction [sync]) -> result | resistance

Deliver a `(agent){instruction}` commission to an agent.

- **agent-name**: string — the agent name
- **instruction**: string or AST — the commission body
- **sync**: optional boolean. `nil` (default) = fire-and-forget; `t` = await response.

When `sync` is false: return `(make-innate-result :value t :context :commission)` always; the agent handles success/failure internally.

When `sync` is true: return `(make-innate-result :value <agent-return> :context :commission)` or resistance. The corpus needs this for verbs like `(@reviewer){verify @draft}` whose output the choreography binds via `<-`.

**This extends the first-pass contract.** The first pass said "Never returns resistance" — the corpus contradicts that for synchronous commissions. Fire-and-forget remains the default; sync is opt-in via the flag.

**Corpus examples:** `(@kathryn){verify conservation of transactions: @all-tx}` (classes/bank-account.dpn — sync), `(@writer){draft article}` in burg_pipeline (async).

### 4. resolve-wikilink (resolver title) -> result | resistance

Resolve a `[[Title]]` wikilink to its target.

- **title**: string — the wikilink title text
- **Found**: return `(make-innate-result :value <content> :context :query)`
- **Not found**: return resistance with kind `:wikilink-missing`

**Corpus examples:** `[[T.A.S.K.S.]]`, `[[Rosetta Stone]]`, `[[07:00]]` (resolves as a time wikilink in alarm-clock.dpn).

### 5. resolve-context (resolver context verb args [where] [purpose]) -> result | resistance

The workhorse generic. Resolves `[context[verb[args]]]` bracket expressions — which, per the corpus, is how 90% of choreographic work reaches the resolver.

- **context**: string — the outermost bracket context (e.g. `"bank"`, `"sql"`, `"tag-store"`)
- **verb**: string — the verb/action (e.g. `"transfer"`, `"analyse"`, `"query"`)
- **args**: plist of evaluated keyword arguments — `(:from-id @a :to-id @b :amount-cents 3000)`
- **where**: optional predicate AST from the block's `where` clause
- **purpose**: optional string from the block's `IN ORDER TO`
- **Found**: return `(make-innate-result :value <result> :context :query)` — value can be any value the choreography binds via `<-`
- **Not found / failed**: return resistance with a meaningful kind

The resolver should treat `(context, verb)` as a dispatch pair. Context names a module; verb names an operation on that module. The corpus uses a consistent verb vocabulary per domain (`new`, `add`, `get`, `query`, `by-*`, `tick`, `to-text`, `from-text`, `render`, ...).

**Corpus examples:**
- `[db[get_count[entry, tables]name]]` — context=db, verb=get_count, args=(entry tables), modifier=name
- `[sql[analyse {query: @q, schema: @s}]]` — keyword form
- `[wb[thread-tree {board: @b, thread-id: 1}]]` — returns structured data the choreography walks

**Note on positional vs keyword:** both forms parse correctly. Keyword is preferred; the corpus uses it almost exclusively.

### 6. load-bundle (resolver name) -> nodes | nil

Load a `{bundle_name}` bundle by name.

- **name**: string — the bundle name
- **Found**: return a list of AST nodes (the bundle's parsed contents)
- **Not found**: return `nil` (not resistance — absence is a valid state for bundles)

The default resolver searches for `name.dpn` then `name.md` in the search path. Bundles are typically procedures or scope definitions brought into the current expression.

**Corpus examples:** `{burg_pipeline}`, `{draw-square}` (turtle.dpn), `{follow wikilinks}` (burg_pipeline.dpn).

### 7. deliver-verification (resolver agent-name prior-output) -> result | resistance

Route verification to an agent via the `<-` operator.

- **agent-name**: string — the verifying agent
- **prior-output**: the output from the prior stage to be verified
- **Success**: return `(make-innate-result :value <corrections-or-approval> :context :commission)`
- **Failure**: return resistance with kind `:verification-failed`

**Corpus examples:** `<- @kathryn{verify @total against @room:budget}` (tile-cost.dpn), `<- @eliana{verify projections are grounded}` (fibonacci.dpn).

### 8. schedule-at (resolver time expression) -> result | resistance

Schedule an expression for future evaluation via the `at` operator.

- **time**: string or wikilink — the target time (`[[07:00]]`, `[[2026-05-01]]`, or a duration)
- **expression**: AST node — the expression to evaluate at that time
- **Success**: return `(make-innate-result :value <handle> :context :query)` where handle identifies the scheduled item
- **Failure**: return resistance with kind `:schedule-rejected`

**Corpus examples:** `at [[07:00]] [...]` in alarm-clock.dpn, morning-ops in text-game.dpn's event handlers.

### 9. resolve-tick (resolver context delta-ms state) -> result | resistance  **[NEW]**

**Narrow scope: simulation tick only.** This generic advances an in-memory stateful module by a millisecond delta. It is NOT the noosphere-ghosts agent-tick cycle — see "Two Tick Concepts" below for the distinction.

- **context**: string — the state-bearing module (`"mp3"`, `"saver"`, `"mgr"`, `"tl"`, ...)
- **delta-ms**: integer — milliseconds to advance
- **state**: the module's mutable state (typically held in a CLOS slot on the resolver)
- **Returns**: `(make-innate-result :value (events-fired) :context :query)` — the list of boundary events produced during the tick

The corpus's tick implementations return events on boundaries, not every tick (see web/media-player.dpn, graphics/screen-saver.dpn, graphics/traffic-light.dpn). Events are data the choreography can dispatch on. Calls are synchronous, pure on inputs, and don't invoke LLMs or cross network boundaries — the tick of a traffic light takes nanoseconds, not minutes.

**Open design question (deferred):** whether `every Nms [...]` as a choreographic operator should automatically dispatch tick to every tick-registered resolver (ambient), or only to explicitly-targeted ones (explicit). The corpus uses explicit form; ambient is easier on authors but harder on the evaluator.

**Corpus examples:** `[media[tick {player: @p, delta-ms: 100}]]`, `[progress[advance {tracker: @t, delta: @n}]]`.

### 10. snapshot-state / restore-state (resolver) -> snapshot / unit  **[NEW]**

Paired generics for stateful-resolver serialization. Required by preemption, retry-resume, and any choreography that branches over a hypothetical continuation.

```lisp
(defgeneric snapshot-state (resolver)
  (:documentation "Return an opaque value capturing the resolver's current state."))

(defgeneric restore-state (resolver snapshot)
  (:documentation "Mutate the resolver to match the captured snapshot. Side effect."))
```

The snapshot's representation is resolver-specific. A Dragonpunk resolver might capture DB connection state; a Rosetta resolver might capture playback position, retry counters, physics state.

**Corpus examples:** G125 Traffic Light emergency preempt (saves phase/elapsed/cycle-side), G121 YouTube Downloader resumable retry (saves bytes-done + retry count), G130 Turtle push-state/pop-state.

---

## Stateful Resolvers

The first-pass contract called the base resolver class "empty" — accurate, but silent on the intended pattern. The corpus demands it be said out loud:

**Stateful resolvers are intended and normal.** Hold state in CLOS slots. The evaluator keeps one resolver instance alive for the duration of a choreography (via `eval-env`), and `:scope`-bound sub-evaluations share that instance.

```lisp
(defclass rosetta-resolver (resolver)
  ((mp3-state   :initform (make-mp3-player-state))
   (canvas      :initform (make-canvas))
   (bookmarks   :initform (make-bookmarks-collection))
   ...))

(defmethod resolve-context ((r rosetta-resolver) (context (eql "mp3")) verb args)
  (ecase (intern (string-upcase verb))
    (:play    (mp3-player:player-play   (slot-value r 'mp3-state)))
    (:tick    (mp3-player:player-tick   (slot-value r 'mp3-state)
                                         (getf args :delta-ms)))
    (:current-track (mp3-player:current-track (slot-value r 'mp3-state)))))
```

Scope keywords on `eval-env`:

- `:query` — default. Read-mostly; mutations are allowed but expected to be small.
- `:scope` — state-bearing. The resolver persists state across invocations within the scope.
- `:render` — output-producing. Resolver should minimize side effects.
- `:commission` — agent-directed. Used by `deliver-commission` dispatch.

`:scope` is the one most of the corpus uses implicitly. The next spec revision should codify what it means beyond "mutations are OK."

---

## Two Tick Concepts

InnateScript and noosphere-ghosts both talk about "tick." They are not the same primitive. Conflating them is the mistake the first-pass contract almost made.

| Dimension | Simulation tick (`resolve-tick`) | Agent tick (noosphere-ghosts) |
|---|---|---|
| Cadence | 1 ms–1 s (driven by `every Nms`) | 10 min (driven by `TICK_INTERVAL_SECONDS`) |
| Granularity | One in-memory module advances by delta-ms | Every active ghost runs a perceive→rank→cognize→act→update cycle |
| Side effects | None beyond module state | DB writes, LLM calls, message sends, energy/tier PATCHes |
| Purity | Synchronous, bounded, no network | Async cognition broker, LLM provider dispatch, minutes of wall-clock |
| Corpus | 20+ Rosetta Stone entries (mp3, traffic light, saver, …) | Runs live on the droplet via `lisp/runtime/tick-engine.lisp` |
| Who drives it | InnateScript evaluator via `every Nms [...]` | External cron or sleep loop inside the ghosts runtime |

### How InnateScript composes with the agent tick

The agent tick is the outer driver. A choreography does NOT drive the agent tick; it runs *as part of* an agent's cognition output when the tick engine selects the agent and the broker resolves its cognition job.

Inside one agent-tick cycle:

```
perceive → rank → classify → cognize (via broker)
                                │
                                ▼
                           LLM produces action
                                │
                                ▼
                     action may be a .dpn choreography
                                │
                                ▼
                Innatescript evaluates it against the resolver
                (which IS the ghosts' substrate-facing layer)
                                │
                                ▼
                  action output returned to the broker
                                │
                                ▼
                           update state → report
```

So choreographies are the shape of an agent's cognition output, not the driver of the cycle. `resolve-tick` remains available for simulations an agent might run *during* its cognition (e.g. an agent that models traffic-light timing as part of its own reasoning), but the outer 10-minute tick is not touched by the InnateScript evaluator at all.

### What the two ticks share

Both produce **events on boundaries** rather than streaming continuous state:

- Simulation tick emits `TrackStarted`, `PlaylistEnded`, `PhaseChanged`.
- Agent tick emits `log-entry`, `request-entry`, `resolution-entry`, eventually a batched tick report.

A future generic (`emit-events` or similar) might unify how both kinds surface their output to observers. Deferred — first resolve the subscribing question: who consumes these events, and through what interface?

---

## Substrate Abstraction: The Noosphere-Ghosts Case

The resolver protocol is a substrate-abstraction pattern. The noosphere-ghosts runtime currently has exactly one substrate: the droplet API (Postgres via `dpn-api-client`). Every runtime module imports `af64.runtime.api` (`api-get`/`api-post`/`api-patch`/`api-put`) and calls `/api/agents`, `/api/perception/~a`, `/api/conversations`, `/api/af64/tasks`, etc.

**This is the same seam a resolver covers.** Reframing the ghosts to work against either a stack of markdown files OR the database is the resolver pattern applied to the ghosts' substrate boundary. The four API verbs become the four resolver verbs; the concrete choice (markdown walker, Postgres client, in-memory stub) becomes a swappable class specialization.

### The minimal ghost-substrate protocol

```lisp
(defgeneric ghost-read   (substrate resource filter)
  (:documentation "GET /api/<resource>?<filter> — returns hash-table or vector."))

(defgeneric ghost-write  (substrate resource data)
  (:documentation "POST /api/<resource> — returns the created resource."))

(defgeneric ghost-update (substrate resource id data)
  (:documentation "PATCH /api/<resource>/<id> — returns the updated resource."))

(defgeneric ghost-upsert (substrate resource data)
  (:documentation "PUT /api/<resource> — create-or-update by natural key."))
```

Concrete substrates:

| Substrate | ghost-read / write / update / upsert |
|---|---|
| `postgres-substrate` | Wrap existing `api-get`/`api-post`/`api-patch`/`api-put`. One-to-one. |
| `markdown-substrate` | Read: scan `~/Documents/Droplet-Org/` for frontmatter + content. Write: create `.md` with YAML frontmatter. Update: in-place edit of frontmatter fields. Upsert: resolve by wikilink or path. |
| `stub-substrate` | In-memory hash-of-hashes. For tests and offline work. |

### Field mapping is already halfway there

`config/em-field-mapping.lisp` exists and defines how agents' domain vocabulary maps to API payload keys. That file is the substrate's schema descriptor — it's the contract a markdown-substrate also has to satisfy, just with YAML frontmatter keys instead of JSON field names.

### What this lets the ghosts do

- Run against the droplet for production (today).
- Run against a local markdown stack for development, travel, offline — the laptop becomes fully self-contained.
- Run against the stub for tests.
- Swap substrates mid-session in principle (though no corpus choreography demands this yet).

### Where this meets InnateScript

When an InnateScript choreography delivered as an agent's cognition output needs to read or write ghost-state (tasks, conversations, drives, decisions), it goes through the *same* resolver that the agent tick uses for its own substrate calls. One class of resolver. Two callers: the outer tick engine and the InnateScript evaluator during cognition. Both see the same markdown-or-DB choice and neither cares which was picked.

This is why "reframing the ghosts for markdown OR database" is not a separate project from "wiring InnateScript into the ghosts." They are the same seam, addressed by the same protocol.

---

## Where Clauses: The Missing Feature

The first pass of this contract did not mention `where` at all. Every file in the corpus uses it. This section documents the gap the corpus filled.

### The shape `where` takes

Three common forms appear across the 130 files:

**Filter (most common):**
```
@entries where is-read is false
@c:gifts where @g:traits intersected-with @t count at least 2
```

**Dispatch (alternative to match):**
```
@cmd:kind
    where "LIST"     -> ...
    where "RETR"     -> ...
    otherwise        -> ...
```

**Invariant (rule checked by the resolver):**
```
[wb[add-post {board: @b, post: @p}
    where @p:parent-id references a post in @p:thread-id]]
```

### How the resolver receives a `where`

The parser lifts `where` clauses into a predicate AST node attached to the nearest enclosing bracket or reference. The evaluator hands it to the resolver as an optional `:where` key in the args plist (for `resolve-context`) or a dedicated parameter (for `resolve-reference` and `resolve-search`).

The predicate AST has a small inductive shape:

```
predicate ::= comparison
            | logical-and   [predicate predicate ...]
            | logical-or    [predicate predicate ...]
            | logical-not   predicate
            | field-access  target field
            | in-set        target set
            | contains      target needle
            | matches       target pattern
```

### How the resolver interprets it

Two legal strategies:

1. **Evaluate in CL.** Load all candidates, apply the predicate in Lisp, return matches. Works universally; slow on large sets.
2. **Translate to substrate query.** A Postgres resolver translates the predicate into SQL `WHERE`; an ElasticSearch resolver into a DSL query. Faster but substrate-specific.

The resolver chooses per verb. A resolver that cannot interpret a given predicate should either fall back to (1) or return resistance with kind `:unsupported-predicate`.

---

## IN ORDER TO: Purpose Blocks

`IN ORDER TO` opens every choreographic case in the corpus. The clauses that follow state what the block is for in natural language.

**What the resolver may do with it:**
- Attach to logs / traces for operator diagnostics.
- Display in commission tooling ("this agent is being asked to verify X so that Y").
- Use for verb selection *when the verb dispatch is ambiguous* — rare, but valid.

**What the resolver must not do with it:**
- Treat behavior as load-bearing on purpose content. Purpose is narrative. The verbs are operational. A choreography with a misleading `IN ORDER TO` is still expected to execute the same way.

The parser attaches `IN ORDER TO` bodies to the block's AST node as a `:purpose` prop. The resolver may read it from `eval-env` during context resolution.

---

## Choreographic Operators and the Resolver

The choreographic operators (`concurrent`, `sync`, `join`, `until N`, `every Nms`, `at [[time]]`, `<-`, `||`) are evaluator concerns, not resolver concerns — **except** where they intersect with scheduling and state.

### `||` (fulfillment on resistance)

When a bracket expression returns resistance, the evaluator checks for a `||` follow-up. The resolver doesn't see the `||` directly; it just returns resistance and the evaluator routes.

Example shape: `[op] || [fallback]`

### `concurrent [...]` / `join`

Fan out sub-expressions, wait for all. The resolver sees each sub-expression as a normal call; the evaluator handles parallelism. **Stateful resolvers must be thread-safe** when used under `concurrent`. This is a cost of being stateful.

### `every Nms [...]`

Periodically re-evaluate the block. Relies on `schedule-at` and (for state-bearing modules) `resolve-tick`. The evaluator owns the cadence; the resolver owns the step.

### `until N [...]` / `until condition`

Bounded repeat. Count-bounded (`until 10 found`) or condition-bounded (`until @status is not "running"`). The evaluator tests the condition; the resolver supplies the values the condition reads.

### `at [[time]]`

Delegates to `schedule-at`. Handle returned by `schedule-at` is the choreography's reference to the pending item (for cancel, inspect, etc.).

### `<-` (inward bind)

`@x <- [op]` binds the result to `@x`. `<- @agent{verify @prior}` routes verification. The evaluator handles binding; the resolver handles `deliver-verification`.

---

## Resolver Comparison

| Behavior | stub-resolver | default-resolver | rosetta-resolver (hypothetical) | your-resolver |
|----------|--------------|------------------|-------------------------------|---------------|
| resolve-reference | Hash-table lookup | Internal registry | Module-state reads | Your DB/API |
| resolve-search | Hash-table lookup | Returns resistance | Index queries | Your search |
| resolve-context | Hash dispatch | Returns resistance | Dispatches to 130 CL modules | Your substrate |
| load-bundle | Hash lookup | .dpn/.md file search | File search | Your storage |
| resolve-wikilink | Hash lookup | Vault-path file read | Vault read | Your wiki |
| deliver-commission (async) | Records to list | Records to list | Logs + queue | Your agent system |
| deliver-commission (sync) | Hash lookup | Returns resistance | Not applicable | Your agents w/ reply |
| deliver-verification | Records to list | Pass-through | Verifier dispatch | Your verification flow |
| schedule-at | Records to list | Records to list | In-memory scheduler | Your scheduler |
| resolve-tick | Records to list | Returns resistance | Advances module state | Your state machine |
| snapshot/restore | Dict copy | Returns resistance | CLOS slot copy | Your persistence |

---

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
    #:load-bundle #:deliver-verification #:schedule-at
    #:resolve-tick #:snapshot-state #:restore-state)
  (:import-from :innate.types
    #:make-innate-result #:make-resistance))
```

See `docs/examples/skeleton-resolver.lisp` for a complete minimal example.

---

## Corpus Anchors

Three representative `.dpn` files that stress-test this contract. A resolver that correctly runs all three covers most of what the 130 demand:

- **`classes/bank-account.dpn`** — `resolve-context` with keyword args, `<-` verification gated by `where` invariant, structured resistance on conservation-check failure.
- **`graphics/turtle.dpn`** — stateful resolver (canvas + turtle + state-stack), `resolve-tick`-equivalent via step commands, snapshot/restore via PushState/PopState, bundle loading for sub-procedures.
- **`web/media-player.dpn`** — three-state FSM, `resolve-tick` consumes delta-ms and emits boundary events, `where`-gated transport actions (context-dependent play/pause/stop).

Together these three exercise: keyword args, `where` clauses, `IN ORDER TO` purpose blocks, structured resistance, stateful resolver state, tick-driven updates, snapshot/restore, bundle loading, verification via `<-`, and fulfillment via `||`.

---

## What Changed Since the First Pass

For reviewers of the pre-corpus contract, the concrete deltas:

1. **Argument conventions documented** — keyword plists, structured resistance, `where` predicates, `IN ORDER TO` purpose blocks. Previously unmentioned.
2. **`deliver-commission` supports sync return values** — previous contract forbade resistance from commissions; the corpus requires synchronous replies.
3. **Two new generics** — `resolve-tick` (20+ corpus entries are tick-driven) and `snapshot-state`/`restore-state` (preemption, retry-resume).
4. **Simulation tick distinguished from agent tick** — `resolve-tick` is the former; the noosphere-ghosts 10-minute cycle is the latter; they are not the same primitive and InnateScript never drives the outer agent tick.
5. **Substrate abstraction section added** — the noosphere-ghosts `af64.runtime.api` seam is the same shape as the resolver protocol; reframing the ghosts to work against markdown OR Postgres is the resolver pattern applied to the ghost substrate.
6. **Stateful resolvers made explicit** — was implicit in "concrete resolvers add their own state"; now a named pattern with scope semantics.
7. **`where` as a first-class input to three generics** — reference, search, context.
8. **Choreographic-operator integration** — `concurrent`, `every`, `until`, `at`, `||`, `<-` now documented at the resolver boundary even though most live in the evaluator.
9. **Corpus anchors** — three specific `.dpn` files named as the smallest set that exercises the full surface.
