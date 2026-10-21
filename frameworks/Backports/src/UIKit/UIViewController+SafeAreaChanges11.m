#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

static const char RevenantLastSafeAreaKey;
static const char RevenantLastAdjustedInsetKey;
static const char RevenantRespectsMinimumKey;

static BOOL revenant_overrides(UIView *view, SEL selector, Class base)
{
    return class_getMethodImplementation([view class], selector) != class_getMethodImplementation(base, selector);
}

static void revenant_scroll_adjusted_changed(UIScrollView *scrollView)
{
    UIEdgeInsets adjusted = scrollView.adjustedContentInset;
    NSValue *last = objc_getAssociatedObject(scrollView, &RevenantLastAdjustedInsetKey);
    objc_setAssociatedObject(scrollView, &RevenantLastAdjustedInsetKey, [NSValue valueWithUIEdgeInsets:adjusted], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if (!last || UIEdgeInsetsEqualToEdgeInsets(last.UIEdgeInsetsValue, adjusted))
        return;
    [scrollView adjustedContentInsetDidChange];
    id delegate = scrollView.delegate;
    if ([delegate respondsToSelector:@selector(scrollViewDidChangeAdjustedContentInset:)])
        [delegate scrollViewDidChangeAdjustedContentInset:scrollView];
}

static void revenant_deliver_safe_area(UIView *view)
{
    if (revenant_overrides(view, @selector(safeAreaInsetsDidChange), [UIView class]))
        [view safeAreaInsetsDidChange];
    if ([view isKindOfClass:[UIScrollView class]])
        revenant_scroll_adjusted_changed((UIScrollView *)view);
    for (UIView *subview in view.subviews)
        revenant_deliver_safe_area(subview);
}

@interface RevenantSafeAreaChanges11 : NSObject
@end

@implementation RevenantSafeAreaChanges11

+ (void)load
{
    if ([UIViewController instancesRespondToSelector:@selector(viewSafeAreaInsetsDidChange)])
        return;
    SEL layout = @selector(viewDidLayoutSubviews);
    void (*originalLayout)(id, SEL) = (void (*)(id, SEL))class_getMethodImplementation([UIViewController class], layout);
    class_replaceMethod([UIViewController class], layout, imp_implementationWithBlock(^(UIViewController *controller) {
        originalLayout(controller, layout);
        if (!controller.isViewLoaded || !controller.view.window)
            return;
        UIEdgeInsets insets = controller.view.safeAreaInsets;
        NSValue *last = objc_getAssociatedObject(controller, &RevenantLastSafeAreaKey);
        objc_setAssociatedObject(controller, &RevenantLastSafeAreaKey, [NSValue valueWithUIEdgeInsets:insets], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        if (last && !UIEdgeInsetsEqualToEdgeInsets(last.UIEdgeInsetsValue, insets)) {
            [controller viewSafeAreaInsetsDidChange];
            revenant_deliver_safe_area(controller.view);
        }
    }), "v@:");
    SEL setInset = @selector(setContentInset:);
    Method setInsetMethod = class_getInstanceMethod([UIScrollView class], setInset);
    void (*originalSetInset)(id, SEL, UIEdgeInsets) = (void (*)(id, SEL, UIEdgeInsets))method_getImplementation(setInsetMethod);
    class_replaceMethod([UIScrollView class], setInset, imp_implementationWithBlock(^(UIScrollView *scrollView, UIEdgeInsets inset) {
        if (!objc_getAssociatedObject(scrollView, &RevenantLastAdjustedInsetKey))
            objc_setAssociatedObject(scrollView, &RevenantLastAdjustedInsetKey, [NSValue valueWithUIEdgeInsets:scrollView.adjustedContentInset], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        originalSetInset(scrollView, setInset, inset);
        revenant_scroll_adjusted_changed(scrollView);
    }), method_getTypeEncoding(setInsetMethod));
}

@end

@implementation UIViewController (RevenantSafeAreaChanges11)

- (void)viewSafeAreaInsetsDidChange
{
}

- (NSDirectionalEdgeInsets)systemMinimumLayoutMargins
{
    CGFloat margin = self.traitCollection.horizontalSizeClass == UIUserInterfaceSizeClassRegular ? 20 : 16;
    return NSDirectionalEdgeInsetsMake(0, margin, 0, margin);
}

- (BOOL)viewRespectsSystemMinimumLayoutMargins
{
    NSNumber *stored = objc_getAssociatedObject(self, &RevenantRespectsMinimumKey);
    return stored ? stored.boolValue : YES;
}

- (void)setViewRespectsSystemMinimumLayoutMargins:(BOOL)viewRespectsSystemMinimumLayoutMargins
{
    objc_setAssociatedObject(self, &RevenantRespectsMinimumKey, @(viewRespectsSystemMinimumLayoutMargins), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if (self.isViewLoaded)
        [self.view layoutMarginsDidChange];
}

@end

@implementation UIScrollView (RevenantAdjustedInsetChanges11)

- (void)adjustedContentInsetDidChange
{
}

@end
