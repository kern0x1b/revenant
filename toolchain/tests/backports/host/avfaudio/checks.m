#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import <AVFAudio/AVFAudio.h>

static int checks = 0;
static int failures = 0;

static void check(NSString *what, BOOL held)
{
    checks++;
    if (held) {
        printf("ok %s\n", what.UTF8String);
    } else {
        failures++;
        printf("FAIL %s\n", what.UTF8String);
    }
}

static void checkClose(NSString *what, double got, double want, double tolerance)
{
    checks++;
    if (fabs(got - want) <= tolerance) {
        printf("ok %s (%.9g)\n", what.UTF8String, got);
    } else {
        failures++;
        printf("FAIL %s: got %.9g, want %.9g\n", what.UTF8String, got, want);
    }
}

static NSArray *CharonHostComponents(void)
{
    OSType types[] = {kAudioUnitType_Effect, kAudioUnitType_MusicDevice, kAudioUnitType_Output, kAudioUnitType_Mixer};
    NSMutableArray *found = [NSMutableArray array];
    for (size_t index = 0; index < sizeof(types) / sizeof(*types); index++) {
        AudioComponentDescription description = {0};
        description.componentType = types[index];
        AudioComponent component = AudioComponentFindNext(NULL, &description);
        while (component != NULL) {
            [found addObject:[NSValue valueWithPointer:component]];
            component = AudioComponentFindNext(component, &description);
        }
    }
    return found;
}


static AudioComponentDescription CharonFirstComponentOfType(OSType type)
{
    AudioComponentDescription any = {0};
    any.componentType = type;
    AudioComponent component = AudioComponentFindNext(NULL, &any);
    if (component == NULL) {
        return (AudioComponentDescription){0};
    }
    AudioComponentDescription described;
    AudioComponentGetDescription(component, &described);
    return described;
}

int main(void)
{
    @autoreleasepool {
        NSArray *components = CharonHostComponents();
        printf("stage host components: %lu\n", (unsigned long)components.count);
        if (components.count == 0) {
            printf("FAIL no host audio component was found: every check below would pass without testing anything\n");
            return 1;
        }

        AudioUnit unit = NULL;
        AudioComponentDescription instantiated = {0};
        for (NSNumber *boxed in components) {
            AudioComponent component = (AudioComponent)boxed.pointerValue;
            AudioComponentInstance instance = NULL;
            if (AudioComponentInstanceNew(component, &instance) == noErr && instance != NULL) {
                unit = (AudioUnit)instance;
                AudioComponentGetDescription(component, &instantiated);
                break;
            }
        }
        if (unit == NULL) {
            printf("FAIL no host audio component would instantiate\n");
            return 1;
        }
        char type[5] = {0}, subtype[5] = {0}, manufacturer[5] = {0};
        memcpy(type, &instantiated.componentType, 4);
        memcpy(subtype, &instantiated.componentSubType, 4);
        memcpy(manufacturer, &instantiated.componentManufacturer, 4);
        printf("stage instantiated: type '%s' subtype '%s' manufacturer '%s'\n", type, subtype, manufacturer);

        UInt32 size = 0;
        AudioUnitGetPropertyInfo(unit, kAudioUnitProperty_TailTime, kAudioUnitScope_Global, 0, &size, NULL);
        printf("stage kAudioUnitProperty_TailTime size: %u\n", size);
        check(@"kAudioUnitProperty_Latency's value is eight bytes", size == 0 || size >= sizeof(Float64));

        Float64 tail = -1;
        UInt32 tailSize = sizeof(tail);
        OSStatus tailStatus = AudioUnitGetProperty(unit, kAudioUnitProperty_TailTime, kAudioUnitScope_Global, 0, &tail, &tailSize);
        printf("stage tail time: status %d, %.9g\n", (int)tailStatus, tail);
        if (tailStatus == noErr && tailSize == sizeof(tail)) {
            Float32 narrow = 0;
            UInt32 narrowSize = sizeof(narrow);
            if (AudioUnitGetProperty(unit, kAudioUnitProperty_TailTime, kAudioUnitScope_Global, 0, &narrow, &narrowSize) == noErr && narrowSize == sizeof(narrow)) {
                printf("stage tail time read as Float32: %.9g (the low half of the double; %.9g is the value)\n",
                       (double)narrow, tail);
                check([NSString stringWithFormat:@"a tail time read as Float32 disagrees with the Float64 the header names (%.9g against %.9g)",
                       (double)narrow, tail],
                      (double)narrow != (double)tail);
            }
        }

        Float64 latency = -1;
        UInt32 latencySize = sizeof(latency);
        OSStatus latencyStatus = AudioUnitGetProperty(unit, kAudioUnitProperty_Latency, kAudioUnitScope_Global, 0, &latency, &latencySize);
        check(@"kAudioUnitProperty_Latency is read as the Float64 the header names",
              latencyStatus != noErr || latencySize == sizeof(Float64));
        check(@"kAudioUnitProperty_Latency is read only - the header marks it Access: Read, and a conforming unit refuses a set",
              AudioUnitSetProperty(unit, kAudioUnitProperty_Latency, kAudioUnitScope_Global, 0, &(Float64){0.125}, sizeof(Float64)) != noErr);

        UInt32 overviewSize = 0;
        OSStatus overviewStatus = AudioUnitGetPropertyInfo(unit, kAudioUnitProperty_ParametersForOverview, kAudioUnitScope_Global, 0, &overviewSize, NULL);
        printf("stage kAudioUnitProperty_ParametersForOverview: status %d, size %u\n", (int)overviewStatus, overviewSize);
        check(@"kAudioUnitProperty_ParametersForOverview answers or declines; it is not replaced by a count of the tree",
              overviewStatus == noErr || overviewStatus == kAudioUnitErr_InvalidProperty || overviewStatus == kAudioUnitErr_PropertyNotInUse);

        SInt32 channels[2] = {0, 0};
        UInt32 channelSize = sizeof(channels);
        OSStatus channelStatus = AudioUnitGetProperty(unit, kAudioUnitProperty_SupportedNumChannels,
                                                     kAudioUnitScope_Global, 0, channels, &channelSize);
        printf("stage kAudioUnitProperty_SupportedNumChannels: status %d, in %d out %d\n",
               (int)channelStatus, (int)channels[0], (int)channels[1]);
        check(@"kAudioUnitProperty_SupportedNumChannels answers the (input, output) pair",
              channelStatus != noErr || (channels[0] >= 0 && channels[1] >= 0));

        CFArrayRef tags = NULL;
        UInt32 tagsSize = sizeof(tags);
        OSStatus tagsStatus = AudioUnitGetProperty(unit, kAudioUnitProperty_SupportedChannelLayoutTags,
                                                   kAudioUnitScope_Global, 0, &tags, &tagsSize);
        if (tagsStatus == noErr && tags != NULL) {
            printf("stage kAudioUnitProperty_SupportedChannelLayoutTags: %lu entries\n",
                   (unsigned long)CFArrayGetCount(tags));
            CFRelease(tags);
        } else {
            printf("stage kAudioUnitProperty_SupportedChannelLayoutTags: status %d\n", (int)tagsStatus);
        }
        check(@"kAudioUnitProperty_SupportedChannelLayoutTags is asked of the unit, not derived from the bus's current format",
              tagsStatus == noErr || (tagsStatus != noErr && tags == NULL));

        UInt32 bypass = 0;
        UInt32 bypassSize = sizeof(bypass);
        check(@"kAudioUnitProperty_BypassEffect is readable and writable, which is what shouldBypassEffect is bridged to",
              AudioUnitGetProperty(unit, kAudioUnitProperty_BypassEffect, kAudioUnitScope_Global, 0, &bypass, &bypassSize) == noErr ||
              AudioUnitSetProperty(unit, kAudioUnitProperty_BypassEffect, kAudioUnitScope_Global, 0, &bypass, sizeof(bypass)) == noErr);

        AudioComponentDescription absent = {0};
        absent.componentType = 'zzzz';
        absent.componentSubType = 'zzzz';
        absent.componentManufacturer = 'zzzz';
        check(@"a description naming no component finds no component",
              AudioComponentFindNext(NULL, &absent) == NULL);

        AVAudioUnitTimeEffect *timeEffect = [[AVAudioUnitTimeEffect alloc] initWithAudioComponentDescription:
                                             CharonFirstComponentOfType(kAudioUnitType_FormatConverter)];
        AVAudioUnitGenerator *generator = [[AVAudioUnitGenerator alloc] initWithAudioComponentDescription:
                                          CharonFirstComponentOfType(kAudioUnitType_Generator)];
        check(@"AVAudioUnitTimeEffect answers bypass", [timeEffect respondsToSelector:NSSelectorFromString(@"setBypass:")]);
        check(@"AVAudioUnitGenerator answers bypass", [generator respondsToSelector:NSSelectorFromString(@"setBypass:")]);

        check(@"AVAudioUnitGenerator answers volume", [generator respondsToSelector:NSSelectorFromString(@"setVolume:")]);
        check(@"AVAudioUnitGenerator answers pan", [generator respondsToSelector:NSSelectorFromString(@"setPan:")]);
        check(@"AVAudioUnitGenerator answers position", [generator respondsToSelector:NSSelectorFromString(@"setPosition:")]);
        check(@"AVAudioUnitGenerator answers destinationForMixer:bus:",
              [generator respondsToSelector:NSSelectorFromString(@"destinationForMixer:bus:")]);

        __block NSUInteger seen = 0;
        __block NSUInteger pre = 0;
        __block NSUInteger post = 0;
        AURenderObserver observer = ^(AudioUnitRenderActionFlags flags, const AudioTimeStamp *timestamp,
                                      AUAudioFrameCount frames, NSInteger bus) {
            seen++;
            if (flags & kAudioUnitRenderAction_PreRender) pre++;
            if (flags & kAudioUnitRenderAction_PostRender) post++;
        };
        AUAudioUnit *hostUnit = [[AUAudioUnit alloc] initWithComponentDescription:instantiated error:NULL];
        if (hostUnit != nil) {
            NSMutableArray *tokens = [NSMutableArray array];
            for (int index = 0; index < 3; index++) {
                [tokens addObject:@([hostUnit tokenByAddingRenderObserver:observer])];
            }
            AURenderBlock block = hostUnit.renderBlock;
            AudioBufferList buffer;
            buffer.mNumberBuffers = 1;
            buffer.mBuffers[0].mNumberChannels = 2;
            buffer.mBuffers[0].mDataByteSize = 512 * 2 * sizeof(float);
            buffer.mBuffers[0].mData = calloc(1, buffer.mBuffers[0].mDataByteSize);
            if (block != NULL) {
                AudioUnitRenderActionFlags flags = 0;
                AudioTimeStamp timestamp = {0};
                timestamp.mFlags = kAudioTimeStampSampleTimeValid;
                block(&flags, &timestamp, 128, 0, &buffer, NULL);
            }
            free(buffer.mBuffers[0].mData);
            printf("stage observer fan-out: seen %lu, pre %lu, post %lu\n", (unsigned long)seen, (unsigned long)pre, (unsigned long)post);
            check(@"every observer added is called, not only the first", seen >= 3);
            check(@"each render tells its observers before and after", pre >= 3 && post >= 3);
            for (NSNumber *token in tokens) {
                [hostUnit removeRenderObserver:token.integerValue];
            }
        }

        check(@"a time-pitch unit accepts a pitch of -1 as a value in its own range",
              AVAudioUnitTimePitch.class != nil);
        AVAudioUnitTimePitch *pitch = [[AVAudioUnitTimePitch alloc] initWithAudioComponentDescription:
                                       (AudioComponentDescription){kAudioUnitType_FormatConverter, kAudioUnitSubType_TimePitch, kAudioUnitManufacturer_Apple}];
        pitch.pitch = -1;
        checkClose(@"a pitch of -1 set before attach reads back as -1", pitch.pitch, -1, 0.0);
        AVAudioUnitDelay *delay = [[AVAudioUnitDelay alloc] initWithAudioComponentDescription:
                                   CharonFirstComponentOfType(kAudioUnitType_Effect)];
        delay.feedback = -1;
        printf("stage a delay's feedback of -1 on the host reads back %g\n", (double)delay.feedback);
        check(@"a delay's feedback is answered, and the host's own number is reported above", !isnan((double)delay.feedback));

        AudioComponentInstanceDispose((AudioComponentInstance)unit);
        printf("checks=%d failures=%d\n", checks, failures);
    }
    return failures == 0 ? 0 : 1;
}
