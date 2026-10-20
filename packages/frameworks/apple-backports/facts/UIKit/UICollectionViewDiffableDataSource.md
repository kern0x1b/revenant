# UICollectionViewDiffableDataSource, iOS 13.0 and 14.0

Introduced in iOS 13.0: a data source that takes a whole snapshot and works out for itself what a collection view has to insert, delete,
move and reload to show it. 14.0 added the snapshot of a section (`NSDiffableDataSourceSectionSnapshot.md`), and the handlers for
reordering and for expanding. The table view's counterpart is `UITableViewDiffableDataSource.md`.

Source: the host's own UIKit under Mac Catalyst (macOS 27.0), held against the port by two windowed groups of
`tests/backports/host/uikit2`, which run the system's data source and the port's in the same application, each on a collection view or a
table view of its own, apply the same random snapshots to both, and compare after every one. `diffabledatasource`: about 400 applies per run,
each of up to eight items in up to four sections, animated or not, with reloaded items and sections; `diffablesectiondatasource`: 240 applies of
section snapshots. In every one the port and the system agree on the counts of the view, the snapshot the data source gives back and its
description, the index path of every item and the item at every index path. `device/diffable.m` runs the scenarios on the device.

## What the port does as the system does

- `-initWithCollectionView:cellProvider:` makes the data source the view's `dataSource` (the view does not keep it), and an object made by
  `-init` has no view and answers an empty snapshot. `-snapshot` answers a copy every time, without the reload marks. `-itemIdentifierForIndexPath:`
  answers nil for a nil, negative or out of range path and `-indexPathForItemIdentifier:` nil for one that is not there.
- As the view's data source it answers `numberOfSectionsInCollectionView:`, `collectionView:numberOfItemsInSection:` (a section past the end raises
  "Invalid parameter not satisfying: section < _impl.numberOfSections"), `collectionView:cellForItemAtIndexPath:` (the provider is called with
  the index path and the item, and a cell it does not return raises "UICollectionViewDiffableDataSource cell provider returned nil for index path ...
  with item identifier '...', which is not allowed. You must always return a cell to the collection view: ...") and
  `collectionView:viewForSupplementaryElementOfKind:atIndexPath:`, which calls `supplementaryViewProvider` and raises "CollectionView ... requested a
  supplementary view, but a supplementaryViewProvider was not specified on the diffable data source ..." when there is none. It answers nothing
  else - not the index titles, not the moves of iOS 9 - so `respondsToSelector:` on it is the system's for these.
- `-applySnapshot:animatingDifferences:` and its completion form are synchronous on the main thread. The first apply is `reloadData`, in the port
  and in the system; the port does the same for a view that is not in a window, which was not asked of the system. Every other apply compares the sections and the items with the old snapshot's by identifier and
  gives the view one batch of `deleteSections`, `insertSections`, `moveSection`, `deleteItems`, `insertItems` and `moveItem` - the sections
  and the items of a section are compared with the shortest edit script, so an item that keeps its place is left alone, an item that changed
  places is moved, an item that another section receives, and that both sections keep, is moved there, and only an item the old snapshot did not
  have is inserted. **iOS 6 refuses a move out of a section the same batch deletes or into one it inserts** (the system's UIKit accepts it), so
  such an item is deleted and inserted, or just inserted, and its cell is made again. After the batch the reloaded sections and items of the new snapshot are reloaded
  in a second batch, at their new index paths, so an item that was inserted and reloaded is asked for twice; an item of a reloaded section that is
  reloaded as well is asked for once. The provider is asked for the cells of what is inserted and reloaded, and for nothing that moved. With
  `animatingDifferences:NO` the animations are turned off around the apply.
- The first apply of a data source with animations on, and reload marks, reloads them after the reload of the data too, so the provider is
  asked again for those items and sections; without animations the marks are not read.
- A snapshot applied is kept, without its reload marks; `nil` is refused with "Invalid parameter not satisfying: snapshot".

## 14.0

- `-applySnapshot:toSection:animatingDifferences:` (and with a completion) makes the visible items of the section snapshot the items of the
  section, at the end of the sections when there is no such section, moving in the items of other sections that it names, and keeps the snapshot;
  `-snapshotForSection:` answers a copy of the one kept, or a snapshot of the section's items as roots, or an empty one for a section that is not
  there or nil. An item that moves into a section that had no items is asked for again by the provider; one that moves into a section with items is not.
- `reorderingHandlers` and `sectionSnapshotHandlers` are **carried**: a tap on the outline disclosure of a list cell expands or collapses the item and
  calls the section snapshot handlers, and a finger on the reorder grip drags the row and calls the reordering handlers with an
  `NSDiffableDataSourceTransaction`; see `UICollectionViewOutline.md` and `UICollectionViewInteractiveMovement.md`. Both getters answer one object,
  empty to begin with, and an assigned object is copied.

## Where the port departs

- **A batch the port cannot prove consistent is a `reloadData`.** iOS 6 checks the counts of a batch strictly and raises on a mismatch, so the
  port checks, section by section, that before - deleted - moved out + inserted + moved in is the new count, and reloads the view, losing the
  animation, when it does not; also when any item moves between sections, and when a section is inserted, deleted or moved in a batch that
  changes items as well. The system animates these. The provider is then asked for every cell (about half of random applies in the host group).

- The system works out the difference on a queue of its own and applies it on the main queue; the port does both on the main queue, before
  the call returns.
- A reloaded section and reloaded items of it, applied for the first time with animations on, are asked for twice by a collection view and once by a
  table view, in the system and in the port. In a later apply that has changes in it, an item of a reloaded section that is reloaded as well is asked
  for twice in the system, and the port asks as it does; when nothing else changes it is asked for once by both.
- A regular apply that changes the items of a section for which a section snapshot was applied keeps its tree, drops what has gone and puts
  the new items after the visible item that came before them in the section, at its level. The system does this in more cases, and in a few of them
  keeps items of a tree that are not in the section any more.
- `applySnapshot:toSection:` with a nil section or snapshot raises `NSInternalInconsistencyException` with the reason of the system; the system's
  own raise, on its queue, ends the process.

## `applySnapshotUsingReloadData:`, `sectionIdentifierForIndex:` and `indexForSectionIdentifier:`, iOS 15.0

`UIKit/UIDiffableDataSource+iOS15.m`, over the data source's own state.

- `-applySnapshotUsingReloadData:` and its completion form take the snapshot as current, without its reload marks, call `reloadData` and
  `layoutIfNeeded` on the collection view and run the completion on the main queue afterwards - what an `applySnapshot:` that cannot diff already
  does, now on request. No difference is worked out and nothing is animated, as the header asks. A nil snapshot raises
  "Invalid parameter not satisfying: snapshot", the port's wording for `applySnapshot:`. The next `applySnapshot:` diffs against this
  snapshot, as against any applied one.
- Section snapshots applied earlier are carried onto the new snapshot as for a regular apply: a section that is gone loses its tree.
- `-sectionIdentifierForIndex:` answers the section at that index of the current snapshot, and nil for a negative or out-of-range index -
  nil because the header declares the result nullable, not because the system's answer was read.
- `-indexForSectionIdentifier:` answers the snapshot's `indexOfSectionIdentifier:`, NSNotFound for a section that is not there.

None of this was held against the system: no host oracle runs on this machine (Catalyst is not installed), and the device run is the last section.
Ladder by `objc.inventory` (`.agent-work/plan-and-analysis/b1314-flips/ladder-diffable.log`, with `applySnapshot:animatingDifferences:`
as the positive control and an invented selector as the negative one): the class is in neither the 6.1.3 nor the 12.0 cache, and all four
methods are in 16.0 and 18.0. There is no 13-15 cache, so `introduced` stays the header's 15.0.

## On a device, iOS 6.1.3

On an iPad 2 of iOS 6.1.3 (2026-09-23), a process of the band's own (`.agent-work/runs/b1314-live/main.m`, output `run4-all.txt` beside it) loaded the gate's `libUIKitBackports.dylib` and checked nothing of the collection view's data source: the run held the table's (`UITableViewDiffableDataSource.md`).
