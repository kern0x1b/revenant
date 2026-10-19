# Registering for a preview, iOS 9

Introduced in iOS 9.0, deprecated in iOS 13: `-[UIViewController registerForPreviewingWithDelegate:sourceView:]`,
`-unregisterForPreviewingWithContext:`, the `UIViewControllerPreviewing` context it answers and the
`UIViewControllerPreviewingDelegate` the context holds. A press that measures hard enough on a 3D Touch screen asks
the delegate for a view controller to peek at, and a harder press commits it.

Source: the host's own UIKit under Mac Catalyst, run over `device/previewing-cases.m` by `host/previewing/run.sh`.
The host is the right oracle here and not a newer release standing in for an older one: Mac Catalyst reports
`UIForceTouchCapabilityUnavailable` just as iOS 6 does through this package's own
`UITraitCollection.forceTouchCapability`, so what the host records *is* the registration on a device that cannot
measure force.

## What the release does, and what the port copies

Read off the host and matched one for one:

- Registering answers a context that keeps the delegate and the source view it was given.
- `sourceRect` starts as `CGRectNull`, which prints as `{{inf, inf}, {0, 0}}`. It is not the source view's bounds:
  the header says the rect is set before each call to `-previewingContext:viewControllerForLocation:`, and no such
  call is ever made here. The application may set it and it reads back.
- `previewingGestureRecognizerForFailureRelationship` answers a real `UIGestureRecognizer`, the same object every
  time, enabled, and in no view. The system's is not added to the source view either, so a failure relationship
  built on it behaves as it does on the release.
- **The context is keyed by the source view.** Registering a second time on the same source view answers the
  context that is already there and keeps the delegate it was registered with, ignoring the new one; registering
  on another source view answers another context. That was read off the host, not assumed.
- `-unregisterForPreviewingWithContext:` forgets the context, is quiet for a context that was never registered and
  quiet when called twice.
- The delegate is asked nothing: `-previewingContext:viewControllerForLocation:` and
  `-previewingContext:commitViewController:` are never sent, on the host and here. Both are `absent` in the registry and
  not `ignored`: `ignored` would say the release answers the call itself, and iOS 6 has no
  `UIViewControllerPreviewingDelegate` at all. An application still adopts the protocol and builds, because the metadata
  comes from the SDK's header; nothing ever calls it.

## Where the port departs

The context holds its delegate weakly, as a delegate is held. The host was not asked which way it holds it, so this
is the port's choice and not a reading: a delegate that goes away leaves `delegate` nil here rather than dangling.

The registration says once in the log that no preview will ever be offered. An application that asks
`traitCollection.forceTouchCapability` first — which is what Apple's own guidance is — never registers at all and
never sees the line.
