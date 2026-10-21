#import "RevenantSplit.h"
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

static const char RevenantCollapsedSecondaryKey;

static void revenant_phone_attach(UISplitViewController *split)
{
    UIViewController *shown = revenant_split_state(split)->primary;
    if (!shown || shown.parentViewController == split)
        return;
    [split addChildViewController:shown];
    shown.view.frame = split.view.bounds;
    shown.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [split.view addSubview:shown.view];
    [shown didMoveToParentViewController:split];
}

static void revenant_phone_detach(UISplitViewController *split)
{
    UIViewController *shown = revenant_split_state(split)->primary;
    if (!shown || shown.parentViewController != split)
        return;
    [shown willMoveToParentViewController:nil];
    [shown.view removeFromSuperview];
    [shown removeFromParentViewController];
}

static void revenant_phone_set(UISplitViewController *split, NSArray *controllers)
{
    RevenantSplitState *state = revenant_split_state(split);
    revenant_phone_detach(split);
    UIViewController *primary = controllers.firstObject;
    UIViewController *secondary = controllers.count > 1 ? controllers[1] : nil;
    id delegate = state->appDelegate;
    if (secondary) {
        if ([delegate respondsToSelector:@selector(primaryViewControllerForCollapsingSplitViewController:)])
            primary = [delegate primaryViewControllerForCollapsingSplitViewController:split] ?: primary;
        BOOL handled = [delegate respondsToSelector:@selector(splitViewController:collapseSecondaryViewController:ontoPrimaryViewController:)]
            && [delegate splitViewController:split collapseSecondaryViewController:secondary ontoPrimaryViewController:primary];
        if (!handled)
            [primary collapseSecondaryViewController:secondary forSplitViewController:split];
    }
    state->primary = primary;
    state->secondary = secondary;
    if (split.isViewLoaded)
        revenant_phone_attach(split);
}

static UIViewController *revenant_column_of(UISplitViewController *split, id sender)
{
    UIResponder *source = sender;
    while (source && ![source isKindOfClass:[UIViewController class]])
        source = source.nextResponder;
    NSArray *columns = split.viewControllers;
    for (UIViewController *controller = (UIViewController *)source; controller; controller = controller.parentViewController) {
        if ([columns containsObject:controller])
            return controller;
    }
    return columns.firstObject;
}

@interface RevenantSplitCollapseInstaller : NSObject
@end

@implementation RevenantSplitCollapseInstaller

+ (void)load
{
    if (!revenant_split_on_phone() || [UISplitViewController instancesRespondToSelector:@selector(isCollapsed)])
        return;
    Class split = [UISplitViewController class];
    class_replaceMethod(split, @selector(setViewControllers:), imp_implementationWithBlock(^(UISplitViewController *controller, NSArray *controllers) {
        revenant_phone_set(controller, controllers);
    }), "v@:@");
    class_replaceMethod(split, @selector(viewControllers), imp_implementationWithBlock(^NSArray *(UISplitViewController *controller) {
        UIViewController *primary = revenant_split_state(controller)->primary;
        return primary ? @[primary] : @[];
    }), "@@:");
    class_replaceMethod(split, @selector(loadView), imp_implementationWithBlock(^(UISplitViewController *controller) {
        controller.view = [[UIView alloc] initWithFrame:[UIScreen mainScreen].applicationFrame];
        controller.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        revenant_phone_attach(controller);
    }), "v@:");
    class_replaceMethod(split, @selector(shouldAutorotateToInterfaceOrientation:), imp_implementationWithBlock(^BOOL(UISplitViewController *controller, UIInterfaceOrientation orientation) {
        UIViewController *primary = revenant_split_state(controller)->primary;
        return primary ? [primary shouldAutorotateToInterfaceOrientation:orientation] : orientation == UIInterfaceOrientationPortrait;
    }), "c@:i");
}

@end

@implementation UISplitViewController (RevenantShow8)

- (void)showViewController:(UIViewController *)vc sender:(id)sender
{
    RevenantSplitState *state = revenant_split_state(self);
    id delegate = state->appDelegate;
    if ([delegate respondsToSelector:@selector(splitViewController:showViewController:sender:)] && [delegate splitViewController:self showViewController:vc sender:sender])
        return;
    if (state->showing) {
        [self presentViewController:vc animated:YES completion:nil];
        return;
    }
    if (revenant_split_collapsed(self)) {
        state->showing = YES;
        [(state->primary ?: self.viewControllers.firstObject) showViewController:vc sender:sender];
        state->showing = NO;
        return;
    }
    NSArray *columns = self.viewControllers;
    if (columns.count > 1 && revenant_column_of(self, sender) == columns[1])
        self.viewControllers = @[columns[0], vc];
    else
        self.viewControllers = columns.count > 1 ? @[vc, columns[1]] : @[vc];
}

- (void)showDetailViewController:(UIViewController *)vc sender:(id)sender
{
    RevenantSplitState *state = revenant_split_state(self);
    id delegate = state->appDelegate;
    if ([delegate respondsToSelector:@selector(splitViewController:showDetailViewController:sender:)] && [delegate splitViewController:self showDetailViewController:vc sender:sender])
        return;
    if (state->showing) {
        [self presentViewController:vc animated:YES completion:nil];
        return;
    }
    if (revenant_split_collapsed(self)) {
        state->showing = YES;
        [(state->primary ?: self.viewControllers.firstObject) showViewController:vc sender:sender];
        state->showing = NO;
        state->secondary = vc;
        return;
    }
    UIViewController *primary = self.viewControllers.firstObject;
    self.viewControllers = primary ? @[primary, vc] : @[vc];
}

@end

@implementation UIViewController (RevenantSplitCollapse8)

- (void)collapseSecondaryViewController:(UIViewController *)secondaryViewController forSplitViewController:(UISplitViewController *)splitViewController
{
    objc_setAssociatedObject(self, &RevenantCollapsedSecondaryKey, secondaryViewController, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (UIViewController *)separateSecondaryViewControllerForSplitViewController:(UISplitViewController *)splitViewController
{
    UIViewController *secondary = objc_getAssociatedObject(self, &RevenantCollapsedSecondaryKey);
    objc_setAssociatedObject(self, &RevenantCollapsedSecondaryKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return secondary;
}

@end

@implementation UINavigationController (RevenantSplitCollapse8)

- (void)collapseSecondaryViewController:(UIViewController *)secondaryViewController forSplitViewController:(UISplitViewController *)splitViewController
{
    BOOL navigation = [secondaryViewController isKindOfClass:[UINavigationController class]];
    NSArray *content = navigation ? [(UINavigationController *)secondaryViewController viewControllers] : @[secondaryViewController];
    if (navigation)
        [(UINavigationController *)secondaryViewController setViewControllers:@[] animated:NO];
    objc_setAssociatedObject(self, &RevenantCollapsedSecondaryKey, @{@"secondary": secondaryViewController, @"content": content}, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [self setViewControllers:[self.viewControllers arrayByAddingObjectsFromArray:content] animated:NO];
}

- (UIViewController *)separateSecondaryViewControllerForSplitViewController:(UISplitViewController *)splitViewController
{
    NSDictionary *collapsed = objc_getAssociatedObject(self, &RevenantCollapsedSecondaryKey);
    if (!collapsed)
        return nil;
    objc_setAssociatedObject(self, &RevenantCollapsedSecondaryKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    NSMutableArray *stack = [self.viewControllers mutableCopy];
    NSArray *content = collapsed[@"content"];
    [stack removeObjectsInArray:content];
    [self setViewControllers:stack animated:NO];
    UIViewController *secondary = collapsed[@"secondary"];
    if ([secondary isKindOfClass:[UINavigationController class]])
        [(UINavigationController *)secondary setViewControllers:content animated:NO];
    return secondary;
}

@end
