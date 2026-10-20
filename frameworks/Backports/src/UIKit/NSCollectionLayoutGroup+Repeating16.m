#import "RevenantCompositionalLayout.h"

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

@implementation NSCollectionLayoutGroup (RevenantRepeating16)

+ (instancetype)revenant_groupWithLayoutSize:(NSCollectionLayoutSize *)layoutSize direction:(RevenantGroupDirection)direction repeatingSubitem:(NSCollectionLayoutItem *)subitem count:(NSInteger)count
{
    if (!layoutSize)
        [NSException raise:NSInternalInconsistencyException format:@"A size is required."];
    if (count < 1)
        [NSException raise:NSInternalInconsistencyException format:@"A repeating %@ group should specify a count >= 1", direction == RevenantGroupDirectionHorizontal ? @"horizontal" : @"vertical"];
    return [[self alloc] initRevenantWithSize:layoutSize direction:direction subitems:@[[subitem copy]] count:count provider:nil];
}

+ (instancetype)horizontalGroupWithLayoutSize:(NSCollectionLayoutSize *)layoutSize repeatingSubitem:(NSCollectionLayoutItem *)subitem count:(NSInteger)count
{
    return [self revenant_groupWithLayoutSize:layoutSize direction:RevenantGroupDirectionHorizontal repeatingSubitem:subitem count:count];
}

+ (instancetype)verticalGroupWithLayoutSize:(NSCollectionLayoutSize *)layoutSize repeatingSubitem:(NSCollectionLayoutItem *)subitem count:(NSInteger)count
{
    return [self revenant_groupWithLayoutSize:layoutSize direction:RevenantGroupDirectionVertical repeatingSubitem:subitem count:count];
}

@end
