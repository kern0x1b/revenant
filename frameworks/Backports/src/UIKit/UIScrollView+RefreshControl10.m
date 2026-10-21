#import "RevenantMenus.h"
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

static const char RevenantRefreshControlKey;

static UITableViewController *revenant_table_controller(UIScrollView *scrollView)
{
    for (UIResponder *responder = scrollView.nextResponder; responder; responder = responder.nextResponder) {
        if ([responder isKindOfClass:[UITableViewController class]] && ((UITableViewController *)responder).tableView == scrollView)
            return (UITableViewController *)responder;
    }
    return nil;
}

@implementation UIScrollView (RevenantRefreshControl10)

- (UIRefreshControl *)refreshControl
{
    return objc_getAssociatedObject(self, &RevenantRefreshControlKey);
}

- (void)setRefreshControl:(UIRefreshControl *)refreshControl
{
    objc_setAssociatedObject(self, &RevenantRefreshControlKey, refreshControl, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    UITableViewController *controller = revenant_table_controller(self);
    if (controller)
        controller.refreshControl = refreshControl;
    else if (refreshControl)
        revenant_menus_say_once(@"scroll-refresh", @"UIScrollView.refreshControl: the iOS 6 refresh control is driven by a UITableViewController, so a control on a scroll view that no table view controller owns is kept and read back and is not shown");
}

@end
