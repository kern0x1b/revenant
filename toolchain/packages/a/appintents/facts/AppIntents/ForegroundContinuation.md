# `ForegroundContinuableIntent` — the two rows, and why they are not written yet

The next family piece after the two builder families, by the order in `NextFamily.md`. The corpus
ledger carries two rows, and this module has an **empty** `extension ForegroundContinuableIntent`
(`Remaining.swift:230`), so both are undeclared — and the check says so rather than the facts
asserting it: the shape check over the framework's declarations.

**What the framework declares**, quoted from the machine's `charon@iphoneos-sdk` 26.2 install:

| row | the framework's declaration |
| --- | --- |
| `requestToContinueInForeground(_:continuation:)` | `public func requestToContinueInForeground<ResultValue>(_ dialog: AppIntents.IntentDialog? = nil, continuation: @MainActor () async throws -> Result) -> Result` |
| `needsToContinueInForegroundError(_:continuation:)` | `public func needsToContinueInForegroundError(_ dialog: AppIntents.IntentDialog? = nil, continuation: (@MainActor () async throws -> Void)? = nil) -> AppIntentError` |

**The port's design, decided.** A service that needs a system is not hardware; it is ours to
provide, and these are the decisions:

* **`requestToContinueInForeground` runs the continuation in place and carries the generic through.**
  The framework's declaration is `requestToContinueInForeground<ResultValue>(_ dialog: IntentDialog? =
  nil, continuation: @MainActor () async throws -> ResultValue = { () }) async throws -> ResultValue
  where ResultValue: Sendable`, and this port declares exactly that shape: `ResultValue` is **not**
  wrapped in a port-specific type, the closure's value is what comes back, and an error it throws is
  thrown on. A lossy wrapper would be a second answer to a question the caller already answered.
* **Both `needsToContinueInForegroundError` overloads exist** -- the `continuation:` one, which runs
  the caller's continuation, and the `alwaysConfirm:` one, which is the framework's second overload
  (`:1005` in the same interface) and not a subset chosen by which row the ledger carries.
* **What a device does that this does not, named as the difference:** the system puts the intent's
  window in front of the user and asks. There is no system dialog on these releases, and this port's
  intent runs **inside the app's own process**, so there is nothing to move in front of and nothing to
  keep alive. The call runs the continuation here, and `alwaysConfirm:` has no dialog to consult --
  both return the framework's own empty `AppIntentError`, which is what its return type says. That is
  the one thing this port cannot reproduce, and it is a *missing service*, not a missing declaration.

**The check now holds all three shapes**, not the ledger's two: it matches the framework's **matching
overload** per row (the label that identifies an overload is the second one -- a row's first label is
`_`, the dialog), and it compares the generic parameter, the labels, `async` and `throws` against it.
`3 of 3 rows declared, 0 shape failure(s)`.

**What made this harder to check than the builder families**, and it is the same class of bug twice
more: a parameter's own type contains `()` and `)`, so a `\([^)]*\)` match stops *inside* it; a
declaration wraps onto the next line, so a per-line match never sees the label; and
`requestToContinueInForeground<ResultValue>(` puts a generic list between the name and the `(`.

**What the earlier version of this file said, and why it was wrong to say it.** Every earlier declaration was a shape the interface fully determined — a stored
property, a `static var` of a named type, a `@resultBuilder` member. These two have a **generic
parameter and a return type the interface fixes to the *caller's* `Result`**:

* `requestToContinueInForeground` is generic in a `ResultValue` and returns it: it runs the
  continuation and hands back the value the caller asked for. The port would have to carry that
  generic parameter, and to decide what it does *with* the answer — which is a system's job (does the
  run carry on, does it come back to the foreground), and there is no system here. The port's
  `CharonForeground.Continuation` is a value with `mayContinue`, which is the port's own answer to
  "may it carry on", and wiring it to a generic `ResultValue` is a design decision, not a copy of a
  signature.
* `needsToContinueInForegroundError` has a **second overload** in the same interface taking
  `alwaysConfirm: Bool` and returning `AppIntentError`; the ledger's row is the `continuation:` one. A
  declaration that only had the overload the ledger names would be a subset, and a subset chosen by
  which row happens to be in the ledger is a metric, not a shape.

So this piece is the **check and the two quoted declarations**, which is what lets the next one write
the code against the interface rather than against my memory of it. The check runs, exits 0, and
prints `0 of 2 rows declared` — which is the fact.
