#import <UIKit/UIKit.h>

UIEdgeInsets revenant_safe_area_insets(UIView *view);
UIEdgeInsets revenant_content_overlay_insets(UIViewController *controller, UIView *view);
UIEdgeInsets revenant_status_bar_overlap(UIView *view);

static UIEdgeInsets revenant_insets_in_inner_rect(UIEdgeInsets insets, CGRect outer, CGRect inner)
{
    CGFloat top = MAX(0, CGRectGetMinY(outer) + insets.top - CGRectGetMinY(inner));
    CGFloat left = MAX(0, CGRectGetMinX(outer) + insets.left - CGRectGetMinX(inner));
    CGFloat bottom = MAX(0, CGRectGetMaxY(inner) - (CGRectGetMaxY(outer) - insets.bottom));
    CGFloat right = MAX(0, CGRectGetMaxX(inner) - (CGRectGetMaxX(outer) - insets.right));
    return UIEdgeInsetsMake(MIN(top, CGRectGetHeight(inner)), MIN(left, CGRectGetWidth(inner)),
                            MIN(bottom, CGRectGetHeight(inner)), MIN(right, CGRectGetWidth(inner)));
}

static UIEdgeInsets revenant_insets_above_zero(UIEdgeInsets insets)
{
    return UIEdgeInsetsMake(MAX(0, insets.top), MAX(0, insets.left), MAX(0, insets.bottom), MAX(0, insets.right));
}

static BOOL revenant_in_a_window(UIView *view)
{
    return [view isKindOfClass:[UIWindow class]] || view.window != nil;
}

static UIViewController *revenant_view_controller(UIView *view)
{
    UIResponder *next = [view nextResponder];
    return [next isKindOfClass:[UIViewController class]] ? (UIViewController *)next : nil;
}

UIEdgeInsets revenant_safe_area_insets(UIView *view)
{
    UIView *superview = view.superview;
    if (!superview) {
        if ([view isKindOfClass:[UIWindow class]])
            return revenant_status_bar_overlap(view);
        UIViewController *controller = revenant_view_controller(view);
        return controller ? revenant_content_overlay_insets(controller, view) : UIEdgeInsetsZero;
    }
    UIViewController *controller = revenant_view_controller(superview);
    UIEdgeInsets outer = controller ? revenant_content_overlay_insets(controller, superview)
                                    : revenant_safe_area_insets(superview);
    return revenant_insets_in_inner_rect(revenant_insets_above_zero(outer), superview.bounds, view.frame);
}

@implementation UIView (RevenantSafeArea)

- (UIEdgeInsets)safeAreaInsets
{
    if (!revenant_in_a_window(self))
        return UIEdgeInsetsZero;
    UIViewController *controller = revenant_view_controller(self);
    if (controller)
        return revenant_insets_above_zero(revenant_content_overlay_insets(controller, self));
    return revenant_insets_above_zero(revenant_safe_area_insets(self));
}

@end
