# revenant@tipkit

The TipKit framework of iOS 17, as one Swift module a port writes `import TipKit` for, built against
the `revenant@swift-runtime` a port carries.

    target("my-port")
        add_requires("revenant@swift-runtime")
        add_requires("revenant@appintents")
        add_requires("revenant@tipkit")
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

`docs/reference/backports/TipKit/TipKit/Rendering.md`.

## The SwiftUI half

Ten of TipKit's rows are extensions on `SwiftUI.View` (`View.popoverTip(_:arrowEdge:action:)` and its
five siblings, `View.tipBackground(_:)`, `View.tipCornerRadius(_:antialiased:)` and the rest). There is
no SwiftUI on a release this port builds for, so the module cannot declare them; `TipView` is the
value the app's own modifier attaches, and the same modifier is what a port with SwiftUI writes
against it. **Those ten rows belong to the SwiftUI band**, not to this one.

## Licence

MIT, the repository's.

## Building it on its own

The Backports build does not include this package; the `Swift` component does:

    ./xmakew f -P . -p iphoneos -a armv7 --component=Swift -y
    ./xmakew require -P . -y revenant@tipkit

`require` builds the package and the packages its recipe declares (here `revenant@swift-runtime` and
`revenant@appintents`), so that one command is enough. The first run also builds swift-runtime and
libcxx from source unless it takes their prebuilt releases; see
[prebuilt packages](../../../guides/prebuilt.md).

If an `xmake` command waits with `package(...) is being accessed by other processes, please wait!`,
another build is using the same package store, `$XMAKE_GLOBALDIR` (default
`~/.revenant/cache/xmake-global`). Wait for it to finish, or give this build its own store by setting
`XMAKE_GLOBALDIR` to another folder.
