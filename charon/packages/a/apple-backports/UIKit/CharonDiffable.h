#import <UIKit/UIKit.h>

static inline void charon_diffable_raise(NSString *file, NSInteger line, NSString *reason)
{
    [[NSException exceptionWithName:NSInternalInconsistencyException reason:reason userInfo:@{@"NSAssertFile": file, @"NSAssertLine": @(line)}] raise];
}

static inline void charon_diffable_require(BOOL condition, NSString *file, NSInteger line, NSString *what)
{
    if (!condition)
        charon_diffable_raise(file, line, [@"Invalid parameter not satisfying: " stringByAppendingString:what]);
}

@interface NSDiffableDataSourceSnapshot (CharonDiffable)
- (NSArray *)charon_sections;
- (NSUInteger)charon_countInSectionAtIndex:(NSUInteger)index;
- (NSArray *)charon_itemsInSectionAtIndex:(NSUInteger)index;
- (NSArray *)charon_reloadedItems;
- (NSArray *)charon_reloadedSections;
- (NSDiffableDataSourceSnapshot *)charon_copyWithoutReloads;
- (NSIndexPath *)charon_indexPathForItem:(id)item;
- (id)charon_itemAtIndexPath:(NSIndexPath *)indexPath;
- (void)charon_replaceItems:(NSArray *)items inSectionAtIndex:(NSUInteger)index;
@end

NSDictionary *charon_diffable_changes(NSDiffableDataSourceSnapshot *old, NSDiffableDataSourceSnapshot *current, BOOL table);

NSString *charon_diffable_source_description(NSDiffableDataSourceSnapshot *snapshot);
void charon_diffable_finish(void (^completion)(void));

@interface UICollectionViewDiffableDataSource (CharonDiffable)
- (NSDiffableDataSourceSnapshot *)charon_current;
- (void)charon_replaceCurrent:(NSDiffableDataSourceSnapshot *)snapshot;
- (UICollectionView *)charon_collectionView;
- (void)charon_configureCell:(UICollectionViewCell *)cell item:(id)item indexPath:(NSIndexPath *)indexPath;
- (NSDiffableDataSourceSnapshot *)charon_reorderInitial;
- (void)charon_reorderBegan;
- (void)charon_reorderEnded;
- (void)charon_reorderCancelled;
- (void)charon_rebaseSectionSnapshotsFrom:(NSDiffableDataSourceSnapshot *)previous onto:(NSDiffableDataSourceSnapshot *)snapshot;
- (void)charon_applyReloadingData:(NSDiffableDataSourceSnapshot *)snapshot completion:(void (^)(void))completion;
@end

@interface UITableViewDiffableDataSource (CharonDiffable)
- (NSDiffableDataSourceSnapshot *)charon_current;
- (void)charon_applyReloadingData:(NSDiffableDataSourceSnapshot *)snapshot completion:(void (^)(void))completion;
@end

@interface NSDiffableDataSourceTransaction (CharonDiffable)
- (instancetype)initCharonWithInitial:(NSDiffableDataSourceSnapshot *)initial final:(NSDiffableDataSourceSnapshot *)final;
@end

@interface NSDiffableDataSourceSectionTransaction (CharonDiffable)
- (instancetype)initCharonWithSection:(id)section initial:(NSArray *)initial final:(NSArray *)final;
@end
