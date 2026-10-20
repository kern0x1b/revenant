#import <UIKit/UIKit.h>

static inline void revenant_diffable_raise(NSString *file, NSInteger line, NSString *reason)
{
    [[NSException exceptionWithName:NSInternalInconsistencyException reason:reason userInfo:@{@"NSAssertFile": file, @"NSAssertLine": @(line)}] raise];
}

static inline void revenant_diffable_require(BOOL condition, NSString *file, NSInteger line, NSString *what)
{
    if (!condition)
        revenant_diffable_raise(file, line, [@"Invalid parameter not satisfying: " stringByAppendingString:what]);
}

@interface NSDiffableDataSourceSnapshot (RevenantDiffable)
- (NSArray *)revenant_sections;
- (NSUInteger)revenant_countInSectionAtIndex:(NSUInteger)index;
- (NSArray *)revenant_itemsInSectionAtIndex:(NSUInteger)index;
- (NSArray *)revenant_reloadedItems;
- (NSArray *)revenant_reloadedSections;
- (NSDiffableDataSourceSnapshot *)revenant_copyWithoutReloads;
- (NSIndexPath *)revenant_indexPathForItem:(id)item;
- (id)revenant_itemAtIndexPath:(NSIndexPath *)indexPath;
- (void)revenant_replaceItems:(NSArray *)items inSectionAtIndex:(NSUInteger)index;
@end

NSDictionary *revenant_diffable_changes(NSDiffableDataSourceSnapshot *old, NSDiffableDataSourceSnapshot *current, BOOL table);

NSString *revenant_diffable_source_description(NSDiffableDataSourceSnapshot *snapshot);
void revenant_diffable_finish(void (^completion)(void));

@interface UICollectionViewDiffableDataSource (RevenantDiffable)
- (NSDiffableDataSourceSnapshot *)revenant_current;
- (void)revenant_replaceCurrent:(NSDiffableDataSourceSnapshot *)snapshot;
- (UICollectionView *)revenant_collectionView;
- (void)revenant_configureCell:(UICollectionViewCell *)cell item:(id)item indexPath:(NSIndexPath *)indexPath;
- (NSDiffableDataSourceSnapshot *)revenant_reorderInitial;
- (void)revenant_reorderBegan;
- (void)revenant_reorderEnded;
- (void)revenant_reorderCancelled;
- (void)revenant_rebaseSectionSnapshotsFrom:(NSDiffableDataSourceSnapshot *)previous onto:(NSDiffableDataSourceSnapshot *)snapshot;
- (void)revenant_applyReloadingData:(NSDiffableDataSourceSnapshot *)snapshot completion:(void (^)(void))completion;
@end

@interface UITableViewDiffableDataSource (RevenantDiffable)
- (NSDiffableDataSourceSnapshot *)revenant_current;
- (void)revenant_applyReloadingData:(NSDiffableDataSourceSnapshot *)snapshot completion:(void (^)(void))completion;
@end

@interface NSDiffableDataSourceTransaction (RevenantDiffable)
- (instancetype)initRevenantWithInitial:(NSDiffableDataSourceSnapshot *)initial final:(NSDiffableDataSourceSnapshot *)final;
@end

@interface NSDiffableDataSourceSectionTransaction (RevenantDiffable)
- (instancetype)initRevenantWithSection:(id)section initial:(NSArray *)initial final:(NSArray *)final;
@end
