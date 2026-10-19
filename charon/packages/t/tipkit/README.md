# charon@tipkit

The TipKit framework of iOS 17, as one Swift module a port writes `import TipKit` for, built against
the `charon@swift-runtime` a port carries.

    target("my-port")
        add_requires("charon@swift-runtime")
        add_requires("charon@appintents")
        add_requires("charon@tipkit")
        add_packages("swift-runtime", "appintents", "tipkit")

## What the module is

`Tip`, `AnyTip`, `TipGroup`, `Tips` and everything under it — `Status`, `InvalidationReason`, `Action`,
`Parameter`, `Rule` with its `CompoundOperation`, `Event` with its `Donation`, `EmptyDonation`,
`DonationTimeRange`, `DonationLimit`, the three options, the four builders, `ConfigurationOption` with
its three nested values, and the four `PredicateExpressions` — plus `TipOption`, `TipKitError`, and the
views: `TipView`, `TipViewStyle` and its configuration, `MiniTipViewStyle`, `TipUIView`,
`TipUICollectionReusableView`, `TipUICollectionViewCell` and `TipUIPopoverViewController`.

## The seam: the tip is drawn in the app

TipKit's presentation is a popover the system's own service (`TipKitAgent`) draws over the app's
views, animated from the edge of the view the tip is anchored to, driven by a datastore the system's
settings app writes. iOS 6.1.3 runs no such service and has no TipKit at all, so:

* the **rules, the display count, the display duration, the donations and the datastore are real**: the
  store is a plist in the app's own Application Support, a rule's condition is evaluated over what the
  app has donated, and `shouldDisplay` is the framework's own answer (not invalidated, rules hold,
  the frequency allows it, the options' count and duration allow it);
* the **presentation is the app's own**: `TipUIView`, `TipUICollectionReusableView`,
  `TipUICollectionViewCell` and `TipUIPopoverViewController` are real `UIView`/`UIViewController`
  subclasses drawn by the release's own drawing, and the app presents `TipUIPopoverViewController` over
  its own controller — which is the in-app popover the framework would have drawn;
* `Tips.configure(_:)` records the app's own display frequency and container in the store.

`facts/TipKit/Rendering.md`.

## The SwiftUI half

Ten of TipKit's rows are extensions on `SwiftUI.View` (`View.popoverTip(_:arrowEdge:action:)` and its
five siblings, `View.tipBackground(_:)`, `View.tipCornerRadius(_:antialiased:)` and the rest). There is
no SwiftUI on a release this port builds for, so the module cannot declare them; `TipView` is the
value the app's own modifier attaches, and the same modifier is what a port with SwiftUI writes
against it. **Those ten rows belong to the SwiftUI band**, not to this one.

## Licence

MIT, the repository's.

## Building it on its own, and the one-at-a-time rule

`xmake` resolves these packages out of the shared `~/.xmake` store, and that store takes a
**machine-wide** lock per package: a second `xmake` that reaches the same package waits, and prints
`package(swift-runtime) is being accessed by other processes, please wait!` until the first is done.
So every `xmake` command that touches the store goes through `coordination/heavy.sh`, one at a time,
or it hangs:

    coordination/heavy.sh xmake f -c -y      # resolve
    coordination/heavy.sh xmake -y            # build

To build one of these Swift packages without a port, give `xmake` a project of its own, shaped as
the gate's `resolve()` shapes one (`coordination/build-gate.lua:44-48`):

    set_project("gate-tipkit")
    add_repositories("charon <path to a checkout>")
    add_addons("charon v0.8.13")             -- the newest version the checkout's recipe names
    set_config("apple_minimum", "6.1.3")
    includes("@addon/charon/apple-ios")
    set_defaultplat("iphoneos")
    set_defaultarchs("iphoneos|armv7")
    add_requires("charon@swift-runtime", {alias = "swift-runtime"})
    add_requires("charon@appintents", {alias = "appintents"})
    add_requires("charon@tipkit", {alias = "tipkit"})

A **fresh directory name per attempt** matters: xmake keeps a repository search index under
`~/.xmake/cache/quick_search`, and a directory name it has seen before is answered from that index
rather than from the checkout, so a stale entry makes a package that is present look absent. The
projects must be built through `heavy.sh` even to resolve, because resolution alone takes the lock.
