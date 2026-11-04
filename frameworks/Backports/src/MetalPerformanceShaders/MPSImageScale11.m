#import "RevenantMPS.h"
#import "../revenant_alias.h"

REVENANT_ALIAS_OF(MPSImageScale, MPSUnaryImageKernel)

@implementation REVENANT_ALIAS_CLASS(MPSImageScale) (RevenantMPSImageScale)

static const void *RevenantMPSImageScaleTransformKey = &RevenantMPSImageScaleTransformKey;

- (const MPSScaleTransform *)scaleTransform
{
    NSData *transform = objc_getAssociatedObject(self, RevenantMPSImageScaleTransformKey);
    return transform ? (const MPSScaleTransform *)transform.bytes : NULL;
}

- (void)setScaleTransform:(const MPSScaleTransform *)scaleTransform
{
    NSData *transform = scaleTransform ? [NSData dataWithBytes:scaleTransform length:sizeof(MPSScaleTransform)] : nil;
    objc_setAssociatedObject(self, RevenantMPSImageScaleTransformKey, transform, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
