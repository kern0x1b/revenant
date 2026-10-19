#import "CharonAUAudioUnit.h"

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

- (instancetype)initWithComponentDescription:(AudioComponentDescription)description options:(AudioComponentInstantiationOptions)options error:(NSError **)outError
{
    if ((self = [super init])) {
        _charon_description = description;
        _charon_maximumFramesToRender = 4096;
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
            return (AUAudioUnitStatus)AudioUnitRender(handle, flags, timestamp, (UInt32)inputBusNumber, frameCount, inputData);
        };
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

- (void)setRenderBlock:(AURenderBlock)renderBlock
{
    _charon_renderBlock = [renderBlock copy];
}

- (NSInteger)tokenByAddingRenderObserver:(AURenderObserver)observer
{
    if (observer == nil) {
        return 0;
    }
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

- (void)setShouldBypassEffect:(BOOL)shouldBypassEffect
{
    UInt32 bypass = shouldBypassEffect ? 1u : 0u;
    if (AudioUnitSetProperty(_charon_audioUnit, kAudioUnitProperty_BypassEffect, kAudioUnitScope_Global, 0,
                             &bypass, sizeof(bypass)) != noErr) {
        [AUAudioUnit charon_noteInert:@"setShouldBypassEffect:"
                                 why:@"this release's unit refused kAudioUnitProperty_BypassEffect, so the value is kept and read back"];
    }
}

- (BOOL)canProcessInPlace
{
    return NO;
}

- (BOOL)isRenderingOffline
{
    return NO;
}

- (BOOL)isMusicDeviceOrEffect
{
    OSType type = _charon_description.componentType;
    return type == kAudioUnitType_MusicDevice || type == kAudioUnitType_MusicEffect || type == kAudioUnitType_Effect;
}

- (NSInteger)virtualMIDICableCount
{
    return 0;
}

- (NSArray<NSNumber *> *)channelCapabilities
{
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

- (AUScheduleParameterBlock)scheduleParameterBlock
{
    if (_charon_scheduleParameterBlock == nil) {
        AudioUnit handle = _charon_audioUnit;
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
