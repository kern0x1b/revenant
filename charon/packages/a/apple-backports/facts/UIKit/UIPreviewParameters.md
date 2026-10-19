# UIPreviewParameters, iOS 13.0 and 14.0

Introduced in iOS 13.0: how a preview of a view is drawn - the background behind the view, the path the view is clipped to and, since 14.0, the path
the shadow follows. Nothing on iOS 6 draws a preview; the class is a value.

Source: the host's own UIKit under Mac Catalyst (macOS 27.0), held against the backport by `tests/backports/host/uikit2` (the `menus` group).

## As UIKit does

- `-init` has the system background colour, no visible path and no shadow path. The port answers `+systemBackgroundColor` when the release has
  it and white, the light appearance's value, when it has not.
- `backgroundColor` is a copy and is `null_resettable`: nil brings the default back.
- `visiblePath` and `shadowPath` (14.0) are copies of the path they are given.
- `-initWithTextLineRects:` makes the visible path from the lines: each rectangle is rounded to whole points (`CGRectIntegral`), made larger by 14 to
  the left and right and 10 above and below, and drawn as a rounded rectangle with a continuous corner of radius 13 - or half the width or height when
  that is smaller - as one closed sub-path per line, in the order given. No lines give no path. The path elements of one line and of lines that do
  not touch are the same as the host's to 1e-4.
- `-copy` is another object with a copy of each of the three values and is of the same class.
- The class adopts `NSCopying` and not `NSSecureCoding`.
- `-description` is `<UIPreviewParameters: 0x...; backgroundColor = ...; visiblePath = ...; shadowPath = ...>`, the two paths only when set.

## Where the port differs

- Lines of text that touch or overlap - such as two lines one above the other - are, on the host, joined into one outline with rounded inward
  corners where they meet. The port draws one closed sub-path per line and does not join them; the bounds are the host's, the outline is not. Nothing
  here draws the path.
- The host's `-isEqual:` answers NO even for the object itself (its `-hash` agrees between two default objects, which does not help); the port
  keeps identity, which is YES for the object itself and NO for any other, and the test says so.
