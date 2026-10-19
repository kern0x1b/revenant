#import <UIKit/UIKit.h>
#import <objc/runtime.h>

UIEdgeInsets charon_content_overlay_insets(UIViewController *controller, UIView *view);

static char CharonAdditionalSafeAreaInsetsKey;

static UIEdgeInsets charon_bar_overlap(UIView *bar, UIView *view, CGFloat statusBottom)
{
    UIWindow *window = [view isKindOfClass:[UIWindow class]] ? (UIWindow *)view : view.window;
    if (!bar || bar.hidden || bar.alpha <= 0 || !bar.window || bar.window != window)
        return UIEdgeInsetsZero;
    CGRect covered = CGRectIntersection([view convertRect:bar.bounds fromView:bar], view.bounds);
    if (CGRectIsNull(covered) || CGRectIsEmpty(covered))
        return UIEdgeInsetsZero;
    CGRect bounds = view.bounds;
    if (CGRectGetMinY(covered) <= CGRectGetMinY(bounds) + statusBottom + 0.5)
        return UIEdgeInsetsMake(CGRectGetMaxY(covered) - CGRectGetMinY(bounds), 0, 0, 0);
    if (CGRectGetMaxY(covered) >= CGRectGetMaxY(bounds))
        return UIEdgeInsetsMake(0, 0, CGRectGetMaxY(bounds) - CGRectGetMinY(covered), 0);
    return UIEdgeInsetsZero;
}

UIEdgeInsets charon_status_bar_overlap(UIView *view);

UIEdgeInsets charon_status_bar_overlap(UIView *view)
{
    UIApplication *application = [UIApplication sharedApplication];
    UIWindow *window = [view isKindOfClass:[UIWindow class]] ? (UIWindow *)view : view.window;
    if (application.statusBarHidden || !window)
        return UIEdgeInsetsZero;
    CGRect bar = [window convertRect:application.statusBarFrame fromWindow:nil];
    CGRect covered = CGRectIntersection([view convertRect:bar fromView:window], view.bounds);
    if (CGRectIsNull(covered) || CGRectIsEmpty(covered) || CGRectGetMinY(covered) > CGRectGetMinY(view.bounds))
        return UIEdgeInsetsZero;
    return UIEdgeInsetsMake(CGRectGetMaxY(covered) - CGRectGetMinY(view.bounds), 0, 0, 0);
}

UIEdgeInsets charon_content_overlay_insets(UIViewController *controller, UIView *view)
{
    UIEdgeInsets insets = charon_status_bar_overlap(view);
    UINavigationController *navigation = controller.navigationController;
    UITabBarController *tabs = controller.tabBarController;
    // A toolbar the controller keeps hidden covers nothing, and its getter makes the bar the first time it is asked, so a hidden
    // one is not asked for (facts/UIKit/UIViewSafeArea.md).
    UIToolbar *toolbar = navigation.toolbarHidden ? nil : navigation.toolbar;
    UIEdgeInsets bars[] = {charon_bar_overlap(navigation.navigationBar, view, insets.top),
                           charon_bar_overlap(toolbar, view, insets.top),
                           charon_bar_overlap(tabs.tabBar, view, insets.top)};
    for (NSUInteger index = 0; index < sizeof bars / sizeof *bars; index++) {
        insets.top = MAX(insets.top, bars[index].top);
        insets.bottom = MAX(insets.bottom, bars[index].bottom);
    }
    UIEdgeInsets additional = controller.additionalSafeAreaInsets;
    return UIEdgeInsetsMake(insets.top + additional.top, insets.left + additional.left,
                            insets.bottom + additional.bottom, insets.right + additional.right);
}

@implementation UIViewController (CharonSafeArea)

- (UIEdgeInsets)additionalSafeAreaInsets
{
    NSValue *stored = objc_getAssociatedObject(self, &CharonAdditionalSafeAreaInsetsKey);
    return stored ? stored.UIEdgeInsetsValue : UIEdgeInsetsZero;
}

- (void)setAdditionalSafeAreaInsets:(UIEdgeInsets)additionalSafeAreaInsets
{
    objc_setAssociatedObject(self, &CharonAdditionalSafeAreaInsetsKey,
                             [NSValue valueWithUIEdgeInsets:additionalSafeAreaInsets], OBJC_ASSOCIATION_RETAIN);
    if (self.isViewLoaded)
        [self.view setNeedsLayout];
}

@end
