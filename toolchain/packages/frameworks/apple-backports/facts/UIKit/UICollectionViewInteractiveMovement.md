# Reordering rows: interactive movement, and the reordering handlers, iOS 14.0 (movement API iOS 9.0)

`-[UICollectionView beginInteractiveMovementForItemAtIndexPath:]`, `updateInteractiveMovementTargetPosition:`, `endInteractiveMovement`, `cancelInteractiveMovement`; `UICollectionViewDiffableDataSource.reorderingHandlers`; `NSDiffableDataSourceTransaction` and `NSDiffableDataSourceSectionTransaction`; the finger on `UICellAccessoryReorder`.

Source: the host's own UIKit under Mac Catalyst (macOS 27.0), driven with the same script as the port in one process (`tests/backports/host/uikit2`, the `listactions` group), and the header of SDK 16.4. The touch behaviour on the release is checked on an iPhone 4S by `tests/backports/device/lists.m`, with real touches sent through the HID event system (`device/gesture.h`).

## What the host does, and the port with it (six drags inside a section, across sections, refused and cancelled, all equal)

- `begin` asks the data source `collectionView:canMoveItemAtIndexPath:` (the diffable data source answers `canReorderItemHandler`, and NO when there is none) and answers whether the item was lifted. The cell moves to the target position, and the item under it takes its place.
- `end` calls, once, `willReorderHandler` with a transaction while the data source still holds the old snapshot, then `didReorderHandler` with the data source holding the new one. `cancel` calls nothing and leaves the snapshot as it was. While the item moves, `snapshot` still answers the old one.
- The transaction is the snapshot before, the snapshot after, and the difference of the item identifiers with moves inferred (a removal and an insertion that name each other's index); its section transactions are the changed sections, the **last section first**, each with the section's items before and after.

## What the port does differently

- iOS 6 has no interactive movement, so the port lifts the row as an image above the list, hides the cell, follows the finger, and moves the item under it with `moveItemAtIndexPath:toIndexPath:` in a batch; the neighbours shift as they do in a table. The scrolling of the list is switched off while a finger is on the grip, and the list scrolls itself when the item is near its top or bottom.
- The data source is told of each step as it happens, with `collectionView:moveItemAtIndexPath:toIndexPath:`, not once at the end: the host does not touch the data source before the movement ends. The diffable data source keeps the old snapshot for `snapshot` and for the handlers, so the difference is not seen there. A data source of the application's own gets one call per step and none more; a cancelled movement moves the item back in the same way.
- The target of a step is the item under the position; an item cannot be put after the last item of another section; the delegate's `collectionView:targetIndexPathForMoveFromItemAtIndexPath:toProposedIndexPath:` is asked for it (not compared with the host).
- The shadow and scale the host gives the lifted row are approximated by a shadow.

## The table view

`UITableViewDiffableDataSource` has no reordering handlers and no editing methods of its own on the host (`tableView:canMoveRowAtIndexPath:` and `tableView:moveRowAtIndexPath:toIndexPath:` are answered by a subclass that overrides them, and the base class does not respond to either). The table of iOS 6 reorders natively when the data source answers them, so a subclass works as on the host and nothing more is carried.
