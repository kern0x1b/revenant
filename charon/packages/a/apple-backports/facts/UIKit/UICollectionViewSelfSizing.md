# Self-sizing items of a flow layout, iOS 8

Introduced in iOS 8.0: `UICollectionViewFlowLayout.estimatedItemSize`, and with it `-[UICollectionReusableView
preferredLayoutAttributesFittingAttributes:]`, `-[UICollectionViewLayout shouldInvalidateLayoutForPreferredLayoutAttributes:
withOriginalAttributes:]` and `-invalidationContextForPreferredLayoutAttributes:withOriginalAttributes:`. iOS 10 adds the constant
`UICollectionViewFlowLayoutAutomaticSize`.

Source: the host's own UIKit under Mac Catalyst (`host/flowauto/run.sh`): 16 scenarios of a flow layout that self-sizes - a column
of cells that fix their width, cells that override `preferredLayoutAttributesFittingAttributes:` for the height only, cells of
their own width in a line, section insets, line spacing and headers, a delegate that answers `sizeForItemAtIndexPath:`, the
automatic size, lines whose last line is short, cells with no constraints, and long lists - each recorded as the frame of every
item and the content size once the layout has settled. `device/flowauto.m` builds the same scenarios on iOS 6 and compares.

## What the port does as the system does

A flow layout with an `estimatedItemSize` that is not zero lays every item at its estimate; a cell that is displayed is asked for
`preferredLayoutAttributesFittingAttributes:`, and when the layout agrees (`shouldInvalidate...`, whose default is a preferred
size that differs from the original), the size is kept for the index path, the layout is invalidated with the context
`invalidationContextForPreferredLayoutAttributes:...` builds, and the lines are laid again with the size the cell wanted. The
default `preferredLayoutAttributesFittingAttributes:` fits the cell's content view with Auto Layout to the smallest size, rounded up
to the pixel, and keeps the original size in a direction where the view has no constraints. The sizes are forgotten when the
width of the collection view changes and on `reloadData`.

The port lays the lines itself in this mode, and the answers match the host's on: one item to a line, several in a line with the
line's items centred on the tallest one, a line of items that leaves its slack between the items, a line of one item that is
centred, a last line that keeps the minimum spacing and is left aligned, a last line of one item that is centred when two of it
would not fit, section insets, minimum line spacing, headers and footers, the delegate's insets, spacings and reference sizes,
and item positions aligned to the pixel. Where the items of a section are all one width, they are a grid with the same
spacing in every line, the last one included.

An item that is not displayed keeps its estimate, or the size the delegate answers when it implements
`collectionView:layout:sizeForItemAtIndexPath:`; a delegate's size is an estimate in this mode, as it is on the release.

## What differs

- Only a vertical flow layout self-sizes. A horizontal one keeps its estimate for every item, as the release before iOS 8 does; the
  host lays the items of a horizontal layout out in a way the port does not reproduce.
- The host today gives an item that has not been displayed the average of the sizes it has measured; the port, as iOS 8 to 10 do,
  gives it the estimate. The scenarios keep every item on screen for this reason, and the lists of forty items differ from the
  host in the content size and in the items below the screen.
- Cells are measured as they are put in the collection view, at the position of the estimate, and an item that is measured while
  it is on screen and leaves it once the lines above have grown keeps its measured size; the host does not measure it.
- The text a cell measures is the release's own: the widths of text differ from the host's by up to a pixel, so the scenarios
  whose cells take their width from their text are compared to a point, and the others to the pixel of the screen.
- Supplementary views do not self-size.

A compositional layout (`UICollectionViewCompositionalLayout.md`) measures its estimated items on the same steps and shares the
default `preferredLayoutAttributesFittingAttributes:`: a layout that answers `-charon_estimatedAxesForAttributes:` tells the default
which axes are free, and the default holds the others at the size the layout gave, as the release's does with the width of the
attributes. A cell that overrides the method works for both layouts.
