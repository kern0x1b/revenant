#import "RevenantMenus.h"
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

static const char revenant_adjusts_key;

@implementation UIScrollView (RevenantIndicatorInsets13)

- (BOOL)automaticallyAdjustsScrollIndicatorInsets
{
    NSNumber *held = objc_getAssociatedObject(self, &revenant_adjusts_key);
    return held ? held.boolValue : YES;
}

- (void)setAutomaticallyAdjustsScrollIndicatorInsets:(BOOL)automaticallyAdjustsScrollIndicatorInsets
{
    if (!automaticallyAdjustsScrollIndicatorInsets)
        revenant_menus_say_once(@"indicator-insets", @"UIScrollView.automaticallyAdjustsScrollIndicatorInsets: iOS 6 has no safe area to adjust the scroll indicators by, so the flag is kept and read back and the indicators are placed as before");
    objc_setAssociatedObject(self, &revenant_adjusts_key, @(automaticallyAdjustsScrollIndicatorInsets), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
