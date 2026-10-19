#import <UIKit/UIKit.h>
#import "collectiontransition-cases.h"

@interface TransitionPlain : UICollectionViewLayout
@end

@implementation TransitionPlain
@end

void collectiontransition_run(CollectionTransitionRecorder record)
{
    TransitionPlain *plain = [[TransitionPlain alloc] init];
    record(@"targetContentOffset", NSStringFromCGPoint([plain targetContentOffsetForProposedContentOffset:CGPointMake(11, 22)]));
    record(@"targetContentOffsetZero", NSStringFromCGPoint([plain targetContentOffsetForProposedContentOffset:CGPointZero]));

    CGSize before = plain.collectionViewContentSize;
    [plain prepareForTransitionToLayout:[[TransitionPlain alloc] init]];
    [plain prepareForTransitionFromLayout:[[TransitionPlain alloc] init]];
    [plain finalizeLayoutTransition];
    record(@"prepareAndFinalizeLeaveContentSize",
           NSStringFromCGSize(before) == NSStringFromCGSize(plain.collectionViewContentSize) ? @"same" : @"changed");

    NSArray *kinds = @[UICollectionElementKindSectionHeader, UICollectionElementKindSectionFooter, @"charon.decoration"];
    for (NSString *kind in kinds) {
        NSArray *deleteSupplementary = [plain indexPathsToDeleteForSupplementaryViewOfKind:kind];
        NSArray *insertSupplementary = [plain indexPathsToInsertForSupplementaryViewOfKind:kind];
        NSArray *deleteDecoration = [plain indexPathsToDeleteForDecorationViewOfKind:kind];
        NSArray *insertDecoration = [plain indexPathsToInsertForDecorationViewOfKind:kind];
        record([NSString stringWithFormat:@"%@.deleteSupplementary", kind],
               deleteSupplementary ? [NSString stringWithFormat:@"%lu", (unsigned long)deleteSupplementary.count] : @"nil");
        record([NSString stringWithFormat:@"%@.insertSupplementary", kind],
               insertSupplementary ? [NSString stringWithFormat:@"%lu", (unsigned long)insertSupplementary.count] : @"nil");
        record([NSString stringWithFormat:@"%@.deleteDecoration", kind],
               deleteDecoration ? [NSString stringWithFormat:@"%lu", (unsigned long)deleteDecoration.count] : @"nil");
        record([NSString stringWithFormat:@"%@.insertDecoration", kind],
               insertDecoration ? [NSString stringWithFormat:@"%lu", (unsigned long)insertDecoration.count] : @"nil");
    }

    TransitionPlain *from = [[TransitionPlain alloc] init];
    TransitionPlain *to = [[TransitionPlain alloc] init];
    UICollectionViewTransitionLayout *transition = [[UICollectionViewTransitionLayout alloc] initWithCurrentLayout:from
                                                                                                       nextLayout:to];
    record(@"transition.currentLayoutIsFrom", transition.currentLayout == from ? @"same" : @"other");
    record(@"transition.nextLayoutIsTo", transition.nextLayout == to ? @"same" : @"other");
    record(@"transition.progressAtStart", NSStringFromCGPoint(CGPointMake(transition.transitionProgress, 0)));
    transition.transitionProgress = 0.25;
    record(@"transition.progressSet", NSStringFromCGPoint(CGPointMake(transition.transitionProgress, 0)));
    transition.transitionProgress = 2;
    record(@"transition.progressAboveOne", NSStringFromCGPoint(CGPointMake(transition.transitionProgress, 0)));
    transition.transitionProgress = -1;
    record(@"transition.progressBelowZero", NSStringFromCGPoint(CGPointMake(transition.transitionProgress, 0)));
    transition.transitionProgress = 0.5;
    [transition finalizeLayoutTransition];
    record(@"transition.progressAfterFinalize", NSStringFromCGPoint(CGPointMake(transition.transitionProgress, 0)));

    transition.transitionProgress = 0.5;
    [transition updateValue:0.7 forAnimatedKey:@"a"];
    record(@"transition.animatedKeyAfterUpdate", NSStringFromCGPoint(CGPointMake([transition valueForAnimatedKey:@"a"], 0)));
    record(@"transition.animatedKeyOther", NSStringFromCGPoint(CGPointMake([transition valueForAnimatedKey:@"b"], 0)));
    record(@"transition.progressAfterAnimatedKeyUpdate", NSStringFromCGPoint(CGPointMake(transition.transitionProgress, 0)));
}
