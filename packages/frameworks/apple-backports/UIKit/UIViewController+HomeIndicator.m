#import <UIKit/UIKit.h>

@implementation UIViewController (RevenantHomeIndicator)

- (BOOL)prefersHomeIndicatorAutoHidden
{
    return NO;
}

- (UIViewController *)childViewControllerForHomeIndicatorAutoHidden
{
    return nil;
}

- (void)setNeedsUpdateOfHomeIndicatorAutoHidden
{
    UIViewController *parent = self.parentViewController ?: self.presentingViewController;
    [parent setNeedsUpdateOfHomeIndicatorAutoHidden];
}

- (UIRectEdge)preferredScreenEdgesDeferringSystemGestures
{
    return UIRectEdgeNone;
}

- (UIViewController *)childViewControllerForScreenEdgesDeferringSystemGestures
{
    return nil;
}

- (void)setNeedsUpdateOfScreenEdgesDeferringSystemGestures
{
    UIViewController *parent = self.parentViewController ?: self.presentingViewController;
    [parent setNeedsUpdateOfScreenEdgesDeferringSystemGestures];
}

@end

@implementation UINavigationController (RevenantHomeIndicator)

- (UIViewController *)childViewControllerForHomeIndicatorAutoHidden
{
    return self.topViewController;
}

- (UIViewController *)childViewControllerForScreenEdgesDeferringSystemGestures
{
    return self.topViewController;
}

@end

@implementation UITabBarController (RevenantHomeIndicator)

- (UIViewController *)childViewControllerForHomeIndicatorAutoHidden
{
    return self.selectedViewController;
}

- (UIViewController *)childViewControllerForScreenEdgesDeferringSystemGestures
{
    return self.selectedViewController;
}

@end
