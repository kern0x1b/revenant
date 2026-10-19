#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static BOOL charon_overrides(UIViewController *controller, SEL action)
{
    Method own = class_getInstanceMethod([controller class], action);
    Method base = class_getInstanceMethod([UIViewController class], action);
    return own && (!base || method_getImplementation(own) != method_getImplementation(base));
}

@implementation UIViewController (CharonShow)

- (UIViewController *)targetViewControllerForAction:(SEL)action sender:(id)sender
{
    BOOL baseHas = class_getInstanceMethod([UIViewController class], action) != NULL;
    for (UIViewController *controller = self; controller; controller = controller.parentViewController) {
        if ([controller canPerformAction:action withSender:sender] && (!baseHas || charon_overrides(controller, action)))
            return controller;
    }
    return nil;
}

- (void)showViewController:(UIViewController *)controller sender:(id)sender
{
    UIViewController *target = [self targetViewControllerForAction:@selector(showViewController:sender:) sender:sender];
    if (target && target != self)
        [target showViewController:controller sender:sender];
    else
        [self presentViewController:controller animated:YES completion:nil];
}

- (void)showDetailViewController:(UIViewController *)controller sender:(id)sender
{
    UIViewController *target = [self targetViewControllerForAction:@selector(showDetailViewController:sender:) sender:sender];
    if (target && target != self)
        [target showDetailViewController:controller sender:sender];
    else
        [self presentViewController:controller animated:YES completion:nil];
}

@end

@implementation UINavigationController (CharonShow)

- (void)showViewController:(UIViewController *)controller sender:(id)sender
{
    [self pushViewController:controller animated:YES];
}

@end
