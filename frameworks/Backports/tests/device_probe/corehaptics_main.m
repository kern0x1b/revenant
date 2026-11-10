#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreHaptics/CoreHaptics.h>
#import <CoreMotion/CoreMotion.h>
#import <CoreMedia/CoreMedia.h>
#import <Foundation/Foundation.h>
#include <dlfcn.h>
#include <math.h>
#include <stdio.h>
#include <string.h>

#define REVENANT_SAMPLE_HZ 100.0
#define REVENANT_SAMPLE_MAX 8192
#define REVENANT_MICROPHONE_PERIOD 0.005
#define REVENANT_MICROPHONE_BUCKETS 40
#define REVENANT_MICROPHONE_REPEATS 7

typedef struct {
    NSTimeInterval time;
    double x;
    double y;
    double z;
    double magnitude;
} RevenantSample;

static RevenantSample revenant_samples[REVENANT_SAMPLE_MAX];
static int revenant_sample_count;
static int revenant_sample_dropped;

static void *revenant_symbol(const char *library, const char *name)
{
    void *handle = dlopen(library, RTLD_LAZY);
    return handle ? dlsym(handle, name) : NULL;
}

static void revenant_sample(CMAccelerometerData *data, NSError *error)
{
    if (!data) {
        revenant_sample_dropped++;
        return;
    }
    if (revenant_sample_count >= REVENANT_SAMPLE_MAX) {
        revenant_sample_dropped++;
        return;
    }
    CMAcceleration acceleration = data.acceleration;
    RevenantSample *sample = &revenant_samples[revenant_sample_count++];
    sample->time = [NSDate timeIntervalSinceReferenceDate];
    sample->x = acceleration.x;
    sample->y = acceleration.y;
    sample->z = acceleration.z;
    sample->magnitude = sqrt(acceleration.x * acceleration.x + acceleration.y * acceleration.y + acceleration.z * acceleration.z);
}

static void revenant_wait(NSTimeInterval seconds)
{
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:seconds]];
}

static void revenant_report(const char *label, NSTimeInterval started, double threshold)
{
    double peak = 0.0;
    NSTimeInterval first = -1.0;
    NSTimeInterval last = -1.0;
    int above = 0;
    int in_window = 0;
    for (int index = 0; index < revenant_sample_count; index++) {
        RevenantSample *sample = &revenant_samples[index];
        if (sample->time < started - 0.05 || sample->time > started + 2.0)
            continue;
        in_window++;
        double deviation = fabs(sample->magnitude - 1.0);
        if (deviation > peak)
            peak = deviation;
        if (sample->magnitude > threshold) {
            above++;
            if (first < 0.0)
                first = sample->time;
            last = sample->time;
        }
    }
    printf("%-28s samples=%d above=%d first_ms=%.0f last_ms=%.0f span_ms=%.0f peak_deviation=%.5f\n", label, in_window, above,
           first < 0.0 ? -1.0 : (first - started) * 1000.0, last < 0.0 ? -1.0 : (last - started) * 1000.0,
           first < 0.0 || last < 0.0 ? 0.0 : (last - first) * 1000.0, peak);
}

static void revenant_microphone_profile(AVAudioRecorder *recorder, float *buckets)
{
    for (int index = 0; index < REVENANT_MICROPHONE_BUCKETS; index++)
        buckets[index] = -160.0f;
    for (int sample = 0; sample < 300; sample++) {
        [recorder updateMeters];
        float decibels = [recorder averagePowerForChannel:0];
        int bucket = sample / 8;
        if (bucket < REVENANT_MICROPHONE_BUCKETS)
            buckets[bucket] = MAX(buckets[bucket], decibels);
        revenant_wait(REVENANT_MICROPHONE_PERIOD);
    }
}

static int revenant_compare_float(const void *left, const void *right)
{
    float a = *(const float *)left;
    float b = *(const float *)right;
    if (a < b)
        return -1;
    if (a > b)
        return 1;
    return 0;
}

static void revenant_microphone_median(const float *profiles, int repeats, float *buckets)
{
    float values[REVENANT_MICROPHONE_REPEATS];
    for (int bucket = 0; bucket < REVENANT_MICROPHONE_BUCKETS; bucket++) {
        for (int repeat = 0; repeat < repeats; repeat++)
            values[repeat] = profiles[repeat * REVENANT_MICROPHONE_BUCKETS + bucket];
        qsort(values, repeats, sizeof(float), revenant_compare_float);
        buckets[bucket] = values[repeats / 2];
    }
}

static void revenant_vibrator_facts(void)
{
    int (*available)(void) = revenant_symbol("/System/Library/Frameworks/CoreMedia.framework/CoreMedia", "FigVibratorIsVibratorAvailable");
    printf("vibrator_available_symbol=%s\n", available ? "yes" : "no");
    if (available)
        printf("vibrator_available=%d\n", available());

    int (*durations)(CMTime *, CMTime *) = revenant_symbol("/System/Library/Frameworks/CoreMedia.framework/CoreMedia", "FigVibratorGetMinMaxDurations");
    CMTime low = {0, 1, kCMTimeFlags_Valid, 0};
    CMTime high = {0, 1, kCMTimeFlags_Valid, 0};
    int result = durations ? durations(&low, &high) : -1;
    printf("durations_result=%d min=%lld/%d max=%lld/%d\n", result, (long long)low.value, low.timescale, (long long)high.value, high.timescale);

    printf("fig_stop_symbol=%s\n", revenant_symbol("/System/Library/Frameworks/CoreMedia.framework/CoreMedia", "FigVibratorStop") ? "yes" : "no");
    printf("play_with_vibration_symbol=%s\n",
           revenant_symbol("/System/Library/Frameworks/AudioToolbox.framework/AudioToolbox", "AudioServicesPlaySystemSoundWithVibration") ? "yes" : "no");
}

static void revenant_corehaptics_api(void)
{
    id<CHHapticDeviceCapability> capability = [CHHapticEngine capabilitiesForHardware];
    printf("capability supportsHaptics=%d supportsAudio=%d\n", capability.supportsHaptics, capability.supportsAudio);

    NSError *error = nil;
    CHHapticEngine *engine = [[CHHapticEngine alloc] initAndReturnError:&error];
    printf("engine=%s error=%s\n", engine ? "yes" : "no", error ? error.description.UTF8String : "none");
    if (!engine)
        return;
    printf("engine start=%d\n", [engine startAndReturnError:&error]);
    printf("engine start_error=%s\n", error ? error.description.UTF8String : "none");

    CHHapticEventParameter *intensity = [[CHHapticEventParameter alloc] initWithParameterID:CHHapticEventParameterIDHapticIntensity value:1.0f];
    CHHapticEvent *event = [[CHHapticEvent alloc] initWithEventType:CHHapticEventTypeHapticContinuous
                                                          parameters:@[intensity]
                                                        relativeTime:0.0
                                                            duration:0.5];
    CHHapticPattern *pattern = [[CHHapticPattern alloc] initWithEvents:@[event] parameters:@[] error:&error];
    printf("pattern=%s duration=%.3f error=%s\n", pattern ? "yes" : "no", pattern ? pattern.duration : -1.0,
           error ? error.description.UTF8String : "none");

    id<CHHapticPatternPlayer> player = [engine createPlayerWithPattern:pattern error:&error];
    printf("player=%s error=%s\n", player ? "yes" : "no", error ? error.description.UTF8String : "none");
    if (player) {
        printf("player start=%d error=%s\n", [player startAtTime:CHHapticTimeImmediate error:&error],
               error ? error.description.UTF8String : "none");
        printf("player stop=%d\n", [player stopAtTime:CHHapticTimeImmediate error:&error]);
    }
    [engine stopWithCompletionHandler:nil];
    printf("engine stopped\n");
}

int main(int argc, char **argv)
{
    setvbuf(stdout, NULL, _IONBF, 0);
    @autoreleasepool {
        int microphone = argc > 1 && strcmp(argv[1], "--microphone") == 0;
        revenant_vibrator_facts();

        if (microphone) {
            AVAudioSession *session = [AVAudioSession sharedInstance];
            NSError *error = nil;
            BOOL category = [session setCategory:AVAudioSessionCategoryPlayAndRecord error:&error];
            BOOL active = [session setActive:YES error:&error];
            printf("audio_session category=%d active=%d error=%s\n", category, active, error ? error.description.UTF8String : "none");
            NSString *path = @"/var/revenant/corehaptics-microphone.caf";
            NSDictionary *settings = @{AVFormatIDKey: @(kAudioFormatLinearPCM), AVSampleRateKey: @44100.0,
                                       AVNumberOfChannelsKey: @1, AVLinearPCMBitDepthKey: @16};
            AVAudioRecorder *recorder = [[AVAudioRecorder alloc] initWithURL:[NSURL fileURLWithPath:path] settings:settings error:&error];
            recorder.meteringEnabled = YES;
            BOOL recording = [recorder record];
            printf("microphone_recording=%d error=%s\n", recording, error ? error.description.UTF8String : "none");
            if (!recording)
                return 1;
            float profiles[REVENANT_MICROPHONE_REPEATS][REVENANT_MICROPHONE_BUCKETS];
            const int case_count = 7;
            const char *labels[7] = {"silence", "control tock 1103", "pattern 50 ms", "pattern 100 ms", "pattern 200 ms", "pattern 1000 ms", "public vibrate"};
            for (int index = 0; index < case_count; index++) {
                for (int repeat = 0; repeat < REVENANT_MICROPHONE_REPEATS; repeat++) {
                    revenant_wait(0.2);
                    switch (index) {
                        case 0:
                            break;
                        case 1:
                            AudioServicesPlaySystemSound(1103);
                            break;
                        case 6:
                            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
                            break;
                        default: {
                            void (*play)(uint32_t, id, NSDictionary *) =
                                revenant_symbol("/System/Library/Frameworks/AudioToolbox.framework/AudioToolbox", "AudioServicesPlaySystemSoundWithVibration");
                            if (play) {
                                int milliseconds = index == 2 ? 50 : (index == 3 ? 100 : (index == 4 ? 200 : 1000));
                                NSMutableArray *vibe = [NSMutableArray arrayWithCapacity:2];
                                [vibe addObject:(__bridge id)kCFBooleanTrue];
                                [vibe addObject:@(milliseconds)];
                                play(0x00000FFF, nil, @{@"VibePattern": vibe, @"Intensity": @1.0});
                            }
                            break;
                        }
                    }
                    revenant_microphone_profile(recorder, profiles[repeat]);
                }
                float median[REVENANT_MICROPHONE_BUCKETS];
                revenant_microphone_median(&profiles[0][0], REVENANT_MICROPHONE_REPEATS, median);
                printf("%-24s median:", labels[index]);
                for (int bucket = 0; bucket < REVENANT_MICROPHONE_BUCKETS; bucket++)
                    printf(" %.0f", median[bucket]);
                printf("\n");
            }
            [recorder stop];
            [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
            [session setActive:NO error:nil];
            return 0;
        }

        CMMotionManager *manager = [[CMMotionManager alloc] init];
        manager.accelerometerUpdateInterval = 1.0 / REVENANT_SAMPLE_HZ;
        NSOperationQueue *queue = [[NSOperationQueue alloc] init];
        [manager startAccelerometerUpdatesToQueue:queue withHandler:^(CMAccelerometerData *data, NSError *error) {
            revenant_sample(data, error);
        }];
        revenant_wait(2.0);
        RevenantSample *first = &revenant_samples[0];
        printf("accelerometer_available=%d samples=%d dropped=%d first=%.4f %.4f %.4f magnitude=%.5f\n", manager.isAccelerometerAvailable,
               revenant_sample_count, revenant_sample_dropped, first->x, first->y, first->z, first->magnitude);

        double baseline = 0.0;
        for (int index = 0; index < revenant_sample_count; index++)
            baseline = MAX(baseline, revenant_samples[index].magnitude);
        printf("baseline_max=%.5f\n", baseline);

        revenant_wait(0.7);
        NSTimeInterval started = [NSDate timeIntervalSinceReferenceDate];
        AudioServicesPlaySystemSound(1103);
        revenant_wait(2.0);
        revenant_report("control tock 1103", started, baseline + 0.005);

        const int requests[] = {50, 100, 200, 400, 1000};
        for (unsigned index = 0; index < sizeof(requests) / sizeof(requests[0]); index++) {
            int milliseconds = requests[index];
            revenant_wait(0.7);
            started = [NSDate timeIntervalSinceReferenceDate];
            void (*play)(uint32_t, id, NSDictionary *) =
                revenant_symbol("/System/Library/Frameworks/AudioToolbox.framework/AudioToolbox", "AudioServicesPlaySystemSoundWithVibration");
            if (play) {
                NSMutableArray *vibe = [NSMutableArray arrayWithCapacity:2];
                [vibe addObject:(__bridge id)kCFBooleanTrue];
                [vibe addObject:@(milliseconds)];
                play(0x00000FFF, nil, @{@"VibePattern": vibe, @"Intensity": @1.0});
            }
            revenant_wait(2.0);
            char label[64];
            snprintf(label, sizeof(label), "pattern %d ms", milliseconds);
            revenant_report(label, started, baseline + 0.005);
        }

        [manager stopAccelerometerUpdates];
        printf("final samples=%d dropped=%d\n", revenant_sample_count, revenant_sample_dropped);

        revenant_corehaptics_api();
    }
    return 0;
}
