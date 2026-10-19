#import "RevenantImageBaseline.h"
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

static const char revenant_baseline_key;

NSNumber *revenant_image_baseline(UIImage *image)
{
    return objc_getAssociatedObject(image, &revenant_baseline_key);
}

void revenant_set_image_baseline(UIImage *image, NSNumber *baseline)
{
    objc_setAssociatedObject(image, &revenant_baseline_key, baseline, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static UIImage *revenant_baseline_copy(UIImage *image, NSNumber *baseline)
{
    UIImage *copy = revenant_image_copy(image);
    if (copy == image)
        copy = [image imageWithRenderingMode:image.renderingMode];
    revenant_set_image_baseline(copy, baseline);
    return copy;
}

@implementation UIImage (RevenantBaseline)

- (BOOL)hasBaseline
{
    return revenant_image_baseline(self) != nil;
}

- (CGFloat)baselineOffsetFromBottom
{
    return (CGFloat)[revenant_image_baseline(self) doubleValue];
}

- (UIImage *)imageWithBaselineOffsetFromBottom:(CGFloat)baselineOffset
{
    return revenant_baseline_copy(self, @(baselineOffset));
}

- (UIImage *)imageWithoutBaseline
{
    return revenant_baseline_copy(self, nil);
}

@end
