#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>
#include <math.h>

static const double CharonDisplayLinkFramesPerSecond = 60.0;

static const char CharonDisplayLinkRateKey;
static const char CharonDisplayLinkFrameRateRangeKey;

@interface CharonDisplayLinkRate : NSObject {
@public
    NSInteger frames;
    NSInteger interval;
}
@end

@implementation CharonDisplayLinkRate
@end

static double charon_display_link_refresh(CADisplayLink *link)
{
    CFTimeInterval duration = [link duration];
    return duration > 0 ? (double)duration : 1.0 / CharonDisplayLinkFramesPerSecond;
}

@implementation CADisplayLink (CharonFrameRate)

- (CFTimeInterval)targetTimestamp
{
    return [self timestamp] + [self duration] * (double)[self frameInterval];
}

- (NSInteger)preferredFramesPerSecond
{
    CharonDisplayLinkRate *rate = objc_getAssociatedObject(self, &CharonDisplayLinkRateKey);
    NSInteger interval = [self frameInterval];
    if (rate && rate->interval == interval)
        return rate->frames;
    if (!rate && interval == 1)
        return 0;
    return (NSInteger)(CharonDisplayLinkFramesPerSecond / (double)(interval > 1 ? interval : 1));
}

- (void)setPreferredFramesPerSecond:(NSInteger)preferredFramesPerSecond
{
    NSInteger interval = 1;
    if (preferredFramesPerSecond != 0) {
        long rounded = lroundf((float)(1.0 / (charon_display_link_refresh(self) * (double)preferredFramesPerSecond)));
        interval = rounded > 1 ? (NSInteger)rounded : 1;
    }
    [self setFrameInterval:interval];
    CharonDisplayLinkRate *rate = [[CharonDisplayLinkRate alloc] init];
    rate->frames = preferredFramesPerSecond;
    rate->interval = [self frameInterval];
    objc_setAssociatedObject(self, &CharonDisplayLinkRateKey, rate, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (CAFrameRateRange)preferredFrameRateRange
{
    NSValue *boxed = objc_getAssociatedObject(self, &CharonDisplayLinkFrameRateRangeKey);
    CAFrameRateRange range = CAFrameRateRangeDefault;
    if (boxed)
        [boxed getValue:&range];
    return range;
}

// The real header deprecates preferredFramesPerSecond in favor of this property, so this drives
// the same frameInterval mechanism rather than being a second, disconnected store: the preferred
// rate (clamped to [minimum, maximum] when both are given) becomes the target fps, the honest
// answer for a release with one fixed refresh rate and no ProMotion range to actually offer.
- (void)setPreferredFrameRateRange:(CAFrameRateRange)preferredFrameRateRange
{
    NSValue *boxed = [NSValue valueWithBytes:&preferredFrameRateRange objCType:@encode(CAFrameRateRange)];
    objc_setAssociatedObject(self, &CharonDisplayLinkFrameRateRangeKey, boxed, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    float target = preferredFrameRateRange.preferred > 0 ? preferredFrameRateRange.preferred : preferredFrameRateRange.maximum;
    if (target <= 0) {
        [self setPreferredFramesPerSecond:0];
        return;
    }
    if (preferredFrameRateRange.minimum > 0 && target < preferredFrameRateRange.minimum)
        target = preferredFrameRateRange.minimum;
    if (preferredFrameRateRange.maximum > 0 && target > preferredFrameRateRange.maximum)
        target = preferredFrameRateRange.maximum;
    [self setPreferredFramesPerSecond:(NSInteger)lroundf(target)];
}

@end
