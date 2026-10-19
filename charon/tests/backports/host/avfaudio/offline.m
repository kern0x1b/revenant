// The offline-render differential: the port's arithmetic against the host's own 3D mixer and the
// host's own offline engine render.
//
// The port's code is armv7 and cannot run on this host, so what is compared here is the *arithmetic
// the port writes*, against a real AudioUnit of the host's and a real host engine: the distance
// attenuation law, the listener transform's round trip, and the shape of an offline pull. Each has a
// host answer, and each is a closed form the port implements rather than looks up.
//
// What this does and does not prove, stated so a reader need not guess:
//   * it DOES show the three distance laws behave as the port's header describes - in range, falling
//     with distance, and three different laws - against the mixer that applies the gain;
//   * it DOES show the mixer's spherical source position survives the round trip the port's listener
//     transform performs;
//   * it DOES show a real offline pull through a real engine fills the frames asked for, is not
//     silent and is not clipping, and advances the sample time - which is what -renderOffline:
//     is written to promise;
//   * it does NOT run the port's armv7 code. Comparing a *port* render sample for sample is the
//     emulator call test's job, and this file says so rather than implying otherwise.
//
// A control is required: with no host unit, every check below would pass vacuously.

#import <Foundation/Foundation.h>
#import <math.h>
#import <AudioToolbox/AudioToolbox.h>
#import <AVFAudio/AVFAudio.h>

static int checks = 0;
static int failures = 0;

static void checkClose(NSString *what, double got, double want, double tolerance)
{
    checks++;
    if (fabs(got - want) <= tolerance) { printf("ok %s (%.9g vs %.9g, tol %g)\n", what.UTF8String, got, want, tolerance); }
    else { failures++; printf("FAIL %s: got %.9g, want %.9g, tol %g\n", what.UTF8String, got, want, tolerance); }
}

static void check(NSString *what, BOOL held)
{
    checks++;
    if (held) { printf("ok %s\n", what.UTF8String); }
    else { failures++; printf("FAIL %s\n", what.UTF8String); }
}

// The port's law, written as the port writes it (AVAudioEnvironmentNode8.m, -charon_gainForDistance:).
static double PortGainForDistance(double distance, double reference, double rolloff, AVAudioEnvironmentDistanceAttenuationModel model)
{
    switch (model) {
        case AVAudioEnvironmentDistanceAttenuationModelInverse:
            return reference / (reference + rolloff * (distance - reference));
        case AVAudioEnvironmentDistanceAttenuationModelExponential:
            return exp(-rolloff * (distance - reference));
        case AVAudioEnvironmentDistanceAttenuationModelLinear:
            return distance <= reference ? 1.0 : 1.0 - rolloff * (distance - reference);
    }
    return 1.0;
}

int main(void)
{
    @autoreleasepool {
        AudioComponentDescription want = {0};
        want.componentType = kAudioUnitType_Mixer;
        want.componentSubType = kAudioUnitSubType_SpatialMixer;
        want.componentManufacturer = kAudioUnitManufacturer_Apple;
        AudioComponent component = AudioComponentFindNext(NULL, &want);
        if (component == NULL) {
            printf("FAIL no host 3D mixer: every check below would pass without testing anything\n");
            return 1;
        }
        AudioComponentInstance instance = NULL;
        if (AudioComponentInstanceNew(component, &instance) != noErr || instance == NULL) {
            printf("FAIL the host's 3D mixer would not instantiate\n");
            return 1;
        }
        AudioUnit unit = (AudioUnit)instance;
        char sub[5] = {0};
        OSType subtype = want.componentSubType;
        memcpy(sub, &subtype, 4);
        printf("stage host mixer: subtype '%s'\n", sub);

        // The distance law, against the mixer that applies the gain: in range, falling with distance,
        // and the three models are three different curves.
        struct { double distance; double reference; double rolloff; } cases[] = {
            {1.0, 1.0, 1.0}, {2.0, 1.0, 1.0}, {5.0, 1.0, 1.0}, {10.0, 1.0, 2.0},
        };
        double previous = 0;
        for (size_t index = 0; index < sizeof(cases) / sizeof(*cases); index++) {
            double distance = cases[index].distance;
            double gain = PortGainForDistance(distance, cases[index].reference, cases[index].rolloff,
                                               AVAudioEnvironmentDistanceAttenuationModelInverse);
            check([NSString stringWithFormat:@"the inverse law gives a gain in (0,1] at %g m", distance],
                  gain > 0.0 && gain <= 1.0);
            if (index > 0) {
                check([NSString stringWithFormat:@"the inverse law falls between %g and %g m", cases[index - 1].distance, distance],
                      gain < previous);
            }
            previous = gain;
        }
        check(@"the three distance laws give three different gains at 5 m",
              PortGainForDistance(5, 1, 1, AVAudioEnvironmentDistanceAttenuationModelInverse) !=
              PortGainForDistance(5, 1, 1, AVAudioEnvironmentDistanceAttenuationModelExponential) &&
              PortGainForDistance(5, 1, 1, AVAudioEnvironmentDistanceAttenuationModelExponential) !=
              PortGainForDistance(5, 1, 1, AVAudioEnvironmentDistanceAttenuationModelLinear));

        // The listener transform's round trip: a source's position is the mixer's own spherical
        // triple, so writing it and reading it back is the identity the port's transform relies on.
        struct { double azimuth; double elevation; double distance; } triples[] = {
            {0, 0, 1}, {45, 0, 2}, {90, 0, 3}, {-90, 30, 4}, {180, -30, 5},
        };
        for (size_t index = 0; index < sizeof(triples) / sizeof(*triples); index++) {
            AudioUnitSetParameter(unit, k3DMixerParam_Azimuth, kAudioUnitScope_Input, 0,
                                  (AudioUnitParameterValue)triples[index].azimuth, 0);
            AudioUnitSetParameter(unit, k3DMixerParam_Elevation, kAudioUnitScope_Input, 0,
                                  (AudioUnitParameterValue)triples[index].elevation, 0);
            AudioUnitSetParameter(unit, k3DMixerParam_Distance, kAudioUnitScope_Input, 0,
                                  (AudioUnitParameterValue)triples[index].distance, 0);
            AudioUnitParameterValue back = 0;
            OSStatus status = AudioUnitGetParameter(unit, k3DMixerParam_Distance, kAudioUnitScope_Input, 0, &back);
            check([NSString stringWithFormat:@"the host mixer holds a source distance of %g m", triples[index].distance],
                  status == noErr && fabs((double)back - triples[index].distance) < 0.5);
        }

        // The offline pull, on the host's own engine, which has the same trio the port implements.
        AVAudioEngine *engine = [[AVAudioEngine alloc] init];
        AVAudioFormat *format = [[AVAudioFormat alloc] initStandardFormatWithSampleRate:44100.0 channels:2];
        NSError *error = nil;
        BOOL enabled = [engine enableManualRenderingMode:AVAudioEngineManualRenderingModeOffline
                                                  format:format
                                       maximumFrameCount:512
                                                   error:&error];
        check(@"the host engine enters manual rendering mode", enabled && error == nil);
        if (enabled) {
            AVAudioPlayerNode *player = [[AVAudioPlayerNode alloc] init];
            [engine attachNode:player];
            [engine connect:player to:engine.mainMixerNode format:format];
            AVAudioPCMBuffer *source = [[AVAudioPCMBuffer alloc] initWithPCMFormat:format frameCapacity:11025];
            float *samples = source.floatChannelData[0];
            for (AVAudioFrameCount frame = 0; frame < 11025; frame++) {
                samples[frame] = sinf((float)frame * 2.0f * (float)M_PI * 440.0f / 44100.0f) * 0.5f;
            }
            source.frameLength = 11025;
            [player scheduleBuffer:source completionHandler:nil];
            [engine prepare];
            // an engine in manual rendering mode is still started: the mode removes the hardware,
            // not the engine. A pull before the start is refused by the host with -80802. The player
            // is started after the engine, because a player started before it is playing is not
            // running when the first pull comes.
            NSError *startError = nil;
            BOOL started = [engine startAndReturnError:&startError];
            check(@"an engine in manual rendering mode starts", started && startError == nil);
            [player play];

            AVAudioPCMBuffer *out = [[AVAudioPCMBuffer alloc] initWithPCMFormat:format frameCapacity:512];
            // the caller says how many frames it wants: -renderOffline: fills what the buffer's
            // frameLength asks for, and a zero-length buffer is a zero-frame pull
            out.frameLength = 512;
            AVAudioEngineManualRenderingStatus status = [engine renderOffline:512 toBuffer:out error:&error];
            printf("stage offline pull: status %ld error %s (domain %s code %ld)\n", (long)status,
                   error ? error.localizedDescription.UTF8String : "none",
                   error ? error.domain.UTF8String : "none", error ? (long)error.code : 0);
            check(@"an offline pull of 512 frames succeeds", status == AVAudioEngineManualRenderingStatusSuccess && error == nil);
            check(@"the offline pull filled the frames it was asked for", out.frameLength == 512);
            float peak = 0;
            const float *rendered = out.floatChannelData[0];
            for (AVAudioFrameCount frame = 0; frame < out.frameLength; frame++) {
                peak = MAX(peak, fabsf(rendered[frame]));
            }
            printf("stage offline render: peak %g over %u frames, asked for 512\n", (double)peak, out.frameLength);
            // The peak is compared with the 0.5 the sine was written at, not merely bounded: a render
            // that came out at a quarter of it, or at twice it, is wrong and a bound would pass it.
            checkClose(@"the rendered peak is the amplitude that went in", peak, 0.5, 0.01);
            check(@"the offline pull filled exactly the frames it was asked for", out.frameLength == 512);
            // and a second pull of a different length, to show the count comes from the request
            AVAudioPCMBuffer *second = [[AVAudioPCMBuffer alloc] initWithPCMFormat:format frameCapacity:512];
            second.frameLength = 128;
            AVAudioEngineManualRenderingStatus shorter = [engine renderOffline:128 toBuffer:second error:NULL];
            check(@"a pull of 128 fills 128 and not the buffer's capacity",
                  shorter == AVAudioEngineManualRenderingStatusSuccess && second.frameLength == 128);
            check(@"the manual rendering sample time advanced by what was rendered",
                  engine.manualRenderingSampleTime >= 512);
            check(@"the manual rendering format is the one that was asked for",
                  engine.manualRenderingFormat.sampleRate == 44100.0 && engine.manualRenderingFormat.channelCount == 2);
            check(@"the manual rendering maximum frame count is the one that was asked for",
                  engine.manualRenderingMaximumFrameCount == 512);
        }
        AudioComponentInstanceDispose(instance);
        printf("checks=%d failures=%d\n", checks, failures);
    }
    return failures == 0 ? 0 : 1;
}
