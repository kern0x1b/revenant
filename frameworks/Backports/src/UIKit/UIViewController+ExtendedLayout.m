#import <UIKit/UIKit.h>
#import <objc/message.h>
#import <objc/runtime.h>

static char revenant_edges_key;
static char revenant_opaque_bars_key;
static char revenant_scroll_insets_key;
static char revenant_prior_wants_key;

static BOOL revenant_edges_noted;
static BOOL revenant_opaque_bars_noted;
static BOOL revenant_scroll_insets_noted;

static void revenant_note_once(BOOL *noted, NSString *message)
{
    if (*noted)
        return;
    *noted = YES;
    NSLog(@"%@", message);
}

@implementation UIViewController (RevenantExtendedLayout)

- (UIRectEdge)edgesForExtendedLayout
{
    NSNumber *stored = objc_getAssociatedObject(self, &revenant_edges_key);
    return stored ? (UIRectEdge)stored.unsignedIntegerValue : UIRectEdgeAll;
}

- (void)setEdgesForExtendedLayout:(UIRectEdge)edgesForExtendedLayout
{
    objc_setAssociatedObject(self, &revenant_edges_key, @(edgesForExtendedLayout), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    NSNumber *prior = objc_getAssociatedObject(self, &revenant_prior_wants_key);
    if (edgesForExtendedLayout == UIRectEdgeAll) {
        if (!prior) {
            BOOL current = ((BOOL (*)(id, SEL))objc_msgSend)(self, sel_registerName("wantsFullScreenLayout"));
            objc_setAssociatedObject(self, &revenant_prior_wants_key, @(current), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        ((void (*)(id, SEL, BOOL))objc_msgSend)(self, sel_registerName("setWantsFullScreenLayout:"), YES);
        return;
    }
    if (prior) {
        objc_setAssociatedObject(self, &revenant_prior_wants_key, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        ((void (*)(id, SEL, BOOL))objc_msgSend)(self, sel_registerName("setWantsFullScreenLayout:"), prior.boolValue);
    }
    if (edgesForExtendedLayout != UIRectEdgeNone)
        revenant_note_once(&revenant_edges_noted, @"edgesForExtendedLayout: only UIRectEdgeAll and UIRectEdgeNone are mapped to wantsFullScreenLayout on this release; other edges are stored without effect");
}

- (BOOL)extendedLayoutIncludesOpaqueBars
{
    return [objc_getAssociatedObject(self, &revenant_opaque_bars_key) boolValue];
}

- (void)setExtendedLayoutIncludesOpaqueBars:(BOOL)extendedLayoutIncludesOpaqueBars
{
    objc_setAssociatedObject(self, &revenant_opaque_bars_key, @(extendedLayoutIncludesOpaqueBars), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    revenant_note_once(&revenant_opaque_bars_noted, @"extendedLayoutIncludesOpaqueBars is stored without effect: this release does not extend the layout under opaque bars");
}

- (BOOL)automaticallyAdjustsScrollViewInsets
{
    NSNumber *stored = objc_getAssociatedObject(self, &revenant_scroll_insets_key);
    return stored ? stored.boolValue : YES;
}

- (void)setAutomaticallyAdjustsScrollViewInsets:(BOOL)automaticallyAdjustsScrollViewInsets
{
    objc_setAssociatedObject(self, &revenant_scroll_insets_key, @(automaticallyAdjustsScrollViewInsets), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    revenant_note_once(&revenant_scroll_insets_noted, @"automaticallyAdjustsScrollViewInsets is stored without effect: this release does not adjust scroll view insets under the bars");
}

@end
