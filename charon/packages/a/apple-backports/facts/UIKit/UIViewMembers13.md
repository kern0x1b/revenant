# The members of views, controllers and controls that iOS 13 and 14 added

Source: the host's own UIKit under Mac Catalyst (macOS 27.0), run in a process of its own before the port is loaded, and held against
the backport by the `views13` group of `tests/backports/host/uikit2` (68 statements); `tests/backports/device/uirest.m`
for a device. Where the host answers as the Mac does the test says so.

## Views and controllers

- `UIView.transform3D` is the layer's `transform`, and follows `transform` as the host's does.
- `overrideUserInterfaceStyle` of a view controller is kept, unspecified until set, and is part of its trait collection: the
  controller's `traitCollection` carries it over the one its parent or the screen gives, and the controllers and views under it
  inherit it as any trait. Setting it delivers `traitCollectionDidChange:` to the controller and everything under it, once, where
  the trait moved. The host answers this way (`darkstyle` group of `tests/backports/host/uikit2`), and the port does the same.
- `overrideUserInterfaceStyle` of a view is kept and read back, unspecified until set, and does NOT reach the view's own trait
  collection or the views under it: the host measures the view's trait as the superview's, dark under a light override, and the
  view under a light view as dark. The port answers the same, so a view's override changes nothing a program can read from the
  traits (the `darkstyle` group checks both).
- iOS 6 has no dark appearance to draw, so under a dark trait the system's controls keep their light drawing; the first dark
  override says so once in the log.
- `UIViewController.modalInPresentation` is kept, NO until set. A sheet (`UISheetPresentationController.md`) holds to it: a drag or a
  tap on its dimming view does not dismiss the controller, and a drag pulled a quarter of the way past the smallest detent tells
  the delegate it was attempted. A full-screen presentation has no
  swipe to dismiss, here as on iOS 13. `performsActionsWhilePresentingModally` is YES unless the Info.plist sets
  `UIViewControllerPerformsActionsWhilePresentingModally`.
- `UIView.focusGroupIdentifier` is kept, nil until set; iOS 6 has no focus engine. (`UIViewController.focusGroupIdentifier` is iOS 15's
  and is decided in `registry/UIKit/ios15-16.json`.)
- `+[UIView modifyAnimationsWithRepeatCount:autoreverses:animations:]` runs the block after setting `setAnimationRepeatCount:` and
  `setAnimationRepeatAutoreverses:`. The release has no way to scope them to the animations inside the block, so those of the whole
  enclosing block repeat, and the first call says so once in the log. Only a device can show the animations, so `uirest.m` reads the
  layer's animation after the block.

## Controls

- `UIDatePicker.datePickerStyle` is always the wheels, the one style iOS 6 draws; `preferredDatePickerStyle` is kept, automatic until
  set. (The host answers compact or inline, the Mac's.)
- `UISwitch.style` is sliding and `preferredStyle` is kept, automatic until set. `title` is the checkbox style's of the Mac idiom, which
  raises on the host off that idiom; the port keeps it, the first non-empty title says so once in the log.
- `UIPageControl` keeps the indicator images by page, the preferred image, `allowsContinuousInteraction` (YES until set) and the
  background style; `interactionState` is always none. A page out of range raises `NSInternalInconsistencyException`, "Page (3) must be
  within 0 and 3." for a page control of three pages (the bound is the count). The release lays out and draws its dots itself, and
  the port takes its `-layoutSubviews`: the release's layout runs first, then each page with an image (its own, else the preferred
  one) gets that image as a layer at the centre of its dot, where a page with neither keeps the release's dot. The centres are the
  release's own: a row of `sizeForNumberOfPages:` for the count, centred on the control, with the distance between dots the
  difference of the sizes for the count and for one, over the gaps. The image is drawn at its own size and over the dot, so an
  image with transparent pixels shows the release's dot beneath it. The layers are rebuilt at each layout, which the setters of the
  images request. The `pagecontrol` group of `tests/backports/host/uikit2` reads the pixels at the dot centres of a rendered control.
- The release's dots are not per-page subviews, so they cannot be hidden one page at a time. Measured on the host (macOS 27, the
  `pagecontrol` group): the control's one public subview is a `_UIPageControlContentView` (74 by 26) holding a `UIVisualEffectView`
  and a `_UIPageControlIndicatorContentView` (46 by 26), which draws the dots. The 6.1.3 inventory (`tools/corpus/objc-inventory.lua`)
  has no class of either name, so the host's structure is not the release's. The release's own per-page hook is
  `-[UIPageControl _pageIndicatorImageForPage:]` (and `_pageIndicatorCurrentImageForPage:`), which `EmojiPageControl` overrides; whether
  the release's layout reads it, and what the dot subviews of 6.1.3 are, is not measured here. Until one is, a transparent image
  shows the dot beneath it on the port, which the host does not do.
- `UILabel.lineBreakStrategy` is 65535, the standard, until set and is kept; `UIScrollView.automaticallyAdjustsScrollIndicatorInsets` is
  YES until set and is kept; `UITextView.usesStandardTextScaling` NO; `UISplitViewController.primaryBackgroundStyle` none.
  Each says so once in the log when set to something else, since nothing of the release reads it.
- `UISegmentedControl.selectedSegmentTintColor` is kept; iOS 6 tints the whole control and not the selected segment alone.
- `UIPanGestureRecognizer.allowedScrollTypesMask` is kept, none until set, and says so once when set; no scroll event reaches the
  recogniser.
- `-[UISearchBar setShowsScopeBar:animated:]` sets `showsScopeBar`. `UIScreen.calibratedLatency` is 0.
- `UINavigationItem.backButtonDisplayMode` is kept; generic gives the item's `backButtonTitle` the localised "Back" and minimal the
  empty string, unless the title was set by the application, which the port then leaves alone; default puts back what it set.
- `+[UIVibrancyEffect effectForBlurEffect:style:]` is the effect of the blur, with the style kept and nothing drawn differently.
- `-[UIResponder validateCommand:]` does nothing and does not pass the command to the next responder, as the host does.
- `UIResponder.editingInteractionConfiguration` is the default.
- `UNNotificationResponse.targetScene` is the application's one scene, and `NSUserActivity.targetContentIdentifier` is kept.
- `-[UIImpactFeedbackGenerator impactOccurredWithIntensity:]` plays the impact's buzz with its strength multiplied by the intensity,
  clamped to 0 and 1; 0 plays nothing.
