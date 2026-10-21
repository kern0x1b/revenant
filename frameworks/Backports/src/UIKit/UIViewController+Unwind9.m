#import <UIKit/UIKit.h>

#pragma clang diagnostic ignored "-Wdeprecated-declarations"
#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

@implementation UIViewController (RevenantUnwind9)

- (UIViewController *)childViewControllerContainingSegueSource:(UIStoryboardUnwindSegueSource *)source
{
    UIViewController *current = source.sourceViewController;
    for (NSUInteger depth = 0; current && depth < 64; depth++) {
        if (current.parentViewController == self || current.presentingViewController == self)
            return current;
        current = current.parentViewController ?: current.presentingViewController;
    }
    return nil;
}

- (NSArray<UIViewController *> *)allowedChildViewControllersForUnwindingFromSource:(UIStoryboardUnwindSegueSource *)source
{
    UIViewController *containing = [self childViewControllerContainingSegueSource:source];
    NSMutableArray *allowed = [self.childViewControllers mutableCopy];
    if (containing)
        [allowed removeObjectIdenticalTo:containing];
    return allowed;
}

- (void)unwindForSegue:(UIStoryboardSegue *)unwindSegue towardsViewController:(UIViewController *)subsequentVC
{
}

@end

@implementation UINavigationController (RevenantUnwind9)

- (void)unwindForSegue:(UIStoryboardSegue *)unwindSegue towardsViewController:(UIViewController *)subsequentVC
{
    if ([self.viewControllers containsObject:subsequentVC])
        [self popToViewController:subsequentVC animated:NO];
}

@end

@implementation UITabBarController (RevenantUnwind9)

- (void)unwindForSegue:(UIStoryboardSegue *)unwindSegue towardsViewController:(UIViewController *)subsequentVC
{
    if ([self.viewControllers containsObject:subsequentVC])
        self.selectedViewController = subsequentVC;
}

@end
