#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

static const char revenant_style_key, revenant_prior_background_key;

@implementation UISplitViewController (RevenantBackground13)

- (UISplitViewControllerBackgroundStyle)primaryBackgroundStyle
{
    return (UISplitViewControllerBackgroundStyle)[objc_getAssociatedObject(self, &revenant_style_key) integerValue];
}

- (void)setPrimaryBackgroundStyle:(UISplitViewControllerBackgroundStyle)primaryBackgroundStyle
{
    UIView *primary = self.viewControllers.firstObject.view;
    if (primaryBackgroundStyle == UISplitViewControllerBackgroundStyleSidebar && primary) {
        if (self.primaryBackgroundStyle != UISplitViewControllerBackgroundStyleSidebar)
            objc_setAssociatedObject(self, &revenant_prior_background_key, primary.backgroundColor ?: [NSNull null], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        primary.backgroundColor = [UIColor colorWithRed:0.93 green:0.93 blue:0.95 alpha:1];
    } else if (primary && self.primaryBackgroundStyle == UISplitViewControllerBackgroundStyleSidebar) {
        id prior = objc_getAssociatedObject(self, &revenant_prior_background_key);
        primary.backgroundColor = [prior isKindOfClass:[UIColor class]] ? prior : nil;
        objc_setAssociatedObject(self, &revenant_prior_background_key, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    objc_setAssociatedObject(self, &revenant_style_key, @(primaryBackgroundStyle), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
