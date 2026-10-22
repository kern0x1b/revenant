#import "RevenantRefreshHost.h"
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
    if (controller) {
        [RevenantRefreshHost setControl:nil forScrollView:self];
        controller.refreshControl = refreshControl;
    } else {
        [RevenantRefreshHost setControl:refreshControl forScrollView:self];
    }
}

@end
