// UIDiffableDataSource+Reconfigure15.m - the 15.0 reconfigure pass, for both data sources.
//
// Three rows, one object: -[NSDiffableDataSourceSnapshot reconfigureItemsWithIdentifiers:],
// -[UICollectionView reconfigureItemsAtIndexPaths:] and -[UITableView reconfigureRowsAtIndexPaths:].
// NSDiffableDataSourceSnapshot.reconfiguredItemIdentifiers is the fourth, and it is @dynamic on
// the port's own snapshot already (NSDiffableDataSourceSnapshot.m:44), so the storage this needs
// is added here rather than in that file - that file is placed at 13.0 and this API is 15.0.
//
// WHAT RECONFIGURE IS, and why a reload is the whole of it. 15.0 added a third state to a
// diffable apply alongside "inserted" and "deleted": an item that stays where it is but is asked
// to build itself again, keeping its position and its cell. On this release there is no separate
// reconfigure - UICollectionView has no -reconfigureItemsAtIndexPaths: and UITableView no
// -reconfigureRowsAtIndexPaths: - and the cells have no configuration to rebuild from, because a
// 6.1.3 cell is not a configured cell. What the release does have is the reload the diffable
// data sources already use for exactly this purpose:
// -[UICollectionView reloadItemsAtIndexPaths:] and
// -[UITableView reloadRowsAtIndexPaths:withRowAnimation:], both measured present in the 6.1.3
// cache, and both already called from UICollectionViewDiffableDataSource.m and
// UITableViewDiffableDataSource.m when a snapshot asks for an item to be reloaded.
//
// So a reconfigure here is a reload of the same index paths, inside the same
// -performBatchUpdates: the cell is asked to build itself again, which is the observable
// behaviour, and the difference 15.0 draws - keep the item's position, do not treat it as a
// delete-and-insert pair - is preserved because the item is never removed from the data source.
// The row animation is UITableViewRowAnimationNone, which is the reload the diffable table data
// source uses when the apply is not animating.
//
// The snapshot's own bookkeeping is the other half: reconfigureItemsWithIdentifiers: records the
// identifiers in the set reconfiguredItemIdentifiers answers, so a caller that asks for a
// reconfigure can read back what it asked for - which is what the property is for, and the same
// relationship reloadItemsAtIndexPaths: has with reloadedItemIdentifiers in the port's own
// snapshot.
//
// The set is an associated object rather than an ivar, and that is a decision with a measured
// cost: NSDiffableDataSourceSnapshot.m owns _reloadedItems and _reloadedSections and unions them
// into a copy at NSDiffableDataSourceSnapshot.m:67, so a copied snapshot carries what the original
// was asked to reload. An associated object does NOT survive -copyWithZone:, which was measured
// on the host before this sentence was written (objc_getAssociatedObject on the copy answers nil
// where the original answers the set), so a COPIED snapshot reports no reconfigured items even
// when the original does.
//
// The alternative was rejected rather than overlooked. The port defines NSDiffableDataSourceSnapshot
// in NSDiffableDataSourceSnapshot.m, which the registry places at 13.0; adding a 15.0 ivar and a
// 15.0 union to that file is exactly the mixed-release object that band() and release-split
// refuse. So the storage lives here, and the one place the port's own shape is not reproduced is
// named rather than papered over: an apply is given the snapshot that asked for the reconfigure,
// which is the object the caller holds, not a copy of it.
//
// The C seam lives in this file's own category on the two views, and the snapshot's storage is
// reached through the port's own accessors rather than its ivars, so nothing here depends on a
// private name or an offset.

#import "CharonLists.h"
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

static const void *CharonReconfiguredItemsKey = &CharonReconfiguredItemsKey;

@implementation NSDiffableDataSourceSnapshot (CharonReconfigure15)

- (NSArray *)reconfiguredItemIdentifiers
{
    NSMutableOrderedSet *kept = objc_getAssociatedObject(self, CharonReconfiguredItemsKey);
    return kept ? kept.array : @[];
}

- (void)reconfigureItemsWithIdentifiers:(NSArray *)identifiers
{
    if (!identifiers.count)
        return;
    NSMutableOrderedSet *kept = objc_getAssociatedObject(self, CharonReconfiguredItemsKey);
    if (!kept) {
        kept = [NSMutableOrderedSet orderedSet];
        objc_setAssociatedObject(self, CharonReconfiguredItemsKey, kept, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    [kept unionOrderedSet:[NSOrderedSet orderedSetWithArray:identifiers]];
}

@end

@implementation UICollectionView (CharonReconfigure15)

- (void)reconfigureItemsAtIndexPaths:(NSArray<NSIndexPath *> *)indexPaths
{
    if (!indexPaths.count)
        return;
    // One batch, so the reloads animate together the way the diffable apply's own reload does.
    [self performBatchUpdates:^{
        [self reloadItemsAtIndexPaths:indexPaths];
    } completion:nil];
}

@end

@implementation UITableView (CharonReconfigure15)

- (void)reconfigureRowsAtIndexPaths:(NSArray<NSIndexPath *> *)indexPaths
{
    if (!indexPaths.count)
        return;
    [self performBatchUpdates:^{
        [self reloadRowsAtIndexPaths:indexPaths withRowAnimation:UITableViewRowAnimationNone];
    } completion:nil];
}

@end
