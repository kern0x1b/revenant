# The sizes and spacings of a compositional layout, iOS 13.0

Introduced in iOS 13.0: the value objects a layout is described with. `NSCollectionLayoutDimension` is one of four
things - a fraction of the container's width, a fraction of its height, an absolute length, an estimate;
`NSCollectionLayoutSize` pairs two of them; `NSCollectionLayoutSpacing` is a fixed length or a flexible minimum;
`NSCollectionLayoutEdgeSpacing` holds four of those, for the edges of an item; `NSCollectionLayoutAnchor` names
edges of a rectangle and an offset from them; `NSCollectionLayoutGroupCustomItem` is a frame a custom group answers with.

Source: the host's own UIKit under Mac Catalyst (macOS 27.0), asked every question below, and the header of SDK 16.4.
They are held against the backport by `tests/backports/host/uikit2` (the `layoutvalues` group: 139 statements
compared as text, exceptions included). The device test is `tests/backports/device/compositional.m`.

## What the port does as UIKit does

- A dimension raises `NSInternalInconsistencyException` for a value that is not finite, with the host's words:
  `Invalid fractional width: nan. The fraction must be a finite value.`, `... fractional height ...`,
  `Invalid absolute dimension: inf. The dimension must be a finite value.`, `Invalid estimated dimension: ...`.
  Negative and zero values, and fractions above one, are accepted and kept.
- `isFractionalWidth`, `isFractionalHeight`, `isAbsolute`, `isEstimated` and `dimension` answer as the header says. The
  object's own `-description` is the plain `<NSCollectionLayoutDimension: 0x...>`; equality is by kind and value.
- A size prints as `{.containerWidthFactor(0.5), .containerHeightFactor(0.25)}`, with `.absolute(20)` and `.estimated(30)`
  for the other two, numbers with `%g`. A nil dimension is an absolute zero. `new` gives two absolute zeros.
- A spacing prints as `<NSCollectionLayoutSpacing - 0x...: fixed:4>` or `flexible:5`. Its value is kept whatever it is:
  negative, NaN and infinity raise nothing.
- An edge spacing prints its four spacings, `(null)` for the ones that are not set, and `outsets=@{top,trailing,bottom,leading}`
  of their values (an unset one is zero); it copies its four spacings.
- An anchor prints `<NSCollectionLayoutAnchor 0x...: edges=3; offset={0, 0}; anchorPoint={0, 0}>`: the anchor point is 0 for
  a leading or top edge, 1 for a trailing or bottom edge, and one half when both, or neither, of an axis are named. An
  offset from `layoutAnchorWithEdges:` is absolute; `fractionalOffset:` makes `isFractionalOffset` YES. Odd edge masks and
  offsets raise nothing.
- Every one of them copies to a new object, not to itself; none adopts `NSCoding`. A custom item keeps its frame and z
  index, is equal only to itself, and accepts any frame.

## Where the port differs

- `-hash`. The host's hash of two equal dimensions, sizes, spacings and items differs; the port's agrees, as `NSObject` asks
  of it. The differential test does not compare the number.
