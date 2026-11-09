#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>
#import <MediaToolbox/MediaToolbox.h>
#import <objc/message.h>

typedef struct {
    double sum;
    long count;
    int format;
    int bits;
    BOOL interleaved;
} RevenantMeter;

static void revenant_tap_init(MTAudioProcessingTapRef tap, void *clientInfo, void **storage)
{
    *storage = clientInfo;
}

static void revenant_tap_prepare(MTAudioProcessingTapRef tap, CMItemCount maxFrames, const AudioStreamBasicDescription *format)
{
    RevenantMeter *meter = MTAudioProcessingTapGetStorage(tap);
    meter->format = (format->mFormatFlags & kAudioFormatFlagIsFloat) ? 1 : 0;
    meter->bits = (int)format->mBitsPerChannel;
    meter->interleaved = !(format->mFormatFlags & kAudioFormatFlagIsNonInterleaved);
}

static void revenant_tap_unprepare(MTAudioProcessingTapRef tap)
{
}

static void revenant_tap_process(MTAudioProcessingTapRef tap, CMItemCount frames, MTAudioProcessingTapFlags flags, AudioBufferList *list, CMItemCount *framesOut, MTAudioProcessingTapFlags *flagsOut)
{
    if (MTAudioProcessingTapGetSourceAudio(tap, frames, list, flagsOut, NULL, framesOut) != noErr)
        return;
    RevenantMeter *meter = MTAudioProcessingTapGetStorage(tap);
    for (UInt32 buffer = 0; buffer < list->mNumberBuffers; buffer++) {
        const AudioBuffer *audio = &list->mBuffers[buffer];
        if (meter->format == 1 && meter->bits == 32) {
            const float *samples = audio->mData;
            long count = audio->mDataByteSize / 4;
            for (long index = 0; index < count; index++)
                meter->sum += (double)samples[index] * samples[index];
            meter->count += count;
        } else if (meter->bits == 16) {
            const int16_t *samples = audio->mData;
            long count = audio->mDataByteSize / 2;
            for (long index = 0; index < count; index++) {
                double value = samples[index] / 32768.0;
                meter->sum += value * value;
            }
            meter->count += count;
        } else if (meter->bits == 32) {
            const int32_t *samples = audio->mData;
            long count = audio->mDataByteSize / 4;
            for (long index = 0; index < count; index++) {
                double value = samples[index] / 2147483648.0;
                meter->sum += value * value;
            }
            meter->count += count;
        }
    }
}

static NSURL *revenant_tone(void)
{
    static const uint32_t rate = 44100;
    static const uint32_t seconds = 4;
    NSMutableData *wave = [NSMutableData data];
    void (^word)(uint32_t, int) = ^(uint32_t value, int bytes) {
        for (int index = 0; index < bytes; index++) {
            uint8_t byte = (uint8_t)(value >> (8 * index));
            [wave appendBytes:&byte length:1];
        }
    };
    [wave appendBytes:"RIFF" length:4];
    word(36 + rate * 2 * seconds, 4);
    [wave appendBytes:"WAVEfmt " length:8];
    word(16, 4);
    word(1, 2);
    word(1, 2);
    word(rate, 4);
    word(rate * 2, 4);
    word(2, 2);
    word(16, 2);
    [wave appendBytes:"data" length:4];
    word(rate * 2 * seconds, 4);
    for (uint32_t index = 0; index < rate * seconds; index++) {
        int16_t sample = (int16_t)(0.1 * 32767.0 * sin(2.0 * M_PI * 1000.0 * index / rate));
        [wave appendBytes:&sample length:2];
    }
    NSURL *url = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:@"revenant-tone.wav"]];
    [wave writeToURL:url atomically:YES];
    return url;
}

static void revenant_spin(double seconds)
{
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:seconds]];
}

static AVAudioMix *revenant_mix(AVAsset *asset, RevenantMeter *meter, MTAudioProcessingTapRef *tapOut, NSNumber *volume)
{
    AVAssetTrack *track = [asset tracksWithMediaType:AVMediaTypeAudio].firstObject;
    AVMutableAudioMixInputParameters *parameters = [AVMutableAudioMixInputParameters audioMixInputParametersWithTrack:track];
    if (volume)
        [parameters setVolume:volume.floatValue atTime:kCMTimeZero];
    if (meter) {
        MTAudioProcessingTapCallbacks callbacks = {kMTAudioProcessingTapCallbacksVersion_0, meter, revenant_tap_init, NULL, revenant_tap_prepare, revenant_tap_unprepare, revenant_tap_process};
        MTAudioProcessingTapRef tap = NULL;
        OSStatus status = MTAudioProcessingTapCreate(kCFAllocatorDefault, &callbacks, kMTAudioProcessingTapCreationFlag_PostEffects, &tap);
        if (status == noErr) {
            parameters.audioTapProcessor = tap;
            *tapOut = tap;
        } else {
            printf("    tap creation failed %d\n", (int)status);
        }
    }
    AVMutableAudioMix *mix = [AVMutableAudioMix audioMix];
    mix.inputParameters = @[parameters];
    return mix;
}

static void revenant_scenario(const char *label, NSURL *url, NSNumber *mixVolume, NSNumber *adjustment, NSNumber *playerVolume, BOOL meterTap, AVAudioRecorder *recorder)
{
    AVURLAsset *asset = [AVURLAsset URLAssetWithURL:url options:nil];
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    [asset loadValuesAsynchronouslyForKeys:@[@"tracks"] completionHandler:^{
        dispatch_semaphore_signal(semaphore);
    }];
    dispatch_semaphore_wait(semaphore, dispatch_time(DISPATCH_TIME_NOW, 10 * NSEC_PER_SEC));
    RevenantMeter meter = {0, 0, 0, 0, YES};
    MTAudioProcessingTapRef tap = NULL;
    AVPlayerItem *item = [AVPlayerItem playerItemWithAsset:asset];
    if (mixVolume || meterTap)
        item.audioMix = revenant_mix(asset, meterTap ? &meter : NULL, &tap, mixVolume);
    if (adjustment)
        ((void (*)(id, SEL, float))objc_msgSend)(item, NSSelectorFromString(@"setVolumeAdjustment:"), adjustment.floatValue);
    AVPlayer *player = [AVPlayer playerWithPlayerItem:item];
    if (playerVolume)
        ((void (*)(id, SEL, float))objc_msgSend)(player, NSSelectorFromString(@"_setVolume:"), playerVolume.floatValue);
    for (int step = 0; step < 300 && item.status != AVPlayerItemStatusReadyToPlay; step++)
        revenant_spin(0.01);
    [player play];
    revenant_spin(0.6);
    double power = 0;
    int samples = 0;
    long startCount = meter.count;
    double startSum = meter.sum;
    for (int step = 0; step < 20; step++) {
        [recorder updateMeters];
        power += [recorder averagePowerForChannel:0];
        samples++;
        revenant_spin(0.05);
    }
    double window = meter.count - startCount;
    double rms = window > 0 ? sqrt((meter.sum - startSum) / window) : -1;
    printf("  %-34s tap rms %.4f (format %s%d)  mic mean power %.1f dB  adjustment=%.3f\n", label, rms, meter.format ? "float" : "int", meter.bits, power / samples,
           ((float (*)(id, SEL))objc_msgSend)(item, NSSelectorFromString(@"volumeAdjustment")));
    [player pause];
    revenant_spin(0.2);
}

static double revenant_window(AVAudioRecorder *recorder, double seconds)
{
    double power = 0;
    int samples = 0;
    for (double elapsed = 0; elapsed < seconds; elapsed += 0.05) {
        [recorder updateMeters];
        power += [recorder averagePowerForChannel:0];
        samples++;
        revenant_spin(0.05);
    }
    return power / samples;
}

static AVPlayerItem *revenant_loaded_item(NSURL *url)
{
    AVURLAsset *asset = [AVURLAsset URLAssetWithURL:url options:nil];
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    [asset loadValuesAsynchronouslyForKeys:@[@"tracks"] completionHandler:^{
        dispatch_semaphore_signal(semaphore);
    }];
    dispatch_semaphore_wait(semaphore, dispatch_time(DISPATCH_TIME_NOW, 10 * NSEC_PER_SEC));
    return [AVPlayerItem playerItemWithAsset:asset];
}

static void revenant_set(AVPlayerItem *item, float value)
{
    ((void (*)(id, SEL, float))objc_msgSend)(item, NSSelectorFromString(@"setVolumeAdjustment:"), value);
}

static void revenant_live(NSURL *tone, AVAudioRecorder *recorder)
{
    AVPlayerItem *item = revenant_loaded_item(tone);
    AVPlayer *player = [AVPlayer playerWithPlayerItem:item];
    for (int step = 0; step < 300 && item.status != AVPlayerItemStatusReadyToPlay; step++)
        revenant_spin(0.01);
    [player play];
    revenant_spin(0.4);
    printf("  live: adjustment 1 while playing       %.1f dB\n", revenant_window(recorder, 0.5));
    revenant_set(item, 0.25);
    revenant_spin(0.15);
    printf("  live: set 0.25 while playing           %.1f dB\n", revenant_window(recorder, 0.5));
    revenant_set(item, 0.0);
    revenant_spin(0.15);
    printf("  live: set 0 while playing              %.1f dB\n", revenant_window(recorder, 0.5));
    revenant_set(item, 1.0);
    revenant_spin(0.15);
    printf("  live: set 1 again while playing        %.1f dB\n", revenant_window(recorder, 0.5));
    [player pause];
    revenant_spin(0.2);
}

static void revenant_queue(NSURL *tone, AVAudioRecorder *recorder)
{
    AVPlayerItem *first = revenant_loaded_item(tone);
    first.forwardPlaybackEndTime = CMTimeMakeWithSeconds(1.2, 600);
    AVPlayerItem *second = revenant_loaded_item(tone);
    revenant_set(second, 0.25);
    AVQueuePlayer *queue = [AVQueuePlayer queuePlayerWithItems:@[first]];
    for (int step = 0; step < 300 && first.status != AVPlayerItemStatusReadyToPlay; step++)
        revenant_spin(0.01);
    [queue play];
    revenant_spin(0.3);
    [queue insertItem:second afterItem:first];
    printf("  queue: first item (adjustment 1)       %.1f dB\n", revenant_window(recorder, 0.6));
    revenant_spin(0.7);
    printf("  queue: current item is second %s, adjustment %.2f\n", queue.currentItem == second ? "yes" : "no", ((float (*)(id, SEL))objc_msgSend)(second, NSSelectorFromString(@"volumeAdjustment")));
    printf("  queue: second item (adjustment 0.25)   %.1f dB\n", revenant_window(recorder, 0.6));
    [queue pause];
    revenant_spin(0.2);
}

static void revenant_backport(NSURL *tone, AVAudioRecorder *recorder)
{
    struct {
        const char *label;
        float volume;
        BOOL muted;
    } cases[] = {{"backport player.volume 1", 1.0f, NO}, {"backport player.volume 0.5", 0.5f, NO}, {"backport player.volume 0.25", 0.25f, NO}, {"backport player.muted", 1.0f, YES}, {"backport volume 0.5 and muted", 0.5f, YES}};
    for (size_t index = 0; index < sizeof(cases) / sizeof(cases[0]); index++) {
        AVPlayerItem *item = revenant_loaded_item(tone);
        AVPlayer *player = [AVPlayer playerWithPlayerItem:item];
        player.volume = cases[index].volume;
        player.muted = cases[index].muted;
        for (int step = 0; step < 300 && item.status != AVPlayerItemStatusReadyToPlay; step++)
            revenant_spin(0.01);
        [player play];
        revenant_spin(0.6);
        printf("  %-34s mic mean power %.1f dB  adjustment=%.3f\n", cases[index].label, revenant_window(recorder, 1.0), ((float (*)(id, SEL))objc_msgSend)(item, NSSelectorFromString(@"volumeAdjustment")));
        [player pause];
        revenant_spin(0.2);
    }
    AVPlayerItem *item = revenant_loaded_item(tone);
    AVPlayer *player = [AVPlayer playerWithPlayerItem:item];
    for (int step = 0; step < 300 && item.status != AVPlayerItemStatusReadyToPlay; step++)
        revenant_spin(0.01);
    [player play];
    revenant_spin(0.4);
    printf("  %-34s mic mean power %.1f dB\n", "backport live: before", revenant_window(recorder, 0.5));
    player.volume = 0.25f;
    revenant_spin(0.15);
    printf("  %-34s mic mean power %.1f dB\n", "backport live: volume 0.25", revenant_window(recorder, 0.5));
    player.muted = YES;
    revenant_spin(0.15);
    printf("  %-34s mic mean power %.1f dB\n", "backport live: muted", revenant_window(recorder, 0.5));
    player.muted = NO;
    player.volume = 1.0f;
    revenant_spin(0.15);
    printf("  %-34s mic mean power %.1f dB\n", "backport live: volume 1", revenant_window(recorder, 0.5));
    [player pause];
    revenant_spin(0.2);
    AVPlayerItem *first = revenant_loaded_item(tone);
    first.forwardPlaybackEndTime = CMTimeMakeWithSeconds(1.2, 600);
    AVPlayerItem *second = revenant_loaded_item(tone);
    AVQueuePlayer *queue = [AVQueuePlayer queuePlayerWithItems:@[first]];
    queue.volume = 0.25f;
    for (int step = 0; step < 300 && first.status != AVPlayerItemStatusReadyToPlay; step++)
        revenant_spin(0.01);
    [queue play];
    revenant_spin(0.3);
    [queue insertItem:second afterItem:first];
    printf("  %-34s mic mean power %.1f dB\n", "backport queue: first at 0.25", revenant_window(recorder, 0.6));
    revenant_spin(0.7);
    printf("  %-34s mic mean power %.1f dB (current is second: %s)\n", "backport queue: inserted later", revenant_window(recorder, 0.6), queue.currentItem == second ? "yes" : "no");
    [queue pause];
    revenant_spin(0.2);
}

int main(void)
{
    setvbuf(stdout, NULL, _IONBF, 0);
    @autoreleasepool {
        NSError *error = nil;
        AVAudioSession *session = [AVAudioSession sharedInstance];
        [session setCategory:AVAudioSessionCategoryPlayAndRecord error:&error];
        [session overrideOutputAudioPort:AVAudioSessionPortOverrideSpeaker error:&error];
        [session setActive:YES error:&error];
        printf("session error %s, output volume %.3f\n", error ? error.description.UTF8String : "none", session.outputVolume);
        NSURL *recording = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:@"revenant-mic.caf"]];
        NSDictionary *settings = @{AVFormatIDKey: @(kAudioFormatLinearPCM), AVSampleRateKey: @44100.0, AVNumberOfChannelsKey: @1, AVLinearPCMBitDepthKey: @16};
        AVAudioRecorder *recorder = [[AVAudioRecorder alloc] initWithURL:recording settings:settings error:&error];
        recorder.meteringEnabled = YES;
        printf("recorder %s\n", [recorder record] ? "recording" : "failed to record");
        revenant_spin(0.5);
        NSURL *tone = revenant_tone();
        double ambient = 0;
        for (int step = 0; step < 20; step++) {
            [recorder updateMeters];
            ambient += [recorder averagePowerForChannel:0];
            revenant_spin(0.05);
        }
        printf("  %-34s mic mean power %.1f dB\n", "ambient, nothing playing", ambient / 20);
        revenant_scenario("plain item", tone, nil, nil, nil, YES, recorder);
        revenant_scenario("mix volume 0.5", tone, @0.5, nil, nil, YES, recorder);
        revenant_scenario("mix volume 0.25", tone, @0.25, nil, nil, YES, recorder);
        revenant_scenario("mix volume 0", tone, @0.0, nil, nil, YES, recorder);
        revenant_scenario("volumeAdjustment 0.5", tone, nil, @0.5, nil, YES, recorder);
        revenant_scenario("volumeAdjustment 0.25", tone, nil, @0.25, nil, YES, recorder);
        revenant_scenario("volumeAdjustment 0", tone, nil, @0.0, nil, YES, recorder);
        revenant_scenario("volumeAdjustment 2", tone, nil, @2.0, nil, YES, recorder);
        revenant_scenario("mix 0.5 and adjustment 0.5", tone, @0.5, @0.5, nil, YES, recorder);
        revenant_scenario("mix volume 0.75", tone, @0.75, nil, nil, YES, recorder);
        revenant_scenario("volumeAdjustment 0.75", tone, nil, @0.75, nil, YES, recorder);
        revenant_scenario("mix volume 0.1", tone, @0.1, nil, nil, YES, recorder);
        revenant_scenario("volumeAdjustment 0.1", tone, nil, @0.1, nil, YES, recorder);
        revenant_scenario("plain item again", tone, nil, nil, nil, YES, recorder);
        revenant_live(tone, recorder);
        revenant_queue(tone, recorder);
        revenant_backport(tone, recorder);
        [recorder stop];
        [session setActive:NO error:nil];
    }
    return 0;
}
