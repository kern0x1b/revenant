#import <Foundation/Foundation.h>
#import <ExposureNotification/ExposureNotification.h>
#import <objc/runtime.h>

static const char revenant_variantOfConcernTypeKey;

@implementation ENExposureWindow (RevenantVariant15)

- (ENVariantOfConcernType)variantOfConcernType
{
    NSNumber *stored = objc_getAssociatedObject(self, &revenant_variantOfConcernTypeKey);
    return stored ? (ENVariantOfConcernType)stored.unsignedIntValue : ENVariantOfConcernTypeUnknown;
}

- (void)revenant_setVariantOfConcernType:(ENVariantOfConcernType)variantOfConcernType
{
    objc_setAssociatedObject(self, &revenant_variantOfConcernTypeKey,
                             @(variantOfConcernType), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
