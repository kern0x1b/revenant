#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>
#include <math.h>

const CAFrameRateRange CAFrameRateRangeDefault = {-1, -1, -1};

CAFrameRateRange CAFrameRateRangeMake(float minimum, float maximum, float preferred)
{
    return (CAFrameRateRange){minimum, maximum, preferred};
}

bool CAFrameRateRangeIsEqualToRange(CAFrameRateRange range, CAFrameRateRange other)
{
    return range.minimum == other.minimum && range.maximum == other.maximum && range.preferred == other.preferred;
}

static const char CharonAnimationFrameRateRangeKey;

@implementation CAAnimation (CharonFrameRateRange)

- (CAFrameRateRange)preferredFrameRateRange
{
    NSValue *boxed = objc_getAssociatedObject(self, &CharonAnimationFrameRateRangeKey);
    CAFrameRateRange range = CAFrameRateRangeDefault;
    if (boxed)
        [boxed getValue:&range];
    return range;
}

- (void)setPreferredFrameRateRange:(CAFrameRateRange)preferredFrameRateRange
{
    NSValue *boxed = [NSValue valueWithBytes:&preferredFrameRateRange objCType:@encode(CAFrameRateRange)];
    objc_setAssociatedObject(self, &CharonAnimationFrameRateRangeKey, boxed, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
