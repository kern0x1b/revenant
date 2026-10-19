#import "RevenantDiffable.h"
#import "RevenantLists.h"
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

static const char revenant_reordering_key = 0, revenant_snapshot_handlers_key = 0, revenant_sections_key = 0, revenant_applying_key = 0, revenant_reorder_initial_key = 0;

@implementation UICollectionViewDiffableDataSource (RevenantFourteen)

- (UICollectionViewDiffableDataSourceReorderingHandlers *)reorderingHandlers
{
    id handlers = objc_getAssociatedObject(self, &revenant_reordering_key);
    if (!handlers) {
        handlers = [[UICollectionViewDiffableDataSourceReorderingHandlers alloc] init];
        objc_setAssociatedObject(self, &revenant_reordering_key, handlers, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return handlers;
}

- (void)setReorderingHandlers:(UICollectionViewDiffableDataSourceReorderingHandlers *)reorderingHandlers
{
    objc_setAssociatedObject(self, &revenant_reordering_key, [reorderingHandlers copy], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (UICollectionViewDiffableDataSourceSectionSnapshotHandlers *)sectionSnapshotHandlers
{
    id handlers = objc_getAssociatedObject(self, &revenant_snapshot_handlers_key);
    if (!handlers) {
        handlers = [[UICollectionViewDiffableDataSourceSectionSnapshotHandlers alloc] init];
        objc_setAssociatedObject(self, &revenant_snapshot_handlers_key, handlers, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return handlers;
}

- (void)setSectionSnapshotHandlers:(UICollectionViewDiffableDataSourceSectionSnapshotHandlers *)sectionSnapshotHandlers
{
    objc_setAssociatedObject(self, &revenant_snapshot_handlers_key, [sectionSnapshotHandlers copy], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSMutableDictionary *)revenant_sectionSnapshots
{
    NSMutableDictionary *snapshots = objc_getAssociatedObject(self, &revenant_sections_key);
    if (!snapshots) {
        snapshots = [NSMutableDictionary dictionary];
        objc_setAssociatedObject(self, &revenant_sections_key, snapshots, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return snapshots;
}

- (void)revenant_rebaseSectionSnapshotsFrom:(NSDiffableDataSourceSnapshot *)previous onto:(NSDiffableDataSourceSnapshot *)snapshot
{
    if ([objc_getAssociatedObject(self, &revenant_applying_key) boolValue])
        return;
    NSMutableDictionary *snapshots = [self revenant_sectionSnapshots];
    for (id section in snapshots.allKeys) {
        NSDiffableDataSourceSectionSnapshot *stored = snapshots[section];
        NSInteger index = [snapshot indexOfSectionIdentifier:section];
        if (index == NSNotFound) {
            [snapshots removeObjectForKey:section];
            continue;
        }
        NSArray *items = [snapshot itemIdentifiersInSectionWithIdentifier:section], *visible = [previous indexOfSectionIdentifier:section] == NSNotFound ? @[] : [previous itemIdentifiersInSectionWithIdentifier:section];
        if ([items isEqual:visible])
            continue;
        visible = stored.visibleItems;
        NSMutableArray *gone = [NSMutableArray array];
        for (id item in visible)
            if (![items containsObject:item])
                [gone addObject:item];
        NSDiffableDataSourceSectionSnapshot *rebased = [stored copy];
        BOOL usable = YES;
        for (id item in gone)
            if ([rebased containsItem:item])
                [rebased deleteItems:@[item]];
        for (NSUInteger position = 0; position < items.count; position++) {
            id item = items[position];
            if ([visible containsObject:item])
                continue;
            if ([rebased containsItem:item])
                usable = NO;
            else if (position > 0 && [rebased containsItem:items[position - 1]])
                [rebased insertItems:@[item] afterItem:items[position - 1]];
            else if (rebased.rootItems.count)
                [rebased insertItems:@[item] beforeItem:rebased.rootItems.firstObject];
            else
                [rebased appendItems:@[item]];
        }
        if (usable && [rebased.visibleItems isEqual:items])
            snapshots[section] = rebased;
        else
            [snapshots removeObjectForKey:section];
    }
}

- (void)applySnapshot:(NSDiffableDataSourceSectionSnapshot *)snapshot toSection:(id)sectionIdentifier animatingDifferences:(BOOL)animatingDifferences
{
    [self applySnapshot:snapshot toSection:sectionIdentifier animatingDifferences:animatingDifferences completion:nil];
}

- (void)applySnapshot:(NSDiffableDataSourceSectionSnapshot *)snapshot toSection:(id)sectionIdentifier animatingDifferences:(BOOL)animatingDifferences completion:(void (^)(void))completion
{
    if (!sectionIdentifier)
        [NSException raise:NSInternalInconsistencyException format:@"Invalid parameter not satisfying: section"];
    if (!snapshot)
        [NSException raise:NSInternalInconsistencyException format:@"Invalid parameter not satisfying: snapshot"];
    NSDiffableDataSourceSnapshot *updated = [self snapshot];
    if ([updated indexOfSectionIdentifier:sectionIdentifier] == NSNotFound)
        [updated appendSectionsWithIdentifiers:@[sectionIdentifier]];
    [updated revenant_replaceItems:snapshot.visibleItems inSectionAtIndex:(NSUInteger)[updated indexOfSectionIdentifier:sectionIdentifier]];
    NSMutableDictionary *stored = [self revenant_sectionSnapshots];
    id previous = stored[sectionIdentifier];
    stored[sectionIdentifier] = [snapshot copy];
    objc_setAssociatedObject(self, &revenant_applying_key, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    @try {
        [self applySnapshot:updated animatingDifferences:animatingDifferences completion:completion];
    } @catch (NSException *exception) {
        if (previous)
            stored[sectionIdentifier] = previous;
        else
            [stored removeObjectForKey:sectionIdentifier];
        @throw;
    } @finally {
        objc_setAssociatedObject(self, &revenant_applying_key, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    UICollectionView *view = [self revenant_collectionView];
    for (UICollectionViewCell *cell in view.visibleCells) {
        NSIndexPath *path = [view indexPathForCell:cell];
        id item = path ? [self itemIdentifierForIndexPath:path] : nil;
        if (item)
            [self revenant_configureCell:cell item:item indexPath:path];
    }
}

- (NSDiffableDataSourceSectionSnapshot *)snapshotForSection:(id)section
{
    NSDiffableDataSourceSectionSnapshot *stored = section ? [self revenant_sectionSnapshots][section] : nil;
    if (stored)
        return [stored copy];
    NSDiffableDataSourceSectionSnapshot *snapshot = [[NSDiffableDataSourceSectionSnapshot alloc] init];
    NSDiffableDataSourceSnapshot *current = [self revenant_current];
    if (section && [current indexOfSectionIdentifier:section] != NSNotFound)
        [snapshot appendItems:[current itemIdentifiersInSectionWithIdentifier:section]];
    return snapshot;
}


- (NSDiffableDataSourceSnapshot *)revenant_reorderInitial
{
    return objc_getAssociatedObject(self, &revenant_reorder_initial_key);
}

- (id)revenant_sectionIdentifierAtIndex:(NSInteger)index
{
    NSArray *sections = [[self revenant_current] sectionIdentifiers];
    return index >= 0 && (NSUInteger)index < sections.count ? sections[(NSUInteger)index] : nil;
}

- (void)revenant_configureCell:(UICollectionViewCell *)cell item:(id)item indexPath:(NSIndexPath *)indexPath
{
    if (![cell isKindOfClass:[UICollectionViewListCell class]])
        return;
    id section = [self revenant_sectionIdentifierAtIndex:indexPath.section];
    NSDiffableDataSourceSectionSnapshot *stored = section ? [self revenant_sectionSnapshots][section] : nil;
    UICollectionViewListCell *list = (UICollectionViewListCell *)cell;
    if (!stored || ![stored containsItem:item]) {
        [list revenant_setExpansionHandler:nil];
        return;
    }
    list.indentationLevel = [stored levelOfItem:item];
    [list revenant_setExpanded:[stored isExpanded:item] animated:NO];
    __weak UICollectionViewDiffableDataSource *weakSelf = self;
    [list revenant_setExpansionHandler:^{
        [weakSelf revenant_toggleItem:item inSection:section];
    }];
}

- (void)revenant_refreshOutlineCellsAnimated:(BOOL)animated
{
    UICollectionView *view = [self revenant_collectionView];
    for (UICollectionViewCell *cell in view.visibleCells) {
        NSIndexPath *path = [view indexPathForCell:cell];
        id item = path ? [self itemIdentifierForIndexPath:path] : nil;
        id section = path ? [self revenant_sectionIdentifierAtIndex:path.section] : nil;
        NSDiffableDataSourceSectionSnapshot *stored = section ? [self revenant_sectionSnapshots][section] : nil;
        if ([cell isKindOfClass:[UICollectionViewListCell class]] && item && [stored containsItem:item])
            [(UICollectionViewListCell *)cell revenant_setExpanded:[stored isExpanded:item] animated:animated];
    }
}

- (void)revenant_toggleItem:(id)item inSection:(id)section
{
    NSDiffableDataSourceSectionSnapshot *snapshot = [[self revenant_sectionSnapshots][section] copy];
    if (!snapshot || ![snapshot containsItem:item])
        return;
    UICollectionViewDiffableDataSourceSectionSnapshotHandlers *handlers = [self sectionSnapshotHandlers];
    if (![snapshot isExpanded:item]) {
        if (handlers.shouldExpandItemHandler && !handlers.shouldExpandItemHandler(item))
            return;
        if (handlers.willExpandItemHandler)
            handlers.willExpandItemHandler(item);
        if (handlers.snapshotForExpandingParentItemHandler) {
            NSDiffableDataSourceSectionSnapshot *children = handlers.snapshotForExpandingParentItemHandler(item, [snapshot snapshotOfParentItem:item]);
            if (children)
                [snapshot replaceChildrenOfParentItem:item withSnapshot:children];
        }
        [snapshot expandItems:@[item]];
    } else {
        if (handlers.shouldCollapseItemHandler && !handlers.shouldCollapseItemHandler(item))
            return;
        if (handlers.willCollapseItemHandler)
            handlers.willCollapseItemHandler(item);
        [snapshot collapseItems:@[item]];
    }
    [self applySnapshot:snapshot toSection:section animatingDifferences:YES];
    [self revenant_refreshOutlineCellsAnimated:YES];
}

- (BOOL)collectionView:(UICollectionView *)collectionView canMoveItemAtIndexPath:(NSIndexPath *)indexPath
{
    BOOL (^handler)(id) = [self reorderingHandlers].canReorderItemHandler;
    id item = handler ? [self itemIdentifierForIndexPath:indexPath] : nil;
    return item ? handler(item) : NO;
}

- (void)collectionView:(UICollectionView *)collectionView moveItemAtIndexPath:(NSIndexPath *)source toIndexPath:(NSIndexPath *)destination
{
    NSDiffableDataSourceSnapshot *snapshot = [self revenant_current];
    id item = [snapshot revenant_itemAtIndexPath:source], target = [snapshot revenant_itemAtIndexPath:destination];
    if (!item || !target || item == target)
        return;
    if (source.section == destination.section && source.item < destination.item)
        [snapshot moveItemWithIdentifier:item afterItemWithIdentifier:target];
    else
        [snapshot moveItemWithIdentifier:item beforeItemWithIdentifier:target];
}

- (void)revenant_reorderBegan
{
    objc_setAssociatedObject(self, &revenant_reorder_initial_key, [self snapshot], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)revenant_reorderCancelled
{
    objc_setAssociatedObject(self, &revenant_reorder_initial_key, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)revenant_reorderEnded
{
    NSDiffableDataSourceSnapshot *initial = objc_getAssociatedObject(self, &revenant_reorder_initial_key);
    objc_setAssociatedObject(self, &revenant_reorder_initial_key, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    NSDiffableDataSourceSnapshot *final = [self snapshot];
    if (!initial || [initial.itemIdentifiers isEqual:final.itemIdentifiers])
        return;
    NSDiffableDataSourceTransaction *transaction = [[NSDiffableDataSourceTransaction alloc] initRevenantWithInitial:initial final:final];
    UICollectionViewDiffableDataSourceReorderingHandlers *handlers = [self reorderingHandlers];
    NSDiffableDataSourceSnapshot *live = [self revenant_current];
    if (handlers.willReorderHandler) {
        [self revenant_replaceCurrent:initial];
        handlers.willReorderHandler(transaction);
        [self revenant_replaceCurrent:live];
    }
    [self revenant_rebaseSectionSnapshotsFrom:initial onto:live];
    if (handlers.didReorderHandler)
        handlers.didReorderHandler(transaction);
}

@end
