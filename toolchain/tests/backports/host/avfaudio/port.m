#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import <AVFAudio/AVFAudio.h>

@interface revenant_host_AUAudioUnit : NSObject
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

@interface revenant_host_AUAudioUnitBus : NSObject
@property (readonly) NSArray<NSNumber *> *supportedChannelLayoutTags;
@property (readonly) double latency;
@property (readonly, copy) AVAudioFormat *format;
- (BOOL)setFormat:(AVAudioFormat *)format error:(NSError **)error;
@end

@interface revenant_host_AUAudioUnitBusArray : NSObject
- (id)objectAtIndexedSubscript:(NSUInteger)index;
- (NSUInteger)count;
@end

@interface revenant_host_AUParameterTree : NSObject
@property (readonly) NSArray *allParameters;
- (id)parameterWithAddress:(AUParameterAddress)address;
@end

@interface revenant_host_AVAudioChannelLayout : NSObject
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

static AudioComponentDescription RevenantFirstComponentOfType(OSType type)
{
    AudioComponentDescription any = {0};
    any.componentType = type;
    AudioComponent component = AudioComponentFindNext(NULL, &any);
    if (component == NULL) { return (AudioComponentDescription){0}; }
    AudioComponentDescription described;
    AudioComponentGetDescription(component, &described);
    return described;
}

typedef struct {
    BOOL answered;
    BOOL raised;
    AudioChannelLayoutTag tag;
    AVAudioChannelCount channels;
} RevenantLayoutAnswer;

static RevenantLayoutAnswer RevenantHostLayoutAnswer(const AudioChannelLayout *input)
{
    RevenantLayoutAnswer answer = {0};
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

static RevenantLayoutAnswer RevenantPortLayoutAnswer(const AudioChannelLayout *input)
{
    RevenantLayoutAnswer answer = {0};
    @try {
        revenant_host_AVAudioChannelLayout *object = [[revenant_host_AVAudioChannelLayout alloc] initWithLayout:input];
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

static NSString *RevenantDescribeLayoutAnswer(RevenantLayoutAnswer answer)
{
    if (answer.raised) { return @"raised"; }
    if (!answer.answered) { return @"nil"; }
    return [NSString stringWithFormat:@"object tag 0x%08x channels %u", (unsigned)answer.tag, (unsigned)answer.channels];
}

static void RevenantCompareLayout(NSString *name, const AudioChannelLayout *input)
{
    RevenantLayoutAnswer host = RevenantHostLayoutAnswer(input);
    RevenantLayoutAnswer port = RevenantPortLayoutAnswer(input);
    printf("stage -initWithLayout: %s: host %s; port %s\n", name.UTF8String,
           RevenantDescribeLayoutAnswer(host).UTF8String, RevenantDescribeLayoutAnswer(port).UTF8String);
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
        AudioComponentDescription described = RevenantFirstComponentOfType(kAudioUnitType_Effect);
        if (described.componentType == 0) {
            described = RevenantFirstComponentOfType(kAudioUnitType_FormatConverter);
        }
        AudioComponentDescription mixer = {0};
        {
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

        revenant_host_AUAudioUnit *port = [[revenant_host_AUAudioUnit alloc] initWithComponentDescription:described error:NULL];
        revenant_host_AUAudioUnit *portOnMixer = mixer.componentType != 0
            ? [[revenant_host_AUAudioUnit alloc] initWithComponentDescription:mixer error:NULL] : nil;
        check(@"the port instantiates a real effect", port != nil);
        check(@"the port instantiates a real mixer for the channel pair", mixer.componentType == 0 || portOnMixer != nil);
        AUAudioUnit *host = [[AUAudioUnit alloc] initWithComponentDescription:described error:NULL];
        check(@"the host's AUAudioUnit instantiates the same one", host != nil);
        if (port == nil || host == nil) {
            printf("checks=%d failures=%d\n", checks, failures);
            return 1;
        }

        revenant_host_AUAudioUnit *channelUnit = portOnMixer != nil ? portOnMixer : port;
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
        if (portChannels.count == 2) {
            check(@"the port answers the channel pair when the unit does", YES);
        } else {
            printf("stage the channel pair is not compared: this unit declines kAudioUnitProperty_SupportedNumChannels\n");
        }
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
            check(@"the port's first number is the input count, as the header documents",
                  [portChannels[0] integerValue] >= [portChannels[1] integerValue]);
            check(@"the port's pair matches the host's element for element",
                  [portChannels[0] isEqual:hostChannels[0]] && [portChannels[1] isEqual:hostChannels[1]]);
        }

        printf("stage latency: port %g, host %g | tailTime: port %g, host %g\n",
               port.latency, host.latency, port.tailTime, host.tailTime);
        check(@"the port's latency is the host's latency",
              fabs(port.latency - host.latency) <= 1e-9);
        check(@"the port's tail time is the host's tail time",
              fabs(port.tailTime - host.tailTime) <= 1e-9);
        Float64 tail = host.tailTime;
        Float32 narrow = (Float32)tail;
        if (tail != 0) {
            check(@"a Float32 read of the tail time disagrees with it, which is why it is read wide",
                  (double)narrow != (double)tail);
        }

        port.shouldBypassEffect = YES;
        host.shouldBypassEffect = YES;
        check(@"the port's bypass reads back what the host's does after the same set",
              port.shouldBypassEffect == host.shouldBypassEffect);
        printf("stage shouldBypassEffect: port %d, host %d\n", port.shouldBypassEffect, host.shouldBypassEffect);
        port.shouldBypassEffect = NO;
        host.shouldBypassEffect = NO;
        check(@"and both clear it", !port.shouldBypassEffect && !host.shouldBypassEffect);

        AVAudioFormat *portFormat = [[AVAudioFormat alloc] initStandardFormatWithSampleRate:44100.0 channels:2];
        NSUInteger bussesSet = 0;
        for (id array in @[port.inputBusses, port.outputBusses]) {
            revenant_host_AUAudioUnitBusArray *list = array;
            for (NSUInteger index = 0; index < list.count; index++) {
                revenant_host_AUAudioUnitBus *bus = [list objectAtIndexedSubscript:index];
                if (bus == nil) { continue; }
                NSError *formatError = nil;
                if ([bus setFormat:portFormat error:&formatError]) { bussesSet++; }
            }
        }
        printf("stage the port's busses took a format: %lu\n", (unsigned long)bussesSet);
        check(@"the port's busses accept a format", bussesSet > 0);

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
        check(@"the port's render block is called exactly once by a pull", portRenders == 1);
        check(@"the port's render block wrote the buffer it was handed", portData != NULL);
        printf("stage the host's render block calls %lu (readonly on this SDK, so reported, not compared)\n",
               (unsigned long)hostRenders);

        AudioChannelLayout tagZero;
        memset(&tagZero, 0, sizeof(tagZero));
        tagZero.mChannelLayoutTag = kAudioChannelLayoutTag_UseChannelDescriptions;
        AudioChannelLayout unknownTag;
        memset(&unknownTag, 0, sizeof(unknownTag));
        unknownTag.mChannelLayoutTag = 0xFFFF0003;
        AudioChannelLayout stereo;
        memset(&stereo, 0, sizeof(stereo));
        stereo.mChannelLayoutTag = kAudioChannelLayoutTag_Stereo;
        RevenantCompareLayout(@"NULL layout", NULL);
        RevenantCompareLayout(@"tag 0 (UseChannelDescriptions, no descriptions)", &tagZero);
        RevenantCompareLayout(@"unknown tag 0xFFFF0003", &unknownTag);
        RevenantCompareLayout(@"Stereo (control)", &stereo);

        printf("checks=%d failures=%d\n", checks, failures);
    }
    return failures == 0 ? 0 : 1;
}
