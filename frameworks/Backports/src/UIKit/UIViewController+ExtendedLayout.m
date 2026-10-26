#import <UIKit/UIKit.h>
#import <objc/message.h>
#import <objc/runtime.h>

static char revenant_edges_key;
static char revenant_opaque_bars_key;
static char revenant_scroll_insets_key;

@implementation UIViewController (RevenantExtendedLayout)

- (UIRectEdge)edgesForExtendedLayout
{
    NSNumber *stored = objc_getAssociatedObject(self, &revenant_edges_key);
    return stored ? (UIRectEdge)stored.unsignedIntegerValue : UIRectEdgeAll;
}

- (void)setEdgesForExtendedLayout:(UIRectEdge)edgesForExtendedLayout
{
    objc_setAssociatedObject(self, &revenant_edges_key, @(edgesForExtendedLayout), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    ((void (*)(id, SEL, BOOL))objc_msgSend)(self, sel_registerName("setWantsFullScreenLayout:"), edgesForExtendedLayout != UIRectEdgeNone);
}

- (BOOL)extendedLayoutIncludesOpaqueBars
{
    return [objc_getAssociatedObject(self, &revenant_opaque_bars_key) boolValue];
}

- (void)setExtendedLayoutIncludesOpaqueBars:(BOOL)extendedLayoutIncludesOpaqueBars
{
    objc_setAssociatedObject(self, &revenant_opaque_bars_key, @(extendedLayoutIncludesOpaqueBars), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)automaticallyAdjustsScrollViewInsets
{
    NSNumber *stored = objc_getAssociatedObject(self, &revenant_scroll_insets_key);
    return stored ? stored.boolValue : YES;
}

- (void)setAutomaticallyAdjustsScrollViewInsets:(BOOL)automaticallyAdjustsScrollViewInsets
{
    objc_setAssociatedObject(self, &revenant_scroll_insets_key, @(automaticallyAdjustsScrollViewInsets), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
