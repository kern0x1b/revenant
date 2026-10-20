# Outline rows: expanding and collapsing a section snapshot, iOS 14.0

`UICellAccessoryOutlineDisclosure` on a cell of a collection view whose data source is a `UICollectionViewDiffableDataSource`, with the section applied as an `NSDiffableDataSourceSectionSnapshot` that has children, and `UICollectionViewDiffableDataSource.sectionSnapshotHandlers`.

Source: the host's own UIKit under Mac Catalyst (macOS 27.0), driven with the same script as the port in one process (`tests/backports/host/uikit2`, the `listactions` group), and the header of SDK 16.4. The touch behaviour on the release is checked on an iPhone 4S by `tests/backports/device/lists.m`, with real touches sent through the HID event system (`device/gesture.h`).

## What the host does, and the port with it (13 steps of expand, nested expand, collapse and a refused expand, all equal)

- The disclosure is a control. Its action, when the accessory has no `actionHandler` of its own, is the cell's toggle; an accessory that has a handler runs that handler **instead** and expands nothing.
- Expanding asks `shouldExpandItemHandler` (YES when there is none; NO ends it), then `willExpandItemHandler`, then `snapshotForExpandingParentItemHandler` with the item and the section snapshot of that item's children (`snapshotOfParentItem:`, the item itself left out). The snapshot it returns replaces the children (`replaceChildrenOfParentItem:withSnapshot:`), also when the item had children before, and the item is expanded. Collapsing asks `shouldCollapseItemHandler`, then `willCollapseItemHandler`. In every handler the data source still holds the old items.
- The result is applied to the section with the difference animated, so the rows of the children come and go, and the stored section snapshot is the new one.
- The data source sets `indentationLevel` of a list cell to the level of its item in the section snapshot, after the application's configuration handler ran, and the cell's configuration state is `expanded` for an expanded item, updated on the rows that stay.
- The chevron of the disclosure turns a quarter turn when its item is expanded, and turns back.

## What the port does differently

- The chevron is a view of its own that turns; the host's is an image view that turns (the port's turns to the same angle).
- A section that was applied as a whole snapshot, with no section snapshot, has no outline: the disclosure does nothing.
