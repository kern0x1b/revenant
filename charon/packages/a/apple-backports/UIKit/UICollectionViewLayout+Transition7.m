#import <UIKit/UIKit.h>

// The layout hooks a collection view drives while it transitions between two layouts, and the one
// it asks where the content should come to rest. The base class carries all of them and answers
// the way Apple's own base class answers, measured under Mac Catalyst (macOS 27.0) with
// tests/backports/host/collectiontransition against this file: the content offset asked for is the
// content offset given, the two prepare messages and the finalize message are the subclass's to
// answer and do nothing here, and the four element questions name no element until a layout that
// draws those elements answers them. A layout that draws headers, footers or decoration views
// overrides the four and is what a transition then moves.
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
