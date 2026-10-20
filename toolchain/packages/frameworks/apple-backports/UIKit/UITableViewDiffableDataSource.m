#import "RevenantDiffable.h"

static NSString *const revenant_source_file = @"UIDiffableDataSource.m";

@implementation UITableViewDiffableDataSource {
@private
    __weak UITableView *_tableView;
    UITableViewDiffableDataSourceCellProvider _cellProvider;
    NSDiffableDataSourceSnapshot *_snapshot;
    BOOL _applied;
    UITableViewRowAnimation _defaultRowAnimation;
}

- (instancetype)init
{
    if ((self = [super init])) {
        _snapshot = [[NSDiffableDataSourceSnapshot alloc] init];
        _defaultRowAnimation = UITableViewRowAnimationAutomatic;
    }
    return self;
}

- (instancetype)initWithTableView:(UITableView *)tableView cellProvider:(UITableViewDiffableDataSourceCellProvider)cellProvider
{
    if ((self = [super init])) {
        _tableView = tableView;
        _cellProvider = [cellProvider copy];
        _snapshot = [[NSDiffableDataSourceSnapshot alloc] init];
        _defaultRowAnimation = UITableViewRowAnimationAutomatic;
        tableView.dataSource = self;
    }
    return self;
}

- (UITableViewRowAnimation)defaultRowAnimation
{
    return _defaultRowAnimation;
}

- (void)setDefaultRowAnimation:(UITableViewRowAnimation)defaultRowAnimation
{
    _defaultRowAnimation = defaultRowAnimation;
}

- (NSDiffableDataSourceSnapshot *)revenant_current
{
    if (!_snapshot)
        _snapshot = [[NSDiffableDataSourceSnapshot alloc] init];
    return _snapshot;
}

- (NSDiffableDataSourceSnapshot *)snapshot
{
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
    UITableView *view = _tableView;
    NSDictionary *changes = revenant_diffable_changes(old, snapshot, YES);
    BOOL visible = view.window != nil, initial = !_applied, structural = visible && !initial && old.numberOfSections && ![changes[@"fallback"] boolValue];
    _applied = YES;
    NSIndexSet *deleteSections = changes[@"deleteSections"], *insertSections = changes[@"insertSections"], *reloadSections = changes[@"reloadSections"];
    BOOL changed = deleteSections.count || insertSections.count || [changes[@"moveSections"] count] || [changes[@"deleteItems"] count] || [changes[@"insertItems"] count] || [changes[@"moveItems"] count];
    NSMutableArray *reloadItems = [changes[@"reloadItems"] mutableCopy];
    if (structural && !changed)
        for (NSIndexPath *path in changes[@"reloadItems"])
            if ([reloadSections containsIndex:(NSUInteger)path.section])
                [reloadItems removeObject:path];
    UITableViewRowAnimation animation = animatingDifferences ? _defaultRowAnimation : UITableViewRowAnimationNone;
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
        [CATransaction begin];
        [CATransaction setCompletionBlock:^{
            if (finish)
                finish();
        }];
        [view beginUpdates];
        if (reloadSections.count)
            [view reloadSections:reloadSections withRowAnimation:animation];
        if (reloadItems.count)
            [view reloadRowsAtIndexPaths:reloadItems withRowAnimation:animation];
        [view endUpdates];
        [CATransaction commit];
    };
    if (!structural) {
        _snapshot = updated;
        [view reloadData];
        [view layoutIfNeeded];
        reload();
    } else {
        if (!changed) {
            _snapshot = updated;
            reload();
        } else {
            [view beginUpdates];
            _snapshot = updated;
            if (deleteSections.count)
                [view deleteSections:deleteSections withRowAnimation:animation];
            if (insertSections.count)
                [view insertSections:insertSections withRowAnimation:animation];
            for (NSArray *pair in changes[@"moveSections"])
                [view moveSection:[pair[0] integerValue] toSection:[pair[1] integerValue]];
            if ([changes[@"deleteItems"] count])
                [view deleteRowsAtIndexPaths:changes[@"deleteItems"] withRowAnimation:animation];
            if ([changes[@"insertItems"] count])
                [view insertRowsAtIndexPaths:changes[@"insertItems"] withRowAnimation:animation];
            for (NSArray *pair in changes[@"moveItems"])
                [view moveRowAtIndexPath:pair[0] toIndexPath:pair[1]];
            [view endUpdates];
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
    _applied = YES;
    _snapshot = updated;
    [_tableView reloadData];
    [_tableView layoutIfNeeded];
    revenant_diffable_finish(completion);
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return [self revenant_current].numberOfSections;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    NSDiffableDataSourceSnapshot *snapshot = [self revenant_current];
    revenant_diffable_require(section < snapshot.numberOfSections, revenant_source_file, 392, @"section < _impl.numberOfSections");
    return (NSInteger)[snapshot revenant_countInSectionAtIndex:(NSUInteger)section];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    revenant_diffable_require(indexPath != nil, revenant_source_file, 397, @"indexPath");
    id item = [[self revenant_current] revenant_itemAtIndexPath:indexPath];
    revenant_diffable_require(item != nil, @"_UIDiffableDataSourceImpl.m", 1658, @"itemIdentifier");
    UITableViewCell *cell = _cellProvider ? _cellProvider(tableView, indexPath, item) : nil;
    if (!cell)
        revenant_diffable_raise(@"_UIDiffableDataSourceImpl.m", 1663, [NSString stringWithFormat:@"UITableViewDiffableDataSource cell provider returned nil for index path %@ with item identifier '%@', which is not allowed. You must always return a cell to the table view: %@", indexPath, item, tableView]);
    return cell;
}

- (NSString *)description
{
    return revenant_diffable_source_description([self revenant_current]);
}

@end
