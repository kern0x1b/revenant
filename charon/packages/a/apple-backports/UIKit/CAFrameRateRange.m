#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>
#include <math.h>

// CAFrameRateRange is a plain three-float struct with no OS dependency at all - "it arrived in
// iOS 15" is not a wall for a value type the caller only ever constructs and compares.
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

// CAAnimation carries no display link of its own on this release - CoreAnimation commits at the
// one rhythm the render server drives, the same way a real ProMotion-less device answers this
// property today: kept and returned faithfully, never messaged, since there is nothing here for a
// per-animation range to throttle.
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
