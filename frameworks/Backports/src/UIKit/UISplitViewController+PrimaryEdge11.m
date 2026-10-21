#import "RevenantMenus.h"
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

static const char RevenantPrimaryEdgeKey;

@implementation UISplitViewController (RevenantPrimaryEdge11)

- (UISplitViewControllerPrimaryEdge)primaryEdge
{
    return (UISplitViewControllerPrimaryEdge)[objc_getAssociatedObject(self, &RevenantPrimaryEdgeKey) integerValue];
}

- (void)setPrimaryEdge:(UISplitViewControllerPrimaryEdge)primaryEdge
{
    if (primaryEdge != UISplitViewControllerPrimaryEdgeLeading)
        revenant_menus_say_once(@"split-primary-edge", @"UISplitViewController.primaryEdge: the iOS 6 split view controller always lays its primary column out on the leading side, so the edge is kept and read back and the columns are laid out as before");
    objc_setAssociatedObject(self, &RevenantPrimaryEdgeKey, @(primaryEdge), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
