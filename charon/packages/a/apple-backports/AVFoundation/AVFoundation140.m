#import <AVFoundation/AVFoundation.h>
#import <objc/runtime.h>

static const char charon_preferred_segment_interval_key;

@implementation AVAssetWriter (CharonAVFoundationPreferredSegmentInterval)

- (CMTime)preferredOutputSegmentInterval
{
    NSValue *stored = objc_getAssociatedObject(self, &charon_preferred_segment_interval_key);
    return stored ? stored.CMTimeValue : kCMTimeInvalid;
}

- (void)setPreferredOutputSegmentInterval:(CMTime)preferredOutputSegmentInterval
{
    objc_setAssociatedObject(self, &charon_preferred_segment_interval_key,
                             [NSValue valueWithCMTime:preferredOutputSegmentInterval], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if (CMTIME_IS_NUMERIC(preferredOutputSegmentInterval))
        [self setMovieFragmentInterval:preferredOutputSegmentInterval];
}

@end
