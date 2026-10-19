#import "CharonDiffable.h"

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

static id charon_section_at(NSDiffableDataSourceSnapshot *snapshot, NSInteger index)
{
    NSArray *sections = [snapshot charon_sections];
    return index >= 0 && (NSUInteger)index < sections.count ? sections[(NSUInteger)index] : nil;
}

@implementation NSDiffableDataSourceSnapshot (CharonFifteen)

- (NSArray *)reloadedItemIdentifiers
{
    return [self charon_reloadedItems];
}

- (NSArray *)reloadedSectionIdentifiers
{
    return [self charon_reloadedSections];
}

@end

@implementation UICollectionViewDiffableDataSource (CharonFifteen)

- (void)applySnapshotUsingReloadData:(NSDiffableDataSourceSnapshot *)snapshot
{
    [self charon_applyReloadingData:snapshot completion:nil];
}

- (void)applySnapshotUsingReloadData:(NSDiffableDataSourceSnapshot *)snapshot completion:(void (^)(void))completion
{
    [self charon_applyReloadingData:snapshot completion:completion];
}

- (id)sectionIdentifierForIndex:(NSInteger)index
{
    return charon_section_at([self charon_current], index);
}

- (NSInteger)indexForSectionIdentifier:(id)identifier
{
    return [[self charon_current] indexOfSectionIdentifier:identifier];
}

@end

@implementation UITableViewDiffableDataSource (CharonFifteen)

- (void)applySnapshotUsingReloadData:(NSDiffableDataSourceSnapshot *)snapshot
{
    [self charon_applyReloadingData:snapshot completion:nil];
}

- (void)applySnapshotUsingReloadData:(NSDiffableDataSourceSnapshot *)snapshot completion:(void (^)(void))completion
{
    [self charon_applyReloadingData:snapshot completion:completion];
}

- (id)sectionIdentifierForIndex:(NSInteger)index
{
    return charon_section_at([self charon_current], index);
}

- (NSInteger)indexForSectionIdentifier:(id)identifier
{
    return [[self charon_current] indexOfSectionIdentifier:identifier];
}

@end
