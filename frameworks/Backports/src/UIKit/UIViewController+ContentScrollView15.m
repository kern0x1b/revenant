#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

static const char RevenantContentScrollViewsKey;

static UIScrollView *revenant_first_scroll_view(UIView *view)
{
    if ([view isKindOfClass:[UIScrollView class]])
        return (UIScrollView *)view;
    for (UIView *subview in view.subviews) {
        UIScrollView *found = revenant_first_scroll_view(subview);
        if (found)
            return found;
    }
    return nil;
}

@implementation UIViewController (RevenantContentScrollView15)

- (void)setContentScrollView:(UIScrollView *)scrollView forEdge:(NSDirectionalRectEdge)edge
{
    NSMutableDictionary *stored = objc_getAssociatedObject(self, &RevenantContentScrollViewsKey);
    if (!stored && scrollView) {
        stored = [NSMutableDictionary dictionary];
        objc_setAssociatedObject(self, &RevenantContentScrollViewsKey, stored, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    for (NSUInteger bit = 0; bit < 4; bit++) {
        if (!(edge & (1 << bit)))
            continue;
        if (scrollView)
            stored[@(1 << bit)] = scrollView;
        else
            [stored removeObjectForKey:@(1 << bit)];
    }
}

- (UIScrollView *)contentScrollViewForEdge:(NSDirectionalRectEdge)edge
{
    UIScrollView *stored = [objc_getAssociatedObject(self, &RevenantContentScrollViewsKey) objectForKey:@(edge)];
    if (stored)
        return stored;
    return self.isViewLoaded ? revenant_first_scroll_view(self.view) : nil;
}

@end
