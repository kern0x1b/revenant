#import "RevenantMenus.h"
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

static const char revenant_tint_key;

@implementation UISegmentedControl (RevenantSelectedTint13)

- (UIColor *)selectedSegmentTintColor
{
    return objc_getAssociatedObject(self, &revenant_tint_key);
}

- (void)setSelectedSegmentTintColor:(UIColor *)selectedSegmentTintColor
{
    if (selectedSegmentTintColor)
        revenant_menus_say_once(@"selected-segment-tint", @"UISegmentedControl.selectedSegmentTintColor: iOS 6 tints a whole segmented control and not its selected segment alone, so the colour is kept and read back and the control is drawn as before");
    objc_setAssociatedObject(self, &revenant_tint_key, selectedSegmentTintColor, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
