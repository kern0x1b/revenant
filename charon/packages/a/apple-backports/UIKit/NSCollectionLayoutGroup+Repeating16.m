#import "CharonCompositionalLayout.h"

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

@implementation NSCollectionLayoutGroup (CharonRepeating16)

// Count copies of the subitem at its own size: unlike the deprecated subitem:count:,
// the subitem is not resized to a share of the group, and fitting is the caller's.
+ (instancetype)charon_groupWithLayoutSize:(NSCollectionLayoutSize *)layoutSize direction:(CharonGroupDirection)direction repeatingSubitem:(NSCollectionLayoutItem *)subitem count:(NSInteger)count
{
    if (!layoutSize)
        [NSException raise:NSInternalInconsistencyException format:@"A size is required."];
    if (count < 1)
        [NSException raise:NSInternalInconsistencyException format:@"A repeating %@ group should specify a count >= 1", direction == CharonGroupDirectionHorizontal ? @"horizontal" : @"vertical"];
    return [[self alloc] initCharonWithSize:layoutSize direction:direction subitems:@[[subitem copy]] count:count provider:nil];
}

+ (instancetype)horizontalGroupWithLayoutSize:(NSCollectionLayoutSize *)layoutSize repeatingSubitem:(NSCollectionLayoutItem *)subitem count:(NSInteger)count
{
    return [self charon_groupWithLayoutSize:layoutSize direction:CharonGroupDirectionHorizontal repeatingSubitem:subitem count:count];
}

+ (instancetype)verticalGroupWithLayoutSize:(NSCollectionLayoutSize *)layoutSize repeatingSubitem:(NSCollectionLayoutItem *)subitem count:(NSInteger)count
{
    return [self charon_groupWithLayoutSize:layoutSize direction:CharonGroupDirectionVertical repeatingSubitem:subitem count:count];
}

@end
