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
}
@end

RevenantSplitState *revenant_split_state(UISplitViewController *split);
BOOL revenant_split_collapsed(UISplitViewController *split);
BOOL revenant_split_on_phone(void);
UISplitViewControllerDisplayMode revenant_split_resolve(UISplitViewController *split);
