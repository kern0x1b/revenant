# UIHoverGestureRecognizer, iOS 13.0

Introduced in iOS 13.0: a gesture recogniser that reports a pointer hovering over a view. iOS 6 has no pointing device, so the class is
present and answers as an iPad without a pointer does: it is a `UIGestureRecognizer` that never recognises, since nothing hovers, and says so once in the log the first time one is made
("this release has no pointing device, so the recognizer never leaves the possible state"), and can be added to a view like any recogniser.

Source: the host's own UIKit under Mac Catalyst (macOS 27.0), held against the backport by `tests/backports/host/uikit2` (the
`pointer` group), and the header of SDK 16.4.

## As UIKit does

- A fresh recogniser is possible, enabled, without a view, with no touches, `cancelsTouchesInView` YES, `delaysTouchesBegan` NO,
  `delaysTouchesEnded` YES and without a delegate; `-locationInView:` answers the origin. It is made with `-initWithTarget:action:` or `-init`.
- Added to a view it knows the view, and the view lists it in `gestureRecognizers`; it can be disabled and removed.
- It answers every member that arrived after the class did: `zOffset` (16.1), `altitudeAngle`,
  `azimuthAngleInView:` and `azimuthUnitVectorInView:` (16.4) and `rollAngle` (17.5) are all there, and
  on a device that cannot hover each answers what the header of 16.4 documents - 0 for the three, and
  an empty vector for `azimuthUnitVectorInView:`. Measured on 2026-10-01, all five of them, by the
  `hover16` group of `tests/backports/host/uikit2` and the recording beside it
  (`facts/UIKit/HoverAndTextInput16.md`). An earlier revision of this page said the class answered
  none of them: it had read the port's side of a one-sided check as a statement about the system, and
  the measurement says otherwise. `zOffset` and `altitudeAngle` are the port's own, in
  `UIHoverGestureRecognizer+Hover16.m`; `rollAngle` is the release's.

## What the port does

- The recogniser fails at the first touch it is offered, which is how a recogniser is told to be left out of a touch sequence: iOS 6 sends
  it only direct touches, which a hover never uses, so it does not hold back a recogniser that has to wait for it to fail. The system's does
  not receive touches at all.

## Where it differs

- `-description` of a subclass of `UIGestureRecognizer` on the host names the base class; the system's own class does not. Nothing else differs.
