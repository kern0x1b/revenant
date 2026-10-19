#import <UIKit/UIKit.h>
#import "uikitscroll-cases.h"

// The two orientation questions are optional on the delegate, so their signatures are declared here
// to be called without a warning about a method the protocol does not promise.
@protocol UiKitScrollNavDelegateQuestions <UINavigationControllerDelegate>
- (UIInterfaceOrientation)navigationControllerPreferredInterfaceOrientationForPresentation:(UINavigationController *)navigationController;
- (UIInterfaceOrientationMask)navigationControllerSupportedInterfaceOrientations:(UINavigationController *)navigationController;
@end

// What the system answers for the navigation bar hiding on a gesture and for a table view's
// separators, so the backport's defaults are measured rather than assumed. The host records these and
// the device is held to them.
void uikitscroll_run(UiKitScrollRecorder record)
{
    UINavigationController *navigation = [[UINavigationController alloc] init];
    // The defaults matter more than anything else here: an application that never sets these must
    // get the system's own answer, and a guess would be a quiet wrong answer on every navigation
    // stack in the port.
    record(@"nav.hidesBarsOnSwipeDefault", navigation.hidesBarsOnSwipe ? @"yes" : @"no");
    record(@"nav.hidesBarsOnTapDefault", navigation.hidesBarsOnTap ? @"yes" : @"no");
    record(@"nav.hidesBarsWhenKeyboardAppearsDefault", navigation.hidesBarsWhenKeyboardAppears ? @"yes" : @"no");
    record(@"nav.hidesBarsWhenVerticallyCompactDefault", navigation.hidesBarsWhenVerticallyCompact ? @"yes" : @"no");

    // Whether the bar-hiding swipe is the same gesture as the one that pops, which is what decides
    // whether the port reuses the gesture it already has or installs a second one.
    UIGestureRecognizer *hiding = navigation.barHideOnSwipeGestureRecognizer;
    UIGestureRecognizer *popping = navigation.interactivePopGestureRecognizer;
    record(@"nav.swipeIsThePopGesture", (hiding && popping && hiding == popping) ? @"same" : @"different");
    // The two gesture kinds are the one place this family answers differently from the host, and
    // deliberately: the host's are private classes (_UIBarPanGestureRecognizer and
    // _UIBarTapGestureRecognizer) that this port may not name, so it uses the public
    // UIScreenEdgePanGestureRecognizer and UITapGestureRecognizer and behaves the same. These two
    // cases assert the port's own kind, so the case fails if the host ever stops diverging or the
    // port ever starts naming a private class.
    record(@"nav.swipeGestureKind.diverges", hiding ? NSStringFromClass([hiding class]) : @"nil");
    record(@"nav.tapGestureKind.diverges", navigation.barHideOnTapGestureRecognizer ? NSStringFromClass([navigation.barHideOnTapGestureRecognizer class]) : @"nil");
    record(@"nav.swipeGestureEnabled", hiding ? (hiding.enabled ? @"yes" : @"no") : @"nil");

    // Setting the flags is remembered, and asking twice gives the same recogniser rather than a new
    // one, because there is one gesture and not one per question.
    navigation.hidesBarsOnSwipe = YES;
    record(@"nav.hidesBarsOnSwipeAfterSet", navigation.hidesBarsOnSwipe ? @"yes" : @"no");
    record(@"nav.swipeRecogniserIsStable", navigation.barHideOnSwipeGestureRecognizer == hiding ? @"same" : @"different");
    navigation.hidesBarsOnTap = YES;
    record(@"nav.hidesBarsOnTapAfterSet", navigation.hidesBarsOnTap ? @"yes" : @"no");
    navigation.hidesBarsOnSwipe = NO;
    record(@"nav.hidesBarsOnSwipeAfterClear", navigation.hidesBarsOnSwipe ? @"yes" : @"no");

    // A table view's separators: the insets and the colours, as the system leaves them.
    UITableView *table = [[UITableView alloc] initWithFrame:CGRectMake(0, 0, 320, 480) style:UITableViewStylePlain];
    record(@"table.separatorInset", NSStringFromUIEdgeInsets(table.separatorInset));
    record(@"table.sectionIndexBackgroundColor", table.sectionIndexBackgroundColor ? @"set" : @"nil");
    record(@"table.separatorEffect", table.separatorEffect ? @"set" : @"nil");
    record(@"table.cellLayoutMarginsFollowReadableWidth", table.cellLayoutMarginsFollowReadableWidth ? @"yes" : @"no");
    record(@"table.remembersLastFocusedIndexPath", table.remembersLastFocusedIndexPath ? @"yes" : @"no");

    table.separatorInset = UIEdgeInsetsMake(1, 2, 3, 4);
    record(@"table.separatorInsetAfterSet", NSStringFromUIEdgeInsets(table.separatorInset));
    table.sectionIndexBackgroundColor = [UIColor redColor];
    record(@"table.sectionIndexColorAfterSet", table.sectionIndexBackgroundColor ? @"set" : @"nil");
    table.cellLayoutMarginsFollowReadableWidth = YES;
    record(@"table.followsReadableAfterSet", table.cellLayoutMarginsFollowReadableWidth ? @"yes" : @"no");

    // A cell's own separator inset, which is the per-cell override of the table's.
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    // A cell's own separator inset is a UIEdgeInsets, a value and not an object, so what is recorded
    // is the value: a fresh cell's own inset is the zero inset until a table gives it one.
    record(@"cell.separatorInsetDefault", NSStringFromUIEdgeInsets(cell.separatorInset));
    cell.separatorInset = UIEdgeInsetsMake(5, 6, 7, 8);
    record(@"cell.separatorInsetAfterSet", NSStringFromUIEdgeInsets(cell.separatorInset));

    // The layout attributes a collection view draws an element in: bounds beside frame, since a
    // transform moves one and not the other.
    NSIndexPath *first = [NSIndexPath indexPathForItem:0 inSection:0];
    UICollectionViewLayoutAttributes *attributes = [UICollectionViewLayoutAttributes layoutAttributesForCellWithIndexPath:first];
    record(@"attributes.boundsEqualsFrame", CGRectEqualToRect(attributes.bounds, attributes.frame) ? @"same" : @"different");
    attributes.frame = CGRectMake(5, 6, 7, 8);
    record(@"attributes.boundsAfterFrameSet", NSStringFromCGRect(attributes.bounds));
    record(@"attributes.frameAfterFrameSet", NSStringFromCGRect(attributes.frame));

    // A flow layout's pinning of its headers and footers to the visible bounds.
    UICollectionViewFlowLayout *flow = [[UICollectionViewFlowLayout alloc] init];
    record(@"flow.sectionHeadersPinToVisibleBoundsDefault", flow.sectionHeadersPinToVisibleBounds ? @"yes" : @"no");
    record(@"flow.sectionFootersPinToVisibleBoundsDefault", flow.sectionFootersPinToVisibleBounds ? @"yes" : @"no");
    flow.sectionHeadersPinToVisibleBounds = YES;
    record(@"flow.headersPinAfterSet", flow.sectionHeadersPinToVisibleBounds ? @"yes" : @"no");

    // A collection view controller's layout, and whether it lays its transitions out with the layout
    // or with the navigation controller's own animation.
    UICollectionViewController *controller = [[UICollectionViewController alloc] initWithCollectionViewLayout:flow];
    record(@"collectionController.hasLayout", controller.collectionViewLayout ? @"set" : @"nil");
    record(@"collectionController.layoutIsTheOneGiven", controller.collectionViewLayout == flow ? @"same" : @"different");
    record(@"collectionController.useLayoutToLayoutNavigationTransitionsDefault",
           controller.useLayoutToLayoutNavigationTransitions ? @"yes" : @"no");
    record(@"collectionController.installsStandardGestureForInteractiveMovementDefault",
           controller.installsStandardGestureForInteractiveMovement ? @"yes" : @"no");

    // The geometry the port needs before it can draw a separator itself: the style and colour the
    // release would have used, the scale a hairline is measured in, and the readable width the flag
    // is about. Every default is recorded rather than assumed.
    record(@"table.separatorStyleDefault", [NSString stringWithFormat:@"%ld", (long)table.separatorStyle]);
    record(@"table.separatorColorDefault", table.separatorColor ? @"set" : @"nil");
    record(@"screen.scale", [NSString stringWithFormat:@"%g", [UIScreen mainScreen].scale]);
    record(@"table.layoutMargins", NSStringFromUIEdgeInsets(table.layoutMargins));

    // A navigation controller's delegate questions, which are the release's to answer and the
    // delegate's to override.
    id<UiKitScrollNavDelegateQuestions> questions = (id<UiKitScrollNavDelegateQuestions>)navigation.delegate;
    record(@"nav.delegatePreferredOrientationDefault", [questions navigationControllerPreferredInterfaceOrientationForPresentation:navigation] == UIInterfaceOrientationPortrait ? @"portrait" : @"other");
    record(@"nav.delegateSupportedOrientationsDefault", [questions navigationControllerSupportedInterfaceOrientations:navigation] == UIInterfaceOrientationMaskAll ? @"all" : @"other");
}
