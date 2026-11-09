#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>
#import <objc/runtime.h>

static const char revenant_track_min_frame_duration_key;

static BOOL revenant_track_is_visual(AVAssetTrack *track)
{
    return [track.mediaType isEqualToString:AVMediaTypeVideo] || [track hasMediaCharacteristic:AVMediaCharacteristicVisual];
}

static CMTime revenant_shortest_sample_duration(AVAssetTrack *track)
{
    AVAsset *asset = track.asset;
    if (!asset)
        return kCMTimeInvalid;
    AVAssetReader *reader = [AVAssetReader assetReaderWithAsset:asset error:NULL];
    AVAssetReaderTrackOutput *output = [AVAssetReaderTrackOutput assetReaderTrackOutputWithTrack:track outputSettings:nil];
    if (!reader || !output || ![reader canAddOutput:output])
        return kCMTimeInvalid;
    output.alwaysCopiesSampleData = NO;
    [reader addOutput:output];
    if (![reader startReading])
        return kCMTimeInvalid;
    CMTime shortest = kCMTimeInvalid;
    while (true) {
        CMSampleBufferRef sample = [output copyNextSampleBuffer];
        if (!sample)
            break;
        CMTime duration = CMSampleBufferGetDuration(sample);
        CFRelease(sample);
        if (CMTIME_IS_NUMERIC(duration) && CMTimeCompare(duration, kCMTimeZero) > 0 && (CMTIME_IS_INVALID(shortest) || CMTimeCompare(duration, shortest) < 0))
            shortest = duration;
    }
    return reader.status == AVAssetReaderStatusCompleted ? shortest : kCMTimeInvalid;
}

@implementation AVAssetTrack (RevenantAVFoundationFrameDuration)

- (CMTime)minFrameDuration
{
    NSValue *cached = objc_getAssociatedObject(self, &revenant_track_min_frame_duration_key);
    if (cached)
        return cached.CMTimeValue;
    CMTime duration = revenant_track_is_visual(self) ? revenant_shortest_sample_duration(self) : kCMTimeInvalid;
    objc_setAssociatedObject(self, &revenant_track_min_frame_duration_key, [NSValue valueWithCMTime:duration], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return duration;
}

@end

static CMTime revenant_segment_frame_duration(AVCompositionTrackSegment *segment, NSMutableDictionary<NSString *, NSValue *> *sources)
{
    NSString *key = [NSString stringWithFormat:@"%@#%d", segment.sourceURL.absoluteString, (int)segment.sourceTrackID];
    NSValue *known = sources[key];
    if (!known) {
        AVURLAsset *asset __attribute__((objc_precise_lifetime)) = [AVURLAsset URLAssetWithURL:segment.sourceURL options:nil];
        AVAssetTrack *source = [asset trackWithTrackID:segment.sourceTrackID];
        known = [NSValue valueWithCMTime:source ? source.minFrameDuration : kCMTimeInvalid];
        sources[key] = known;
    }
    CMTime duration = known.CMTimeValue;
    CMTimeMapping mapping = segment.timeMapping;
    Float64 original = CMTimeGetSeconds(mapping.source.duration);
    Float64 placed = CMTimeGetSeconds(mapping.target.duration);
    if (CMTIME_IS_VALID(duration) && original > 0.0 && placed > 0.0 && isfinite(original) && isfinite(placed))
        return CMTimeMultiplyByFloat64(duration, placed / original);
    return duration;
}

@implementation AVCompositionTrack (RevenantAVFoundationFrameDuration)

- (CMTime)minFrameDuration
{
    if (!revenant_track_is_visual(self))
        return kCMTimeInvalid;
    NSMutableDictionary<NSString *, NSValue *> *sources = [NSMutableDictionary dictionary];
    CMTime shortest = kCMTimeInvalid;
    for (AVCompositionTrackSegment *segment in self.segments) {
        if (segment.isEmpty || !segment.sourceURL)
            continue;
        CMTime duration = revenant_segment_frame_duration(segment, sources);
        if (CMTIME_IS_NUMERIC(duration) && CMTimeCompare(duration, kCMTimeZero) > 0 && (CMTIME_IS_INVALID(shortest) || CMTimeCompare(duration, shortest) < 0))
            shortest = duration;
    }
    return shortest;
}

@end
