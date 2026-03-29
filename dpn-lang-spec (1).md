# Innate Language Specification
*A language of intention for the Dragonpunk stack*

---

## Philosophy

DPN-lang is not a query language, a scripting language, or a conventional agent orchestration DSL. It is a **language of intention** — a formal syntax for describing what you want, who should handle it, what context they need, and why, with enough structure that a capable receiver can act on it.

The language is grounded. Named contexts map to real infrastructure. `db` is the database. `noosphere` is the agent layer. You are not abstracting reality — you are addressing it directly.

The test of an Innate program: a human unfamiliar with any programming language should be able to make a reasonable guess at what it does.

---

## Core Syntax: The Container Trinity

DPN-lang has three container types, each with a distinct ontological role:

| Container | Syntax | Role | Feels Like |
|---|---|---|---|
| Brackets | `[name[...]]` | context / navigation / invocation | *going somewhere* |
| Parentheses | `(name)` | agent address | *speaking to someone* |
| Braces | `{name}` | bundle / scope / procedure | *bringing something* |

**Place, Person, Thing.**

---

## Bracket Expressions

Brackets are the universal container and address mechanism.

```
[context[verb[args]]]
```

### Anonymous Brackets
All layers unnamed — contextual placement or broadcast.

```
[[["Hello World!"]]]
```

Three depth levels, all anonymous. Depth is address. The presence or absence of a name changes the bracket's ontological type.

### Named Brackets
Named layers — addressed traversal or invocation.

```
[db[get_count[entry]]]
```

This reads as: ***to db, regarding get_count, concerning entry.***

Not `db.get_count(entry)` — not a method call. A prepositional address. More like sending a letter than calling a function.

### Arguments Inside Brackets

Comma separates multiple arguments to a context:

```
[db[get_count[entry, tables]]]
```

### Modifiers

A bare word appearing after a child expression but before the closing bracket is a **modifier** — an instruction to the outer context about how to handle or return results:

```
[db[get_count[entry, tables]name]]
```

Here `name` tells `db` to return names rather than (or alongside) counts. The receiver defines what modifiers it understands. Different contexts accept different modifier vocabularies.

### Key-Value Arguments

Labeled arguments use colon syntax inside brackets:

```
[type: "[[Burg]]", Lifestage: "<emoji>Seed"]
```

`[[Burg]]` is an Obsidian wikilink as a value — a document reference, a native type alongside strings and numbers.

### Block Body (Sequential Operations)

A named bracket expression can contain a list of operations that execute in order:

```
[noosphere[discuss_project(sylvia){burg_pipeline}[type: "[[Burg]]", Lifestage: "<emoji>Seed"]
                             advance[Lifestage]
                             process[yaml{follow wikilinks}+all, context]]
 append(entry)]
```

Operations in the body execute sequentially. The body implies **purposive** sequence — steps exist *because of* the goal, not merely *after* it.

---

## Agent Address

Parentheses designate an agent — a named entity with judgment who receives instructions and decides how to carry them out:

```
discuss_project(sylvia)
```

Sylvia is not a function. Functions get called. Agents get addressed. The parenthesis syntax marks delegation, not invocation.

Agents can also appear at the terminal position as the target of an append or output operation:

```
append(entry)
```

---

## Bundles / Scopes

Curly braces carry a named bundle, scope, or procedure — something brought into the expression rather than navigated to:

```
{burg_pipeline}
{follow wikilinks}
```

Bundles can appear as arguments to verbs, or as qualifiers on other expressions:

```
process[yaml{follow wikilinks}+all, context]
```

---

## The `+` Combinator

`+` extends scope. `yaml{follow wikilinks}` is a qualified expression; `+all` expands it to include everything:

```
yaml{follow wikilinks}+all
```

Read as: *yaml, following wikilinks, and everything else.*

---

## Emission: `->`

The `->` operator emits results. It is not assignment — values are not captured, they *flow out*.

```
[db[get_count[entry]]]
-> 52125
```

### Multiple Results

Space and comma both delimit multiple emitted values:

```
-> 52125 234
-> 52125, 234
```

Both forms are equivalent. Numbers never contain commas — commas are structural delimiters, not numeric formatting.

### Multi-Type Emission

Different types can flow out in sequence. Named results (table names, bare words) appear on separate lines:

```
-> 52125, 52
vault_notes
documents
projects
```

The emitter is layout-aware. Different types surface differently.

---

## Types

| Type | Example | Notes |
|---|---|---|
| Number | `52125` | No comma formatting |
| String | `"Hello World!"` | Double-quoted |
| Bare word | `entry`, `name`, `context` | Unquoted identifier |
| Wikilink | `[[Burg]]` | Obsidian document reference, used inside strings |
| Emoji slot | `<emoji>` | Type annotation for emoji-typed values |

---

## Intentional Structure: IN ORDER TO

DPN-lang has purposive sequencing built into its semantics. The body of a block expression is not merely sequential — steps exist *in order to* accomplish the goal stated in the header.

English equivalent of the block body structure:

```
noosphere, tell sylvia to discuss the burg_pipeline project
where type is [[Burg]] and Lifestage is Seed
IN ORDER TO
  advance the Lifestage
  process all yaml following wikilinks with full context
and append the result as an entry
```

`IN ORDER TO` is not `AND THEN`. It is causal and teleological. Most programming languages have no way to express *why* something is being done, only *what*. DPN-lang encodes purpose structurally.

---

## Formal Grammar (Current State)

```
program         := statement*
statement       := expression | emission

expression      := '[' name? agent? bundle? args? body modifier* ']'
agent           := '(' bare_word ')'
bundle          := '{' bare_word '}'
args            := '[' arg_list ']'
arg_list        := arg (',' arg)*
arg             := bare_word | string | kv_pair | qualified
kv_pair         := bare_word ':' value
qualified       := bare_word bundle combinator?
combinator      := '+' bare_word
body            := statement*
modifier        := bare_word

emission        := '->' emission_value+
emission_value  := value (',' value)* | bare_word

value           := number | string | bare_word | wikilink | emoji_slot
bare_word       := [a-zA-Z_][a-zA-Z0-9_]*
number          := [0-9]+
string          := '"' [^"]* '"'
wikilink        := '[[' [^\]]* ']]'
emoji_slot      := '<emoji>'
name            := bare_word
```

---

## Example Programs

### 1. Hello World

```dpn
[[["Hello World!"]]]
```

### 2. Count Documents

```dpn
[db[get_count[entry]]]
-> 52125
```

### 3. Count with Named Results

```dpn
[db[get_count[entry, tables]name]]
-> 52125, 52
vault_notes
documents
projects
```

### 4. Agent Orchestration

```dpn
[noosphere[discuss_project(sylvia){burg_pipeline}[type: "[[Burg]]", Lifestage: "<emoji>Seed"]
                             advance[Lifestage]
                             process[yaml{follow wikilinks}+all, context]]
 append(entry)]
```

---

## Open Questions

1. **What does a conditional look like?** When the world pushes back — what does DPN-lang say?
2. **Inward flow** — `->` is emission outward. Is there a `<-` for explicit inward binding, or does nesting handle all inward flow?
3. **Anonymous vs named bracket depth** — Does `[[["Hello"]]]` mean something different from `[[["Hello"]["World"]]]`? Is order within a layer meaningful?
4. **Are modifiers a fixed vocabulary per context, or fully open?** If open, the receiver defines its own language — contexts have dialects.
5. **Emoji slot** — is `<emoji>` a type annotation (a value of emoji type) or a literal placeholder? If annotation, the type system includes emoji as a native type.
6. **Wikilinks as values** — `[[Burg]]` inside a string implies the language knows about the document graph. What operations can be performed on wikilink-typed values?

---

*Derived from design session, March 2026.*
*Language: Innate (.dpn). Stack: Dragonpunk / EM Corporation.*
