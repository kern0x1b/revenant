#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static char RevenantContentInsetAdjustmentBehaviorKey;

static BOOL revenant_scroll_view_scrolls_along_x(UIScrollView *view)
{
    return view.contentSize.width > CGRectGetWidth(view.bounds) || view.alwaysBounceHorizontal;
}

static BOOL revenant_scroll_view_scrolls_along_y(UIScrollView *view)
{
    return view.contentSize.height > CGRectGetHeight(view.bounds) || view.alwaysBounceVertical;
}

static UIRectEdge revenant_scroll_view_safe_area_edges(UIScrollView *view)
{
    UIScrollViewContentInsetAdjustmentBehavior behavior = view.contentInsetAdjustmentBehavior;
    if (behavior == UIScrollViewContentInsetAdjustmentNever)
        return 0;
    if (behavior == UIScrollViewContentInsetAdjustmentAlways)
        return UIRectEdgeAll;
    UIRectEdge edges = view.contentSize.width > CGRectGetWidth(view.bounds) || revenant_scroll_view_scrolls_along_x(view)
                     ? UIRectEdgeAll : (UIRectEdgeTop | UIRectEdgeBottom);
    if (!(view.contentSize.height > CGRectGetHeight(view.bounds)) && !revenant_scroll_view_scrolls_along_y(view))
        edges &= (UIRectEdgeLeft | UIRectEdgeRight);
    return edges;
}

@implementation UIScrollView (RevenantAdjustedContentInset)

- (UIScrollViewContentInsetAdjustmentBehavior)contentInsetAdjustmentBehavior
{
    NSNumber *stored = objc_getAssociatedObject(self, &RevenantContentInsetAdjustmentBehaviorKey);
    return stored ? (UIScrollViewContentInsetAdjustmentBehavior)stored.integerValue : UIScrollViewContentInsetAdjustmentAutomatic;
}

- (void)setContentInsetAdjustmentBehavior:(UIScrollViewContentInsetAdjustmentBehavior)contentInsetAdjustmentBehavior
{
    objc_setAssociatedObject(self, &RevenantContentInsetAdjustmentBehaviorKey, @(contentInsetAdjustmentBehavior), OBJC_ASSOCIATION_RETAIN);
    [self setNeedsLayout];
}

- (UIEdgeInsets)adjustedContentInset
{
    UIEdgeInsets content = self.contentInset;
    UIEdgeInsets safe = self.safeAreaInsets;
    UIRectEdge edges = revenant_scroll_view_safe_area_edges(self);
    return UIEdgeInsetsMake(content.top + ((edges & UIRectEdgeTop) ? safe.top : 0),
                            content.left + ((edges & UIRectEdgeLeft) ? safe.left : 0),
                            content.bottom + ((edges & UIRectEdgeBottom) ? safe.bottom : 0),
                            content.right + ((edges & UIRectEdgeRight) ? safe.right : 0));
}

@end
