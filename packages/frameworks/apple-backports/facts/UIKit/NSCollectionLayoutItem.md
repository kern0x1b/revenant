# The items, groups and sections of a compositional layout, iOS 13.0

Introduced in iOS 13.0: what a layout is made of. `NSCollectionLayoutItem` is a cell's size, insets and spacing;
`NSCollectionLayoutGroup` is an item that holds items and lays them out in a row (horizontal), a column (vertical) or as it
is told (custom); `NSCollectionLayoutSupplementaryItem` is a view tied to an item or a group by an anchor;
`NSCollectionLayoutBoundarySupplementaryItem` is one that sits at the edge of a section or of the layout;
`NSCollectionLayoutDecorationItem` is a background view; `NSCollectionLayoutSection` is a group, repeated, with the space
around it. The classes are carried so that an application which builds them links and runs; the layout that reads them is
described in `UICollectionViewCompositionalLayout.md`.

Source: the host's own UIKit under Mac Catalyst (macOS 27.0), asked each question below and held against the backport by
`tests/backports/host/uikit2` (the `layoutvalues` group), and the header of SDK 16.4. The device test is
`tests/backports/device/compositional.m`.

## What the port does as UIKit does

- Defaults. An item made with `itemWithLayoutSize:` has zero content insets, an edge spacing of four fixed zeros, no
  supplementary items (an empty array) and an identifier; a decoration item has a whole-container size, no edge spacing and
  z index 0; a supplementary item has z index 1, no item anchor; a boundary item extends the boundary, is not pinned, and has
  no container anchor; a group has an inter-item spacing of fixed zero; a section has zero insets and spacing, no
  orthogonal scrolling, empty boundary and decoration arrays and follows the content insets. `new` and `init` give an empty
  object - a nil size, no identifier, a section that does not follow the insets - exactly as the host's do, though the
  headers mark them unavailable.
- `-description`. An item prints `<NSCollectionLayoutItem 0x...; name=(null); size={...};` then, one to a line and indented
  by a tab, `edgeSpacing=...;`, `identfier=...;` (the spelling is UIKit's) and `contentInsets={t,l,b,r}>`. A group adds
  `group: subitems=`, its subitems each indented one tab deeper than the group, and `interItemSpacing=...;`,
  `layoutDirection=.horizontal>` (a custom group says `.vertical`). A section prints `<NSCollectionLayoutSection: 0x...;
  group = <NSCollectionLayoutGroup: 0x...>` and, only for what differs from the default, `contentInsets`,
  `supplementariesFollowContentInsets = NO`, `interGroupSpacing`, `orthogonalScrollingBehavior` by name (Continuous,
  Continuous Group Leading Boundary, Paging, Group Paging, Group Paging Centered, `(unknown value: n)`),
  `boundarySupplementaryItems = <0x...>` and `decorationItems = <0x...>`.
- Copies. Every one copies to a new object. An item copies its size and edge spacing and shares its supplementary items; a
  group copies its subitems, and its spacing; a section copies its group and its decoration items and shares its boundary
  items; a group made from subitems keeps copies of them. A group made for a repeating count is one subitem, a copy of the
  item with its width (horizontal) or height (vertical) replaced by one over the count.
- Equality is by content: size, insets, edge spacing and supplementary items of an item; the element kind, z index and
  anchors of a supplementary item; alignment, offset, extension and pinning of a boundary item; kind, z index and insets of a
  decoration item; direction, subitems and spacing of a group (the block of a custom group is not compared); every property of
  a section. A class is equal only to its own class.
- Exceptions, all `NSInternalInconsistencyException`: `A size is required.` for a group without a size,
  `At least 1 subitem is required for a group` for a group with none or a custom group without a provider,
  `A repeating horizontal group should specify a count >= 1` (vertical likewise), `Invalid parameter not satisfying: group`
  for a section without a group. A nil item for a repeating group is the array literal's exception. Nothing else is checked;
  the section, and the layout, check the supplementary kinds when they lay out: `Error: Every supplementary must have a unique
  elementKind: duplicates detected: (...)`.
- Setters. `supplementaryItems` of a group and `edgeSpacing` and `contentInsets` of an item are settable; setting nil
  leaves nil. A section's decoration items become an empty array when set to nil, and its boundary items stay nil.

## What the port does not carry

- `-[NSCollectionLayoutGroup visualDescription]`, a drawing of the group in characters on a canvas of 100 columns and 50
  rows, a debugging aid. The port has no such drawing, and `respondsToSelector:` says no.
- `+[NSCollectionLayoutGroup horizontalGroupWithLayoutSize:repeatingSubitem:count:]` and its vertical twin (16.0),
  `supplementaryContentInsetsReference` (16.0) and `orthogonalScrollingProperties` (17.0): they belong to later releases.
- The host answers `-setSupplementaryItems:` on an item too, which the header declares read-only; the port does not.
- `orthogonalScrollingBehavior` and `visibleItemsInvalidationHandler` are acted on: see Orthogonal scrolling in the layout's facts.
- `NSCollectionLayoutVisibleItem` is adopted by an object of the port's own that the handler is given, with the members the header
  has.

## Where the port differs

- `-hash` of equal objects, as for the values.

## `horizontalGroupWithLayoutSize:repeatingSubitem:count:` and the vertical one, iOS 16.0

`UIKit/NSCollectionLayoutGroup+Repeating16.m`. The iOS 16 names are not the deprecated `subitem:count:` renamed: the header of the
deprecated pair says it "forces the width dimension of the subitem to .fractionalWidth(1.0/count)", and the header of the new pair says
only that it repeats the subitem `count` times and that fitting them in the group is the caller's responsibility. The port follows the
two headers: the new group is one subitem, a copy of the item at its own size, repeated `count` times by the layout's counted path, the
same path the deprecated group takes. The exceptions are the deprecated form's: no size, a count below 1, a nil item.

Not measured: a fractional dimension of the repeated item resolves, as in the deprecated form, against the group's extent less the
spacing between the copies, where the system may resolve it against the whole group; and a counted group does not self-size its items
along the main axis, which with the deprecated form's fractional share never mattered and with an estimated item of the new form does.
No host oracle runs here, and the device run is the last section. `objc.inventory` (`.agent-work/plan-and-analysis/b1314-flips/ladder-rest.log`):
both are not in 6.1.3 or 12.0 and are in 16.0 and 18.0, with the deprecated `horizontalGroupWithLayoutSize:subitem:count:`; no 13-15
cache, so `introduced` stays the header's 16.0.

## On a device, iOS 6.1.3

On an iPad 2 of iOS 6.1.3 (2026-09-23), a process of the band's own (`.agent-work/runs/b1314-live/main.m`, output `run4-all.txt` beside it) loaded the gate's `libUIKitBackports.dylib` and checked the repeating-subitem group: one subitem at its own absolute width where the deprecated form takes a share, and a count below 1 raising with the deprecated form's text. No layout was run.
