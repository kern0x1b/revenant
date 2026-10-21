#import <UIKit/UIKit.h>

@interface RevenantSplitState : NSObject {
@public
    UISplitViewControllerDisplayMode preferred;
    NSInteger notified;
    CGFloat fraction;
    CGFloat minimum;
    CGFloat maximum;
    __weak id appDelegate;
    __weak UIPopoverController *popover;
    UIBarButtonItem *button;
    UIBarButtonItem *nativeButton;
    id proxy;
    BOOL proxyInstalled;
    UIViewController *primary;
    UIViewController *secondary;
    BOOL showing;
    CGFloat preferredWidth;
    UISplitViewControllerStyle style;
    UISplitViewControllerSplitBehavior behavior;
    UISplitViewControllerDisplayModeButtonVisibility visibility;
    UIViewController *columnPrimary;
    UIViewController *columnSecondary;
    UIViewController *compact;
    BOOL showsSecondaryOnlyButton;
    CGFloat supplementaryFraction;
    CGFloat supplementaryWidth;
    CGFloat supplementaryMinimum;
    CGFloat supplementaryMaximum;
}
@end

RevenantSplitState *revenant_split_state(UISplitViewController *split);
BOOL revenant_split_collapsed(UISplitViewController *split);
BOOL revenant_split_on_phone(void);
void revenant_split_apply_width(UISplitViewController *split);
UISplitViewControllerDisplayMode revenant_split_resolve(UISplitViewController *split);
NSArray<UIViewController *> *revenant_split_collapsed_content(UIViewController *primary);
void revenant_split_collapse_again(UISplitViewController *split);
