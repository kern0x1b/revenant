#import "RevenantDiffable.h"

static NSString *const revenant_source_file = @"UIDiffableDataSource.m";

@implementation UICollectionViewDiffableDataSource {
@private
    __weak UICollectionView *_collectionView;
    UICollectionViewDiffableDataSourceCellProvider _cellProvider;
    UICollectionViewDiffableDataSourceSupplementaryViewProvider _supplementaryViewProvider;
    NSDiffableDataSourceSnapshot *_snapshot;
    BOOL _applied;
}

@dynamic reorderingHandlers, sectionSnapshotHandlers;

- (instancetype)init
{
    if ((self = [super init]))
        _snapshot = [[NSDiffableDataSourceSnapshot alloc] init];
    return self;
}

- (instancetype)initWithCollectionView:(UICollectionView *)collectionView cellProvider:(UICollectionViewDiffableDataSourceCellProvider)cellProvider
{
    if ((self = [super init])) {
        _collectionView = collectionView;
        _cellProvider = [cellProvider copy];
        _snapshot = [[NSDiffableDataSourceSnapshot alloc] init];
        collectionView.dataSource = self;
    }
    return self;
}

- (UICollectionViewDiffableDataSourceSupplementaryViewProvider)supplementaryViewProvider
{
    return _supplementaryViewProvider;
}

- (void)setSupplementaryViewProvider:(UICollectionViewDiffableDataSourceSupplementaryViewProvider)supplementaryViewProvider
{
    _supplementaryViewProvider = [supplementaryViewProvider copy];
}

- (NSDiffableDataSourceSnapshot *)revenant_current
{
    if (!_snapshot)
        _snapshot = [[NSDiffableDataSourceSnapshot alloc] init];
    return _snapshot;
}

- (void)revenant_replaceCurrent:(NSDiffableDataSourceSnapshot *)snapshot
{
    _snapshot = snapshot;
}

- (UICollectionView *)revenant_collectionView
{
    return _collectionView;
}

- (NSDiffableDataSourceSnapshot *)snapshot
{
    NSDiffableDataSourceSnapshot *held = [self respondsToSelector:@selector(revenant_reorderInitial)] ? [self revenant_reorderInitial] : nil;
    if (held)
        return [held copy];
    return [[self revenant_current] revenant_copyWithoutReloads];
}

- (id)itemIdentifierForIndexPath:(NSIndexPath *)indexPath
{
    return [[self revenant_current] revenant_itemAtIndexPath:indexPath];
}

- (NSIndexPath *)indexPathForItemIdentifier:(id)identifier
{
    return [[self revenant_current] revenant_indexPathForItem:identifier];
}

- (void)applySnapshot:(NSDiffableDataSourceSnapshot *)snapshot animatingDifferences:(BOOL)animatingDifferences
{
    [self applySnapshot:snapshot animatingDifferences:animatingDifferences completion:nil];
}

- (void)applySnapshot:(NSDiffableDataSourceSnapshot *)snapshot animatingDifferences:(BOOL)animatingDifferences completion:(void (^)(void))completion
{
    if (!snapshot)
        [NSException raise:NSInternalInconsistencyException format:@"Invalid parameter not satisfying: snapshot"];
    NSDiffableDataSourceSnapshot *old = [self revenant_current], *updated = [snapshot revenant_copyWithoutReloads];
    if ([self respondsToSelector:@selector(revenant_rebaseSectionSnapshotsFrom:onto:)])
        [self revenant_rebaseSectionSnapshotsFrom:old onto:updated];
    UICollectionView *view = _collectionView;
    NSDictionary *changes = revenant_diffable_changes(old, snapshot, NO);
    BOOL visible = view.window != nil, initial = !_applied, structural = visible && !initial && ![changes[@"fallback"] boolValue];
    _applied = YES;
    NSIndexSet *deleteSections = changes[@"deleteSections"], *insertSections = changes[@"insertSections"], *reloadSections = changes[@"reloadSections"];
    BOOL changed = deleteSections.count || insertSections.count || [changes[@"moveSections"] count] || [changes[@"deleteItems"] count] || [changes[@"insertItems"] count] || [changes[@"moveItems"] count];
    NSMutableArray *reloadItems = [changes[@"reloadItems"] mutableCopy];
    if (structural && !changed)
        for (NSIndexPath *path in changes[@"reloadItems"])
            if ([reloadSections containsIndex:(NSUInteger)path.section])
                [reloadItems removeObject:path];
    BOOL animations = [UIView areAnimationsEnabled];
    if (!animatingDifferences)
        [UIView setAnimationsEnabled:NO];
    void (^finish)(void) = [completion copy];
    BOOL reloads = visible && (initial ? animatingDifferences : ![changes[@"fallback"] boolValue]) && (reloadSections.count || reloadItems.count);
    void (^reload)(void) = ^{
        if (!reloads) {
            revenant_diffable_finish(finish);
            return;
        }
        if (initial) {
            [view performBatchUpdates:^{
                if (reloadItems.count)
                    [view reloadItemsAtIndexPaths:reloadItems];
            } completion:nil];
            [view performBatchUpdates:^{
                if (reloadSections.count)
                    [view reloadSections:reloadSections];
            } completion:^(BOOL finished) {
                if (finish)
                    finish();
            }];
            return;
        }
        [view performBatchUpdates:^{
            if (reloadSections.count)
                [view reloadSections:reloadSections];
            if (reloadItems.count)
                [view reloadItemsAtIndexPaths:reloadItems];
        } completion:^(BOOL finished) {
            if (finish)
                finish();
        }];
    };
    if (initial && visible && animatingDifferences && insertSections.count) {
        [view performBatchUpdates:^{
            self->_snapshot = updated;
            [view insertSections:insertSections];
        } completion:nil];
        reload();
    } else if (!structural) {
        _snapshot = updated;
        [view reloadData];
        [view layoutIfNeeded];
        reload();
    } else {
        if (!changed) {
            _snapshot = updated;
            reload();
        } else {
            [view performBatchUpdates:^{
                self->_snapshot = updated;
                if (deleteSections.count)
                    [view deleteSections:deleteSections];
                if (insertSections.count)
                    [view insertSections:insertSections];
                for (NSArray *pair in changes[@"moveSections"])
                    [view moveSection:[pair[0] integerValue] toSection:[pair[1] integerValue]];
                if ([changes[@"deleteItems"] count])
                    [view deleteItemsAtIndexPaths:changes[@"deleteItems"]];
                if ([changes[@"insertItems"] count])
                    [view insertItemsAtIndexPaths:changes[@"insertItems"]];
                for (NSArray *pair in changes[@"moveItems"])
                    [view moveItemAtIndexPath:pair[0] toIndexPath:pair[1]];
            } completion:nil];
            reload();
        }
    }
    if (!animatingDifferences)
        [UIView setAnimationsEnabled:animations];
}

- (void)revenant_applyReloadingData:(NSDiffableDataSourceSnapshot *)snapshot completion:(void (^)(void))completion
{
    if (!snapshot)
        [NSException raise:NSInternalInconsistencyException format:@"Invalid parameter not satisfying: snapshot"];
    NSDiffableDataSourceSnapshot *updated = [snapshot revenant_copyWithoutReloads];
    if ([self respondsToSelector:@selector(revenant_rebaseSectionSnapshotsFrom:onto:)])
        [self revenant_rebaseSectionSnapshotsFrom:[self revenant_current] onto:updated];
    _applied = YES;
    _snapshot = updated;
    [_collectionView reloadData];
    [_collectionView layoutIfNeeded];
    revenant_diffable_finish(completion);
}

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView
{
    return [self revenant_current].numberOfSections;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    NSDiffableDataSourceSnapshot *snapshot = [self revenant_current];
    revenant_diffable_require(section < snapshot.numberOfSections, revenant_source_file, 141, @"section < _impl.numberOfSections");
    return (NSInteger)[snapshot revenant_countInSectionAtIndex:(NSUInteger)section];
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    revenant_diffable_require(indexPath != nil, revenant_source_file, 146, @"indexPath");
    id item = [[self revenant_current] revenant_itemAtIndexPath:indexPath];
    UICollectionViewCell *cell = _cellProvider ? _cellProvider(collectionView, indexPath, item) : nil;
    if (!cell)
        revenant_diffable_raise(@"_UIDiffableDataSourceImpl.m", 1533, [NSString stringWithFormat:@"UICollectionViewDiffableDataSource cell provider returned nil for index path %@ with item identifier '%@', which is not allowed. You must always return a cell to the collection view: %@", indexPath, item, collectionView]);
    if ([self respondsToSelector:@selector(revenant_configureCell:item:indexPath:)])
        [self revenant_configureCell:cell item:item indexPath:indexPath];
    return cell;
}

- (UICollectionReusableView *)collectionView:(UICollectionView *)collectionView viewForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath
{
    if (!_supplementaryViewProvider)
        revenant_diffable_raise(revenant_source_file, 152, [NSString stringWithFormat:@"CollectionView %@ requested a supplementary view, but a supplementaryViewProvider was not specified on the diffable data source. Please configure the diffable data source accordingly and add the supplementary provider", collectionView]);
    return _supplementaryViewProvider(collectionView, kind, indexPath);
}

- (NSString *)description
{
    return revenant_diffable_source_description([self revenant_current]);
}

@end
