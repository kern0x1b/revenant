#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>
#import <objc/runtime.h>
#import "check.h"

@interface AVPlayerItem (RevenantVolumeAdjustment)
- (float)volumeAdjustment;
- (void)setVolumeAdjustment:(float)volumeAdjustment;
@end

#if !TARGET_OS_IPHONE
static const char revenant_adjustment_key;

@implementation AVPlayerItem (RevenantHostVolumeAdjustment)

- (float)volumeAdjustment
{
    NSNumber *value = objc_getAssociatedObject(self, &revenant_adjustment_key);
    return value ? value.floatValue : 1.0f;
}

- (void)setVolumeAdjustment:(float)volumeAdjustment
{
    objc_setAssociatedObject(self, &revenant_adjustment_key, @(volumeAdjustment), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
#endif

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

static BOOL revenant_adjusted(AVPlayerItem *item, float expected)
{
    return fabsf(item.volumeAdjustment - expected) < 1e-5f;
}

static AVAudioMix *revenant_base_mix(AVPlayerItem *item)
{
    AVAssetTrack *track = [item.asset tracksWithMediaType:AVMediaTypeAudio].firstObject;
    AVMutableAudioMixInputParameters *parameters = [AVMutableAudioMixInputParameters audioMixInputParametersWithTrack:track];
    [parameters setVolume:0.5f atTime:kCMTimeZero];
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
        revenant_check((player.volume == 1.0f && !player.isMuted && revenant_adjusted(item, 1.0f) && item.audioMix == nil) != revenant_negative, "a new player is at full volume, unmuted, and leaves the item alone", @"the defaults differ");

        player.volume = 2.0f;
        BOOL high = player.volume == 1.0f;
        player.volume = -1.0f;
        BOOL low = player.volume == 0.0f;
        player.volume = 1.0f;
        revenant_check((high && low && revenant_adjusted(item, 1.0f)) != revenant_negative, "a volume outside zero to one is clamped and full volume leaves the item's own gain", @"the clamp or the reset differs");

        player.volume = 0.5f;
        revenant_check(revenant_adjusted(item, 0.5f) != revenant_negative, "a volume of one half sets the gain of the item to one half", @"the gain is not one half");
        revenant_check((player.volume == 0.5f) != revenant_negative, "the volume reads back as set", @"the volume differs");

        player.muted = YES;
        revenant_check((revenant_adjusted(item, 0.0f) && player.volume == 0.5f && player.isMuted) != revenant_negative, "muting silences the item and keeps the volume that the player returns to", @"the mute differs");
        player.muted = NO;
        revenant_check(revenant_adjusted(item, 0.5f) != revenant_negative, "unmuting restores the volume", @"the gain was not restored");

        player.volume = 1.0f;
        revenant_check((revenant_adjusted(item, 1.0f) && item.audioMix == nil) != revenant_negative, "returning to full volume gives the item its own gain back", @"the gain stayed");

        AVPlayerItem *late = revenant_item(revenant_silence(), NO);
        AVPlayer *waiting = [AVPlayer playerWithPlayerItem:late];
        waiting.volume = 0.25f;
        revenant_check(revenant_adjusted(late, 0.25f) != revenant_negative, "an item whose tracks have not loaded gets the gain at once", @"the gain did not arrive");

        AVPlayerItem *mixed = revenant_item(url, YES);
        AVAudioMix *own = revenant_base_mix(mixed);
        mixed.audioMix = own;
        AVAudioMix *stored = mixed.audioMix;
        AVPlayer *composed = [AVPlayer playerWithPlayerItem:mixed];
        composed.volume = 0.5f;
        composed.muted = YES;
        composed.muted = NO;
        BOOL untouched = mixed.audioMix == stored && revenant_adjusted(mixed, 0.5f);
        composed.volume = 1.0f;
        revenant_check((untouched && mixed.audioMix == stored && revenant_adjusted(mixed, 1.0f)) != revenant_negative, "the audio mix of the app is never replaced or scaled", @"the app's mix changed");

        AVPlayerItem *tuned = revenant_item(url, YES);
        tuned.volumeAdjustment = 0.8f;
        AVPlayer *scaling = [AVPlayer playerWithPlayerItem:tuned];
        scaling.volume = 0.5f;
        BOOL scaled = revenant_adjusted(tuned, 0.4f);
        scaling.volume = 1.0f;
        revenant_check((scaled && revenant_adjusted(tuned, 0.8f)) != revenant_negative, "the gain multiplies the gain the item had and gives it back at full volume", @"the item's own gain was lost");

        AVPlayerItem *next = revenant_item(url, YES);
        AVPlayerItem *old = revenant_item(url, YES);
        AVPlayer *swapping = [AVPlayer playerWithPlayerItem:old];
        swapping.volume = 0.5f;
        BOOL applied = revenant_adjusted(old, 0.5f);
        [swapping replaceCurrentItemWithPlayerItem:next];
        revenant_check((applied && revenant_adjusted(next, 0.5f) && revenant_adjusted(old, 1.0f)) != revenant_negative, "replacing the item moves the volume to the new item and frees the old one", @"the item swap differs");

        AVPlayerItem *kept = revenant_item(url, YES);
        @autoreleasepool {
            AVPlayer *gone = [AVPlayer playerWithPlayerItem:kept];
            gone.muted = YES;
            applied = revenant_adjusted(kept, 0.0f);
        }
        BOOL freed = revenant_wait(^BOOL {
            return revenant_adjusted(kept, 1.0f);
        });
        revenant_check((applied && freed) != revenant_negative, "an item that outlives its muted player is not left muted", @"the item stayed muted");

        AVPlayerItem *first = revenant_item(url, YES);
        AVPlayerItem *second = revenant_item(url, YES);
        AVQueuePlayer *queue = [AVQueuePlayer queuePlayerWithItems:@[first]];
        queue.volume = 0.5f;
        [queue insertItem:second afterItem:first];
        BOOL both = revenant_adjusted(first, 0.5f) && revenant_adjusted(second, 0.5f);
        [queue removeItem:second];
        BOOL removed = revenant_adjusted(second, 1.0f) && revenant_adjusted(first, 0.5f);
        [queue removeAllItems];
        revenant_check((both && removed && revenant_adjusted(first, 1.0f)) != revenant_negative, "a queue player applies the volume to every queued item and frees the ones that leave", @"the queue differs");

        AVPlayerItem *front = revenant_item(url, YES);
        AVPlayerItem *back = revenant_item(url, YES);
        AVQueuePlayer *advancing = [AVQueuePlayer queuePlayerWithItems:@[front, back]];
        advancing.muted = YES;
        BOOL silenced = revenant_adjusted(front, 0.0f) && revenant_adjusted(back, 0.0f);
        [advancing advanceToNextItem];
        revenant_check((silenced && revenant_adjusted(front, 1.0f) && revenant_adjusted(back, 0.0f)) != revenant_negative, "advancing a muted queue frees the finished item and keeps the next one silent", @"the advance differs");
    }
    return revenant_finish();
}
