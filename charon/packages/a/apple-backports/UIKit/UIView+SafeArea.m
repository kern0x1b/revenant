#import <UIKit/UIKit.h>

UIEdgeInsets charon_safe_area_insets(UIView *view);
UIEdgeInsets charon_content_overlay_insets(UIViewController *controller, UIView *view);
UIEdgeInsets charon_status_bar_overlap(UIView *view);

static UIEdgeInsets charon_insets_in_inner_rect(UIEdgeInsets insets, CGRect outer, CGRect inner)
{
    CGFloat top = MAX(0, CGRectGetMinY(outer) + insets.top - CGRectGetMinY(inner));
    CGFloat left = MAX(0, CGRectGetMinX(outer) + insets.left - CGRectGetMinX(inner));
    CGFloat bottom = MAX(0, CGRectGetMaxY(inner) - (CGRectGetMaxY(outer) - insets.bottom));
    CGFloat right = MAX(0, CGRectGetMaxX(inner) - (CGRectGetMaxX(outer) - insets.right));
    return UIEdgeInsetsMake(MIN(top, CGRectGetHeight(inner)), MIN(left, CGRectGetWidth(inner)),
                            MIN(bottom, CGRectGetHeight(inner)), MIN(right, CGRectGetWidth(inner)));
}

static UIEdgeInsets charon_insets_above_zero(UIEdgeInsets insets)
{
    return UIEdgeInsetsMake(MAX(0, insets.top), MAX(0, insets.left), MAX(0, insets.bottom), MAX(0, insets.right));
}

static BOOL charon_in_a_window(UIView *view)
{
    return [view isKindOfClass:[UIWindow class]] || view.window != nil;
}

static UIViewController *charon_view_controller(UIView *view)
{
    UIResponder *next = [view nextResponder];
    return [next isKindOfClass:[UIViewController class]] ? (UIViewController *)next : nil;
}

UIEdgeInsets charon_safe_area_insets(UIView *view)
{
    UIView *superview = view.superview;
    if (!superview) {
        if ([view isKindOfClass:[UIWindow class]])
            return charon_status_bar_overlap(view);
        UIViewController *controller = charon_view_controller(view);
        return controller ? charon_content_overlay_insets(controller, view) : UIEdgeInsetsZero;
    }
    UIViewController *controller = charon_view_controller(superview);
    UIEdgeInsets outer = controller ? charon_content_overlay_insets(controller, superview)
                                    : charon_safe_area_insets(superview);
    return charon_insets_in_inner_rect(charon_insets_above_zero(outer), superview.bounds, view.frame);
}

@implementation UIView (CharonSafeArea)

- (UIEdgeInsets)safeAreaInsets
{
    if (!charon_in_a_window(self))
        return UIEdgeInsetsZero;
    UIViewController *controller = charon_view_controller(self);
    if (controller)
        return charon_insets_above_zero(charon_content_overlay_insets(controller, self));
    return charon_insets_above_zero(charon_safe_area_insets(self));
}

@end
