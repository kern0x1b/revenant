#import <UIKit/UIKit.h>

@implementation UICollectionViewLayout (CharonTransition7)

- (CGPoint)targetContentOffsetForProposedContentOffset:(CGPoint)proposedContentOffset
{
    return proposedContentOffset;
}

- (void)prepareForTransitionToLayout:(UICollectionViewLayout *)newLayout
{
}

- (void)prepareForTransitionFromLayout:(UICollectionViewLayout *)oldLayout
{
}

- (void)finalizeLayoutTransition
{
}

- (NSArray<NSIndexPath *> *)indexPathsToDeleteForSupplementaryViewOfKind:(NSString *)elementKind
{
    return @[];
}

- (NSArray<NSIndexPath *> *)indexPathsToInsertForSupplementaryViewOfKind:(NSString *)elementKind
{
    return @[];
}

- (NSArray<NSIndexPath *> *)indexPathsToDeleteForDecorationViewOfKind:(NSString *)elementKind
{
    return @[];
}

- (NSArray<NSIndexPath *> *)indexPathsToInsertForDecorationViewOfKind:(NSString *)elementKind
{
    return @[];
}

@end
