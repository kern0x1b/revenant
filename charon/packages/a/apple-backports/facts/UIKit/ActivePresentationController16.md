# -[UIViewController activePresentationController], iOS 16.0

## The header

```objc
// Gets the presentation controller managing this view controller. If the original presentation
// controller has adapted, this returns the adaptive presentation controller. If this view controller
// has not yet been presented, this property returns nil.
@property (nullable, nonatomic, readonly) UIPresentationController *activePresentationController API_AVAILABLE(ios(16.0), tvos(16.0)) API_UNAVAILABLE(watchos);
```

## What the release carries, measured

`UIViewController` is a class both band ends carry, so this is a selector-level question with a real
control on the same rows of the same reader:

```
CHARON_ROOT=$PWD xmake l tools/corpus/objc-inventory.lua ~/.charon/dyld/6.1.3/dyld_shared_cache_armv7 > inv-6.1.3.tsv
CHARON_ROOT=$PWD xmake l tools/corpus/objc-inventory.lua ~/.charon/dyld/12.0/dyld_shared_cache_arm64  > inv-12.0.tsv
```

```
6.1.3  UIViewController  selectors=601   activePresentationController: none   presentationController: none   -view: yes  -presentedViewController: yes
12.0   UIViewController  selectors=1406  activePresentationController: none   presentationController: yes   -view: yes  -presentedViewController: yes
16.0   UIViewController  selectors=1639  activePresentationController: -activePresentationController
```

The controls sit on the same rows: 601 and 1406 selectors, including `-view` and
`-presentedViewController`, so the reader is reading the class and its selectors; the zero on
`-activePresentationController` is the release's. The 6.1.3 line also shows why 8.0's
`-presentationController` is a port object rather than a release one: the release of that era has no
such method at all, which is what `ios8presentation.json` records.

## What the port does

The port keeps one presentation controller per presented view controller:
`charon_set_presentation_controller` stores it in `CharonCustomTransition.m` when a presentation
starts, and `charon_presentation_controller_of` reads it back — that is what `-[UIViewController
presentationController]` answers (`UIPresentationController.md`).

`-activePresentationController` answers the stored controller only while it is one that has begun
managing this view controller, which `-presentedViewController` says, and nil otherwise. That is the
header's own rule for "has not yet been presented", and it covers the case where a controller exists
but has not started: `-popoverPresentationController` makes a `UIPopoverPresentationController` on
demand (`UIViewController+Popover.m`), so between asking for it and presenting, this property answers
nil where `-presentationController` answers the object.

**What is not carried:** where UIKit hands back the *adaptive* controller of a presentation that
adapted, this port hands back the controller that is managing the receiver. The one adaptation this
port has is a popover on a phone becoming a full screen presentation, with the delegate free to name
a different view controller (`UIViewController+Popover.m`); the controller that ends up on screen
holds its own presentation controller and answers this property itself. Reporting that difference
here rather than claiming it is what the header asks for.