#import "RevenantAUAudioUnit.h"

@implementation AUAudioUnit (RevenantLogging)
+ (void)revenant_noteInert:(NSString *)member why:(NSString *)why
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
    NSLog(@"[revenant AVFAudio] %@ is kept and read back but acts on no audio on iOS 6.1.3: %@", member, why);
}
@end

@implementation AUAudioUnit {
    AudioUnit _revenant_audioUnit;
    AudioComponent _revenant_component;
    AudioComponentDescription _revenant_description;
    AURenderBlock _revenant_renderBlock;
    AURenderPullInputBlock _revenant_pullInputBlock;
    AUScheduleParameterBlock _revenant_scheduleParameterBlock;
    AUAudioUnitBusArray *_revenant_inputBusses;
    AUAudioUnitBusArray *_revenant_outputBusses;
    AUParameterTree *_revenant_parameterTree;
    CFMutableArrayRef _revenant_renderObservers;
    CFArrayRef _revenant_renderObserverSnapshot;
    BOOL _revenant_resourcesAllocated;
    AUAudioFrameCount _revenant_maximumFramesToRender;
    BOOL _revenant_shouldBypassEffect;
    AUAudioUnitPreset *_revenant_currentPreset;
}

- (instancetype)initWithComponentDescription:(AudioComponentDescription)description options:(AudioComponentInstantiationOptions)options error:(NSError **)outError
{
    if ((self = [super init])) {
        _revenant_description = description;
        _revenant_maximumFramesToRender = 4096;
        AudioComponentInstance instance = NULL;
        _revenant_component = AudioComponentFindNext(NULL, &description);
        if (_revenant_component == NULL || AudioComponentInstanceNew(_revenant_component, &instance) != noErr || instance == NULL) {
            if (outError) {
                *outError = [NSError errorWithDomain:NSOSStatusErrorDomain code:kAudioUnitErr_FormatNotSupported userInfo:nil];
            }
            return nil;
        }
        _revenant_audioUnit = (AudioUnit)instance;
        AudioComponentGetDescription(_revenant_component, &_revenant_description);
        AudioUnit handle = (AudioUnit)instance;
        _revenant_pullInputBlock = ^(AudioUnitRenderActionFlags *flags, const AudioTimeStamp *timestamp, AUAudioFrameCount frameCount, NSInteger inputBusNumber, AudioBufferList *inputData) {
            return (AUAudioUnitStatus)AudioUnitRender(handle, flags, timestamp, (UInt32)inputBusNumber, frameCount, inputData);
        };
        AURenderCallbackStruct callback = {.inputProc = RevenantAURenderInput, .inputProcRefCon = (__bridge void *)self};
        AudioUnitSetProperty(_revenant_audioUnit, kAudioUnitProperty_SetRenderCallback, kAudioUnitScope_Input, 0, &callback, sizeof(callback));
        _revenant_inputBusses = [[AUAudioUnitBusArray alloc] initWithAudioUnit:self busType:AUAudioUnitBusTypeInput];
        _revenant_outputBusses = [[AUAudioUnitBusArray alloc] initWithAudioUnit:self busType:AUAudioUnitBusTypeOutput];
    }
    return self;
}

- (instancetype)initWithComponentDescription:(AudioComponentDescription)componentDescription error:(NSError **)outError
{
    return [self initWithComponentDescription:componentDescription options:0 error:outError];
}

- (void)dealloc
{
    if (_revenant_audioUnit != NULL) {
        AudioComponentInstanceDispose(_revenant_audioUnit);
        _revenant_audioUnit = NULL;
    }
}

#pragma mark Identity

- (AudioComponentDescription)componentDescription
{
    return _revenant_description;
}

- (AudioUnit)audioUnit
{
    return _revenant_audioUnit;
}

- (AudioComponent)component
{
    return _revenant_component;
}

- (NSString *)componentName
{
    CFStringRef name = NULL;
    if (_revenant_component != NULL && AudioComponentCopyName(_revenant_component, &name) == noErr && name != NULL) {
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
    OSType manufacturer = CFSwapInt32HostToBig(_revenant_description.componentManufacturer);
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
    if (_revenant_component != NULL) {
        AudioComponentGetVersion(_revenant_component, &version);
    }
    return version;
}

#pragma mark Render resources

- (BOOL)allocateRenderResourcesAndReturnError:(NSError **)outError
{
    OSStatus status = AudioUnitInitialize(_revenant_audioUnit);
    if (status != noErr) {
        if (outError) {
            *outError = [NSError errorWithDomain:NSOSStatusErrorDomain code:status userInfo:nil];
        }
        return NO;
    }
    _revenant_resourcesAllocated = YES;
    _revenant_parameterTree = RevenantBuildParameterTree(self);
    return YES;
}

- (void)deallocateRenderResources
{
    if (_revenant_resourcesAllocated) {
        AudioUnitUninitialize(_revenant_audioUnit);
        _revenant_resourcesAllocated = NO;
    }
}

- (BOOL)renderResourcesAllocated
{
    return _revenant_resourcesAllocated;
}

- (void)reset
{
    AudioUnitReset(_revenant_audioUnit, kAudioUnitScope_Global, 0);
}

#pragma mark Busses

- (AUAudioUnitBusArray *)inputBusses
{
    return _revenant_inputBusses;
}

- (AUAudioUnitBusArray *)outputBusses
{
    return _revenant_outputBusses;
}

#pragma mark The render block

- (AURenderBlock)renderBlock
{
    return _revenant_renderBlock;
}

- (void)setRenderBlock:(AURenderBlock)renderBlock
{
    _revenant_renderBlock = [renderBlock copy];
}

- (NSInteger)tokenByAddingRenderObserver:(AURenderObserver)observer
{
    if (observer == nil) {
        return 0;
    }
    if (_revenant_renderObservers == NULL) {
        _revenant_renderObservers = CFArrayCreateMutable(NULL, 0, &kCFTypeArrayCallBacks);
    }
    CFArrayAppendValue(_revenant_renderObservers, (__bridge const void *)observer);
    _revenant_renderObserverSnapshot = CFArrayCreateCopy(NULL, _revenant_renderObservers);
    return (NSInteger)(uintptr_t)(__bridge const void *)observer;
}

- (void)removeRenderObserver:(NSInteger)token
{
    AURenderObserver observer = (__bridge AURenderObserver)(const void *)(uintptr_t)token;
    if (observer == NULL || _revenant_renderObservers == NULL) {
        return;
    }
    CFIndex count = CFArrayGetCount(_revenant_renderObservers);
    for (CFIndex index = 0; index < count; index++) {
        if (CFArrayGetValueAtIndex(_revenant_renderObservers, index) == (__bridge const void *)observer) {
            CFArrayRemoveValueAtIndex(_revenant_renderObservers, index);
            break;
        }
    }
    _revenant_renderObserverSnapshot = CFArrayCreateCopy(NULL, _revenant_renderObservers);
}

- (OSStatus)revenant_renderWithActionFlags:(AudioUnitRenderActionFlags *)actionFlags
                               timestamp:(const AudioTimeStamp *)timestamp
                              frameCount:(UInt32)frameCount
                                     bus:(UInt32)bus
                                     data:(AudioBufferList *)data
{
    AudioUnitRenderActionFlags flags = actionFlags != NULL ? *actionFlags : 0;
    CFArrayRef observers = _revenant_renderObserverSnapshot;
    CFIndex seen = 0, count = observers != NULL ? CFArrayGetCount(observers) : 0;
    for (; observers != NULL && seen < count; seen++) {
        AURenderObserver observer = (__bridge AURenderObserver)CFArrayGetValueAtIndex(observers, seen);
        if (observer == NULL) {
            continue;
        }
        observer(flags | kAudioUnitRenderAction_PreRender, timestamp, frameCount, (NSInteger)bus);
    }
    AURenderBlock block = _revenant_renderBlock;
    if (block == NULL) {
        if (data != NULL) {
            memset(data, 0, sizeof(AudioBufferList));
        }
        return noErr;
    }
    AUAudioUnitStatus status = block(actionFlags, timestamp, frameCount, (NSInteger)bus, data, _revenant_pullInputBlock);
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
    return _revenant_parameterTree;
}

- (void)setParameterTree:(AUParameterTree *)parameterTree
{
    _revenant_parameterTree = parameterTree;
}

- (NSArray<NSNumber *> *)parametersForOverviewWithCount:(NSInteger)count
{
    NSMutableArray<NSNumber *> *addresses = [NSMutableArray array];
    UInt32 size = 0;
    if (AudioUnitGetProperty(_revenant_audioUnit, kAudioUnitProperty_ParametersForOverview, kAudioUnitScope_Global, 0, NULL, &size) != noErr || size < sizeof(AudioUnitParameterID)) {
        return addresses;
    }
    UInt32 count_of_parameters = size / (UInt32)sizeof(AudioUnitParameterID);
    AudioUnitParameterID *ids = calloc(count_of_parameters, sizeof(AudioUnitParameterID));
    if (ids == NULL) {
        return addresses;
    }
    OSStatus status = AudioUnitGetProperty(_revenant_audioUnit, kAudioUnitProperty_ParametersForOverview,
                                           kAudioUnitScope_Global, 0, ids, &size);
    if (status == noErr) {
        for (UInt32 index = 0; index + 3 < count_of_parameters && index + 1 < (UInt32)MAX(count, 0); index += 4) {
            AudioUnitScope scope = (AudioUnitScope)ids[index];
            AudioUnitElement element = (AudioUnitElement)ids[index + 1];
            [addresses addObject:@(RevenantAddress(ids[index + 2], scope, element))];
        }
    }
    free(ids);
    return addresses;
}

#pragma mark Timing and quality

- (AUAudioFrameCount)maximumFramesToRender
{
    return _revenant_maximumFramesToRender;
}

- (void)setMaximumFramesToRender:(AUAudioFrameCount)maximumFramesToRender
{
    _revenant_maximumFramesToRender = maximumFramesToRender;
    UInt32 frames = maximumFramesToRender;
    AudioUnitSetProperty(_revenant_audioUnit, kAudioUnitProperty_MaximumFramesPerSlice, kAudioUnitScope_Global, 0, &frames, sizeof(frames));
}

- (NSTimeInterval)latency
{
    Float64 latency = 0;
    UInt32 size = sizeof(Float64);
    if (AudioUnitGetProperty(_revenant_audioUnit, kAudioUnitProperty_Latency, kAudioUnitScope_Global, 0, &latency, &size) != noErr) {
        return 0;
    }
    return latency;
}

- (NSTimeInterval)tailTime
{
    Float64 tail = 0;
    UInt32 size = sizeof(Float64);
    if (AudioUnitGetProperty(_revenant_audioUnit, kAudioUnitProperty_TailTime, kAudioUnitScope_Global, 0, &tail, &size) != noErr) {
        return 0;
    }
    return tail;
}

- (NSInteger)renderQuality
{
    UInt32 quality = 0;
    UInt32 size = sizeof(UInt32);
    if (AudioUnitGetProperty(_revenant_audioUnit, kAudioUnitProperty_RenderQuality, kAudioUnitScope_Global, 0, &quality, &size) != noErr) {
        return 0;
    }
    return (NSInteger)quality;
}

- (void)setRenderQuality:(NSInteger)renderQuality
{
    UInt32 quality = (UInt32)renderQuality;
    AudioUnitSetProperty(_revenant_audioUnit, kAudioUnitProperty_RenderQuality, kAudioUnitScope_Global, 0, &quality, sizeof(quality));
}

- (BOOL)shouldBypassEffect
{
    UInt32 bypass = 0;
    UInt32 size = sizeof(bypass);
    if (AudioUnitGetProperty(_revenant_audioUnit, kAudioUnitProperty_BypassEffect, kAudioUnitScope_Global, 0,
                             &bypass, &size) == noErr) {
        return bypass != 0;
    }
    return _revenant_shouldBypassEffect;
}

- (void)setShouldBypassEffect:(BOOL)shouldBypassEffect
{
    UInt32 bypass = shouldBypassEffect ? 1u : 0u;
    if (AudioUnitSetProperty(_revenant_audioUnit, kAudioUnitProperty_BypassEffect, kAudioUnitScope_Global, 0,
                             &bypass, sizeof(bypass)) != noErr) {
        [AUAudioUnit revenant_noteInert:@"setShouldBypassEffect:"
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
    OSType type = _revenant_description.componentType;
    return type == kAudioUnitType_MusicDevice || type == kAudioUnitType_MusicEffect || type == kAudioUnitType_Effect;
}

- (NSInteger)virtualMIDICableCount
{
    return 0;
}

- (NSArray<NSNumber *> *)channelCapabilities
{
    UInt32 size = 0;
    if (AudioUnitGetProperty(_revenant_audioUnit, kAudioUnitProperty_SupportedNumChannels, kAudioUnitScope_Global,
                             0, NULL, &size) != noErr || size < sizeof(AUChannelInfo)) {
        return @[];
    }
    UInt32 entries = size / (UInt32)sizeof(AUChannelInfo);
    AUChannelInfo *infos = calloc(entries, sizeof(AUChannelInfo));
    if (infos == NULL) {
        return @[];
    }
    OSStatus status = AudioUnitGetProperty(_revenant_audioUnit, kAudioUnitProperty_SupportedNumChannels,
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
    if (AudioUnitGetProperty(_revenant_audioUnit, kAudioUnitProperty_FactoryPresets, kAudioUnitScope_Global, 0, &presets, &size) != noErr || presets == NULL) {
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

- (AUAudioUnitPreset *)revenant_readPresentPreset
{
    CFStringRef name = NULL;
    UInt32 size = sizeof(CFStringRef);
    if (AudioUnitGetProperty(_revenant_audioUnit, kAudioUnitProperty_PresentPreset, kAudioUnitScope_Global, 0, &name, &size) != noErr || name == NULL) {
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
    _revenant_currentPreset = currentPreset;
}

- (AUAudioUnitPreset *)currentPreset
{
    if (_revenant_currentPreset != nil) {
        return _revenant_currentPreset;
    }
    return [self revenant_readPresentPreset];
}

#pragma mark Scheduling

- (AUScheduleParameterBlock)scheduleParameterBlock
{
    if (_revenant_scheduleParameterBlock == nil) {
        AudioUnit handle = _revenant_audioUnit;
        _revenant_scheduleParameterBlock = ^(AUEventSampleTime eventSampleTime, AUAudioFrameCount rampDurationSampleFrames, AUParameterAddress parameterAddress, AUValue value) {
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
    return _revenant_scheduleParameterBlock;
}

@end
