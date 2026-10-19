#import "CharonDiffable.h"

static NSString *const charon_source_file = @"UIDiffableDataSource.m";

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

- (NSDiffableDataSourceSnapshot *)charon_current
{
    if (!_snapshot)
        _snapshot = [[NSDiffableDataSourceSnapshot alloc] init];
    return _snapshot;
}

- (NSDiffableDataSourceSnapshot *)snapshot
{
    return [[self charon_current] charon_copyWithoutReloads];
}

- (id)itemIdentifierForIndexPath:(NSIndexPath *)indexPath
{
    return [[self charon_current] charon_itemAtIndexPath:indexPath];
}

- (NSIndexPath *)indexPathForItemIdentifier:(id)identifier
{
    return [[self charon_current] charon_indexPathForItem:identifier];
}

- (void)applySnapshot:(NSDiffableDataSourceSnapshot *)snapshot animatingDifferences:(BOOL)animatingDifferences
{
    [self applySnapshot:snapshot animatingDifferences:animatingDifferences completion:nil];
}

- (void)applySnapshot:(NSDiffableDataSourceSnapshot *)snapshot animatingDifferences:(BOOL)animatingDifferences completion:(void (^)(void))completion
{
    if (!snapshot)
        [NSException raise:NSInternalInconsistencyException format:@"Invalid parameter not satisfying: snapshot"];
    NSDiffableDataSourceSnapshot *old = [self charon_current], *updated = [snapshot charon_copyWithoutReloads];
    UITableView *view = _tableView;
    NSDictionary *changes = charon_diffable_changes(old, snapshot, YES);
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
            charon_diffable_finish(finish);
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

- (void)charon_applyReloadingData:(NSDiffableDataSourceSnapshot *)snapshot completion:(void (^)(void))completion
{
    if (!snapshot)
        [NSException raise:NSInternalInconsistencyException format:@"Invalid parameter not satisfying: snapshot"];
    NSDiffableDataSourceSnapshot *updated = [snapshot charon_copyWithoutReloads];
    _applied = YES;
    _snapshot = updated;
    [_tableView reloadData];
    [_tableView layoutIfNeeded];
    charon_diffable_finish(completion);
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return [self charon_current].numberOfSections;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    NSDiffableDataSourceSnapshot *snapshot = [self charon_current];
    charon_diffable_require(section < snapshot.numberOfSections, charon_source_file, 392, @"section < _impl.numberOfSections");
    return (NSInteger)[snapshot charon_countInSectionAtIndex:(NSUInteger)section];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    charon_diffable_require(indexPath != nil, charon_source_file, 397, @"indexPath");
    id item = [[self charon_current] charon_itemAtIndexPath:indexPath];
    charon_diffable_require(item != nil, @"_UIDiffableDataSourceImpl.m", 1658, @"itemIdentifier");
    UITableViewCell *cell = _cellProvider ? _cellProvider(tableView, indexPath, item) : nil;
    if (!cell)
        charon_diffable_raise(@"_UIDiffableDataSourceImpl.m", 1663, [NSString stringWithFormat:@"UITableViewDiffableDataSource cell provider returned nil for index path %@ with item identifier '%@', which is not allowed. You must always return a cell to the table view: %@", indexPath, item, tableView]);
    return cell;
}

- (NSString *)description
{
    return charon_diffable_source_description([self charon_current]);
}

@end
