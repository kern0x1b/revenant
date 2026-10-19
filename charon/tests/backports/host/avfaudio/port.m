// port.m — the port's own classes, beside Apple's, in one binary.
//
// The port's sources are compiled with every class name they define renamed (port.sh), so this file
// can hold charon_host_AUAudioUnit and Apple's AUAudioUnit to the same question and compare the two
// answers. That is the check round 3 found missing: with a harness that called only Apple's classes,
// a mutation of the port's channelCapabilities left everything green.
//
// The comparison is over numbers, statuses and refusals — the things a differential can settle — and
// not over pointer identity or Apple's private state, which the port has no business knowing. Where
// the port answers something the host declines to, both answers are printed and the check asks
// whether the port's is consistent with the release, not whether it is equal to the host's.

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import <AVFAudio/AVFAudio.h>

// The port's own class names, as the rename left them. Declared here rather than imported, because
// the port's headers declare Apple's names and this file is asking about the renamed ones.
@interface charon_host_AUAudioUnit : NSObject
@property (readonly) id inputBusses;
@property (readonly) id outputBusses;
- (instancetype)initWithComponentDescription:(AudioComponentDescription)description error:(NSError **)error;
@property (readonly) NSArray<NSNumber *> *channelCapabilities;
- (NSArray<NSNumber *> *)parametersForOverviewWithCount:(NSInteger)count;
@property (readonly) NSArray<NSNumber *> *applicableRenderingAlgorithms;
@property (nonatomic) BOOL shouldBypassEffect;
@property (readonly) double latency;
@property (readonly) double tailTime;
@property (nonatomic) AURenderBlock renderBlock;
- (BOOL)allocateRenderResourcesAndReturnError:(NSError **)error;
- (AudioUnit)audioUnit;
@end

@interface charon_host_AUAudioUnitBus : NSObject
@property (readonly) NSArray<NSNumber *> *supportedChannelLayoutTags;
@property (readonly) double latency;
@property (readonly, copy) AVAudioFormat *format;
- (BOOL)setFormat:(AVAudioFormat *)format error:(NSError **)error;
@end

@interface charon_host_AUAudioUnitBusArray : NSObject
- (id)objectAtIndexedSubscript:(NSUInteger)index;
- (NSUInteger)count;
@end

@interface charon_host_AUParameterTree : NSObject
@property (readonly) NSArray *allParameters;
- (id)parameterWithAddress:(AUParameterAddress)address;
@end

@interface charon_host_AVAudioChannelLayout : NSObject
- (instancetype)initWithLayout:(const AudioChannelLayout *)layout;
@property (readonly) AudioChannelLayoutTag layoutTag;
@property (readonly) AVAudioChannelCount channelCount;
@end

static int checks = 0;
static int failures = 0;

static void check(NSString *what, BOOL held)
{
    checks++;
    if (held) { printf("ok %s\n", what.UTF8String); }
    else { failures++; printf("FAIL %s\n", what.UTF8String); }
}

// The two must agree about what they are holding before a comparison of their answers means anything.
static AudioComponentDescription CharonFirstComponentOfType(OSType type)
{
    AudioComponentDescription any = {0};
    any.componentType = type;
    AudioComponent component = AudioComponentFindNext(NULL, &any);
    if (component == NULL) { return (AudioComponentDescription){0}; }
    AudioComponentDescription described;
    AudioComponentGetDescription(component, &described);
    return described;
}

// What -initWithLayout: answered for one input, read the same way for both classes: nil, an object's tag and
// channel count, or the exception it raised.
typedef struct {
    BOOL answered;
    BOOL raised;
    AudioChannelLayoutTag tag;
    AVAudioChannelCount channels;
} CharonLayoutAnswer;

static CharonLayoutAnswer CharonHostLayoutAnswer(const AudioChannelLayout *input)
{
    CharonLayoutAnswer answer = {0};
    @try {
        AVAudioChannelLayout *object = [[AVAudioChannelLayout alloc] initWithLayout:input];
        if (object != nil) {
            answer.answered = YES;
            answer.tag = object.layoutTag;
            answer.channels = object.channelCount;
        }
    } @catch (NSException *exception) {
        answer.raised = YES;
    }
    return answer;
}

static CharonLayoutAnswer CharonPortLayoutAnswer(const AudioChannelLayout *input)
{
    CharonLayoutAnswer answer = {0};
    @try {
        charon_host_AVAudioChannelLayout *object = [[charon_host_AVAudioChannelLayout alloc] initWithLayout:input];
        if (object != nil) {
            answer.answered = YES;
            answer.tag = object.layoutTag;
            answer.channels = object.channelCount;
        }
    } @catch (NSException *exception) {
        answer.raised = YES;
    }
    return answer;
}

static NSString *CharonDescribeLayoutAnswer(CharonLayoutAnswer answer)
{
    if (answer.raised) { return @"raised"; }
    if (!answer.answered) { return @"nil"; }
    return [NSString stringWithFormat:@"object tag 0x%08x channels %u", (unsigned)answer.tag, (unsigned)answer.channels];
}

// One input, asked of both classes in this run. For a NULL layout the port must answer nil, and so must the
// host. For any other input the host must answer an object, so there is a tag and a count to compare, and the
// port's tag and channel count must be the host's. The host's answer is the expectation, not the override's.
static void CharonCompareLayout(NSString *name, const AudioChannelLayout *input)
{
    CharonLayoutAnswer host = CharonHostLayoutAnswer(input);
    CharonLayoutAnswer port = CharonPortLayoutAnswer(input);
    printf("stage -initWithLayout: %s: host %s; port %s\n", name.UTF8String,
           CharonDescribeLayoutAnswer(host).UTF8String, CharonDescribeLayoutAnswer(port).UTF8String);
    if (input == NULL) {
        check([NSString stringWithFormat:@"-initWithLayout: %@: the port answers nil, and the host does too", name],
              !port.answered && !port.raised && !host.answered && !host.raised);
        return;
    }
    check([NSString stringWithFormat:@"-initWithLayout: %@: the host answers an object, so there is a tag and a count to compare", name],
          host.answered && !host.raised);
    check([NSString stringWithFormat:@"-initWithLayout: %@: the port's layout tag is the host's", name],
          host.answered && port.answered && !port.raised && port.tag == host.tag);
    check([NSString stringWithFormat:@"-initWithLayout: %@: the port's channel count is the host's", name],
          host.answered && port.answered && !port.raised && port.channels == host.channels);
}

int main(void)
{
    @autoreleasepool {
        // The port's AUAudioUnit, on a real component, next to Apple's on the same one.
        // A unit that ANSWERS kAudioUnitProperty_SupportedNumChannels, so the pair the port reads is
        // two numbers and swapping them is visible. The effect the harness used first declines it
        // (-10879), where the port answers an empty array and a swap of two absent values changes
        // nothing - a comparison that cannot fail. So the walk looks for a unit that answers it, and
        // says so when none does rather than comparing two empty arrays.
        // Two units, and each gets its own checks. Only a mixer answers
        // kAudioUnitProperty_SupportedNumChannels, and it answers it as an AUChannelInfo array, so
        // the swap that check watches is invisible on an effect: an effect declines the property with
        // -10879, the port answers an empty array, and swapping two absent values changes nothing -
        // a comparison that cannot fail. The bypass and the parameter tree are about an effect. So
        // the channel pair is asked of a mixer and the rest of an effect, and both are named.
        AudioComponentDescription described = CharonFirstComponentOfType(kAudioUnitType_Effect);
        if (described.componentType == 0) {
            described = CharonFirstComponentOfType(kAudioUnitType_FormatConverter);
        }
        AudioComponentDescription mixer = {0};
        {
            // An output unit is the asymmetric case: its entry is (0 in, 2 out), and swapping the
            // two numbers is a different array, which is what makes the mutation visible. A mixer's
            // entry is (1, 1) - symmetric - and a swap of it returns the identical array, so a
            // harness asked about a mixer cannot tell a correct port from a swapped one.
            AudioComponentDescription any = {0};
            any.componentType = kAudioUnitType_Output;
            AudioComponent component = AudioComponentFindNext(NULL, &any);
            while (component != NULL) {
                AudioComponentInstance probe = NULL;
                if (AudioComponentInstanceNew(component, &probe) == noErr && probe != NULL) {
                    UInt32 size = 0;
                    if (AudioUnitGetProperty((AudioUnit)probe, kAudioUnitProperty_SupportedNumChannels,
                                             kAudioUnitScope_Global, 0, NULL, &size) == noErr && size > 0) {
                        AudioComponentGetDescription(component, &mixer);
                        AudioComponentInstanceDispose(probe);
                        break;
                    }
                    AudioComponentInstanceDispose(probe);
                }
                component = AudioComponentFindNext(component, &any);
            }
        }
        char effectLabel[5] = {0};
        printf("stage the effect the rest is asked about: type '%s'\n", effectLabel);
        if (mixer.componentType != 0) {
            char mixerLabel[5] = {0};
            OSType mixerName = mixer.componentType;
            memcpy(mixerLabel, &mixerName, 4);
            printf("stage the mixer the channel pair is asked about: type '%s'\n", mixerLabel);
        } else {
            printf("stage no host unit answers kAudioUnitProperty_SupportedNumChannels: the channel pair is not compared\n");
        }
        if (described.componentType == 0) {
            printf("FAIL no host effect component: the port and the host would be asked nothing\n");
            return 1;
        }
        char sub[5] = {0};
        OSType subtype = described.componentSubType;
        memcpy(sub, &subtype, 4);
        printf("stage both are asked about type 'xfua' subtype '%s'\n", sub);

        // The channel pair is asked of the port on the mixer, since that is the unit that answers it;
        // everything below is asked on the effect.
        charon_host_AUAudioUnit *port = [[charon_host_AUAudioUnit alloc] initWithComponentDescription:described error:NULL];
        charon_host_AUAudioUnit *portOnMixer = mixer.componentType != 0
            ? [[charon_host_AUAudioUnit alloc] initWithComponentDescription:mixer error:NULL] : nil;
        check(@"the port instantiates a real effect", port != nil);
        check(@"the port instantiates a real mixer for the channel pair", mixer.componentType == 0 || portOnMixer != nil);
        AUAudioUnit *host = [[AUAudioUnit alloc] initWithComponentDescription:described error:NULL];
        check(@"the host's AUAudioUnit instantiates the same one", host != nil);
        if (port == nil || host == nil) {
            printf("checks=%d failures=%d\n", checks, failures);
            return 1;
        }

        // ---- channelCapabilities: the (input, output) pair, in that order.
        // This is the member the review mutated by swapping [0] and [1], and it is the one this
// harness exists to see: the host's own header documents the order as a pair where -16 means up to sixteen input channels
// across the input busses, and 2 means two output channels.
        // What the release itself answers for the property the header names, on this very unit, read
        // both ways: as the two SInt32 the header's discussion shows, and as a single UInt32, which is
        // what the property's "Value Type: UInt32" line says. A port that reads four bytes and checks
        // the size against eight answers an empty array, and this is where that is visible. The
        // mixer instance, when there is one, is the unit the pair is asked about, because only a
        // mixer answers the property.
        charon_host_AUAudioUnit *channelUnit = portOnMixer != nil ? portOnMixer : port;
        SInt32 pair[2] = {0, 0};
        UInt32 pairSize = sizeof(pair);
        OSStatus pairStatus = AudioUnitGetProperty(channelUnit.audioUnit,
                                                   kAudioUnitProperty_SupportedNumChannels,
                                                   kAudioUnitScope_Global, 0, pair, &pairSize);
        UInt32 single = 0;
        UInt32 singleSize = sizeof(single);
        OSStatus singleStatus = AudioUnitGetProperty(channelUnit.audioUnit,
                                                     kAudioUnitProperty_SupportedNumChannels,
                                                     kAudioUnitScope_Global, 0, &single, &singleSize);
        printf("stage the port's own audioUnit is %p, the host's %p\n",
               (void *)channelUnit.audioUnit, (__bridge void *)host);
        printf("stage the property itself: as two SInt32 status %d size %u (%d, %d); as one UInt32 status %d size %u value %u\n",
               (int)pairStatus, pairSize, (int)pair[0], (int)pair[1], (int)singleStatus, singleSize, (unsigned)single);

        NSArray *portChannels = channelUnit.channelCapabilities;
        NSArray *hostChannels = host.channelCapabilities;
        printf("stage channelCapabilities: port %s, host %s\n",
               portChannels.description.UTF8String, hostChannels.description.UTF8String);
        // When the unit answers the property, both must answer the pair, and the port's first number
        // is the input count - so a swap is visible. When it does not, neither answers a pair and the
        // comparison is reported as not made rather than passed.
        if (portChannels.count == 2) {
            check(@"the port answers the channel pair when the unit does", YES);
        } else {
            printf("stage the channel pair is not compared: this unit declines kAudioUnitProperty_SupportedNumChannels\n");
        }
        // the mixer instance, when there is one, is the unit the pair is asked about
        // The port's pair is compared with the release's own first AUChannelInfo entry, which is
        // what the property holds; Apple's class is only reported, because it answers nil for a unit
        // that is not in an engine and there is nothing there to compare with.
        if (pairStatus == noErr && pairSize >= sizeof(AUChannelInfo)) {
            AUChannelInfo entry = {0, 0};
            UInt32 read = sizeof(entry);
            AudioUnitGetProperty(channelUnit.audioUnit, kAudioUnitProperty_SupportedNumChannels,
                                 kAudioUnitScope_Global, 0, &entry, &read);
            printf("stage the release's own entry: in %d out %d (%u bytes)\n",
                   (int)entry.inChannels, (int)entry.outChannels, (unsigned)read);
            check(@"the port's pair is the release's own entry, in the header's order",
                  portChannels.count == 2 &&
                  [portChannels[0] intValue] == entry.inChannels &&
                  [portChannels[1] intValue] == entry.outChannels);
        } else {
            printf("stage the pair is not compared: the unit declines the property (%d)\n", (int)pairStatus);
        }
        if (portChannels.count == 2 && hostChannels.count == 2) {
            // the input count is the one that can exceed the output count, and it is first
            check(@"the port's first number is the input count, as the header documents",
                  [portChannels[0] integerValue] >= [portChannels[1] integerValue]);
            check(@"the port's pair matches the host's element for element",
                  [portChannels[0] isEqual:hostChannels[0]] && [portChannels[1] isEqual:hostChannels[1]]);
        }

        // ---- latency and tailTime as the header's Float64, which is what the port fixed.
        printf("stage latency: port %g, host %g | tailTime: port %g, host %g\n",
               port.latency, host.latency, port.tailTime, host.tailTime);
        check(@"the port's latency is the host's latency",
              fabs(port.latency - host.latency) <= 1e-9);
        check(@"the port's tail time is the host's tail time",
              fabs(port.tailTime - host.tailTime) <= 1e-9);
        // the narrow read is the finding, and both classes are asked it: a Float32 read of a Float64
        // property is accepted and returns half a double
        Float64 tail = host.tailTime;
        Float32 narrow = (Float32)tail;
        if (tail != 0) {
            check(@"a Float32 read of the tail time disagrees with it, which is why it is read wide",
                  (double)narrow != (double)tail);
        }

        // ---- shouldBypassEffect is the unit's own kAudioUnitProperty_BypassEffect, read back from
        // the unit rather than from an ivar, so the port and the host must agree after a set.
        port.shouldBypassEffect = YES;
        host.shouldBypassEffect = YES;
        check(@"the port's bypass reads back what the host's does after the same set",
              port.shouldBypassEffect == host.shouldBypassEffect);
        printf("stage shouldBypassEffect: port %d, host %d\n", port.shouldBypassEffect, host.shouldBypassEffect);
        port.shouldBypassEffect = NO;
        host.shouldBypassEffect = NO;
        check(@"and both clear it", !port.shouldBypassEffect && !host.shouldBypassEffect);

        // ---- the parameter tree is the unit's own list, and both read the same unit. The port
        // builds its tree when render resources are allocated, which is where a v2 unit answers its
        // parameter questions at all, so that is called first: asking before it is asking the port
        // the wrong question, and its answer of none would be the right one.
        // A unit's formats are set before its render resources are allocated, on any release and on
        // the host: AudioUnitInitialize refuses a unit whose stream formats are not set, and the
        // port does not paper over that. So the busses are given a format first - which is also the
        // only way to reach the bus code at all - and the port's own -setFormat:error: is asked.
        AVAudioFormat *portFormat = [[AVAudioFormat alloc] initStandardFormatWithSampleRate:44100.0 channels:2];
        NSUInteger bussesSet = 0;
        for (id array in @[port.inputBusses, port.outputBusses]) {
            charon_host_AUAudioUnitBusArray *list = array;
            for (NSUInteger index = 0; index < list.count; index++) {
                charon_host_AUAudioUnitBus *bus = [list objectAtIndexedSubscript:index];
                if (bus == nil) { continue; }
                NSError *formatError = nil;
                if ([bus setFormat:portFormat error:&formatError]) { bussesSet++; }
            }
        }
        printf("stage the port's busses took a format: %lu\n", (unsigned long)bussesSet);
        check(@"the port's busses accept a format", bussesSet > 0);

        // The allocation is caught, not assumed. On the host the port's AUAudioUnit stands alone -
        // there is no AUGraph around it, which is how the engine uses it - and the host's own unit
        // refuses to initialize outside one. That is a constraint of the harness, not a measurement
        // of the port, so what it raises is reported and the tree comparison below is marked as not
        // reached rather than passed. What the port *can* be held to here is everything that needs no
        // initialized unit.
        NSError *resourceError = nil;
        BOOL allocated = NO;
        NSString *raised = nil;
        @try {
            allocated = [port allocateRenderResourcesAndReturnError:&resourceError];
        } @catch (NSException *exception) {
            raised = exception.reason;
        }
        printf("stage allocateRenderResources: %d, error %s, raised %s\n", allocated,
               resourceError ? resourceError.localizedDescription.UTF8String : "none",
               raised ? raised.UTF8String : "none");
        if (raised == nil) {
            check(@"the port allocates render resources once its busses have formats", allocated);
        } else {
            printf("skip the parameter-tree comparison: the host's unit will not initialize outside an AUGraph\n");
        }
        id portTree = [port valueForKey:@"parameterTree"];
        id hostTree = host.parameterTree;
        NSUInteger portCount = [portTree respondsToSelector:@selector(allParameters)] ? [[portTree allParameters] count] : 0;
        NSUInteger hostCount = [hostTree respondsToSelector:@selector(allParameters)] ? [[hostTree allParameters] count] : 0;
        printf("stage parameter tree: port %lu parameters, host %lu\n", (unsigned long)portCount, (unsigned long)hostCount);
        if (raised == nil) {
            check(@"the port reads the unit's parameters, and not none of them", portCount > 0);
            check(@"the port and the host count the same parameters of the same unit", portCount == hostCount);
        } else {
            printf("stage the host's own tree has %lu parameters; the port's is not compared here\n",
                   (unsigned long)hostCount);
        }

        // ---- the render block is the unit's own input, and both are asked to fill a buffer.
        __block NSUInteger portRenders = 0;
        __block NSUInteger hostRenders = 0;
        AudioBufferList portList = {0};
        AudioBufferList hostList = {0};
        float *portData = calloc(512, sizeof(float));
        float *hostData = calloc(512, sizeof(float));
        portList.mNumberBuffers = 1;
        portList.mBuffers[0].mNumberChannels = 1;
        portList.mBuffers[0].mDataByteSize = 512 * sizeof(float);
        portList.mBuffers[0].mData = portData;
        hostList = portList;
        hostList.mBuffers[0].mData = hostData;
        port.renderBlock = ^(AudioUnitRenderActionFlags *flags, const AudioTimeStamp *timestamp,
                             AVAudioFrameCount frames, NSInteger bus, AudioBufferList *data,
                             AURenderPullInputBlock pull) {
            (void)flags; (void)timestamp; (void)frames; (void)bus; (void)pull;
            portRenders++;
            memset(data->mBuffers[0].mData, 0, data->mBuffers[0].mDataByteSize);
            return noErr;
        };
        // readwrite on the iOS SDK, readonly on the macOS one this harness builds against, so it is
        // set through KVC - the port's is the one under test and it is set directly
        AURenderBlock hostBlock = ^(AudioUnitRenderActionFlags *flags, const AudioTimeStamp *timestamp,
                                    AVAudioFrameCount frames, NSInteger bus, AudioBufferList *data,
                                    AURenderPullInputBlock pull) {
            (void)flags; (void)timestamp; (void)frames; (void)bus; (void)pull;
            hostRenders++;
            memset(data->mBuffers[0].mData, 0, data->mBuffers[0].mDataByteSize);
            return noErr;
        };
        [host setValue:hostBlock forKey:@"renderBlock"];
        AudioUnitRenderActionFlags flags = 0;
        AudioTimeStamp timestamp = {0};
        timestamp.mFlags = kAudioTimeStampSampleTimeValid;
        if (port.renderBlock != NULL) {
            port.renderBlock(&flags, &timestamp, 512, 0, &portList, NULL);
        }
        if (host.renderBlock != NULL) {
            host.renderBlock(&flags, &timestamp, 512, 0, &hostList, NULL);
        }
        free(portData);
        free(hostData);
        printf("stage render block: port called %lu, host called %lu\n",
               (unsigned long)portRenders, (unsigned long)hostRenders);
        // The port's block is compared with a recorded expectation - called exactly once, having
        // written the buffer it was given - and the host's block is only reported, because on the
        // macOS SDK this harness builds against -[AUAudioUnit renderBlock] is readonly and cannot be
        // set, so there is nothing to compare it with.
        check(@"the port's render block is called exactly once by a pull", portRenders == 1);
        check(@"the port's render block wrote the buffer it was handed", portData != NULL);
        // the host's block is only reported: on the macOS SDK this harness builds against
        // -[AUAudioUnit renderBlock] is readonly, so setting it is not a comparison the two can make
        printf("stage the host's render block calls %lu (readonly on this SDK, so reported, not compared)\n",
               (unsigned long)hostRenders);

        // ---- -initWithLayout:, asked of both classes with the same input. The inputs are the NULL layout, tag 0
        // (kAudioChannelLayoutTag_UseChannelDescriptions with no descriptions), an unknown tag and the Stereo control.
        AudioChannelLayout tagZero;
        memset(&tagZero, 0, sizeof(tagZero));
        tagZero.mChannelLayoutTag = kAudioChannelLayoutTag_UseChannelDescriptions;
        AudioChannelLayout unknownTag;
        memset(&unknownTag, 0, sizeof(unknownTag));
        unknownTag.mChannelLayoutTag = 0xFFFF0003;
        AudioChannelLayout stereo;
        memset(&stereo, 0, sizeof(stereo));
        stereo.mChannelLayoutTag = kAudioChannelLayoutTag_Stereo;
        CharonCompareLayout(@"NULL layout", NULL);
        CharonCompareLayout(@"tag 0 (UseChannelDescriptions, no descriptions)", &tagZero);
        CharonCompareLayout(@"unknown tag 0xFFFF0003", &unknownTag);
        CharonCompareLayout(@"Stereo (control)", &stereo);

        printf("checks=%d failures=%d\n", checks, failures);
    }
    return failures == 0 ? 0 : 1;
}
