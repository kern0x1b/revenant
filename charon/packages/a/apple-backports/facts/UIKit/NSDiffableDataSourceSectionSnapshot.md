# NSDiffableDataSourceSectionSnapshot, iOS 14.0

Introduced in iOS 14.0: the items of one section as a tree - roots, children, the level of an item, and which items are expanded - for
sections that show an outline. Unlike the snapshot of iOS 13.0 it holds items only.

Source: the host's own UIKit under Mac Catalyst (macOS 27.0), held against the port by the `diffablesection` group of
`tests/backports/host/uikit2`: random sequences of the 12 operations and the queries, over 42000 steps per run, none differing in
outcome, tree, expanded set, visible items, levels, parents, description of the hierarchy, copy and equality. `device/diffable.m` holds the
port to 800 recorded cases on the device.

## What the port does as the system does

- `-appendItems:`, `-appendItems:intoParentItem:` (a nil parent is the root), `-insertItems:beforeItem:` and `-insertItems:afterItem:` put items
  among the siblings of the destination; inserting after an item puts the new ones behind its subtree, its children included.
  A nil or empty array does nothing, whatever the destination is. An identifier already in the tree, or twice in the argument, raises
  `NSInternalInconsistencyException`, "Identifiers in a section snapshot must be unique. Duplicate item identifiers: {(...)}", with the
  identifiers in the order they are found; nothing is inserted.
- `-deleteItems:` deletes the items and their children, and raises "Failed to find index of item zz" before deleting anything if one is not there;
  the same item twice is fine. `-deleteAllItems` empties the tree and the expanded set.
- `-expandItems:` and `-collapseItems:` change the expanded state of the items that are there and ignore the others. An item does not need
  children to be expanded, and a deleted item is no longer expanded. `-items` is the tree in depth first order, `-rootItems` the roots,
  `-visibleItems` the items with every ancestor expanded, `-expandedItems` the expanded ones in the order of `-items`.
- `-snapshotOfParentItem:` and `...includingParentItem:` copy a subtree, with the expanded state, into a snapshot of its own; the items
  of a parent become its roots. `-replaceChildrenOfParentItem:withSnapshot:` and `-insertSnapshot:beforeItem:` bring a tree in with its
  expanded state, and `-insertSnapshot:afterItem:` answers the item after the subtree when the destination has children, the destination itself when
  it has none and another item follows, and nil when it is the last one.
- Queries: `-isExpanded:`, `-isVisible:`, `-levelOfItem:` and `-parentOfChildItem:` raise for an item that is not there ("Item identifier does not
  exist in section snapshot: zz", and for the parent "Child item identifier ..."), `-containsItem:` answers NO, `-indexOfItem:` `NSNotFound`.
  `-parentOfChildItem:` answers nil for a root.
- The exceptions carry `NSAssertFile` and `NSAssertLine` of the system's, and its reasons ("Parent item identifier does not exist in section snapshot",
  "Item identifier to insert before ..."). Nil for a parent, a snapshot or an item raises "Invalid parameter not satisfying: parentItem != nil",
  "snapshot != nil", "item != nil".
- `-visualDescription` is `<NSDiffableDataSourceSectionSnapshot: 0x...` and a line per item, indented two spaces a level: `+` for an expanded
  item and `-` for a collapsed one, `*` for a visible one and a space for a hidden one, then the identifier, then `>`.
- `-copy` is an equal tree; `-isEqual:` compares the roots, the children of every item and the expanded set; `-hash` is not overridden.

## Where the port departs

- `-description` writes the tree in runs as the system does - `-[0]4: {4,2}` is the fourth run, at level 0, of two items from item 4, `+` or
  `-` for the expanded state of its first - but the system's runs are the ones the items were appended in, and the port's are always as long
  as they can be, an item with children ending its run. A tree built with one `appendItems:` for the children of each parent reads the same
  in both (the host test holds 400 of them to the system), and a tree that was edited afterwards may group differently.
- `-replaceChildrenOfParentItem:` with items that are already in the tree raises the exception for the identifiers that are not unique. The
  system does not: it leaves a tree in which the children of the wrong items are listed. `-insertSnapshot:` of a snapshot whose items have children
  makes a tree with children under the wrong items in many cases too (not read out further), and the port inserts the tree that was given. The host
  test leaves these cases out, since there is no answer of the system's to hold the port to.
