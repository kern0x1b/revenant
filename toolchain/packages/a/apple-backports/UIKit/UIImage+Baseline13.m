#import "CharonImageBaseline.h"
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

static const char charon_baseline_key;

NSNumber *charon_image_baseline(UIImage *image)
{
    return objc_getAssociatedObject(image, &charon_baseline_key);
}

void charon_set_image_baseline(UIImage *image, NSNumber *baseline)
{
    objc_setAssociatedObject(image, &charon_baseline_key, baseline, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static UIImage *charon_baseline_copy(UIImage *image, NSNumber *baseline)
{
    UIImage *copy = charon_image_copy(image);
    if (copy == image)
        copy = [image imageWithRenderingMode:image.renderingMode];
    charon_set_image_baseline(copy, baseline);
    return copy;
}

@implementation UIImage (CharonBaseline)

- (BOOL)hasBaseline
{
    return charon_image_baseline(self) != nil;
}

- (CGFloat)baselineOffsetFromBottom
{
    return (CGFloat)[charon_image_baseline(self) doubleValue];
}

- (UIImage *)imageWithBaselineOffsetFromBottom:(CGFloat)baselineOffset
{
    return charon_baseline_copy(self, @(baselineOffset));
}

- (UIImage *)imageWithoutBaseline
{
    return charon_baseline_copy(self, nil);
}

@end
