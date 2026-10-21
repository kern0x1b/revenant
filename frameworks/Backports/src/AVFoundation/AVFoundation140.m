#import <AVFoundation/AVFoundation.h>
#import <objc/runtime.h>

static const char revenant_preferred_segment_interval_key;

@implementation AVAssetWriter (RevenantAVFoundationPreferredSegmentInterval)

- (CMTime)preferredOutputSegmentInterval
{
    NSValue *stored = objc_getAssociatedObject(self, &revenant_preferred_segment_interval_key);
    return stored ? stored.CMTimeValue : kCMTimeInvalid;
}

- (void)setPreferredOutputSegmentInterval:(CMTime)preferredOutputSegmentInterval
{
    objc_setAssociatedObject(self, &revenant_preferred_segment_interval_key,
                             [NSValue valueWithCMTime:preferredOutputSegmentInterval], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if (CMTIME_IS_NUMERIC(preferredOutputSegmentInterval))
        [self setMovieFragmentInterval:preferredOutputSegmentInterval];
}

@end
