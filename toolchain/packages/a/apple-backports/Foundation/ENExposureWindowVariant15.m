#import <Foundation/Foundation.h>
#import <ExposureNotification/ExposureNotification.h>
#import <objc/runtime.h>

static const char charon_variantOfConcernTypeKey;

@implementation ENExposureWindow (CharonVariant15)

- (ENVariantOfConcernType)variantOfConcernType
{
    NSNumber *stored = objc_getAssociatedObject(self, &charon_variantOfConcernTypeKey);
    return stored ? (ENVariantOfConcernType)stored.unsignedIntValue : ENVariantOfConcernTypeUnknown;
}

- (void)charon_setVariantOfConcernType:(ENVariantOfConcernType)variantOfConcernType
{
    objc_setAssociatedObject(self, &charon_variantOfConcernTypeKey,
                             @(variantOfConcernType), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
