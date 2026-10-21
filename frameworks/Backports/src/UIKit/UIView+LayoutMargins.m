#import <UIKit/UIKit.h>
#import <objc/runtime.h>

@interface UIView (RevenantLayoutMarginsGuideUpdate)
- (void)revenant_updateLayoutMarginsGuide;
@end

static char revenant_margins_key;
static char revenant_preserves_key;
static char revenant_insets_from_safe_area_key;

static void revenant_margins_changed(UIView *view)
{
    if ([view respondsToSelector:@selector(revenant_updateLayoutMarginsGuide)])
        [view revenant_updateLayoutMarginsGuide];
    [view layoutMarginsDidChange];
    UIViewController *controller = nil;
    for (UIResponder *next = view.nextResponder; next; next = next.nextResponder) {
        if ([next isKindOfClass:[UIViewController class]]) {
            controller = (UIViewController *)next;
            break;
        }
    }
    if ([controller respondsToSelector:@selector(viewLayoutMarginsDidChange)])
        [controller viewLayoutMarginsDidChange];
    for (UIView *subview in view.subviews) {
        if ([objc_getAssociatedObject(subview, &revenant_preserves_key) boolValue])
            revenant_margins_changed(subview);
    }
}

@implementation UIView (RevenantLayoutMargins)

- (UIEdgeInsets)layoutMargins
{
    NSValue *stored = objc_getAssociatedObject(self, &revenant_margins_key);
    UIEdgeInsets margins = stored ? [stored UIEdgeInsetsValue] : UIEdgeInsetsMake(8, 8, 8, 8);
    UIView *superview = self.superview;
    if (superview && [objc_getAssociatedObject(self, &revenant_preserves_key) boolValue]) {
        UIEdgeInsets inherited = [superview layoutMargins];
        CGRect bounds = superview.bounds;
        CGRect frame = self.frame;
        margins.top = MAX(margins.top, inherited.top - MAX(CGRectGetMinY(frame) - CGRectGetMinY(bounds), 0));
        margins.left = MAX(margins.left, inherited.left - MAX(CGRectGetMinX(frame) - CGRectGetMinX(bounds), 0));
        margins.bottom = MAX(margins.bottom, inherited.bottom - MAX(CGRectGetMaxY(bounds) - CGRectGetMaxY(frame), 0));
        margins.right = MAX(margins.right, inherited.right - MAX(CGRectGetMaxX(bounds) - CGRectGetMaxX(frame), 0));
    }
    if (self.insetsLayoutMarginsFromSafeArea) {
        UIEdgeInsets safe = self.safeAreaInsets;
        margins.top = MAX(margins.top, safe.top);
        margins.left = MAX(margins.left, safe.left);
        margins.bottom = MAX(margins.bottom, safe.bottom);
        margins.right = MAX(margins.right, safe.right);
    }
    return margins;
}

- (void)setLayoutMargins:(UIEdgeInsets)layoutMargins
{
    NSValue *stored = objc_getAssociatedObject(self, &revenant_margins_key);
    if (stored && UIEdgeInsetsEqualToEdgeInsets([stored UIEdgeInsetsValue], layoutMargins))
        return;
    objc_setAssociatedObject(self, &revenant_margins_key, [NSValue valueWithUIEdgeInsets:layoutMargins], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    revenant_margins_changed(self);
}

- (BOOL)preservesSuperviewLayoutMargins
{
    return [objc_getAssociatedObject(self, &revenant_preserves_key) boolValue];
}

- (void)setPreservesSuperviewLayoutMargins:(BOOL)preservesSuperviewLayoutMargins
{
    if ([self preservesSuperviewLayoutMargins] == preservesSuperviewLayoutMargins)
        return;
    objc_setAssociatedObject(self, &revenant_preserves_key, @(preservesSuperviewLayoutMargins), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    revenant_margins_changed(self);
}

- (void)layoutMarginsDidChange
{
}

- (BOOL)insetsLayoutMarginsFromSafeArea
{
    NSNumber *stored = objc_getAssociatedObject(self, &revenant_insets_from_safe_area_key);
    return stored ? stored.boolValue : YES;
}

- (void)setInsetsLayoutMarginsFromSafeArea:(BOOL)insetsLayoutMarginsFromSafeArea
{
    if (self.insetsLayoutMarginsFromSafeArea == insetsLayoutMarginsFromSafeArea)
        return;
    objc_setAssociatedObject(self, &revenant_insets_from_safe_area_key, @(insetsLayoutMarginsFromSafeArea), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    revenant_margins_changed(self);
}

@end
