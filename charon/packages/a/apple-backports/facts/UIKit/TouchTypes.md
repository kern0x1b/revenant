# Touch types of a gesture recognizer, iOS 9

`UIGestureRecognizer.allowedTouchTypes` (an array of `UITouchType` numbers) says which kinds of touch a recognizer takes: a finger (direct), the Apple TV
remote (indirect) and, from iOS 9.1, a pencil. `requiresExclusiveTouchType` (default YES) keeps a recognizer from recognizing with touches of
two types at once, and `allowedPressTypes` does the same for presses. `UITouch.type` says what kind a touch is. On iOS 6 the selectors are not there.

Source: the host's own UIKit under Mac Catalyst, recorded by `tests/backports/host/touchtypes/run.sh` (8 records: the defaults, an array set,
an empty one, duplicates, the exclusivity, the press types), held against the port on the iPad 2 and the iPhone 4S by `tests/backports/device/touchtypes.m`, which
also taps with a real finger (HID digitizer events) on views whose tap recognizers allow different types.

## What the port does

- `allowedTouchTypes` answers what was set, without duplicates and in the order they were given, and an empty array when an empty one was set. It is direct,
  indirect and pencil (0, 1, 2) until it is set, as it is on iOS 10 (the host's newer answer adds the indirect pointer, which the records leave out).
- `requiresExclusiveTouchType` is kept and is YES until it is set. It changes nothing: the touches of these devices are all of one type.
- `allowedPressTypes` is kept, empty until set, and filters nothing (`inert`, see the registry).
- `-[UITouch type]` answers `UITouchTypeDirect` for every touch. A recognizer whose `allowedTouchTypes` has been set and does not
  contain direct is asked `_delegateShouldReceiveTouch:` by the release for every touch and the port answers NO for it, so a finger does not run it (the
  real touches of `touchtypes.m`: allowing indirect only, or nothing, does not run a tap; allowing direct does, and so does the default).
