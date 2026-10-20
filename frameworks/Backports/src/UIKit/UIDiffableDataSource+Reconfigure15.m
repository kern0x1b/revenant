#import "RevenantLists.h"
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

static const void *RevenantReconfiguredItemsKey = &RevenantReconfiguredItemsKey;

@implementation NSDiffableDataSourceSnapshot (RevenantReconfigure15)

- (NSArray *)reconfiguredItemIdentifiers
{
    NSMutableOrderedSet *kept = objc_getAssociatedObject(self, RevenantReconfiguredItemsKey);
    return kept ? kept.array : @[];
}

- (void)reconfigureItemsWithIdentifiers:(NSArray *)identifiers
{
    if (!identifiers.count)
        return;
    NSMutableOrderedSet *kept = objc_getAssociatedObject(self, RevenantReconfiguredItemsKey);
    if (!kept) {
        kept = [NSMutableOrderedSet orderedSet];
        objc_setAssociatedObject(self, RevenantReconfiguredItemsKey, kept, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    [kept unionOrderedSet:[NSOrderedSet orderedSetWithArray:identifiers]];
}

@end

@implementation UICollectionView (RevenantReconfigure15)

- (void)reconfigureItemsAtIndexPaths:(NSArray<NSIndexPath *> *)indexPaths
{
    if (!indexPaths.count)
        return;
    [self performBatchUpdates:^{
        [self reloadItemsAtIndexPaths:indexPaths];
    } completion:nil];
}

@end

@implementation UITableView (RevenantReconfigure15)

- (void)reconfigureRowsAtIndexPaths:(NSArray<NSIndexPath *> *)indexPaths
{
    if (!indexPaths.count)
        return;
    [self performBatchUpdates:^{
        [self reloadRowsAtIndexPaths:indexPaths withRowAnimation:UITableViewRowAnimationNone];
    } completion:nil];
}

@end
