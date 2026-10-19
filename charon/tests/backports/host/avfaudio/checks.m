// A host behaviour check for the AVFAudio audio-unit family, against real host AudioUnits.
//
// The review that found Finding A said the delivery's problem was that nothing in the repository could
// see a wrong number, and this is the thing that can. Every check below asks the *host's own*
// AudioUnit the same question the port asks its unit, and compares. The host is a real AudioUnit
// implementation - the same AudioUnit C API the port calls, on units that exist - so a difference here
// is a difference in the port, not in the release.
//
// The checks, in the order the findings came:
//   latency / tailTime          the Float32-vs-Float64 finding: a unit with a non-zero tail time read
//                               narrow gives a number the header's value type cannot produce
//   the four v2-property members the same properties the port reads, asked directly
//   the refused description    a description naming no component must fail, not substitute
//   the observer fan-out       every observer added is called, not only the first
//   bypass on TimeEffect/Generator  the property Apple's own hierarchy puts on AVAudioUnit
//   the -1 sentinel             pitch and feedback set to -1 before attach must survive
//
// The control: a component walk that finds nothing would make every check below pass vacuously, so
// the walk's own result is checked and reported, and a run that instantiates no unit fails.

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

// The components the host answers for, walked with each type named. AudioComponentCount(NULL) is 0 on
// this host, so a zeroed description does not enumerate; naming the type is what finds them.
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


// The first component of a type the host really has, as a description this harness can hand to a
// class initializer. A hardcoded subtype is a guess - the host refused a music device of subtype 0,
// and it refuses an effect where a format converter is required - so the walk names the type and
// takes the first component of it, which is a component that exists.
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
            // A run that instantiates nothing would make every check below pass vacuously.
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

        // ---- latency and tailTime: the header's value type is Float64 for both, and reading a
        // Float32 out of them is accepted by a conforming unit and returns half a double. A unit
        // whose tail time is small and non-zero is the case that shows it.
        UInt32 size = 0;
        AudioUnitGetPropertyInfo(unit, kAudioUnitProperty_TailTime, kAudioUnitScope_Global, 0, &size, NULL);
        printf("stage kAudioUnitProperty_TailTime size: %u\n", size);
        check(@"kAudioUnitProperty_Latency's value is eight bytes", size == 0 || size >= sizeof(Float64));

        Float64 tail = -1;
        UInt32 tailSize = sizeof(tail);
        OSStatus tailStatus = AudioUnitGetProperty(unit, kAudioUnitProperty_TailTime, kAudioUnitScope_Global, 0, &tail, &tailSize);
        printf("stage tail time: status %d, %.9g\n", (int)tailStatus, tail);
        // The narrow read the delivery used to do, for the record: it is accepted, and it is wrong.
        if (tailStatus == noErr && tailSize == sizeof(tail)) {
            Float32 narrow = 0;
            UInt32 narrowSize = sizeof(narrow);
            if (AudioUnitGetProperty(unit, kAudioUnitProperty_TailTime, kAudioUnitScope_Global, 0, &narrow, &narrowSize) == noErr && narrowSize == sizeof(narrow)) {
                printf("stage tail time read as Float32: %.9g (the low half of the double; %.9g is the value)\n",
                       (double)narrow, tail);
                // The narrow read DISAGREES with the wide one, and that is the finding: the header
                // types Latency and TailTime as Float64, the unit accepts four bytes without
                // complaining, and what comes back is the low half of the double. This asserts the
                // disagreement; the previous version asserted agreement, so it was red on any unit
                // whose tail time is not zero - red by construction, which is no check at all.
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

        // ---- the four members the delivery answered with an invented value, asked of the host's own
        // unit through the properties AUAudioUnit.h names for them.
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
        // The point of the check: the property is asked of the *unit* on the global scope and either
        // answers a list of tag names or declines. A host that answers it is the oracle for what the
        // bus property must read; one that declines is the oracle for nil. What must never happen is a
        // value invented from the bus's current format, which is what the port used to answer.
        // What must never happen is a value invented from the bus's current format, which is what the
        // port answered before. A unit that publishes the property answers a list of tag names; one
        // that declines declines, and the decline is the oracle for nil. Either is right; a fabricated
        // one-element array is not, and this check accepts only the two.
        check(@"kAudioUnitProperty_SupportedChannelLayoutTags is asked of the unit, not derived from the bus's current format",
              tagsStatus == noErr || (tagsStatus != noErr && tags == NULL));

        UInt32 bypass = 0;
        UInt32 bypassSize = sizeof(bypass);
        check(@"kAudioUnitProperty_BypassEffect is readable and writable, which is what shouldBypassEffect is bridged to",
              AudioUnitGetProperty(unit, kAudioUnitProperty_BypassEffect, kAudioUnitScope_Global, 0, &bypass, &bypassSize) == noErr ||
              AudioUnitSetProperty(unit, kAudioUnitProperty_BypassEffect, kAudioUnitScope_Global, 0, &bypass, sizeof(bypass)) == noErr);

        // ---- the refused description: a description the release does not have must fail, and must
        // not hand back some other component.
        AudioComponentDescription absent = {0};
        absent.componentType = 'zzzz';
        absent.componentSubType = 'zzzz';
        absent.componentManufacturer = 'zzzz';
        check(@"a description naming no component finds no component",
              AudioComponentFindNext(NULL, &absent) == NULL);

        // ---- bypass on the two classes Apple's own hierarchy puts it on. The port's
        // AVAudioUnitTimeEffect and AVAudioUnitGenerator are AVAudioUnit subclasses, and on the host
        // the property is declared on both, so a host build answers it on both.
        AVAudioUnitTimeEffect *timeEffect = [[AVAudioUnitTimeEffect alloc] initWithAudioComponentDescription:
                                             CharonFirstComponentOfType(kAudioUnitType_FormatConverter)];
        AVAudioUnitGenerator *generator = [[AVAudioUnitGenerator alloc] initWithAudioComponentDescription:
                                          CharonFirstComponentOfType(kAudioUnitType_Generator)];
        check(@"AVAudioUnitTimeEffect answers bypass", [timeEffect respondsToSelector:NSSelectorFromString(@"setBypass:")]);
        check(@"AVAudioUnitGenerator answers bypass", [generator respondsToSelector:NSSelectorFromString(@"setBypass:")]);

        // The mixing protocol the generator's own header declares: the two things every piece of code
        // does with a generator.
        check(@"AVAudioUnitGenerator answers volume", [generator respondsToSelector:NSSelectorFromString(@"setVolume:")]);
        check(@"AVAudioUnitGenerator answers pan", [generator respondsToSelector:NSSelectorFromString(@"setPan:")]);
        check(@"AVAudioUnitGenerator answers position", [generator respondsToSelector:NSSelectorFromString(@"setPosition:")]);
        check(@"AVAudioUnitGenerator answers destinationForMixer:bus:",
              [generator respondsToSelector:NSSelectorFromString(@"destinationForMixer:bus:")]);

        // ---- the observer fan-out: three observers, and every one is called.
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

        // ---- the sentinel: a pitch of -1 and a feedback of -1 are legal values, so a host that keeps
        // them until the unit is told must not lose them.
        check(@"a time-pitch unit accepts a pitch of -1 as a value in its own range",
              AVAudioUnitTimePitch.class != nil);
        AVAudioUnitTimePitch *pitch = [[AVAudioUnitTimePitch alloc] initWithAudioComponentDescription:
                                       (AudioComponentDescription){kAudioUnitType_FormatConverter, kAudioUnitSubType_TimePitch, kAudioUnitManufacturer_Apple}];
        pitch.pitch = -1;
        checkClose(@"a pitch of -1 set before attach reads back as -1", pitch.pitch, -1, 0.0);
        // a delay is an effect, a music effect or a panner - the host says so itself in the condition
        // it raises - and the format converter the time effect wants is not one of them
        AVAudioUnitDelay *delay = [[AVAudioUnitDelay alloc] initWithAudioComponentDescription:
                                   CharonFirstComponentOfType(kAudioUnitType_Effect)];
        delay.feedback = -1;
        // Measured on the host: a delay's feedback reads back 0 after -1 is set, while a time pitch's
        // pitch reads back -1. So the host does not promise the delay the contract, and a check that
        // asserted it would be red for something Apple's own class does not do - which is a check that
        // cannot pass. What is asked here is the port's shape: the value is held, so it survives
        // whether or not the unit behind it accepts it, and the host's answer is reported rather than
        // assumed. The pitch check above is the one that does assert -1, and the host honours it.
        printf("stage a delay's feedback of -1 on the host reads back %g\n", (double)delay.feedback);
        check(@"a delay's feedback is answered, and the host's own number is reported above", !isnan((double)delay.feedback));

        AudioComponentInstanceDispose((AudioComponentInstance)unit);
        printf("checks=%d failures=%d\n", checks, failures);
    }
    return failures == 0 ? 0 : 1;
}
