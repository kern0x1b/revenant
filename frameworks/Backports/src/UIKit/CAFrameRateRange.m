#include "../revenant_impl.h"
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>
#include <math.h>

const CAFrameRateRange BACKPORT_IMPL(CAFrameRateRangeDefault) = {-1, -1, -1};

CAFrameRateRange BACKPORT_IMPL(CAFrameRateRangeMake)(float minimum, float maximum, float preferred)
{
    return (CAFrameRateRange){minimum, maximum, preferred};
}

bool BACKPORT_IMPL(CAFrameRateRangeIsEqualToRange)(CAFrameRateRange range, CAFrameRateRange other)
{
    return range.minimum == other.minimum && range.maximum == other.maximum && range.preferred == other.preferred;
}

static const char RevenantAnimationFrameRateRangeKey;

@implementation CAAnimation (RevenantFrameRateRange)

- (CAFrameRateRange)preferredFrameRateRange
{
    NSValue *boxed = objc_getAssociatedObject(self, &RevenantAnimationFrameRateRangeKey);
    CAFrameRateRange range = CAFrameRateRangeDefault;
    if (boxed)
        [boxed getValue:&range];
    return range;
}

- (void)setPreferredFrameRateRange:(CAFrameRateRange)preferredFrameRateRange
{
    NSValue *boxed = [NSValue valueWithBytes:&preferredFrameRateRange objCType:@encode(CAFrameRateRange)];
    objc_setAssociatedObject(self, &RevenantAnimationFrameRateRangeKey, boxed, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
