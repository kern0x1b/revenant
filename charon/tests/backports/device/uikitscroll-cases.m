#import <UIKit/UIKit.h>
#import "uikitscroll-cases.h"

@protocol UiKitScrollNavDelegateQuestions <UINavigationControllerDelegate>
- (UIInterfaceOrientation)navigationControllerPreferredInterfaceOrientationForPresentation:(UINavigationController *)navigationController;
- (UIInterfaceOrientationMask)navigationControllerSupportedInterfaceOrientations:(UINavigationController *)navigationController;
@end

void uikitscroll_run(UiKitScrollRecorder record)
{
    UINavigationController *navigation = [[UINavigationController alloc] init];
    record(@"nav.hidesBarsOnSwipeDefault", navigation.hidesBarsOnSwipe ? @"yes" : @"no");
    record(@"nav.hidesBarsOnTapDefault", navigation.hidesBarsOnTap ? @"yes" : @"no");
    record(@"nav.hidesBarsWhenKeyboardAppearsDefault", navigation.hidesBarsWhenKeyboardAppears ? @"yes" : @"no");
    record(@"nav.hidesBarsWhenVerticallyCompactDefault", navigation.hidesBarsWhenVerticallyCompact ? @"yes" : @"no");

    UIGestureRecognizer *hiding = navigation.barHideOnSwipeGestureRecognizer;
    UIGestureRecognizer *popping = navigation.interactivePopGestureRecognizer;
    record(@"nav.swipeIsThePopGesture", (hiding && popping && hiding == popping) ? @"same" : @"different");
    record(@"nav.swipeGestureKind.diverges", hiding ? NSStringFromClass([hiding class]) : @"nil");
    record(@"nav.tapGestureKind.diverges", navigation.barHideOnTapGestureRecognizer ? NSStringFromClass([navigation.barHideOnTapGestureRecognizer class]) : @"nil");
    record(@"nav.swipeGestureEnabled", hiding ? (hiding.enabled ? @"yes" : @"no") : @"nil");

    navigation.hidesBarsOnSwipe = YES;
    record(@"nav.hidesBarsOnSwipeAfterSet", navigation.hidesBarsOnSwipe ? @"yes" : @"no");
    record(@"nav.swipeRecogniserIsStable", navigation.barHideOnSwipeGestureRecognizer == hiding ? @"same" : @"different");
    navigation.hidesBarsOnTap = YES;
    record(@"nav.hidesBarsOnTapAfterSet", navigation.hidesBarsOnTap ? @"yes" : @"no");
    navigation.hidesBarsOnSwipe = NO;
    record(@"nav.hidesBarsOnSwipeAfterClear", navigation.hidesBarsOnSwipe ? @"yes" : @"no");

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

    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    record(@"cell.separatorInsetDefault", NSStringFromUIEdgeInsets(cell.separatorInset));
    cell.separatorInset = UIEdgeInsetsMake(5, 6, 7, 8);
    record(@"cell.separatorInsetAfterSet", NSStringFromUIEdgeInsets(cell.separatorInset));

    NSIndexPath *first = [NSIndexPath indexPathForItem:0 inSection:0];
    UICollectionViewLayoutAttributes *attributes = [UICollectionViewLayoutAttributes layoutAttributesForCellWithIndexPath:first];
    record(@"attributes.boundsEqualsFrame", CGRectEqualToRect(attributes.bounds, attributes.frame) ? @"same" : @"different");
    attributes.frame = CGRectMake(5, 6, 7, 8);
    record(@"attributes.boundsAfterFrameSet", NSStringFromCGRect(attributes.bounds));
    record(@"attributes.frameAfterFrameSet", NSStringFromCGRect(attributes.frame));

    UICollectionViewFlowLayout *flow = [[UICollectionViewFlowLayout alloc] init];
    record(@"flow.sectionHeadersPinToVisibleBoundsDefault", flow.sectionHeadersPinToVisibleBounds ? @"yes" : @"no");
    record(@"flow.sectionFootersPinToVisibleBoundsDefault", flow.sectionFootersPinToVisibleBounds ? @"yes" : @"no");
    flow.sectionHeadersPinToVisibleBounds = YES;
    record(@"flow.headersPinAfterSet", flow.sectionHeadersPinToVisibleBounds ? @"yes" : @"no");

    UICollectionViewController *controller = [[UICollectionViewController alloc] initWithCollectionViewLayout:flow];
    record(@"collectionController.hasLayout", controller.collectionViewLayout ? @"set" : @"nil");
    record(@"collectionController.layoutIsTheOneGiven", controller.collectionViewLayout == flow ? @"same" : @"different");
    record(@"collectionController.useLayoutToLayoutNavigationTransitionsDefault",
           controller.useLayoutToLayoutNavigationTransitions ? @"yes" : @"no");
    record(@"collectionController.installsStandardGestureForInteractiveMovementDefault",
           controller.installsStandardGestureForInteractiveMovement ? @"yes" : @"no");

    record(@"table.separatorStyleDefault", [NSString stringWithFormat:@"%ld", (long)table.separatorStyle]);
    record(@"table.separatorColorDefault", table.separatorColor ? @"set" : @"nil");
    record(@"screen.scale", [NSString stringWithFormat:@"%g", [UIScreen mainScreen].scale]);
    record(@"table.layoutMargins", NSStringFromUIEdgeInsets(table.layoutMargins));

    id<UiKitScrollNavDelegateQuestions> questions = (id<UiKitScrollNavDelegateQuestions>)navigation.delegate;
    record(@"nav.delegatePreferredOrientationDefault", [questions navigationControllerPreferredInterfaceOrientationForPresentation:navigation] == UIInterfaceOrientationPortrait ? @"portrait" : @"other");
    record(@"nav.delegateSupportedOrientationsDefault", [questions navigationControllerSupportedInterfaceOrientations:navigation] == UIInterfaceOrientationMaskAll ? @"all" : @"other");
}
