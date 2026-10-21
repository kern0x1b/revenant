# revenant@appintents

The AppIntents framework of iOS 16, as one Swift module a port writes `import AppIntents` for, built
against the `revenant@swift-runtime` a port carries.

    target("my-port")
        add_requires("revenant@swift-runtime")
        add_requires("revenant@appintents")
        add_packages("swift-runtime", "appintents")

`AppIntents.swiftmodule` is built for the port's own architecture and release (armv7 at iOS 6.1.3
and later), the way Combine's `Combine` is: one module, so a declaration of one file sees every other,
and `libAppIntents.a` beside it. A port that carries the backports asks for the runtime built with
them, and gets the port's headers with it.

## What the module is

The whole of the API: the protocols (`AppIntent`, `AppEntity`, `AppEnum`, the queries, the resolvers,
the shortcuts provider), the parameter (`IntentParameter` with every one of the 148 initializers the
framework names), the entities, the queries and their comparators, the results, the system schemas
(251 declarations), the macros that declare a type from a schema, and the conformances the release's
own value types carry. `perform()` is the app's own: the module calls it and returns what the app
returned, in process.

The releases this port builds for run no Siri, no Shortcuts, no Spotlight index, no widget timeline and
no live activity. Every API for those exists here, and each one is the port's own answer:

| the framework would | this module | where |
| --- | --- | --- |
| hand the app's shortcuts to the system | writes them into the port's own store, and `appShortcuts()` reads them back | `Shortcuts.swift`, `RevenantShortcutStore` |
| write a donation to the system index | writes it to a plist under Application Support, and `donations()` reads it back | `Donation.swift`, `IntentDonationStore` |
| hand a widget's relevant intents to the timeline | the same store, and `relevantIntents()` reads it back | `Donation.swift`, `RelevantIntentStore` |
| show a confirmation, a choice or a dialog | the in-process handler `IntentConfirmationRequest.handler` / `IntentChoiceRequest.handler` answers; with none, the run continues as the caller asked | `IntentResult.swift` |
| set a focus filter | `current` is nothing, which is what a device with no focus filter answers | `SystemIntents.swift` |
| open a URL through LaunchServices | the port's own `RevenantURL.handler`; the open is recorded and nothing else | `URLRepresentations.swift` |
| expand a macro with the framework's plugin | the declarations are there; a port writes the conformance out | `docs/reference/backports/AppIntents/AppIntents/Macros.md` |

None of these is a silent fake: each is a real value in the port's own store or a real, absent answer,
and the facts file says which is which.

## The Foundation types the API is written in

`LocalizedStringResource` is carried inside the module (`LocalizedStringResource.swift`), because the
port's Foundation is the swift-5.4.3 overlay and predates the type, and AppIntents' entire API is
written in terms of it. The Foundation band owns the canonical copy
((a workflow file kept outside the repository), 24 rows); when it lands, that one file goes away and
nothing else here changes.

`AttributedString`, `Measurement` and `Calendar.RecurrenceRule` are conformed to only when the runtime
this package is built against has them, which the install measures with a probe and prints. Where a
type is missing the rows are left out of the module, and the ledger reads them as `missing` - the
truth - instead of the module claiming them.

## The seams and the hardware

Nothing in this framework needs hardware the device lacks: an intent, a parameter, an entity, a query
and a result are all software. The seams are the system services above, and each is answered the way a
device without the service answers, with the surface still in place.

## Licence

MIT, the repository's. `LICENSE` is the one at the root of the repository, copied into the package.

## Building it on its own, and the one-at-a-time rule

`xmake` resolves these packages out of the shared `~/.xmake` store, and that store takes a
**machine-wide** lock per package: a second `xmake` that reaches the same package waits, and prints
`package(swift-runtime) is being accessed by other processes, please wait!` until the first is done.
So every `xmake` command that touches the store goes through (a workflow file kept outside the repository), one at a time,
or it hangs:

    coordination/heavy.sh xmake f -c -y      # resolve
    coordination/heavy.sh xmake -y            # build

To build one of these Swift packages without a port, give `xmake` a project of its own, shaped as
the gate's `resolve()` shapes one (`coordination/build-gate.lua:44-48`):

    set_project("gate-tipkit")
    add_repositories("revenant <path to a checkout>")
    add_addons("revenant v0.8.13")             -- the newest version the checkout's recipe names
    set_config("apple_minimum", "6.1.3")
    includes("@addon/revenant/apple-ios")
    set_defaultplat("iphoneos")
    set_defaultarchs("iphoneos|armv7")
    add_requires("revenant@swift-runtime", {alias = "swift-runtime"})
    add_requires("revenant@appintents", {alias = "appintents"})
    add_requires("revenant@tipkit", {alias = "tipkit"})

A **fresh directory name per attempt** matters: xmake keeps a repository search index under
`~/.xmake/cache/quick_search`, and a directory name it has seen before is answered from that index
rather than from the checkout, so a stale entry makes a package that is present look absent. The
projects must be built through `heavy.sh` even to resolve, because resolution alone takes the lock.

`revenant@activitykit`, `revenant@tipkit` and `revenant@widgetkit` are built the same way, each adding its
own `add_requires("revenant@<name>", {alias = "<name>"})`; `activitykit` needs `revenant@appintents`
first, `tipkit` needs `revenant@appintents`, and `widgetkit` needs both.
