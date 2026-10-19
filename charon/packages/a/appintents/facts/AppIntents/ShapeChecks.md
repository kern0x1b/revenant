# The shape checks: what they hold, what they do not, and the retired claim

Three tools, all under `packages/a/appintents/tests/`, all run directly — no build, no slow slot.
They read the framework's own interface from the machine's `charon@iphoneos-sdk` 26.2 install.

| tool | rows it holds | what it reads |
| --- | --- | --- |
| the builder shape check (removed) | the two result-builder families' seven rows | the interface's declarations, per type, and **this module's** declarations, per builder |
| the foreground-continuation shape check (removed) | the three `ForegroundContinuableIntent` shapes, including the overload the ledger does not carry | the interface's declarations and this module's `extension ForegroundContinuableIntent` |
| the row census (removed) | nothing -- it *census* | a digester dump and a measured missing-rows list, and sorts what the dump cannot print |

## The one distinction everything rests on: external label vs internal name

A Swift parameter carries an **external label** and an **internal name**. `_ item:` is the label `_`
with the internal name `item`, and the **label** is what a caller writes.

| declaration | external label | internal name | a defect? |
| --- | --- | --- | --- |
| `_ item:` | `_` | `item` | no |
| `_ item2:` | `_` | `item2` | **no** -- the internal name changed, and no caller can see it |
| `item:` | `item` | `item` | **yes** -- a caller must now write `item:` |

The parameter-label parser (removed) tells them apart: the parameter list is split on top-level
commas, a leading `_` is the wildcard label, a single token is both, and a declaration is matched by
**balanced parentheses** -- a bounded window ending at the first `->` stops *inside* an `async`
closure parameter, whose own type contains one (`continuation: (@MainActor () async throws -> Void)?`),
and the signature then parses as having no parameters at all. That was measured on this check, not
reasoned about.

## What the checks hold

**Existence per side, never a first match.** For each row: the row's labels come from the **row's own
spelling** (`buildBlock(_:)` → `['_']`, `buildBlock()` → `[]`, `buildExpression(_:)` → `['_']`); every
declaration of that name is collected **on each side** as a list of label lists; the row is green iff
the row's labels are in **both**. Plus, from the same per-side lists: the **generic parameter**
(`<…>` between the name and the `(`) and **`@resultBuilder`**. For the Foreground rows also
`async`, `throws` and `@MainActor`.

A red row prints the row, the row's labels, and both full lists, e.g.

```
RED  IntentItem.Builder.buildBlock(_:)   row=['_'] port=[[], ['items']] framework=[['_'], ['_'], []]
```

**The two drivers**, the builder mutation driver and the foreground-continuation check's `--mutate` mode, which were removed with the appintents Python tests. They are what made "the check holds" a measurement rather than a claim. Each applied **both** mutations to a **copy** under `.agent-work/runs/`, asserted that the copy differs and
the pattern matched exactly once, ran the check against the copy through `BUILDER_CONTRACT_SOURCE` /
`FOREGROUND_CONTRACT_SOURCE`, and restored **only** from `git show HEAD:<file>`, verifying the bytes
afterwards. Each driver exited 1 if the internal-name change was red, or if the external-label change was
green. Both reported `0 of 2 mutations behaved wrongly` when they last ran.

## What the checks do not hold

**Behaviour.** They read declarations, not calls. A declaration can have the right labels and still be
called wrongly, and the check cannot see that. The *behaviour* half of these rows is the call-site
probes — `tests/probe-intembuilder.swift` writes `buildBlock(a, b, c)` and the empty `buildBlock()`,
`tests/probe-itembuilder.swift` the empty call, a list of sections and a list of items, and
`tests/probe-intembuilder.swift` /  `tests/probe-intentperson-coding.swift` the other two rows — typechecked
against **a module built from this tree**. That is a device compile and a typecheck, it needs a slow
slot, and it is the stronger check the shape checks are a stand-in for until it runs.

**The rows themselves.** These checks do not place a ledger row; the digester does, and it prints a
`@resultBuilder` type's members not at all. A green row here means the *shape* is right, and says
nothing about the count.

## The retired claim

An earlier version of this file said the checks were **"silent on the port's labels"**, and explained
the four "false failures" I got by comparing a row's `_` against a port declaration's whole
`_ items` token. **Both were wrong and the claim is retired.** The first was the review's finding
(the deleted builder check printed the *interface's* declaration as its evidence and never read this
module's); the second was a category error on my part — a label is not a label-plus-internal-name —
and it is why the parser exists. What the file used to get right and still holds: the checks were
one-sided, and are now not.
