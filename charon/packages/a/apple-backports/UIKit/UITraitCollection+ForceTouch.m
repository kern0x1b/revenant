#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static char charon_force_touch_key;

@implementation UITraitCollection (CharonForceTouch)

+ (UITraitCollection *)traitCollectionWithForceTouchCapability:(UIForceTouchCapability)capability
{
    UITraitCollection *collection = [[self alloc] init];
    objc_setAssociatedObject(collection, &charon_force_touch_key, @(capability), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return collection;
}

- (UIForceTouchCapability)forceTouchCapability
{
    // A collection that sets nothing answers Unknown, which is what UITraitCollection.h names as the
    // unspecified value and what UIKitCore 26.2 answers for a collection built from nothing (facts/UIKit/
    // UITrait17.md, M2). A device that has no 3D touch sensor is Unavailable, and the screen's own traits below
    // say so, which is the answer that hardware gives rather than the answer an unset trait gives.
    NSNumber *capability = objc_getAssociatedObject(self, &charon_force_touch_key);
    return capability ? (UIForceTouchCapability)capability.integerValue : UIForceTouchCapabilityUnknown;
}

// The screen's traits answer Unavailable rather than Unknown, because this device has no 3D touch sensor: the
// hardware's answer is a fact about the device, and a collection the port made for the screen states it.
void charon_set_screen_trait_force_touch(UITraitCollection *collection)
{
    charon_set_trait_force_touch(collection, UIForceTouchCapabilityUnavailable);
}

void charon_set_trait_force_touch(UITraitCollection *collection, UIForceTouchCapability capability)
{
    // The one place this trait's storage is written besides the constructor above, so a collection made by the
    // traits of iOS 17 carries the capability the same way and the two compare equal.
    objc_setAssociatedObject(collection, &charon_force_touch_key, capability ? @(capability) : nil,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
