# The 15.0 reconfigure pass: the two views, and the snapshot's one honest gap

Four rows of release 15.0, one object:
`packages/a/apple-backports/UIKit/UIDiffableDataSource+Reconfigure15.m` — three categories, on
`NSDiffableDataSourceSnapshot`, `UICollectionView` and `UITableView`, all SDK classes, nothing
redeclared.

## What a reconfigure is, and why a reload is the whole of it

iOS 15 gave a diffable apply a third state beside *inserted* and *deleted*: an item that stays
exactly where it is but is asked to build itself again, keeping its position and its cell. That
is the distinction from a reload in Apple's own implementation and the reason a caller asks for
it — but the distinction lives in **what the data source does to its model**, not in the view.
A reconfigure never removes the item and re-inserts it, so the item's position, its identity and
its cell all survive. Anything that re-asks the cell to build itself, without touching the model,
has that behaviour.

The release has no reconfigure of its own, measured on the 6.1.3 cache: `UICollectionView` has no
`-reconfigureItemsAtIndexPaths:` and `UITableView` has no `-reconfigureRowsAtIndexPaths:`. What it
has is the reload —

| release selector | measured on 6.1.3 | already used by the port for |
|---|---|---|
| `-[UICollectionView reloadItemsAtIndexPaths:]` | present | `UICollectionViewDiffableDataSource.m:108,123` |
| `-[UITableView reloadRowsAtIndexPaths:withRowAnimation:]` | present | `UITableViewDiffableDataSource.m:99` |

Both are called by the port's own diffable data sources when a snapshot asks for items to be
reloaded, inside a `-performBatchUpdates:`. So the reconfigure rows reuse exactly that: the same
reload, the same batch, and `UITableViewRowAnimationNone`, which is the animation the diffable
table data source uses when the apply is not animating. This is the "no second copy of something
that already exists" rule doing real work — the alternative, a private reconfigure mechanism, would
have been the same code written twice.

## The snapshot's bookkeeping, and the one place this is not like the port's own

`reconfigureItemsWithIdentifiers:` records its identifiers in the set `reconfiguredItemIdentifiers`
answers, which is the same relationship `reloadItemsAtIndexPaths:` has with
`reloadedItemIdentifiers` in `NSDiffableDataSourceSnapshot.m` (`:251` records, `:406` answers).

The set is an **associated object**, and that has a measured cost worth stating plainly:

- The port's `_reloadedItems` is an **ivar**, and `-copyWithZone:` unions it into the copy
  (`NSDiffableDataSourceSnapshot.m:67`), so **a copied snapshot carries what the original was
  asked to reload.**
- An associated object **does not survive `-copyWithZone:`**. Measured on the host before this
  sentence was written: `objc_getAssociatedObject` on the copy answers `nil` where the original
  answers the set.
- **So a copied `NSDiffableDataSourceSnapshot` reports no reconfigured items even when the
  original does**, and its `effect` says so in those words.

Why not fix it by putting the set in the port's own snapshot class, beside `_reloadedItems` where
it would be copied correctly? Because that class is placed at **13.0** — the registry row for
`NSDiffableDataSourceSnapshot` reads `introduced 13.0, minimum 6.0` — and adding a 15.0 ivar and a
15.0 union to a 13.0 object is precisely the mixed-release file that `band()`
(`backports.lua:776-789`) and `tools/release-split.lua` both refuse. The rule is one API per
object per release, and the cost of keeping it is that this one property is copy-fragile where its
13.0 sibling is not.

This is the trade stated rather than hidden: the common case is right. An apply is handed the
snapshot that asked for the reconfigure — the object the caller holds, not a copy of it — and the
set is correct there.

## The three implemented rows

| row | effect |
|---|---|
| `-[UICollectionView reconfigureItemsAtIndexPaths:]` | the index paths are reloaded inside one `-performBatchUpdates:`, so the cells build themselves again and keep their positions |
| `-[UITableView reconfigureRowsAtIndexPaths:]` | as above, with `UITableViewRowAnimationNone` |
| `-[NSDiffableDataSourceSnapshot reconfigureItemsWithIdentifiers:]` | the identifiers are kept, in order, and an empty array does nothing |
| `NSDiffableDataSourceSnapshot.reconfiguredItemIdentifiers` | the identifiers that were given, in order; empty when none, **and empty on a copy** |

## What was checked, and what was not

**This file compiles.** It was checked with the same flags `review-mechanical.sh` uses - `xcrun clang -target armv7-apple-ios6.1.3 -isysroot <iPhoneOS16.4.sdk> -fobjc-arc -Os -g0 -Wall -Wno-unguarded-availability-new -Wno-unguarded-availability -Werror=objc-missing-property-synthesis -fsyntax-only` - and it builds with zero errors and zero warnings. What has **not** happened is a link into a band or a run on a device, and that is the gate's.

Checked here, and then by the compiler:

- every selector the file calls exists and is spelled as the port spells it —
  `-unionOrderedSet:`, `-performBatchUpdates:`, `-reloadItemsAtIndexPaths:` and
  `-reloadRowsAtIndexPaths:withRowAnimation:` — the last two measured present in the 6.1.3 cache
  and already called from the two diffable data sources;
- `reconfiguredItemIdentifiers` is already `@dynamic` on the port's snapshot
  (`NSDiffableDataSourceSnapshot.m:44`), so this file supplies the pair the declaration was
  waiting for and does not redeclare anything;
- the associated-object-does-not-survive-copy behaviour was **run**, not assumed, and it is why
  the property's `effect` names the copy case instead of leaving a caller to find it.

No private class, no ivar read by name, no offset and no swizzling: the set is reached through the
snapshot's own public accessors, and the views' own reloads are public API the release documents.
