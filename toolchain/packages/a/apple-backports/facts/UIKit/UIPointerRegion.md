# UIPointerRegion and UIPointerRegionRequest, iOS 13.4

Introduced in iOS 13.4: the rectangle a pointer style applies to, and the request that asks a delegate for one. Both are values of
the port, real to the last detail that can be asked; nothing on iOS 6 makes a request.

Source: the host's own UIKit under Mac Catalyst (macOS 27.0), held against the backport by `tests/backports/host/uikit2` (the
`pointer` group): descriptions, equality over every pair of six regions, hashes, copies, and the header of SDK 16.4.

## UIPointerRegion, as UIKit does

- `+regionWithRect:identifier:` keeps the rectangle as it is - null and infinite rectangles too - and the identifier **as it is**, not
  copied: a mutable string the caller changes afterwards changes in the region.
- `latchingAxes` starts at zero and keeps any value, including bits UIAxis does not define.
- `-copy` is another object of the same class with the same rectangle, identifier and axes; `-isEqual:` compares the rectangle exactly,
  the identifier with `-isEqual:` and the axes.
- `-hash` is the exclusive or of the four rectangle values, each as a signed integer (a value above the range of an `int` counts as its
  largest), of the identifier's hash and of the latching axes: `(1 2; 3 4)` with no identifier is 4.
- `-init` and `+new` answer a region of the empty rectangle, as the host does although the header marks them unavailable.
- `-description` is `<UIPointerRegion: 0x...; rect = (x y; w h)`, then `; identifier = ...` when there is one, then `; latchingAxes = (horizontal)`,
  `(vertical)` or `(both)` when the axes have one of those three values, then `>`. Numbers are written with `%g`.
- The class has no `defaultRegion`; the header has none either.

## UIPointerRegionRequest, as UIKit does

- `location` and `modifiers` are read-only values; a fresh request has both at zero. Its description is
  `<UIPointerRegionRequest: 0x...; location = {x, y}>` and does not mention the modifiers. It is not copyable.
- No release of iOS 6 makes one, so the port's `-initCharonWithLocation:modifiers:` exists for the tests.
