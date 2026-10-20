#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>
#include <math.h>

static const double RevenantDisplayLinkFramesPerSecond = 60.0;

static const char RevenantDisplayLinkRateKey;
static const char RevenantDisplayLinkFrameRateRangeKey;

@interface RevenantDisplayLinkRate : NSObject {
@public
    NSInteger frames;
    NSInteger interval;
}
@end

@implementation RevenantDisplayLinkRate
@end

static double revenant_display_link_refresh(CADisplayLink *link)
{
    CFTimeInterval duration = [link duration];
    return duration > 0 ? (double)duration : 1.0 / RevenantDisplayLinkFramesPerSecond;
}

@implementation CADisplayLink (RevenantFrameRate)

- (CFTimeInterval)targetTimestamp
{
    return [self timestamp] + [self duration] * (double)[self frameInterval];
}

- (NSInteger)preferredFramesPerSecond
{
    RevenantDisplayLinkRate *rate = objc_getAssociatedObject(self, &RevenantDisplayLinkRateKey);
    NSInteger interval = [self frameInterval];
    if (rate && rate->interval == interval)
        return rate->frames;
    if (!rate && interval == 1)
        return 0;
    return (NSInteger)(RevenantDisplayLinkFramesPerSecond / (double)(interval > 1 ? interval : 1));
}

- (void)setPreferredFramesPerSecond:(NSInteger)preferredFramesPerSecond
{
    NSInteger interval = 1;
    if (preferredFramesPerSecond != 0) {
        long rounded = lroundf((float)(1.0 / (revenant_display_link_refresh(self) * (double)preferredFramesPerSecond)));
        interval = rounded > 1 ? (NSInteger)rounded : 1;
    }
    [self setFrameInterval:interval];
    RevenantDisplayLinkRate *rate = [[RevenantDisplayLinkRate alloc] init];
    rate->frames = preferredFramesPerSecond;
    rate->interval = [self frameInterval];
    objc_setAssociatedObject(self, &RevenantDisplayLinkRateKey, rate, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (CAFrameRateRange)preferredFrameRateRange
{
    NSValue *boxed = objc_getAssociatedObject(self, &RevenantDisplayLinkFrameRateRangeKey);
    CAFrameRateRange range = CAFrameRateRangeDefault;
    if (boxed)
        [boxed getValue:&range];
    return range;
}

- (void)setPreferredFrameRateRange:(CAFrameRateRange)preferredFrameRateRange
{
    NSValue *boxed = [NSValue valueWithBytes:&preferredFrameRateRange objCType:@encode(CAFrameRateRange)];
    objc_setAssociatedObject(self, &RevenantDisplayLinkFrameRateRangeKey, boxed, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
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
