#import "CharonDiffable.h"

@implementation NSDiffableDataSourceSectionTransaction {
@private
    id _sectionIdentifier;
    NSDiffableDataSourceSectionSnapshot *_initialSnapshot;
    NSDiffableDataSourceSectionSnapshot *_finalSnapshot;
    NSOrderedCollectionDifference *_difference;
}

- (instancetype)initCharonWithSection:(id)section initial:(NSArray *)initial final:(NSArray *)final
{
    if ((self = [super init])) {
        _sectionIdentifier = section;
        _initialSnapshot = [[NSDiffableDataSourceSectionSnapshot alloc] init];
        [_initialSnapshot appendItems:initial];
        _finalSnapshot = [[NSDiffableDataSourceSectionSnapshot alloc] init];
        [_finalSnapshot appendItems:final];
        _difference = [final differenceFromArray:initial withOptions:NSOrderedCollectionDifferenceCalculationInferMoves];
    }
    return self;
}

- (id)sectionIdentifier
{
    return _sectionIdentifier;
}

- (NSDiffableDataSourceSectionSnapshot *)initialSnapshot
{
    return _initialSnapshot;
}

- (NSDiffableDataSourceSectionSnapshot *)finalSnapshot
{
    return _finalSnapshot;
}

- (NSOrderedCollectionDifference *)difference
{
    return _difference;
}

@end

@implementation NSDiffableDataSourceTransaction {
@private
    NSDiffableDataSourceSnapshot *_initialSnapshot;
    NSDiffableDataSourceSnapshot *_finalSnapshot;
    NSOrderedCollectionDifference *_difference;
    NSArray *_sectionTransactions;
}

- (instancetype)initCharonWithInitial:(NSDiffableDataSourceSnapshot *)initial final:(NSDiffableDataSourceSnapshot *)final
{
    if ((self = [super init])) {
        _initialSnapshot = [initial copy];
        _finalSnapshot = [final copy];
        _difference = [final.itemIdentifiers differenceFromArray:initial.itemIdentifiers withOptions:NSOrderedCollectionDifferenceCalculationInferMoves];
        NSMutableArray *changed = [NSMutableArray array];
        for (id section in final.sectionIdentifiers) {
            NSArray *before = [initial indexOfSectionIdentifier:section] == NSNotFound ? @[] : [initial itemIdentifiersInSectionWithIdentifier:section];
            NSArray *after = [final itemIdentifiersInSectionWithIdentifier:section];
            if (![before isEqual:after])
                [changed addObject:[[NSDiffableDataSourceSectionTransaction alloc] initCharonWithSection:section initial:before final:after]];
        }
        _sectionTransactions = [[changed reverseObjectEnumerator] allObjects];
    }
    return self;
}

- (NSDiffableDataSourceSnapshot *)initialSnapshot
{
    return _initialSnapshot;
}

- (NSDiffableDataSourceSnapshot *)finalSnapshot
{
    return _finalSnapshot;
}

- (NSOrderedCollectionDifference *)difference
{
    return _difference;
}

- (NSArray *)sectionTransactions
{
    return _sectionTransactions;
}

@end
