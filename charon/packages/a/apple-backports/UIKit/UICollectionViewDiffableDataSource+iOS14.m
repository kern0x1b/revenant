#import "CharonDiffable.h"
#import "CharonLists.h"
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

static const char charon_reordering_key = 0, charon_snapshot_handlers_key = 0, charon_sections_key = 0, charon_applying_key = 0, charon_reorder_initial_key = 0;

@implementation UICollectionViewDiffableDataSource (CharonFourteen)

- (UICollectionViewDiffableDataSourceReorderingHandlers *)reorderingHandlers
{
    id handlers = objc_getAssociatedObject(self, &charon_reordering_key);
    if (!handlers) {
        handlers = [[UICollectionViewDiffableDataSourceReorderingHandlers alloc] init];
        objc_setAssociatedObject(self, &charon_reordering_key, handlers, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return handlers;
}

- (void)setReorderingHandlers:(UICollectionViewDiffableDataSourceReorderingHandlers *)reorderingHandlers
{
    objc_setAssociatedObject(self, &charon_reordering_key, [reorderingHandlers copy], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (UICollectionViewDiffableDataSourceSectionSnapshotHandlers *)sectionSnapshotHandlers
{
    id handlers = objc_getAssociatedObject(self, &charon_snapshot_handlers_key);
    if (!handlers) {
        handlers = [[UICollectionViewDiffableDataSourceSectionSnapshotHandlers alloc] init];
        objc_setAssociatedObject(self, &charon_snapshot_handlers_key, handlers, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return handlers;
}

- (void)setSectionSnapshotHandlers:(UICollectionViewDiffableDataSourceSectionSnapshotHandlers *)sectionSnapshotHandlers
{
    objc_setAssociatedObject(self, &charon_snapshot_handlers_key, [sectionSnapshotHandlers copy], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSMutableDictionary *)charon_sectionSnapshots
{
    NSMutableDictionary *snapshots = objc_getAssociatedObject(self, &charon_sections_key);
    if (!snapshots) {
        snapshots = [NSMutableDictionary dictionary];
        objc_setAssociatedObject(self, &charon_sections_key, snapshots, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return snapshots;
}

- (void)charon_rebaseSectionSnapshotsFrom:(NSDiffableDataSourceSnapshot *)previous onto:(NSDiffableDataSourceSnapshot *)snapshot
{
    if ([objc_getAssociatedObject(self, &charon_applying_key) boolValue])
        return;
    NSMutableDictionary *snapshots = [self charon_sectionSnapshots];
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
    [updated charon_replaceItems:snapshot.visibleItems inSectionAtIndex:(NSUInteger)[updated indexOfSectionIdentifier:sectionIdentifier]];
    NSMutableDictionary *stored = [self charon_sectionSnapshots];
    id previous = stored[sectionIdentifier];
    stored[sectionIdentifier] = [snapshot copy];
    objc_setAssociatedObject(self, &charon_applying_key, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    @try {
        [self applySnapshot:updated animatingDifferences:animatingDifferences completion:completion];
    } @catch (NSException *exception) {
        if (previous)
            stored[sectionIdentifier] = previous;
        else
            [stored removeObjectForKey:sectionIdentifier];
        @throw;
    } @finally {
        objc_setAssociatedObject(self, &charon_applying_key, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    UICollectionView *view = [self charon_collectionView];
    for (UICollectionViewCell *cell in view.visibleCells) {
        NSIndexPath *path = [view indexPathForCell:cell];
        id item = path ? [self itemIdentifierForIndexPath:path] : nil;
        if (item)
            [self charon_configureCell:cell item:item indexPath:path];
    }
}

- (NSDiffableDataSourceSectionSnapshot *)snapshotForSection:(id)section
{
    NSDiffableDataSourceSectionSnapshot *stored = section ? [self charon_sectionSnapshots][section] : nil;
    if (stored)
        return [stored copy];
    NSDiffableDataSourceSectionSnapshot *snapshot = [[NSDiffableDataSourceSectionSnapshot alloc] init];
    NSDiffableDataSourceSnapshot *current = [self charon_current];
    if (section && [current indexOfSectionIdentifier:section] != NSNotFound)
        [snapshot appendItems:[current itemIdentifiersInSectionWithIdentifier:section]];
    return snapshot;
}


- (NSDiffableDataSourceSnapshot *)charon_reorderInitial
{
    return objc_getAssociatedObject(self, &charon_reorder_initial_key);
}

- (id)charon_sectionIdentifierAtIndex:(NSInteger)index
{
    NSArray *sections = [[self charon_current] sectionIdentifiers];
    return index >= 0 && (NSUInteger)index < sections.count ? sections[(NSUInteger)index] : nil;
}

- (void)charon_configureCell:(UICollectionViewCell *)cell item:(id)item indexPath:(NSIndexPath *)indexPath
{
    if (![cell isKindOfClass:[UICollectionViewListCell class]])
        return;
    id section = [self charon_sectionIdentifierAtIndex:indexPath.section];
    NSDiffableDataSourceSectionSnapshot *stored = section ? [self charon_sectionSnapshots][section] : nil;
    UICollectionViewListCell *list = (UICollectionViewListCell *)cell;
    if (!stored || ![stored containsItem:item]) {
        [list charon_setExpansionHandler:nil];
        return;
    }
    list.indentationLevel = [stored levelOfItem:item];
    [list charon_setExpanded:[stored isExpanded:item] animated:NO];
    __weak UICollectionViewDiffableDataSource *weakSelf = self;
    [list charon_setExpansionHandler:^{
        [weakSelf charon_toggleItem:item inSection:section];
    }];
}

- (void)charon_refreshOutlineCellsAnimated:(BOOL)animated
{
    UICollectionView *view = [self charon_collectionView];
    for (UICollectionViewCell *cell in view.visibleCells) {
        NSIndexPath *path = [view indexPathForCell:cell];
        id item = path ? [self itemIdentifierForIndexPath:path] : nil;
        id section = path ? [self charon_sectionIdentifierAtIndex:path.section] : nil;
        NSDiffableDataSourceSectionSnapshot *stored = section ? [self charon_sectionSnapshots][section] : nil;
        if ([cell isKindOfClass:[UICollectionViewListCell class]] && item && [stored containsItem:item])
            [(UICollectionViewListCell *)cell charon_setExpanded:[stored isExpanded:item] animated:animated];
    }
}

- (void)charon_toggleItem:(id)item inSection:(id)section
{
    NSDiffableDataSourceSectionSnapshot *snapshot = [[self charon_sectionSnapshots][section] copy];
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
    [self charon_refreshOutlineCellsAnimated:YES];
}

- (BOOL)collectionView:(UICollectionView *)collectionView canMoveItemAtIndexPath:(NSIndexPath *)indexPath
{
    BOOL (^handler)(id) = [self reorderingHandlers].canReorderItemHandler;
    id item = handler ? [self itemIdentifierForIndexPath:indexPath] : nil;
    return item ? handler(item) : NO;
}

- (void)collectionView:(UICollectionView *)collectionView moveItemAtIndexPath:(NSIndexPath *)source toIndexPath:(NSIndexPath *)destination
{
    NSDiffableDataSourceSnapshot *snapshot = [self charon_current];
    id item = [snapshot charon_itemAtIndexPath:source], target = [snapshot charon_itemAtIndexPath:destination];
    if (!item || !target || item == target)
        return;
    if (source.section == destination.section && source.item < destination.item)
        [snapshot moveItemWithIdentifier:item afterItemWithIdentifier:target];
    else
        [snapshot moveItemWithIdentifier:item beforeItemWithIdentifier:target];
}

- (void)charon_reorderBegan
{
    objc_setAssociatedObject(self, &charon_reorder_initial_key, [self snapshot], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)charon_reorderCancelled
{
    objc_setAssociatedObject(self, &charon_reorder_initial_key, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)charon_reorderEnded
{
    NSDiffableDataSourceSnapshot *initial = objc_getAssociatedObject(self, &charon_reorder_initial_key);
    objc_setAssociatedObject(self, &charon_reorder_initial_key, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    NSDiffableDataSourceSnapshot *final = [self snapshot];
    if (!initial || [initial.itemIdentifiers isEqual:final.itemIdentifiers])
        return;
    NSDiffableDataSourceTransaction *transaction = [[NSDiffableDataSourceTransaction alloc] initCharonWithInitial:initial final:final];
    UICollectionViewDiffableDataSourceReorderingHandlers *handlers = [self reorderingHandlers];
    NSDiffableDataSourceSnapshot *live = [self charon_current];
    if (handlers.willReorderHandler) {
        [self charon_replaceCurrent:initial];
        handlers.willReorderHandler(transaction);
        [self charon_replaceCurrent:live];
    }
    [self charon_rebaseSectionSnapshotsFrom:initial onto:live];
    if (handlers.didReorderHandler)
        handlers.didReorderHandler(transaction);
}

@end
