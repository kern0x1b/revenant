#import <AVFoundation/AVFoundation.h>
#import <objc/runtime.h>

// iOS 14's AVFoundation on 6.1.3: one row of the 29 that this slice carries, and it is applied
// rather than stored. The other 28 are absent with the measurement in each row - see
// facts/AVFoundation/AVFoundation140.md.
//
// AVAssetWriter.preferredOutputSegmentInterval is the target duration of each segment the writer
// AVAssetWriter.h:601 says its default is kCMTimeInvalid, leaving the writer to pick a suitable
// value itself, with a positive numeric value driving the segmentation
// (AVAssetWriter.h:692) and kCMTimeIndefinite leaving it to -flushSegment. 6.1.3's AVAssetWriter
// carries -movieFragmentInterval and -setMovieFragmentInterval: among its 35 own instance methods, and
// that is the release's only segment-duration member: -startSessionAtSourceTime: and
// -endSessionAtSourceTime: are the session boundaries and the interval is what divides them. So a
// positive numeric value is applied there, which is the whole of what this release can do with it, and
// a composition that has set none answers kCMTimeInvalid, which first-rung places at 4.0.

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
    // A positive numeric interval is the one this release can act on: it is the release's own segment
    // duration, and AVAssetWriter.h:692 says a numeric value is what makes the writer emit a segment
    // every interval. kCMTimeIndefinite has nothing on this release to apply itself to - the method
    // that would consume it, -flushSegment, is 14.0's and this release has no segments to flush.
    if (CMTIME_IS_NUMERIC(preferredOutputSegmentInterval))
        [self setMovieFragmentInterval:preferredOutputSegmentInterval];
}

@end