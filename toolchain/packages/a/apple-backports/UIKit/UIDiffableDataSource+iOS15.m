#import "RevenantDiffable.h"

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

static id revenant_section_at(NSDiffableDataSourceSnapshot *snapshot, NSInteger index)
{
    NSArray *sections = [snapshot revenant_sections];
    return index >= 0 && (NSUInteger)index < sections.count ? sections[(NSUInteger)index] : nil;
}

@implementation NSDiffableDataSourceSnapshot (RevenantFifteen)

- (NSArray *)reloadedItemIdentifiers
{
    return [self revenant_reloadedItems];
}

- (NSArray *)reloadedSectionIdentifiers
{
    return [self revenant_reloadedSections];
}

@end

@implementation UICollectionViewDiffableDataSource (RevenantFifteen)

- (void)applySnapshotUsingReloadData:(NSDiffableDataSourceSnapshot *)snapshot
{
    [self revenant_applyReloadingData:snapshot completion:nil];
}

- (void)applySnapshotUsingReloadData:(NSDiffableDataSourceSnapshot *)snapshot completion:(void (^)(void))completion
{
    [self revenant_applyReloadingData:snapshot completion:completion];
}

- (id)sectionIdentifierForIndex:(NSInteger)index
{
    return revenant_section_at([self revenant_current], index);
}

- (NSInteger)indexForSectionIdentifier:(id)identifier
{
    return [[self revenant_current] indexOfSectionIdentifier:identifier];
}

@end

@implementation UITableViewDiffableDataSource (RevenantFifteen)

- (void)applySnapshotUsingReloadData:(NSDiffableDataSourceSnapshot *)snapshot
{
    [self revenant_applyReloadingData:snapshot completion:nil];
}

- (void)applySnapshotUsingReloadData:(NSDiffableDataSourceSnapshot *)snapshot completion:(void (^)(void))completion
{
    [self revenant_applyReloadingData:snapshot completion:completion];
}

- (id)sectionIdentifierForIndex:(NSInteger)index
{
    return revenant_section_at([self revenant_current], index);
}

- (NSInteger)indexForSectionIdentifier:(id)identifier
{
    return [[self revenant_current] indexOfSectionIdentifier:identifier];
}

@end
