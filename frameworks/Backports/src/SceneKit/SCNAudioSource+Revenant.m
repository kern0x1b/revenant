#import "RevenantSCNAudio.h"
#import "RevenantSCNSoundEngine.h"
#import <objc/runtime.h>

static const void *RevenantSCNAudioSourceMonoBufferKey = &RevenantSCNAudioSourceMonoBufferKey;
static const void *RevenantSCNAudioSourceStereoBufferKey = &RevenantSCNAudioSourceStereoBufferKey;
static const void *RevenantSCNAudioSourceSampleRateKey = &RevenantSCNAudioSourceSampleRateKey;
static const void *RevenantSCNAudioSourceFramesKey = &RevenantSCNAudioSourceFramesKey;
static const void *RevenantSCNAudioSourceURLKey = &RevenantSCNAudioSourceURLKey;

@implementation SCNAudioSource (RevenantSCNAudio)

- (NSURL *)revenantURL
{
    // Try to get URL from system class using KVC (looks for _audioURL)
    NSURL *url = [self valueForKey:@"audioURL"];
    if (url) {
        return url;
    }
    // Fallback: try to get from associated object (for Backports instances)
    return objc_getAssociatedObject(self, RevenantSCNAudioSourceURLKey);
}

- (void)setRevenantURL:(NSURL *)url
{
    objc_setAssociatedObject(self, RevenantSCNAudioSourceURLKey, url, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (unsigned int)revenantMonoBuffer
{
    NSNumber *value = objc_getAssociatedObject(self, RevenantSCNAudioSourceMonoBufferKey);
    return value ? value.unsignedIntValue : 0;
}

- (void)setRevenantMonoBuffer:(unsigned int)buffer
{
    objc_setAssociatedObject(self, RevenantSCNAudioSourceMonoBufferKey, @(buffer), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (unsigned int)revenantStereoBuffer
{
    NSNumber *value = objc_getAssociatedObject(self, RevenantSCNAudioSourceStereoBufferKey);
    return value ? value.unsignedIntValue : 0;
}

- (void)setRevenantStereoBuffer:(unsigned int)buffer
{
    objc_setAssociatedObject(self, RevenantSCNAudioSourceStereoBufferKey, @(buffer), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (double)revenantSampleRate
{
    NSNumber *value = objc_getAssociatedObject(self, RevenantSCNAudioSourceSampleRateKey);
    return value ? value.doubleValue : 0;
}

- (void)setRevenantSampleRate:(double)sampleRate
{
    objc_setAssociatedObject(self, RevenantSCNAudioSourceSampleRateKey, @(sampleRate), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (unsigned long long)revenantFrames
{
    NSNumber *value = objc_getAssociatedObject(self, RevenantSCNAudioSourceFramesKey);
    return value ? value.unsignedLongLongValue : 0;
}

- (void)setRevenantFrames:(unsigned long long)frames
{
    objc_setAssociatedObject(self, RevenantSCNAudioSourceFramesKey, @(frames), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (unsigned int)revenantBufferForSpatial:(BOOL)spatial
{
    unsigned int buffer = spatial ? [self revenantMonoBuffer] : [self revenantStereoBuffer];
    if (buffer == 0) {
        [RevenantSCNSoundEngine prepare];
        double sampleRate = 0;
        unsigned long long frames = 0;
        NSURL *url = [self revenantURL];
        NSData *pcm = [RevenantSCNSoundEngine decodeURL:url channels:spatial ? 1 : 2 sampleRate:&sampleRate frames:&frames];
        if (pcm == nil) {
            [NSException raise:NSInvalidArgumentException format:@"SCNAudioSource: %@ cannot be decoded", url];
        }
        buffer = [RevenantSCNSoundEngine newBuffer:pcm channels:spatial ? 1 : 2 sampleRate:sampleRate];
        if (spatial) {
            [self setRevenantMonoBuffer:buffer];
        } else {
            [self setRevenantStereoBuffer:buffer];
        }
        [self setRevenantSampleRate:sampleRate];
        [self setRevenantFrames:frames];
    }
    return buffer;
}

- (double)revenantDuration
{
    if (self.shouldStream) {
        double sampleRate = 0;
        unsigned long long frames = 0;
        NSURL *url = [self revenantURL];
        return url && [RevenantSCNSoundEngine probeURL:url sampleRate:&sampleRate frames:&frames] && sampleRate > 0 ? (double)frames / sampleRate : 0;
    }
    if ([self revenantSampleRate] <= 0) {
        [self revenantBufferForSpatial:YES];
    }
    return [self revenantSampleRate] > 0 ? (double)[self revenantFrames] / [self revenantSampleRate] : 0;
}

- (NSData *)revenantData
{
    return nil;
}

@end