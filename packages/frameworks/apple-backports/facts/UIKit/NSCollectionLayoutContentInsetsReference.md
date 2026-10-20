# NSCollectionLayoutSection content insets reference, iOS 14.0

Introduced in iOS 14.0: which edges of the collection view a section, or a layout, keeps its content clear of.
`NSCollectionLayoutSection.contentInsetsReference` and `UICollectionViewCompositionalLayoutConfiguration.contentInsetsReference`
take one of five values: automatic, none, safe area, layout margins, readable content. The classes are those of
`NSCollectionLayoutItem.md` and `UICollectionViewCompositionalLayout.md`; only the two properties are of this release.

Source: the host's own UIKit under Mac Catalyst (macOS 27.0), with a collection view whose layout margins were set to
top 10, left 20, bottom 30, right 40, asked for each of the five values on the section and on the layout in both scroll
directions, and the header of SDK 16.4. The differential test is `tests/backports/host/uikit2` (the `compositionallayout`
group, ten of its layouts).

## What the port does as UIKit does

- The defaults are the header's: a layout refers to the safe area, a section to automatic, which follows the layout.
- The reference clears the section of edges **across** the scroll direction only: the left and right edges when scrolling
  down, the top and bottom when scrolling sideways. None and automatic clear nothing at all; layout margins clear the
  collection view's `layoutMargins`; readable content does the same, since the port has no readable content guide, and on
  a phone the host's own answer is the layout margins too; the safe area clears the collection view's `safeAreaInsets` (the port
  carries them from iOS 11, see `UIViewSafeArea.md`).
- What is cleared is taken off the size the section's groups are laid out in, and the section is moved by it; the content
  size is not made smaller. The size given to a section provider is the collection view's, cleared of nothing.
- The boundary supplementary items of the **layout** are not cleared by it.
- Both properties are copied with their object.

## What the port cannot do

- The host was measured with a safe area of zero, since the host has no status bar, so the values that come from the safe area
  are the port's own reading of it and are not held against the host.

## `supplementaryContentInsetsReference`, iOS 16.0

`NSCollectionLayoutSection.supplementaryContentInsetsReference` is the same five values for the boundary supplementaries, and it
replaces the deprecated `supplementariesFollowContentInsets` (iOS 13 to 16). Automatic (0) by default, which follows the section's
insets, and it keeps the value set. The two are one setting seen two ways, as the host has them (`tests/backports/host/layout-section`,
58 checks, the port and the host print the same values):

- Setting any reference other than automatic makes the flag read NO, and setting the reference to automatic leaves the flag NO.
- Setting the flag NO is always allowed and leaves the reference alone.
- Setting the flag YES is refused with `NSInternalInconsistencyException` ("Mixing supplementariesFollowContentInsets and
  supplementaryContentInsetsReference is not supported...") when the reference is not automatic, and allowed when it is.
- A copy keeps the reference; equality compares the reference and the flag.

The port's layout places supplementaries from the flag only, so a reference of none or safe area is placed as the flag NO is:
the release's placement for the two references other than automatic is not measured, and the layout is not compared with the host.
