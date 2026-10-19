#import <UIKit/UIKit.h>
#import <objc/runtime.h>

@interface UIView (CharonLayoutMarginsGuideUpdate)
- (void)charon_updateLayoutMarginsGuide;
@end

static char charon_margins_key;
static char charon_preserves_key;
static char charon_insets_from_safe_area_key;

static void charon_margins_changed(UIView *view)
{
    if ([view respondsToSelector:@selector(charon_updateLayoutMarginsGuide)])
        [view charon_updateLayoutMarginsGuide];
    [view layoutMarginsDidChange];
    // The same moment seen from the controller the view belongs to, which is where iOS 11 sends it
    // (UIViewSafeArea.md records the release's own order: the view first, the controller second, at
    // -_safeAreaInsetsDidChangeFromOldInsets: 0x18a27d178). The controller is the view's next
    // responder, the same walk UIView+SafeArea.m's charon_view_controller makes.
    UIViewController *controller = nil;
    for (UIResponder *next = view.nextResponder; next; next = next.nextResponder) {
        if ([next isKindOfClass:[UIViewController class]]) {
            controller = (UIViewController *)next;
            break;
        }
    }
    // Asked whether it is there first, and that is not defensive: this object is kept in every band
    // from 6.0 and the member that answers the message arrives in 11.0, so in a lower band the
    // controller answers NO and the message would raise rather than do nothing.
    if ([controller respondsToSelector:@selector(viewLayoutMarginsDidChange)])
        [controller viewLayoutMarginsDidChange];
    for (UIView *subview in view.subviews) {
        if ([objc_getAssociatedObject(subview, &charon_preserves_key) boolValue])
            charon_margins_changed(subview);
    }
}

@implementation UIView (CharonLayoutMargins)

- (UIEdgeInsets)layoutMargins
{
    NSValue *stored = objc_getAssociatedObject(self, &charon_margins_key);
    UIEdgeInsets margins = stored ? [stored UIEdgeInsetsValue] : UIEdgeInsetsMake(8, 8, 8, 8);
    UIView *superview = self.superview;
    if (superview && [objc_getAssociatedObject(self, &charon_preserves_key) boolValue]) {
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
    NSValue *stored = objc_getAssociatedObject(self, &charon_margins_key);
    if (stored && UIEdgeInsetsEqualToEdgeInsets([stored UIEdgeInsetsValue], layoutMargins))
        return;
    objc_setAssociatedObject(self, &charon_margins_key, [NSValue valueWithUIEdgeInsets:layoutMargins], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    charon_margins_changed(self);
}

- (BOOL)preservesSuperviewLayoutMargins
{
    return [objc_getAssociatedObject(self, &charon_preserves_key) boolValue];
}

- (void)setPreservesSuperviewLayoutMargins:(BOOL)preservesSuperviewLayoutMargins
{
    if ([self preservesSuperviewLayoutMargins] == preservesSuperviewLayoutMargins)
        return;
    objc_setAssociatedObject(self, &charon_preserves_key, @(preservesSuperviewLayoutMargins), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    charon_margins_changed(self);
}

- (void)layoutMarginsDidChange
{
}

- (BOOL)insetsLayoutMarginsFromSafeArea
{
    NSNumber *stored = objc_getAssociatedObject(self, &charon_insets_from_safe_area_key);
    return stored ? stored.boolValue : YES;
}

- (void)setInsetsLayoutMarginsFromSafeArea:(BOOL)insetsLayoutMarginsFromSafeArea
{
    if (self.insetsLayoutMarginsFromSafeArea == insetsLayoutMarginsFromSafeArea)
        return;
    objc_setAssociatedObject(self, &charon_insets_from_safe_area_key, @(insetsLayoutMarginsFromSafeArea), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    charon_margins_changed(self);
}

@end
