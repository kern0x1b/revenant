#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>
#import "check.h"

static NSURL *revenant_silence(void)
{
    static const uint32_t rate = 8000;
    NSMutableData *wave = [NSMutableData data];
    void (^word)(uint32_t, int) = ^(uint32_t value, int bytes) {
        for (int index = 0; index < bytes; index++) {
            uint8_t byte = (uint8_t)(value >> (8 * index));
            [wave appendBytes:&byte length:1];
        }
    };
    [wave appendBytes:"RIFF" length:4];
    word(36 + rate * 2, 4);
    [wave appendBytes:"WAVEfmt " length:8];
    word(16, 4);
    word(1, 2);
    word(1, 2);
    word(rate, 4);
    word(rate * 2, 4);
    word(2, 2);
    word(16, 2);
    [wave appendBytes:"data" length:4];
    word(rate * 2, 4);
    [wave appendData:[NSMutableData dataWithLength:rate * 2]];
    NSURL *url = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"revenant-silence-%@.wav", [[NSUUID UUID] UUIDString]]]];
    [wave writeToURL:url atomically:YES];
    return url;
}

static BOOL revenant_wait(BOOL (^done)(void))
{
    for (int step = 0; step < 1000; step++) {
        if (done())
            return YES;
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
    }
    return done();
}

static AVPlayerItem *revenant_item(NSURL *url, BOOL loaded)
{
    AVURLAsset *asset = [AVURLAsset URLAssetWithURL:url options:nil];
    if (loaded) {
        dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
        [asset loadValuesAsynchronouslyForKeys:@[@"tracks"] completionHandler:^{
            dispatch_semaphore_signal(semaphore);
        }];
        dispatch_semaphore_wait(semaphore, dispatch_time(DISPATCH_TIME_NOW, 10 * NSEC_PER_SEC));
    }
    return [AVPlayerItem playerItemWithAsset:asset];
}

static BOOL revenant_ramp(AVAudioMix *mix, double seconds, float *start, float *end)
{
    AVAudioMixInputParameters *parameters = mix.inputParameters.firstObject;
    CMTimeRange range;
    return [parameters getVolumeRampForTime:CMTimeMakeWithSeconds(seconds, 600) startVolume:start endVolume:end timeRange:&range];
}

static BOOL revenant_gain(AVPlayerItem *item, double seconds, float expected)
{
    float start = -1, end = -1;
    return item.audioMix && revenant_ramp(item.audioMix, seconds, &start, &end) && fabsf(start - expected) < 1e-4f && fabsf(end - expected) < 1e-4f;
}

static AVAudioMix *revenant_base_mix(AVPlayerItem *item)
{
    AVAssetTrack *track = [item.asset tracksWithMediaType:AVMediaTypeAudio].firstObject;
    AVMutableAudioMixInputParameters *parameters = [AVMutableAudioMixInputParameters audioMixInputParametersWithTrack:track];
    [parameters setVolumeRampFromStartVolume:0.2f toEndVolume:0.8f timeRange:CMTimeRangeMake(kCMTimeZero, CMTimeMake(1, 4))];
    [parameters setVolume:0.5f atTime:CMTimeMake(1, 4)];
    AVMutableAudioMix *mix = [AVMutableAudioMix audioMix];
    mix.inputParameters = @[parameters];
    return mix;
}

int main(int argc, char **argv)
{
    revenant_read_arguments(argc, argv);
    @autoreleasepool {
        NSURL *url = revenant_silence();
        AVPlayerItem *item = revenant_item(url, YES);
        AVPlayer *player = [AVPlayer playerWithPlayerItem:item];
        revenant_check((player.volume == 1.0f && !player.isMuted && item.audioMix == nil) != revenant_negative, "a new player is at full volume, unmuted, and leaves the item's audio mix alone", @"the defaults differ");

        player.volume = 2.0f;
        BOOL high = player.volume == 1.0f;
        player.volume = -1.0f;
        BOOL low = player.volume == 0.0f;
        player.volume = 1.0f;
        revenant_check((high && low && item.audioMix == nil) != revenant_negative, "a volume outside zero to one is clamped and full volume needs no audio mix", @"the clamp or the reset differs");

        player.volume = 0.5f;
        revenant_check(revenant_gain(item, 0.0, 0.5f) != revenant_negative, "a volume of one half sets the gain of the item's audio track to one half", @"the gain is not one half");
        revenant_check((player.volume == 0.5f) != revenant_negative, "the volume reads back as set", @"the volume differs");

        player.muted = YES;
        revenant_check((revenant_gain(item, 0.0, 0.0f) && player.volume == 0.5f && player.isMuted) != revenant_negative, "muting silences the track and keeps the volume that the player returns to", @"the mute differs");
        player.muted = NO;
        revenant_check(revenant_gain(item, 0.0, 0.5f) != revenant_negative, "unmuting restores the volume", @"the gain was not restored");

        player.volume = 1.0f;
        revenant_check((item.audioMix == nil) != revenant_negative, "returning to full volume removes the audio mix that the player added", @"an audio mix stayed");

        AVPlayerItem *late = revenant_item(revenant_silence(), NO);
        AVPlayer *waiting = [AVPlayer playerWithPlayerItem:late];
        waiting.volume = 0.25f;
        BOOL arrived = revenant_wait(^BOOL {
            return revenant_gain(late, 0.0, 0.25f);
        });
        revenant_check(arrived != revenant_negative, "an item whose tracks load later gets the gain once they have loaded", @"the gain never arrived");

        AVPlayerItem *scaled = revenant_item(url, YES);
        scaled.audioMix = revenant_base_mix(scaled);
        AVPlayer *composed = [AVPlayer playerWithPlayerItem:scaled];
        composed.volume = 0.5f;
        float start = -1, end = -1;
        BOOL ramp = revenant_ramp(scaled.audioMix, 0.0, &start, &end) && fabsf(start - 0.1f) < 1e-4f && fabsf(end - 0.4f) < 1e-4f;
        revenant_check((ramp && revenant_gain(scaled, 0.5, 0.25f)) != revenant_negative, "an audio mix of the app is scaled by the volume, ramps included", @"the app's ramps were not scaled");
        composed.volume = 1.0f;
        start = -1;
        BOOL restored = scaled.audioMix && revenant_ramp(scaled.audioMix, 0.0, &start, &end) && fabsf(start - 0.2f) < 1e-4f && fabsf(end - 0.8f) < 1e-4f && revenant_gain(scaled, 0.5, 0.5f);
        revenant_check(restored != revenant_negative, "full volume gives the app's audio mix back as it was", @"the app's mix changed");

        AVMutableAudioMixInputParameters *flat = [AVMutableAudioMixInputParameters audioMixInputParametersWithTrack:[scaled.asset tracksWithMediaType:AVMediaTypeAudio].firstObject];
        [flat setVolume:0.8f atTime:kCMTimeZero];
        AVMutableAudioMix *replacement = [AVMutableAudioMix audioMix];
        replacement.inputParameters = @[flat];
        composed.volume = 0.5f;
        scaled.audioMix = replacement;
        composed.volume = 0.25f;
        revenant_check(revenant_gain(scaled, 0.0, 0.2f) != revenant_negative, "an audio mix that the app sets later takes the place of the earlier one under the new volume", @"the new mix was not scaled");
        composed.volume = 1.0f;

        AVPlayerItem *next = revenant_item(url, YES);
        AVPlayerItem *old = revenant_item(url, YES);
        AVPlayer *swapping = [AVPlayer playerWithPlayerItem:old];
        swapping.volume = 0.5f;
        BOOL applied = revenant_gain(old, 0.0, 0.5f);
        [swapping replaceCurrentItemWithPlayerItem:next];
        revenant_check((applied && revenant_gain(next, 0.0, 0.5f) && old.audioMix == nil) != revenant_negative, "replacing the item moves the volume to the new item and frees the old one", @"the item swap differs");

        AVPlayerItem *kept = revenant_item(url, YES);
        @autoreleasepool {
            AVPlayer *gone = [AVPlayer playerWithPlayerItem:kept];
            gone.muted = YES;
            applied = revenant_gain(kept, 0.0, 0.0f);
        }
        BOOL freed = revenant_wait(^BOOL {
            return kept.audioMix == nil;
        });
        revenant_check((applied && freed) != revenant_negative, "an item that outlives its muted player is not left muted", @"the item stayed muted");

        AVPlayerItem *first = revenant_item(url, YES);
        AVPlayerItem *second = revenant_item(url, YES);
        AVQueuePlayer *queue = [AVQueuePlayer queuePlayerWithItems:@[first]];
        queue.volume = 0.5f;
        [queue insertItem:second afterItem:first];
        BOOL both = revenant_gain(first, 0.0, 0.5f) && revenant_gain(second, 0.0, 0.5f);
        [queue removeItem:second];
        BOOL removed = second.audioMix == nil && revenant_gain(first, 0.0, 0.5f);
        [queue removeAllItems];
        revenant_check((both && removed && first.audioMix == nil) != revenant_negative, "a queue player applies the volume to every queued item and frees the ones that leave", @"the queue differs");
    }
    return revenant_finish();
}
