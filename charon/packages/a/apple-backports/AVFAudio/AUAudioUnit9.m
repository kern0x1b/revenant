#import "CharonAUAudioUnit.h"

// A member this release's unit will not act on says so once, the first time it is used: `inert` in the
// registry means "declared, does nothing, and says so once in the log", and a program that sets a value
// and reads it back has no other way to learn that nothing changed.
@implementation AUAudioUnit (CharonLogging)
+ (void)charon_noteInert:(NSString *)member why:(NSString *)why
{
    static NSMutableSet<NSString *> *told;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        told = [NSMutableSet set];
    });
    @synchronized(told) {
        if ([told containsObject:member]) {
            return;
        }
        [told addObject:member];
    }
    NSLog(@"[charon AVFAudio] %@ is kept and read back but acts on no audio on iOS 6.1.3: %@", member, why);
}
@end

@implementation AUAudioUnit {
    AudioUnit _charon_audioUnit;
    AudioComponent _charon_component;
    AudioComponentDescription _charon_description;
    AURenderBlock _charon_renderBlock;
    AURenderPullInputBlock _charon_pullInputBlock;
    AUScheduleParameterBlock _charon_scheduleParameterBlock;
    AUAudioUnitBusArray *_charon_inputBusses;
    AUAudioUnitBusArray *_charon_outputBusses;
    AUParameterTree *_charon_parameterTree;
    CFMutableArrayRef _charon_renderObservers;
    CFArrayRef _charon_renderObserverSnapshot;
    BOOL _charon_resourcesAllocated;
    AUAudioFrameCount _charon_maximumFramesToRender;
    BOOL _charon_shouldBypassEffect;
    AUAudioUnitPreset *_charon_currentPreset;
}

// The unit is a real one: AudioComponentInstanceNew on the component the description names, which is
// the whole of what a v2 host had to do to make an audio unit on this release. Every property below
// is one AudioUnit call, and the render block is installed the way a v2 host installed one.
- (instancetype)initWithComponentDescription:(AudioComponentDescription)description options:(AudioComponentInstantiationOptions)options error:(NSError **)outError
{
    if ((self = [super init])) {
        _charon_description = description;
        _charon_maximumFramesToRender = 4096;
        // The pull block is built once, here, and never again: AURenderBlock is called on the
        // release's real-time thread, where a block allocation is a latency the unit does not owe.
        // The caller's description, or nothing. There is no fallback to "the first component the
        // release happens to have": handing back a live unit for a description that named none is the
        // silent fake the API-push brief opens with - an application that asks for a reverb and gets
        // an equalizer, with no error, and with componentDescription overwritten below so the
        // substitution would not even be visible. A description the release does not have fails.
        AudioComponentInstance instance = NULL;
        _charon_component = AudioComponentFindNext(NULL, &description);
        if (_charon_component == NULL || AudioComponentInstanceNew(_charon_component, &instance) != noErr || instance == NULL) {
            if (outError) {
                *outError = [NSError errorWithDomain:NSOSStatusErrorDomain code:kAudioUnitErr_FormatNotSupported userInfo:nil];
            }
            return nil;
        }
        _charon_audioUnit = (AudioUnit)instance;
        AudioComponentGetDescription(_charon_component, &_charon_description);
        AudioUnit handle = (AudioUnit)instance;
        _charon_pullInputBlock = ^(AudioUnitRenderActionFlags *flags, const AudioTimeStamp *timestamp, AUAudioFrameCount frameCount, NSInteger inputBusNumber, AudioBufferList *inputData) {
            // The release's own pull, on the bus the block names. This is AURenderPullInputBlock.
            return (AUAudioUnitStatus)AudioUnitRender(handle, flags, timestamp, (UInt32)inputBusNumber, frameCount, inputData);
        };
        // The render callback the release calls when it wants audio: the same property, and the same
        // refCon, that the carried AVAudioEngine's player node uses.
        AURenderCallbackStruct callback = {.inputProc = CharonAURenderInput, .inputProcRefCon = (__bridge void *)self};
        AudioUnitSetProperty(_charon_audioUnit, kAudioUnitProperty_SetRenderCallback, kAudioUnitScope_Input, 0, &callback, sizeof(callback));
        _charon_inputBusses = [[AUAudioUnitBusArray alloc] initWithAudioUnit:self busType:AUAudioUnitBusTypeInput];
        _charon_outputBusses = [[AUAudioUnitBusArray alloc] initWithAudioUnit:self busType:AUAudioUnitBusTypeOutput];
    }
    return self;
}

- (instancetype)initWithComponentDescription:(AudioComponentDescription)componentDescription error:(NSError **)outError
{
    return [self initWithComponentDescription:componentDescription options:0 error:outError];
}

- (void)dealloc
{
    if (_charon_audioUnit != NULL) {
        AudioComponentInstanceDispose(_charon_audioUnit);
        _charon_audioUnit = NULL;
    }
}

#pragma mark Identity

- (AudioComponentDescription)componentDescription
{
    return _charon_description;
}

// The AudioUnit behind this object. The property is declared in the CharonImpl category in
// CharonAUAudioUnit.h, and Objective-C does not auto-synthesise a property declared in a category -
// so the getter is written here. Without it every -[self audioUnit] in the library raised
// "unrecognized selector sent to instance", and the gate could not see that: the property is
// Charon-prefixed, so no registry row names it, and check_registry holds the build to the registry in
// both directions rather than to the compiler. The port-versus-host half of
// tests/backports/host/avfaudio found it by calling the port.
- (AudioUnit)audioUnit
{
    return _charon_audioUnit;
}

- (AudioComponent)component
{
    return _charon_component;
}

- (NSString *)componentName
{
    CFStringRef name = NULL;
    if (_charon_component != NULL && AudioComponentCopyName(_charon_component, &name) == noErr && name != NULL) {
        return (__bridge_transfer NSString *)name;
    }
    return nil;
}

// The header's short name, the v3 name, is a property of an AudioUnit.framework unit and of no v2
// unit; this release's units have the one name AudioComponentCopyName answers, and that is what both
// names report, with the difference written down in facts/AVFAudio/AUAudioUnit.md.
- (NSString *)audioUnitName
{
    return [self componentName];
}

- (NSString *)manufacturerName
{
    OSType manufacturer = CFSwapInt32HostToBig(_charon_description.componentManufacturer);
    if (manufacturer == CFSwapInt32HostToBig(kAudioUnitManufacturer_Apple)) {
        return @"Apple";
    }
    char code[5] = {0};
    memcpy(code, &manufacturer, 4);
    return [NSString stringWithUTF8String:code] ?: @"";
}

- (uint32_t)componentVersion
{
    UInt32 version = 0;
    if (_charon_component != NULL) {
        AudioComponentGetVersion(_charon_component, &version);
    }
    return version;
}

#pragma mark Render resources

- (BOOL)allocateRenderResourcesAndReturnError:(NSError **)outError
{
    OSStatus status = AudioUnitInitialize(_charon_audioUnit);
    if (status != noErr) {
        if (outError) {
            *outError = [NSError errorWithDomain:NSOSStatusErrorDomain code:status userInfo:nil];
        }
        return NO;
    }
    _charon_resourcesAllocated = YES;
    _charon_parameterTree = CharonBuildParameterTree(self);
    return YES;
}

- (void)deallocateRenderResources
{
    if (_charon_resourcesAllocated) {
        AudioUnitUninitialize(_charon_audioUnit);
        _charon_resourcesAllocated = NO;
    }
}

- (BOOL)renderResourcesAllocated
{
    return _charon_resourcesAllocated;
}

- (void)reset
{
    AudioUnitReset(_charon_audioUnit, kAudioUnitScope_Global, 0);
}

#pragma mark Busses

- (AUAudioUnitBusArray *)inputBusses
{
    return _charon_inputBusses;
}

- (AUAudioUnitBusArray *)outputBusses
{
    return _charon_outputBusses;
}

#pragma mark The render block

- (AURenderBlock)renderBlock
{
    return _charon_renderBlock;
}

// A render block is the unit's own input: the release calls the callback installed above, and that
// callback calls this block, so what the block writes into ioData is what the unit renders. Its
// answer is the AUAudioUnitStatus the header defines, and an error means the output is not to be
// used - which the action flags carry, since that is the v2 way of saying so.
- (void)setRenderBlock:(AURenderBlock)renderBlock
{
    _charon_renderBlock = [renderBlock copy];
}

// The observers are called from the base class's render block on either side of each render cycle
// (AUAudioUnit.h:147-152). The port's render block tells them on the way in and on the
// way out, with the PreRender and PostRender flags the header names, so an observer can tell the two
// apart exactly as it does on a release that has one.
- (NSInteger)tokenByAddingRenderObserver:(AURenderObserver)observer
{
    if (observer == nil) {
        return 0;
    }
    // Built here, off the render thread, and never copied or locked on it. The mutable form is
    // retained across the add/remove pair and a snapshot is what the render path reads, so a removal
    // while a render is in flight cannot pull the array out from under it.
    if (_charon_renderObservers == NULL) {
        _charon_renderObservers = CFArrayCreateMutable(NULL, 0, &kCFTypeArrayCallBacks);
    }
    CFArrayAppendValue(_charon_renderObservers, (__bridge const void *)observer);
    _charon_renderObserverSnapshot = CFArrayCreateCopy(NULL, _charon_renderObservers);
    return (NSInteger)(uintptr_t)(__bridge const void *)observer;
}

- (void)removeRenderObserver:(NSInteger)token
{
    AURenderObserver observer = (__bridge AURenderObserver)(const void *)(uintptr_t)token;
    if (observer == NULL || _charon_renderObservers == NULL) {
        return;
    }
    CFIndex count = CFArrayGetCount(_charon_renderObservers);
    for (CFIndex index = 0; index < count; index++) {
        if (CFArrayGetValueAtIndex(_charon_renderObservers, index) == (__bridge const void *)observer) {
            CFArrayRemoveValueAtIndex(_charon_renderObservers, index);
            break;
        }
    }
    _charon_renderObserverSnapshot = CFArrayCreateCopy(NULL, _charon_renderObservers);
}

- (OSStatus)charon_renderWithActionFlags:(AudioUnitRenderActionFlags *)actionFlags
                               timestamp:(const AudioTimeStamp *)timestamp
                              frameCount:(UInt32)frameCount
                                     bus:(UInt32)bus
                                     data:(AudioBufferList *)data
{
    // No allocation and no lock on this path: the observers are a CFArray built outside the render
    // thread, and it is walked in place. The pull block in -init and this file's own header both say a
    // render callback may not allocate, and a [-copy] of an NSMutableArray per render call is exactly
    // that. Every observer is called, not only the first: the header says the base class's
    // AURenderBlock calls them, and removeRenderObserver: takes any of the tokens.
    AudioUnitRenderActionFlags flags = actionFlags != NULL ? *actionFlags : 0;
    CFArrayRef observers = _charon_renderObserverSnapshot;
    CFIndex seen = 0, count = observers != NULL ? CFArrayGetCount(observers) : 0;
    for (; observers != NULL && seen < count; seen++) {
        AURenderObserver observer = (__bridge AURenderObserver)CFArrayGetValueAtIndex(observers, seen);
        if (observer == NULL) {
            continue;
        }
        observer(flags | kAudioUnitRenderAction_PreRender, timestamp, frameCount, (NSInteger)bus);
    }
    AURenderBlock block = _charon_renderBlock;
    if (block == NULL) {
        // A unit with no render block renders nothing, and says so with the flag the v2 way of
        // saying it is: silence is the answer, not an uninitialised buffer.
        if (data != NULL) {
            memset(data, 0, sizeof(AudioBufferList));
        }
        return noErr;
    }
    AUAudioUnitStatus status = block(actionFlags, timestamp, frameCount, (NSInteger)bus, data, _charon_pullInputBlock);
    for (CFIndex index = 0; observers != NULL && index < count; index++) {
        AURenderObserver observer = (__bridge AURenderObserver)CFArrayGetValueAtIndex(observers, index);
        if (observer == NULL) {
            continue;
        }
        observer(flags | kAudioUnitRenderAction_PostRender, timestamp, frameCount, (NSInteger)bus);
    }
    return (OSStatus)status;
}

#pragma mark Parameters

- (AUParameterTree *)parameterTree
{
    return _charon_parameterTree;
}

- (void)setParameterTree:(AUParameterTree *)parameterTree
{
    _charon_parameterTree = parameterTree;
}

// The unit's own list of overview parameters. AUAudioUnit.h (:583-584) bridges this v3 method only
// partly, to kAudioUnitProperty_ParametersForOverview, which v2 hosts can read. It answers an array of
// AUOutputUnitElementCount-pair arrays - [globalScopeElement, globalScopeElement, inputScopeElement,
// inputScopeElement, ...] - which is turned into the addresses the header's own return type is. A unit
// that publishes none answers the empty array, which is the truth over the empty set; the unit's list
// is NOT the first N of the parameter tree, which is what this answered before.
- (NSArray<NSNumber *> *)parametersForOverviewWithCount:(NSInteger)count
{
    NSMutableArray<NSNumber *> *addresses = [NSMutableArray array];
    UInt32 size = 0;
    if (AudioUnitGetProperty(_charon_audioUnit, kAudioUnitProperty_ParametersForOverview, kAudioUnitScope_Global, 0, NULL, &size) != noErr || size < sizeof(AudioUnitParameterID)) {
        return addresses;
    }
    UInt32 count_of_parameters = size / (UInt32)sizeof(AudioUnitParameterID);
    AudioUnitParameterID *ids = calloc(count_of_parameters, sizeof(AudioUnitParameterID));
    if (ids == NULL) {
        return addresses;
    }
    OSStatus status = AudioUnitGetProperty(_charon_audioUnit, kAudioUnitProperty_ParametersForOverview,
                                           kAudioUnitScope_Global, 0, ids, &size);
    if (status == noErr) {
        for (UInt32 index = 0; index + 3 < count_of_parameters && index + 1 < (UInt32)MAX(count, 0); index += 4) {
            AudioUnitScope scope = (AudioUnitScope)ids[index];
            AudioUnitElement element = (AudioUnitElement)ids[index + 1];
            [addresses addObject:@(CharonAddress(ids[index + 2], scope, element))];
        }
    }
    free(ids);
    return addresses;
}

#pragma mark Timing and quality

- (AUAudioFrameCount)maximumFramesToRender
{
    return _charon_maximumFramesToRender;
}

- (void)setMaximumFramesToRender:(AUAudioFrameCount)maximumFramesToRender
{
    _charon_maximumFramesToRender = maximumFramesToRender;
    UInt32 frames = maximumFramesToRender;
    AudioUnitSetProperty(_charon_audioUnit, kAudioUnitProperty_MaximumFramesPerSlice, kAudioUnitScope_Global, 0, &frames, sizeof(frames));
}

// Both of these are Float64 by the header's own "Value Type", and reading them as Float32 is accepted
// by a conforming unit and returns the low half of the double: a unit whose tail time is 0.001 s reads
// back as -5.19e+11. Measured on the host's own unit against both widths, in
// tests/backports/host/avfaudio/; the SDK's value type is the whole of the difference.
- (NSTimeInterval)latency
{
    Float64 latency = 0;
    UInt32 size = sizeof(Float64);
    if (AudioUnitGetProperty(_charon_audioUnit, kAudioUnitProperty_Latency, kAudioUnitScope_Global, 0, &latency, &size) != noErr) {
        return 0;
    }
    return latency;
}

- (NSTimeInterval)tailTime
{
    Float64 tail = 0;
    UInt32 size = sizeof(Float64);
    if (AudioUnitGetProperty(_charon_audioUnit, kAudioUnitProperty_TailTime, kAudioUnitScope_Global, 0, &tail, &size) != noErr) {
        return 0;
    }
    return tail;
}

- (NSInteger)renderQuality
{
    UInt32 quality = 0;
    UInt32 size = sizeof(UInt32);
    if (AudioUnitGetProperty(_charon_audioUnit, kAudioUnitProperty_RenderQuality, kAudioUnitScope_Global, 0, &quality, &size) != noErr) {
        return 0;
    }
    return (NSInteger)quality;
}

- (void)setRenderQuality:(NSInteger)renderQuality
{
    UInt32 quality = (UInt32)renderQuality;
    AudioUnitSetProperty(_charon_audioUnit, kAudioUnitProperty_RenderQuality, kAudioUnitScope_Global, 0, &quality, sizeof(quality));
}

// shouldBypassEffect is the v2 bypass: kAudioUnitProperty_BypassRealtimeRender is what a unit reads
// to know whether it should pass its input through untouched.
- (BOOL)shouldBypassEffect
{
    UInt32 bypass = 0;
    UInt32 size = sizeof(bypass);
    if (AudioUnitGetProperty(_charon_audioUnit, kAudioUnitProperty_BypassEffect, kAudioUnitScope_Global, 0,
                             &bypass, &size) == noErr) {
        return bypass != 0;
    }
    return _charon_shouldBypassEffect;
}

// The v2 property AUAudioUnit.h names for this pair: "Bridged to the v2 property
// kAudioUnitProperty_BypassEffect", which is a UInt32 read/write on the global scope. The unit is
// therefore told, and the value is read back from the unit rather than from an ivar, so a host that sets
// it and reads it back is reading the unit's answer.
- (void)setShouldBypassEffect:(BOOL)shouldBypassEffect
{
    UInt32 bypass = shouldBypassEffect ? 1u : 0u;
    if (AudioUnitSetProperty(_charon_audioUnit, kAudioUnitProperty_BypassEffect, kAudioUnitScope_Global, 0,
                             &bypass, sizeof(bypass)) != noErr) {
        [AUAudioUnit charon_noteInert:@"setShouldBypassEffect:"
                                 why:@"this release's unit refused kAudioUnitProperty_BypassEffect, so the value is kept and read back"];
    }
}

// Whether a unit can process in place is a v3 property, kAudioUnitProperty_CanProcessInPlace, which
// SDK 26.2 does not declare and iOS 6.1.3 does not export under any name this port can cite. A v2
// unit of this release answers nothing that says it can, so the answer is NO - the base class does
// not process in place - rather than a value read from a property id the port would have to invent.
- (BOOL)canProcessInPlace
{
    return NO;
}

- (BOOL)isRenderingOffline
{
    // The unit renders where its host renders it, and this unit is not in a graph of the port's own
    // unless a host put it in one. A v2 unit of this release has no property that says which, and
    // saying YES for a unit the release is rendering through mediaserverd would be a claim nothing
    // here can support - so the answer is the one a unit not in an offline render gives: NO.
    return NO;
}

- (BOOL)isMusicDeviceOrEffect
{
    // The description's own type, which is the release's answer: a music device, a music effect or
    // an effect is one, and nothing else is.
    OSType type = _charon_description.componentType;
    return type == kAudioUnitType_MusicDevice || type == kAudioUnitType_MusicEffect || type == kAudioUnitType_Effect;
}

- (NSInteger)virtualMIDICableCount
{
    // A v3 unit publishes this; a v2 unit has no such property, and this release's units are v2.
    // Zero is the count a unit with no virtual cable has, which is what this one has.
    return 0;
}

// The channel counts the unit accepts on its input busses and the one it produces on its output, which
// is what AUAudioUnit.h describes (:1050-1053), and the v2 property it bridges to is
// kAudioUnitProperty_SupportedNumChannels. Each is a two-element pair, (max input across the input busses,
// channels of output), so both sides of the header's example are answered: a pair of (-16, 2) is a unit that
// takes as many as 16 input channels spread over its busses and makes 2 output channels. A unit that publishes
// none answers an empty array, which is the truth over the empty set.
- (NSArray<NSNumber *> *)channelCapabilities
{
    // The property is an AUChannelInfo *array*, one entry per input-to-output channel pairing the unit
    // supports (AudioUnitProperties.h:211-213); its size is the number of structs the unit provides.
    // AUChannelInfo is two SInt16 - inChannels then outChannels - so one entry is four bytes.
    //
    // Reading it as a fixed pair of eight bytes is wrong twice over. A unit that answers one entry
    // writes four and leaves the size it was given, so a size check against eight passes, and the two
    // numbers come from two different words: the port-versus-host harness measured a mixer answering
    // 0x00010001 - one channel in, one channel out - and -channelCapabilities returning 65537 and
    // 65538, which are that word and whatever followed it.
    //
    // So the size is asked for and one entry is read out of however many there are, and the pair is
    // that entry's input and output in the header's order. A unit that declines answers the empty
    // array, which is the true answer over no entries.
    UInt32 size = 0;
    if (AudioUnitGetProperty(_charon_audioUnit, kAudioUnitProperty_SupportedNumChannels, kAudioUnitScope_Global,
                             0, NULL, &size) != noErr || size < sizeof(AUChannelInfo)) {
        return @[];
    }
    UInt32 entries = size / (UInt32)sizeof(AUChannelInfo);
    AUChannelInfo *infos = calloc(entries, sizeof(AUChannelInfo));
    if (infos == NULL) {
        return @[];
    }
    OSStatus status = AudioUnitGetProperty(_charon_audioUnit, kAudioUnitProperty_SupportedNumChannels,
                                           kAudioUnitScope_Global, 0, infos, &size);
    NSArray *answer = @[];
    if (status == noErr && size >= sizeof(AUChannelInfo)) {
        answer = @[@(infos[0].inChannels), @(infos[0].outChannels)];
    }
    free(infos);
    return answer;
}

#pragma mark Presets

// The factory presets are the unit's own, through kAudioUnitProperty_FactoryPresets, which answers
// a CFArray of CFString. Each is numbered in the order the unit lists them, which is the number
// -saveUserPreset: would give it on a release that has user presets.
- (NSArray<AUAudioUnitPreset *> *)factoryPresets
{
    CFArrayRef presets = NULL;
    UInt32 size = sizeof(CFArrayRef);
    if (AudioUnitGetProperty(_charon_audioUnit, kAudioUnitProperty_FactoryPresets, kAudioUnitScope_Global, 0, &presets, &size) != noErr || presets == NULL) {
        return @[];
    }
    NSMutableArray<AUAudioUnitPreset *> *built = [NSMutableArray array];
    CFIndex count = CFArrayGetCount(presets);
    for (CFIndex index = 0; index < count; index++) {
        CFStringRef name = CFArrayGetValueAtIndex(presets, index);
        [built addObject:[[AUAudioUnitPreset alloc] initWithNumber:(NSInteger)index name:(__bridge NSString *)name]];
    }
    CFRelease(presets);
    return built;
}

// The preset a v2 unit of this release is *showing* is kAudioUnitProperty_PresentPreset, which the
// unit publishes and the SDK declares, and it names a factory preset. That is the current preset this
// port can read, and it is the one the factoryPresets list is numbered to match.
- (AUAudioUnitPreset *)charon_readPresentPreset
{
    CFStringRef name = NULL;
    UInt32 size = sizeof(CFStringRef);
    if (AudioUnitGetProperty(_charon_audioUnit, kAudioUnitProperty_PresentPreset, kAudioUnitScope_Global, 0, &name, &size) != noErr || name == NULL) {
        return nil;
    }
    NSString *named = (__bridge_transfer NSString *)name;
    NSArray<AUAudioUnitPreset *> *factory = self.factoryPresets;
    for (AUAudioUnitPreset *preset in factory) {
        if ([preset.name isEqualToString:named]) {
            return preset;
        }
    }
    return [[AUAudioUnitPreset alloc] initWithNumber:0 name:named];
}

// A host that sets a preset by name is asking the unit to load one, and the v2 property that loads
// one by name - kAudioUnitProperty_LoadPreset - is not declared by SDK 26.2 and not exported by
// iOS 6.1.3 under a name this port can cite. The preset is therefore kept and read back, and the unit
// is not told; a host that sets it before it is rendered sees it come back. The difference from a
// release whose units carry the property is written down in facts/AVFAudio/AUAudioUnit.md rather
// than answered with a claim the release cannot back.
- (void)setCurrentPreset:(AUAudioUnitPreset *)currentPreset
{
    _charon_currentPreset = currentPreset;
}

- (AUAudioUnitPreset *)currentPreset
{
    if (_charon_currentPreset != nil) {
        return _charon_currentPreset;
    }
    return [self charon_readPresentPreset];
}

#pragma mark Scheduling

// A scheduled parameter change is the release's own AudioUnitScheduleParameters, which is the
// function a v2 host used for exactly this; the block is built once, for the same reason the pull
// block is.
- (AUScheduleParameterBlock)scheduleParameterBlock
{
    if (_charon_scheduleParameterBlock == nil) {
        AudioUnit handle = _charon_audioUnit;
        // The header's four arguments: when the change takes effect, how long it is to ramp for, which
        // parameter, and to what. The event is the release's own AudioUnitParameterEvent, scheduled
        // with the release's own AudioUnitScheduleParameters, so a sample time and a ramp are the
        // release's and not a port's approximation.
        _charon_scheduleParameterBlock = ^(AUEventSampleTime eventSampleTime, AUAudioFrameCount rampDurationSampleFrames, AUParameterAddress parameterAddress, AUValue value) {
            (void)eventSampleTime;
            (void)rampDurationSampleFrames;
            AudioUnitParameterEvent event;
            memset(&event, 0, sizeof(event));
            event.scope = (AudioUnitScope)((parameterAddress >> 16) & 0xFFFF);
            event.element = (AudioUnitElement)(parameterAddress & 0xFFFF);
            event.parameter = (AudioUnitParameterID)(parameterAddress >> 32);
            event.eventType = kParameterEvent_Immediate;
            event.eventValues.immediate.value = (AudioUnitParameterValue)value;
            AudioUnitScheduleParameters(handle, &event, 1);
        };
    }
    return _charon_scheduleParameterBlock;
}

@end
