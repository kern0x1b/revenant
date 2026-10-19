#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static char revenant_force_touch_key;

@implementation UITraitCollection (RevenantForceTouch)

+ (UITraitCollection *)traitCollectionWithForceTouchCapability:(UIForceTouchCapability)capability
{
    UITraitCollection *collection = [[self alloc] init];
    objc_setAssociatedObject(collection, &revenant_force_touch_key, @(capability), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return collection;
}

- (UIForceTouchCapability)forceTouchCapability
{
    NSNumber *capability = objc_getAssociatedObject(self, &revenant_force_touch_key);
    return capability ? (UIForceTouchCapability)capability.integerValue : UIForceTouchCapabilityUnknown;
}

void revenant_set_screen_trait_force_touch(UITraitCollection *collection)
{
    revenant_set_trait_force_touch(collection, UIForceTouchCapabilityUnavailable);
}

void revenant_set_trait_force_touch(UITraitCollection *collection, UIForceTouchCapability capability)
{
    objc_setAssociatedObject(collection, &revenant_force_touch_key, capability ? @(capability) : nil,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
