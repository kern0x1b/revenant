# The section inset reference of a flow layout, iOS 11

`UICollectionViewFlowLayout.sectionInsetReference` says what the insets of a section are measured from: `UICollectionViewFlowLayoutSectionInsetFromContentInset`
(0, the default: the content area as the flow layout always laid it), `...FromSafeArea` (1) and `...FromLayoutMargins` (2).

Source: UIKit of iOS 11.0 and 12.0 arm64 - the accessors are a plain store of an instance variable, and `-_adjustedSectionInsetForSectionInset:forAxis:`
with the place in `-_getSizingInfosWithExistingSizingDictionary:` that calls it for every section - and the host's own UIKit under Mac Catalyst,
recorded by `tests/backports/host/insetref/run.sh` (32 records: the frame of every item and header and the content size of a flow layout for each of the three
references, with a delegate and without, at three widths, with a content inset, with layout margins of the view, and with an estimated item size), held against the
port with mutants and, through `tests/backports/device/insetref-cases.m`, against the iPad 2, to within half a point: the host draws on a screen of two pixels to the point and the iPad 2 on one, and both round a frame to the pixel.

## What the release does

When the reference is not the content inset, the inset of each section - the layout's `sectionInset`, or what the delegate answers for the section - becomes
`max(inset + reference - adjustedContentInset, 0)` on the axis across the scroll direction: the left and the right of a vertical layout, the top and the bottom of
a horizontal one. `reference` is `safeAreaInsets` of the collection view for the safe area and its `layoutMargins` for the margins. The setter stores and does not
invalidate the layout.

## What the port does

A flow layout whose reference is not the content inset lays its lines with the port's own line layout, the one that self-sizing items use, and applies that
formula to the left and the right of every section. Two things the release does with a content inset are laid in it too: the width the lines fill is the width of
the collection view less the left and right of its adjusted content inset, and an item of no delegate size has the layout's `itemSize`. `safeAreaInsets`
and `adjustedContentInset` are the port's own, so on this device the safe area adds nothing at the sides and the layout margins (eight points at either side
by default) do.

## What differs

- With the default reference the port leaves the lines to the release, and the release's flow layout of iOS 6 fills the whole width of the collection view whatever its content inset is,
  where the host takes the left and right of the content inset off it. A reference other than the default lays the lines with the width the host does.
  The three records of the default reference with a content inset are not held to the device for that reason.
- A horizontal layout keeps the release's own lines, and its reference has no effect: the axis the release adjusts there is the top and bottom, which
  the port's lines do not lay.
- The host of the records is newer than the releases read, and it adjusts all four edges. The port follows 11.0 and 12.0, and the records hold the layout
  margins and the content inset to zero at the top and bottom, where the two agree.
- On iOS 8 to 10, where the release lays self-sizing items itself, a layout with an estimated item size is left to the release and its reference has no effect.
