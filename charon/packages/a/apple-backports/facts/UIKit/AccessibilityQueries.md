# The five exported functions that ask about assistive technology and guided access

`UIAccessibilityConvertPathToScreenCoordinates`, `UIAccessibilityIsAssistiveTouchRunning`,
`UIAccessibilityHearingDevicePairedEar`, `UIAccessibilityRequestGuidedAccessSession` and
`UIGuidedAccessRestrictionStateForIdentifier` each name a state of the running system. On iOS 6.1.3
three of those states are kept where an application cannot read them, so those three answer as a
device in the state that has none of it, and say so. The other two are computed.

## Converted, not refused

`UIAccessibilityConvertPathToScreenCoordinates` takes the path **and the view whose space the path is
in** — the Swift name `convertToScreenCoordinates(_:in:)` is the same signature — and does exactly
what the tree's `UIAccessibilityConvertFrameToScreenCoordinates` already does for a rect: convert
through the view's own window, then through that window's screen space. The transform between views
is read off three converted points rather than assumed to be a scale and a shift, so a rotated or
flipped view is converted as it really is, and a view in no window answers the path unchanged, as
the frame version answers the rect.

iOS has no `-bezierPathByApplyingTransform:`, so the transform goes on the path's `CGPath` with
`CGPathCreateMutableCopyByTransformingPath` and the result is read back into a `UIBezierPath`. The
first attempt used `CGPathCreateCopyByApplyingTransform`, which **does not exist on iOS** — it is
macOS only, and the header search is what caught it.

## Three seams, each with the measurement that closes it

- **`UIAccessibilityIsAssistiveTouchRunning` answers NO.** Measured on the release's own 6.1.3 cache:
  the only AssistiveTouch names it carries are `AssistiveTouchCustomGestureCreation` and
  `AssistiveTouchPID`, neither of which is a state, and it exposes no notification that the state
  changes through. There is nothing on this release to read. NO is what a device with AssistiveTouch
  off gives. The first version of this invented an observer on a notification the release does not
  post; that was a mechanism that could never fire and is gone.
- **`UIAccessibilityHearingDevicePairedEar` answers `UIAccessibilityHearingDeviceEarNone`.** This
  device has no paired hearing device, so there is no ear, which is the release's documented answer
  for no device.
- **`UIGuidedAccessRestrictionStateForIdentifier` answers `UIGuidedAccessRestrictionStateAllow` for
  every identifier.** The release keeps its restrictions where an application cannot read them and
  exposes no query for one. `Allow` is the header's own stated initial state for every restriction
  and what a device outside guided access answers. There is no `None` case in this enum — the two
  cases are `Allow` and `Deny` — and writing one would have invented a value.

`UIAccessibilityRequestGuidedAccessSession` calls its handler with NO: a guided access session is a
state the system puts the whole device into and only the system's own guided access starts one, so
an application asking is answered as an application that did not get one. The handler is called
rather than dropped, so a caller waiting on one is not left waiting.
