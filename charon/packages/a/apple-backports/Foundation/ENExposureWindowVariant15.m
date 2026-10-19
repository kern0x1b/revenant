#import <Foundation/Foundation.h>
#import <ExposureNotification/ExposureNotification.h>
#import <objc/runtime.h>

// ENExposureWindow's variantOfConcernType, iOS 15.2.
//
// One property, and one release: ENExposureWindow and the other six value classes arrived in iOS 12.5
// and are in ENExposureValues.m, which is @dynamic for this one, so the 12.5 object exports no symbol
// for it and this object holds nothing else. That is what release-split reads an object's symbols for,
// and a file holding 12.5 and 15.2 members is one band carrying two releases' API.
//
// The value is the variant the window's scan measured, stored as the framework's own
// ENVariantOfConcernType, which ENCommon.h gives every case of by number, so a window answers what it
// was decoded with.
//
// The storage is an associated object on the release's own runtime, not an ivar on the 12.5 class. An
// ivar cannot serve here: a category may not synthesize a property, and an ivar added to the 12.5
// object's @implementation cannot be named from another file at all. An associated object is the one
// mechanism that gives a category storage, and it is public API since iOS 5.

static const char charon_variantOfConcernTypeKey;

@implementation ENExposureWindow (CharonVariant15)

- (ENVariantOfConcernType)variantOfConcernType
{
    // An ENVariantOfConcernType is a uint32_t, so the association carries it as a pointer-sized value
    // rather than as an NSNumber: the runtime's own documented use for a non-object association.
    NSNumber *stored = objc_getAssociatedObject(self, &charon_variantOfConcernTypeKey);
    return stored ? (ENVariantOfConcernType)stored.unsignedIntValue : ENVariantOfConcernTypeUnknown;
}

- (void)charon_setVariantOfConcernType:(ENVariantOfConcernType)variantOfConcernType
{
    objc_setAssociatedObject(self, &charon_variantOfConcernTypeKey,
                             @(variantOfConcernType), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
