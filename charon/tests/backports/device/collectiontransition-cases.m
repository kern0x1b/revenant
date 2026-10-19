#import <UIKit/UIKit.h>
#import "collectiontransition-cases.h"

// The layout transition hooks, as the system's own UIKit answers them with no collection view and
// no window, so the host records them and the backport is held to the same answers. The driven
// transition needs a live collection view in a window and is checked on the device instead, in
// collectiontransition.m.
@interface TransitionPlain : UICollectionViewLayout
@end

@implementation TransitionPlain
@end

void collectiontransition_run(CollectionTransitionRecorder record)
{
    // The content offset a layout comes to rest at: the one it was given, unless the layout wants
    // another, and the base layout does not.
    TransitionPlain *plain = [[TransitionPlain alloc] init];
    record(@"targetContentOffset", NSStringFromCGPoint([plain targetContentOffsetForProposedContentOffset:CGPointMake(11, 22)]));
    record(@"targetContentOffsetZero", NSStringFromCGPoint([plain targetContentOffsetForProposedContentOffset:CGPointZero]));

    // The two prepare messages and the finalize message are the subclass's to answer; on the base
    // layout they are asked for and change nothing, which is what a layout that has not overridden
    // them must be seen to do.
    CGSize before = plain.collectionViewContentSize;
    [plain prepareForTransitionToLayout:[[TransitionPlain alloc] init]];
    [plain prepareForTransitionFromLayout:[[TransitionPlain alloc] init]];
    [plain finalizeLayoutTransition];
    record(@"prepareAndFinalizeLeaveContentSize",
           NSStringFromCGSize(before) == NSStringFromCGSize(plain.collectionViewContentSize) ? @"same" : @"changed");

    // Which elements a transition takes away and which it adds, for each kind a layout can draw
    // besides a cell. The base layout draws none, so it names none.
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

    // The transition layout holds the two layouts it is between, and the progress starts at the
    // beginning and is held inside the transition however far it is set.
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

    // The animated keys are the collection view's own bookkeeping while a transition runs, and
    // outside one they keep nothing: an update moves nothing and every key answers 0. The same case
    // is in tests/backports/device/presses-cases.m, and both are held to the same host.
    transition.transitionProgress = 0.5;
    [transition updateValue:0.7 forAnimatedKey:@"a"];
    record(@"transition.animatedKeyAfterUpdate", NSStringFromCGPoint(CGPointMake([transition valueForAnimatedKey:@"a"], 0)));
    record(@"transition.animatedKeyOther", NSStringFromCGPoint(CGPointMake([transition valueForAnimatedKey:@"b"], 0)));
    record(@"transition.progressAfterAnimatedKeyUpdate", NSStringFromCGPoint(CGPointMake(transition.transitionProgress, 0)));
}
