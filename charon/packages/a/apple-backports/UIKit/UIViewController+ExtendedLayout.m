#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static char charon_edges_key;
static char charon_opaque_bars_key;
static char charon_scroll_insets_key;

@implementation UIViewController (CharonExtendedLayout)

- (UIRectEdge)edgesForExtendedLayout
{
    NSNumber *stored = objc_getAssociatedObject(self, &charon_edges_key);
    return stored ? (UIRectEdge)stored.unsignedIntegerValue : UIRectEdgeAll;
}

- (void)setEdgesForExtendedLayout:(UIRectEdge)edgesForExtendedLayout
{
    objc_setAssociatedObject(self, &charon_edges_key, @(edgesForExtendedLayout), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)extendedLayoutIncludesOpaqueBars
{
    return [objc_getAssociatedObject(self, &charon_opaque_bars_key) boolValue];
}

- (void)setExtendedLayoutIncludesOpaqueBars:(BOOL)extendedLayoutIncludesOpaqueBars
{
    objc_setAssociatedObject(self, &charon_opaque_bars_key, @(extendedLayoutIncludesOpaqueBars), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)automaticallyAdjustsScrollViewInsets
{
    NSNumber *stored = objc_getAssociatedObject(self, &charon_scroll_insets_key);
    return stored ? stored.boolValue : YES;
}

- (void)setAutomaticallyAdjustsScrollViewInsets:(BOOL)automaticallyAdjustsScrollViewInsets
{
    objc_setAssociatedObject(self, &charon_scroll_insets_key, @(automaticallyAdjustsScrollViewInsets), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
