# UISheetPresentationController, iOS 15.0 and 16.0

Introduced in iOS 15.0: the presentation controller of a page or form sheet in a compact width - the card that
slides up over the presenter to one of its detents, with a grabber, a drag that moves it between detents or takes it
down, and a presenter that scales back behind it. iOS 16.0 added custom detents, their identifiers, the resolution
context, `UISheetPresentationControllerDetentInactive` and `-invalidateDetents` (`UISheetPresentationController16.m`).

Sources:
- UIKitCore of the held 16.0 cache (arm64e), read statically for the geometry, the detents, the dimming, the drag and
  its end, the stack of sheets and the corners; the 18.0 cache where it confirms or corrects a value. The addresses are
  below and, for each value, beside it in the code.
- The host's own UIKit under Mac Catalyst for what the API answers - defaults, descriptions, equality, the resolution of
  detents for eleven containers, which styles have a sheet: `tests/backports/host/sheet/run.sh` writes 42 records into
  `tests/backports/device/sheet-expectations.h`, which `tests/backports/device/sheet.m` holds the port to on iOS 6. The
  host shows a sheet in a bridged window of its own (581 x 641), so it is no oracle for layout, and its idiom is the pad,
  so it is none for the grabber (60 x 4 there, 36 x 5 on the phone).

## What has an oracle besides the read

- The API (defaults, descriptions, equality, which styles have a sheet) and the resolution of the medium and large
  detents for eleven containers (0.63 of the maximum up to a height of 568, 0.56 above): the host's UIKit, recorded by
  `tests/backports/host/sheet/run.sh`.
- The metrics the port takes as constants - topOffset 10, 8 in a compact height, the maximum depth 2, the transition
  duration 0.4, the spring's response 0.3441442326 and damping 1 and 0.8: the host's `_UISheetPresentationMetrics`
  agrees, `tests/backports/host/sheetmetrics/run.sh`, which reads them from the port's source. Its corner radius is 8,
  of the design after iOS 26; 16.0 answers 10, and the test fails if the host stops differing.
- Nothing else. The host (Mac Catalyst of macOS 27) shows a sheet in a bridged window of its own (581 x 641) in the pad
  idiom, and has no `_UISheetLayoutInfo` class to drive with a phone-sized container (measured: `NSClassFromString`
  answers nil). What rests on the read of the 16.0 cache alone: the margins and the frame, the presenter's scale and
  lift and the stack of sheets, the corner radii and their blending, the dimming fractions, the shadow's opacity, the
  grabber's size and spacing (the host's pad grabber is 60 x 4), the drag's rubber band and projection, the keyboard
  detent and the grabber's tap.

## The API

- `mediumDetent` and `largeDetent` make a new object each call; detents of one type are equal and hash as NSObject does;
  a custom detent equals only itself. Descriptions carry `_type=medium|large|custom` and the identifier.
- Identifiers: `com.apple.UIKit.medium`, `com.apple.UIKit.large`; a custom detent without one gets a fresh UUID string.
- `UISheetPresentationControllerAutomaticDimension` and `UISheetPresentationControllerDetentInactive` are the largest
  CGFloat, as the release's are.
- Defaults: detents `[large]`, no selected identifier, no largest undimmed identifier, no grabber, the automatic corner
  radius, scrolling that expands to a larger detent at the edge, not edge-attached in a compact height, the width not
  following the preferred size, no source view and no delegate.
- `UIViewController.sheetPresentationController` answers the sheet for a page or form sheet (Automatic resolves to the
  page sheet, `UIModalPresentationAutomatic.md`), made when it or `presentationController` is first asked, and the same
  object after; nil for every other style.
- The delegate hears `sheetPresentationControllerDidChangeSelectedDetentIdentifier:` when a drag or a tap on the dimming
  view settles on another detent (not when the program sets the identifier), and the four
  `UIAdaptivePresentationControllerDelegate` dismissal members below.

## Geometry (iPhone portrait, 16.0)

- Margins (C function 0x1890cab64): the safe area plus 2 x topOffset = 20 on top and bottom; 8 in a compact height.
  A phone without a home button in a compact width gets topOffset once, 10 (0x1890cad1c: `+[UIDevice _hasHomeButton]`,
  then the horizontal size class); every other idiom and a phone with one get 20. No public API names a home button
  (SDK 16.4 declares none); the port takes a window with a bottom safe area inset for a device without one: such a
  device keeps that inset for its home indicator in every window, from iOS 11, the first release it runs. Before 11
  every device has a home button (iPhone 3GS to 8, every iPod touch and iPad of those releases) and the port's
  `safeAreaInsets` answers no bottom inset. apple-backports is built by band up to the latest release of an
  architecture (`firmware.versions`: arm64 up to 14.x below the sheet's own 15.0, `modules/apple/backports.lua`
  `band_plan`), and the files that carry the sheet and the presentation machinery export nothing the release has before
  15.0 or nothing at all, so they are in the bands of 11 to 14 too, where devices without a home button run.
  From 8.0 on `UIPresentationController` is the release's class and `UIPresentationController.m`, which carries the
  methods the port's engine sends a presentation controller (`-charon_setContainerView:` and the rest), is left out, so
  `UIViewController+TransitionCoordinator.m` does not run its engine there for styles 4 to 6 or for the sheet: it calls
  the release's own present and dismiss. A custom, over-full-screen or over-current-context presentation goes to the
  release with its style and transitioning delegate untouched, and the release makes the application's presentation
  controller and runs its animators. The sheet goes through the same public custom presentation: for the release's
  present call the style is Custom and the transitioning delegate gives the sheet; the animators and the interactive
  controllers are those of the caller's delegate, and the sheet's `charon_transitionAnimator` where it gives none, as the
  engine below 8.0 asks. The style is put back after the call, and the caller's delegate once the sheet is dismissed, or at
  the controller's next presentation when a dismissal the port did not see took it away (its presenter's); until then
  `transitioningDelegate` answers the port's object. The sheet is asked for only when the presentation is one, a page,
  form or automatic style from a compact width (a controller that is asked for its sheet holds it), and the port's hold on
  it ends with the dismissal: UIKit's controller has no sheet after its dismissal either and makes another, with the
  default detents, when asked again (host `sheethandover`, which runs the installer itself on the host's UIKit, a release
  that presents the custom styles as one from 8.0 on does; the host's own sheet class stands in for the port's). The sheet
  lays itself out through the public hooks and `self.containerView`. Not measured on a device: no fleet device or emulator
  runs 8.0 or later; the handover is measured against the host's UIKit only. Two parts have no public
  counterpart there: touches passing through the container at an undimmed detent (`charon_containerIgnoresDirectTouches`),
  and `presentationController` answering the sheet, which below 8.0 only the port's category makes one object. Before
  e5522579 the path sent `-charon_setContainerView:` to the release's class and the application died with an unrecognized
  selector (the 8.0 to 10.3 bands of canon `0.8.10+8cfbbe9d` carry the path and not the class); e5522579 stopped the crash
  but still ran the engine for an animated custom style with a delegate's animator and gave the release full screen.
  On 7.0 and 7.1 the release carries custom transitions with a transitioning delegate too, and the port's engine still
  takes an animated custom presentation there; that is older than the sheet and not changed here.
- Lifetime (host, `sheet.lifetime`): a controller owns the sheet it was asked for and the sheet does not own it back, so the
  two are freed together, and a sheet kept alone answers nil for `presentedViewController` once its controller is gone; a
  presentation controller the caller made holds both of its controllers. Below 8.0 the port's class does the same: it holds
  its presented controller until `charon_set_presentation_controller` gives it to that controller
  (`-charon_ownedByPresentedViewController`), and weakly after, which the popover and the document menu share. From 8.0 on the
  sheet is a subclass of the release's class, whose `initWithPresentedViewController:` holds the controller as the host's
  holds a caller-made one, so a controller asked for its sheet and the sheet hold each other and neither is freed, from the
  moment it is asked until the port drops its own reference at the end of the dismissal: the sheet's
  `dismissalTransitionDidEnd:`, which the release calls once, with `completed` true, on every route (the controller's own
  dismissal, and the dismissal of an ancestor that takes it down: root, A, S and root dismissed; the host's UIKit measured
  both, `tests/backports/host/sheethandover`). There is no public way to make the
  release's reference weak. What stays held is a sheet asked for and never presented as one (never presented, or presented
  from a regular width): UIKit's frees it with its controller, the port's cannot on those releases.
- Frame (`_stackAlignmentFrame` 0x189051544): centred, the container's width, from the top margin to the container's
  bottom edge. iPhone 4S with the status bar: top 40, the sheet 320 x 440.
- Detents: large = the full height less the bottom safe inset (`maximumDetentValue` 0x1895e9958); medium = that times
  0.56 when the container is taller than 568 points, 0.63 otherwise, and inactive in a compact height (block 0x189d322b4,
  table 0x18a07a460; the 18.0 cache agrees). 4S: large 440, medium 277.2 (y 202.8).
- The presenter scales back while a sheet above it rises from its next detent to its full height (`_transform`
  0x1895e88b0): scale s = 1 - 2m/width with the content margin m = 16 at width 320 (0x188f67350: 16 up to 393, 20 above),
  lifted to stand topOffset (10) above the sheet's top. 4S, one sheet at large: the root at 16 30 288 414 behind it; at
  medium it is not scaled. A second sheet stacks the same way: the first at 16 30 288 396, the root at 16 40 288 414.
  These layout values are worked out from the read; `tests/backports/device/sheet.m` on an iPad 2 (6.1.3, the
  application phone-sized) gave every one of them, 2026-09-24, which shows the port computes what the read says, not
  that the read is the release.
- Corners (`_cornerRadii` 0x188f930e8): 10 on top; the bottom of a full-width sheet at depth 0 matches the display's
  corner, and a card behind a child blends towards the child's radius. The root card's corners run 0 to 10 as its child
  rises from medium to large.
- Grabber: 36 x 5, corner radius 2.5, `tertiaryLabelColor`, its top 5 points into the sheet (`_grabberSpacing` 5 in
  `initWithMetrics:` 0x1895e8da0; the 18.0 cache agrees). It fades as a child sheet above reaches its dimming detent.
- Dimming (`_percentDimmedFromOffset` 0x188f93878, `_percentDimmed` 0x188f936bc): the smallest detent dims unless
  `largestUndimmedDetentIdentifier` names one; over a parent that stacks, the dimming is confined to the parent's card at
  0.6 of the fraction, plus 0.2 of a grandchild's. Colour: black at 0.2 (0.48 dark; `_alertControllerDimmingViewColor`).
  At or below the largest undimmed detent the dimming view takes no touch and touches reach the presenter
  (`UITransitionView`'s ignoreDirectTouchEvents; the port's container answers `charon_containerIgnoresDirectTouches`).
- Keyboard (`-[_UISheetLayoutInfo _activeDetents]` 0x1895ea0e0, `-_handleKeyboardNotification:aboutToHide:`
  0x18938274c): the sheet hears the keyboard's will-show, will-hide and will-change-frame notifications (UIKit's private
  ones; the release posts the public ones with the same frame, duration and curve; a frame change counts only while the
  keyboard is shown). It keeps the keyboard's end frame in the container (CGRectNull once it hides) and whether the
  window's first responder needs the keyboard (UIKit's private `-_requiresKeyboardWhenFirstResponder` 0x18910488c: its
  keyboard responder adopts `UIKeyInput` and, when it answers `isEditable`, is editable; the port asks the first
  responder both, with the public protocol and selector). While a first responder in the sheet needs the keyboard and the keyboard meets the
  sheet's full-height frame, the sheet stands at its first detent: when that is below the large detent a detent with no
  identifier is put first, the first detent raised by the height of the keyboard over the full-height frame and no
  higher than the large detent, and the dimming detent moves down one. The selection stays; the sheet moves in an
  animation of the keyboard's duration with its curve as the options (block 0x189323d7c), and goes back to the selected
  detent when the keyboard hides.
- Grabber tap (`-[UIDropShadowView _grabberPrimaryAction]` 0x189e9113c, `-_dropShadowViewGrabberDidTriggerPrimaryAction:`
  0x189d33e74, `-[_UISheetLayoutInfo _grabberAction]` 0x1895ea700): the grabber is a control that acts on a touch up
  inside (0x1896b7964) and takes touches in 44 x 44 points around itself (touch insets, 0x188e8c3e4). While the keyboard
  holds the sheet the presented view ends editing; otherwise the detent before the current one, the last after the
  first (`-_indexOfActiveDetentForTappingGrabber` 0x1895ea69c: (n + current - 1) mod n), is selected in an animation and
  the delegate hears `sheetPresentationControllerDidChangeSelectedDetentIdentifier:`; with one detent the sheet is
  dismissed if it may be, as by a tap on the dimming view.
- Shadow: black at the dimming alpha, radius 2, zero offset, opacity 0.5 x (1 - dimmed) x presented (0x188f94848). Its shape
  is the card's: UIDropShadowView sets `shadowPathIsBounds` (0x189100748), so the shadow follows its bounds with the
  corners of its layer (`-updateCornerClippingViews` 0x18918964c); the port gives the layer the path it masks the card with.

## The drag (16.0)

- Rubber band: UIScrollView's curve d (1 - 1 / (x c / d + 1)) with c = 0.55; above the largest detent d = the gap to the
  safe area's top, at most 100 (20 on a 4S), below the smallest a quarter of the full height, at most 200.
- End (block 0x189069f70 of `draggingEndedInSource:`): the release is projected with the deceleration rate 0.99; the
  detent nearest the projection wins; a flick of 1000 points a second or more that lands back on the detent nearest the
  finger moves one detent further its way; below 250 points a second the velocity counts as none. The spring's damping
  is 1, or 0.8 for a flick, with a response of 0.3441 seconds (the host's metrics).
- Dismissal: when the drag passes the smallest detent the sheet asks whether it may dismiss - not while the controller
  presents another, not when it is `modalInPresentation`, else `presentationControllerShouldDismiss:`. If it may, the
  dismissal starts (`presentationControllerWillDismiss:`) and the drag carries it; let go above the smallest detent, it is
  taken back and the controller stays presented. If it may not, the sheet rubber-bands and, once pulled a quarter of that
  extent, tells the delegate `presentationControllerDidAttemptToDismiss:`, once per drag. `presentationControllerDidDismiss:`
  follows a dismissal by drag or tap once the release has taken the controller down.
- A tap on the dimming view (0x189d33ffc) dismisses when the sheet may be dismissed, otherwise moves to the largest
  undimmed detent if one is set; it tells nothing of an attempt.
- A pan that starts in a scroll view moves the sheet only when the scroll view is at its top edge, has no refresh control,
  does not scroll sideways, is not dismissing the keyboard interactively around the first responder, and the pan is not
  a quick repeat (0.4 s) of the last (0x18906b1b8). Which way the drag then goes is the documented rule
  (`prefersScrollingExpandsWhenScrolledToEdge`); that part of the release was not read.
- On an iPad 2 (6.1.3), the application phone-sized and the drags posted by `revtouch` from a probe outside the tree,
  2026-09-24: a slow drag from the large detent let go near the medium one settled at 202.8 with
  `sheetPresentationControllerDidChangeSelectedDetentIdentifier:`; a drag below the medium detent took the sheet down
  with `presentationControllerShouldDismiss:`, `WillDismiss:` and `DidDismiss:` in that order, and the release no longer
  counted the controller as presented; a `modalInPresentation` sheet dragged as far rubber-banded, sent
  `presentationControllerDidAttemptToDismiss:` once and settled at the medium detent. The flick and its spring were not
  measured there.
- The port's presentation calls the release's own dismissal after `dismissalTransitionDidEnd:`, as UIKit tells the
  presentation controller before the controller is gone, and UIKit 6.1.3 ends that dismissal only while the presented
  controller's view is in the window: taken out before, the presenter kept `presentedViewController` and the controller
  stayed `isBeingDismissed` (measured on the iPad 2, with the view put back as the control). The sheet leaves its card
  and that view in the container, which goes after the release's dismissal.

## Where the port differs

- The display's corner radius, which a full-width sheet's bottom corners match: UIKit reads it from the scene's settings
  (`cornerRadiusConfiguration` of `-_effectiveUISettings`, 0x188f93318), which no public API answers (SDK 16.4 declares
  none). The port answers 0 on a device with a home button, whose display has square corners (every device of iOS 6
  to 10), and on one without asks the release's own `-[UIScreen _displayCornerRadius]`, a private method, because
  nothing public names the value; it is in UIKit of the 11.0 cache (0x18a4df430, the main screen's radius, else 0), the
  first release a device without a home button runs, and in UIKitCore of 16.0 (0x188f8f06c).
- The root presenter: UIKit's root presentation is a full-screen sheet over the whole window; the port uses where the
  release puts the root view, under the status bar (0 20 320 460), which gives the same visible top (30) when it scales
  back. Derived from the read; the iPad 2 gave the root at 16 30 288 414 behind a large sheet.
- The status bar's appearance is not changed while a sheet is up.
- A keyboard change that arrives while the sheet is dragged or a spring moves it takes effect when that ends; UIKit
  moves the sheet at once.
- The grabber's tap is held on the iPad 2 by `sendActionsForControlEvents:` in `tests/backports/device/sheet.m`, and
  the touch reaching it by the window's `hitTest:withEvent:` at the grabber's centre and 10 points above the card
  (`-[UIDropShadowView hitTest:withEvent:]` 0x189041df4 asks the grabbers before its own bounds; a hit on the view itself
  answers nil; a hit in the content is cut to `contentTouchInsets`, which `-[_UISheetLayoutInfo _touchInsets]`
  0x189035fc8 makes the untransformed frame less the hosted one: zero for a sheet not hosting another, and the port has
  no hosting sheet). A real touch was not checked: `revtouch` delivered no touch to the phone-sized application in that
  session, the control tap included.
- In landscape the container is not rotated, a limitation of the port's presentation (`charon_presentation_run`)
  already.
- The "magic" shadow is drawn from a reading of what lies under the sheet, not composited by the render server. UIKit
  lays it under a sheet whose parent does not stack with it (presented from a full-screen or a custom presentation, or
  floating), at `_magicShadowOpacity` (0x188f92204, set by `-_percentDimmed` 0x188f936bc: 0 under a parent that stacks,
  which is every phone sheet over the root or over another sheet, and while the sheet fills the screen; else the
  dimming fraction): a `_UIRoundedRectShadowView` of corner radius 10, 150 points beyond the card, below everything
  (`-[UIDropShadowView initWithFrame:]` 0x189100234), showing the kit image `_UIPopoverShadow` (a 200 x 200 corner
  drawn four times into 400 x 400, stretched with cap insets 200 - 1/scale, or min(max(radius + 150, 170), that) when
  the view is under 400 points either way; `-_loadImageIfNecessary` 0x188efd9d0) under `kCAFilterVibrantColorMatrix`
  with the lower-intensity matrix (`-_updateShadowVisualStyling` 0x189229340). `tests/backports/host/sheetshadow/run.sh`
  measured on the host that this filter takes its colour from what lies behind the layer: the pixel is
  d + α·a(d)·(clamp(M·d) - d), with M the matrix, a(d) its alpha row and α the image's alpha times the view's. The
  release has no such filter and no backdrop layer, so the port reads the window under the sheet (`CharonBackdrop`,
  the blur's reader: the sheet view and everything above it hidden, at the screen scale) and draws that formula into a
  layer (`CharonSheetShadow.c`). The image's alpha is generated, not shipped: two blurred rounded quadrants fitted to
  the host's image, held to it pixel by pixel by the host test (worst 3/255 at 2x and at 1x against the 2x image's
  2 x 2 means). The host test also holds the port's matrix and cap insets to the host's shadow view and the port's
  pixel to the filter's over four colours; `tests/backports/device/sheet-cases.m` holds one pixel 20 points above a
  sheet over a red full-screen presentation to the host's image and matrix. The residual difference is the blur's
  (`UIVisualEffect.md`): what moves under the sheet is followed a few times a second, not every frame, and what is drawn
  with OpenGL ES is not in the reading. Every frame was measured on the iPad 2 (`UIVisualEffect.md`, "What it cannot do"
  has the probe): the read alone took 21 to 33 ms, against 16.7 ms a frame at 60, so a refresh every frame is out of reach.
  The shading of the read took 261 ms for the 620 x 740 region of a 320 x 440 card, 402 ms for 768 x 920 (540 x 620) and 432 ms
  for 768 x 992 (768 x 700) in doubles with a `lround` per channel per pixel, on the main thread (3.8, 2.5 and 2.3 frames a second
  while it ran). In floats and off the main thread (`org.charon.sheet.shadow`) it takes 108, 162 and 174 ms a reading, 8.1, 5.5 and
  5.2 readings a second, and the display link keeps 60.0, 54.8 and 55.5 frames a second while the shadow is followed; what is
  left on the main thread is the read (p95 25.5 to 37.6 ms, once per refresh). Not measured on the iPhone 4S (the screen stayed
  locked to `wake`); its 640 x 960 screen reads four times the pixels of the same region on the iPad 2's generation of chip.
- `presentationController` of a controller with a page or form sheet style answers the sheet; for a custom style the
  port answers the controller a transitioning delegate gave, else a plain `UIPresentationController`, as UIKit does; for
  other styles it answers nil where UIKit has its own full-screen controller.
