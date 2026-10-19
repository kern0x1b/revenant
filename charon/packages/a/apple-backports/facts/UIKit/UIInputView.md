# UIInputView, iOS 7.0

The release already has a `UIInputView`, a private class of the keyboard's own with
`-initWithFrame:` and the split-keyboard content views. iOS 7.0 made it public for an
application's `inputView` and `inputAccessoryView`, and added a style and a switch.

Source: the host's own UIKit under Mac Catalyst, in an application with a window, asked for
each answer below and held against the backport by `tests/backports/host/inputview/run.sh`,
ten records that the app `tests/backports/device/inputview.m` compares on a device running
6.1.3.

- `-initWithFrame:inputViewStyle:` gives a view whose frame is the one it was given, opaque,
  alpha 1, not clipping, with no background colour, for the default style and for the
  keyboard style alike.
- `inputViewStyle` answers the style the view was made with, 0 for `-initWithFrame:`, and a
  value that is neither style as it was given: 7 comes back 7.
- `allowsSelfSizing` is NO at first and can be set and cleared.
- The view is a UIView: it is an `inputView` and an `inputAccessoryView` of a text field as
  any view is, and takes subviews.

## What the port answers, and what iOS 6 does with them

The style is kept and never drawn: the keyboard style is the translucent keyboard-grey
background of iOS 7 and later, and the release's public API has no way to ask for it, so a
view of that style is as plain as one of the default style. `allowsSelfSizing` is kept; the
release sizes an input view by its frame only.

The host's view carries two content subviews of its own beside the ones an application adds;
the release's does not, so `subviews.count` differs by that and is not compared.
