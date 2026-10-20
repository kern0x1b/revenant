#import "RevenantAVAudioEngine.h"
#import "RevenantAVAudioEngineManual.h"
#import "RevenantAVAudioBuffer.h"
#import "RevenantAVAudioUnit.h"
#import <AVFAudio/AVAudioConnectionPoint.h>

extern OSStatus RevenantPlayerRenderCallback(void *inRefCon, AudioUnitRenderActionFlags *ioActionFlags, const AudioTimeStamp *inTimeStamp,
                                           UInt32 inBusNumber, UInt32 inNumberFrames, AudioBufferList *ioData);

static BOOL RevenantOfflineOutput = NO;

@implementation AVAudioEngine {
    AUGraph _revenant_graph;
    BOOL _revenant_initialized;
    BOOL _revenant_running;
    BOOL _revenant_autoShutdown;
    AVAudioMixerNode *_revenant_mainMixer;
    AVAudioOutputNode *_revenant_output;
    AVAudioInputNode *_revenant_input;
    NSMutableSet<AVAudioNode *> *_revenant_attached;
    NSMutableDictionary<NSValue *, NSArray *> *_revenant_playerRoutes;
    BOOL _revenant_offline;
    AUNode _revenant_outputAUNode;
    AUNode _revenant_mainMixerAUNode;
    AudioUnit _revenant_outputUnit;
    BOOL _revenant_manualRendering;
    AVAudioEngineManualRenderingMode _revenant_manualMode;
    AVAudioFormat *_revenant_manualFormat;
    AVAudioFrameCount _revenant_manualMaximumFrameCount;
    AVAudioEngineManualRenderingBlock _revenant_manualBlock;
    AVAudioFramePosition _revenant_manualSampleTime;
}

static OSStatus RevenantAddUnit(AUGraph graph, OSType type, OSType subtype, AUNode *outNode)
{
    AudioComponentDescription desc = {.componentType = type, .componentSubType = subtype, .componentManufacturer = kAudioUnitManufacturer_Apple};
    return AUGraphAddNode(graph, &desc, outNode);
}

- (instancetype)init
{
    if ((self = [super init])) {
        _revenant_attached = [NSMutableSet set];
        _revenant_playerRoutes = [NSMutableDictionary dictionary];
        _revenant_offline = RevenantOfflineOutput;

        AUGraph graph = NULL;
        NewAUGraph(&graph);
        AUGraphOpen(graph);
        _revenant_graph = graph;

        AUNode outputAUNode = 0, mixerAUNode = 0;
    _revenant_outputAUNode = 0;
    _revenant_outputUnit = NULL;
    _revenant_mainMixerAUNode = 0;
        RevenantAddUnit(graph, kAudioUnitType_Output, RevenantOfflineOutput ? kAudioUnitSubType_GenericOutput : kAudioUnitSubType_RemoteIO, &outputAUNode);
        RevenantAddUnit(graph, kAudioUnitType_Mixer, kAudioUnitSubType_MultiChannelMixer, &mixerAUNode);
        AUGraphConnectNodeInput(graph, mixerAUNode, 0, outputAUNode, 0);

        _revenant_outputAUNode = outputAUNode;
        _revenant_mainMixerAUNode = mixerAUNode;
        AudioUnit outputUnit = NULL, mixerUnit = NULL;
        AUGraphNodeInfo(graph, outputAUNode, NULL, &outputUnit);
        AUGraphNodeInfo(graph, mixerAUNode, NULL, &mixerUnit);

        UInt32 maxFrames = 4096;
        AudioUnitSetProperty(outputUnit, kAudioUnitProperty_MaximumFramesPerSlice, kAudioUnitScope_Global, 0, &maxFrames, sizeof(maxFrames));

        _revenant_output = [AVAudioOutputNode new];
        [_revenant_output revenant_setEngine:self auNode:outputAUNode audioUnit:outputUnit];

        _revenant_mainMixer = [AVAudioMixerNode new];
        [_revenant_mainMixer revenant_setEngine:self auNode:mixerAUNode audioUnit:mixerUnit];

        _revenant_input = [AVAudioInputNode new];
    }
    return self;
}

- (void)dealloc
{
    if (_revenant_graph) {
        AUGraphStop(_revenant_graph);
        AUGraphClose(_revenant_graph);
        DisposeAUGraph(_revenant_graph);
    }
}

- (void)attachNode:(AVAudioNode *)node
{
    if ([node isKindOfClass:[AVAudioPlayerNode class]]) {
        [node revenant_setEngine:self auNode:-1 audioUnit:NULL];
        [_revenant_attached addObject:node];
        return;
    }
    if ([node isKindOfClass:[AVAudioUnit class]]) {
        AudioComponentDescription desc = [(AVAudioUnit *)node audioComponentDescription];
        AUNode auNode = 0;
        RevenantAddUnit(_revenant_graph, desc.componentType, desc.componentSubType, &auNode);
        AudioUnit audioUnit = NULL;
        AUGraphNodeInfo(_revenant_graph, auNode, NULL, &audioUnit);
        [node revenant_setEngine:self auNode:auNode audioUnit:audioUnit];
        [(AVAudioUnit *)node revenant_applyPendingParameters];
        [_revenant_attached addObject:node];
        return;
    }
    [_revenant_attached addObject:node];
}

- (void)detachNode:(AVAudioNode *)node
{
    [self disconnectNodeOutput:node];
    [self disconnectNodeInput:node];
    if ([node isKindOfClass:[AVAudioUnit class]])
        AUGraphRemoveNode(_revenant_graph, [node revenant_impl]->auNode);
    [node revenant_setEngine:nil auNode:0 audioUnit:NULL];
    [_revenant_attached removeObject:node];
}

- (void)connect:(AVAudioNode *)node1 to:(AVAudioNode *)node2 fromBus:(AVAudioNodeBus)bus1 toBus:(AVAudioNodeBus)bus2 format:(AVAudioFormat *)format
{
    AVAudioFormat *useFormat = format ?: [node1 outputFormatForBus:bus1];
    [node1 revenant_setFormat:useFormat];
    [node2 revenant_setFormat:useFormat];

    RevenantAudioNodeImpl *destImpl = [node2 revenant_impl];
    if (useFormat && destImpl->audioUnit)
        AudioUnitSetProperty(destImpl->audioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, bus2, [useFormat streamDescription], sizeof(AudioStreamBasicDescription));

    if (node2 == _revenant_mainMixer && useFormat) {
        AudioUnitSetProperty(destImpl->audioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 0, [useFormat streamDescription], sizeof(AudioStreamBasicDescription));
        RevenantAudioNodeImpl *outImpl = [_revenant_output revenant_impl];
        if (outImpl->audioUnit) {
            AudioUnitSetProperty(outImpl->audioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, [useFormat streamDescription], sizeof(AudioStreamBasicDescription));
            AudioUnitSetProperty(outImpl->audioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 0, [useFormat streamDescription], sizeof(AudioStreamBasicDescription));
        }
        [_revenant_output revenant_setFormat:useFormat];
    }

    if ([node1 isKindOfClass:[AVAudioPlayerNode class]]) {
        AURenderCallbackStruct callback = {.inputProc = RevenantPlayerRenderCallback, .inputProcRefCon = (__bridge void *)node1};
        AUGraphSetNodeInputCallback(_revenant_graph, destImpl->auNode, bus2, &callback);
        _revenant_playerRoutes[[NSValue valueWithNonretainedObject:node1]] = @[node2, @(bus2)];
        return;
    }

    RevenantAudioNodeImpl *srcImpl = [node1 revenant_impl];
    if (srcImpl->audioUnit)
        AudioUnitSetProperty(srcImpl->audioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, bus1, [useFormat streamDescription], sizeof(AudioStreamBasicDescription));
    AUGraphConnectNodeInput(_revenant_graph, srcImpl->auNode, bus1, destImpl->auNode, bus2);
}

- (void)connect:(AVAudioNode *)node1 to:(AVAudioNode *)node2 format:(AVAudioFormat *)format
{
    [self connect:node1 to:node2 fromBus:0 toBus:0 format:format];
}

- (void)disconnectNodeInput:(AVAudioNode *)node bus:(AVAudioNodeBus)bus
{
    RevenantAudioNodeImpl *impl = [node revenant_impl];
    if (impl->auNode)
        AUGraphDisconnectNodeInput(_revenant_graph, impl->auNode, bus);
}

- (void)disconnectNodeInput:(AVAudioNode *)node
{
    [self disconnectNodeInput:node bus:0];
}

- (void)disconnectNodeOutput:(AVAudioNode *)node bus:(AVAudioNodeBus)bus
{
    if ([node isKindOfClass:[AVAudioPlayerNode class]]) {
        NSValue *key = [NSValue valueWithNonretainedObject:node];
        NSArray *route = _revenant_playerRoutes[key];
        if (route) {
            AVAudioNode *dest = route[0];
            AVAudioNodeBus destBus = [route[1] unsignedIntValue];
            AURenderCallbackStruct empty = {.inputProc = NULL, .inputProcRefCon = NULL};
            AUGraphSetNodeInputCallback(_revenant_graph, [dest revenant_impl]->auNode, destBus, &empty);
            [_revenant_playerRoutes removeObjectForKey:key];
        }
        return;
    }
}

- (void)disconnectNodeOutput:(AVAudioNode *)node
{
    [self disconnectNodeOutput:node bus:0];
}

- (NSArray<AVAudioConnectionPoint *> *)outputConnectionPointsForNode:(AVAudioNode *)node outputBus:(AVAudioNodeBus)bus
{
    if ([node isKindOfClass:[AVAudioPlayerNode class]]) {
        NSArray *route = _revenant_playerRoutes[[NSValue valueWithNonretainedObject:node]];
        if (!route)
            return @[];
        return @[[[AVAudioConnectionPoint alloc] initWithNode:route[0] bus:[route[1] unsignedIntValue]]];
    }
    if (node == _revenant_mainMixer)
        return @[[[AVAudioConnectionPoint alloc] initWithNode:_revenant_output bus:0]];
    return @[];
}

- (void)prepare
{
    if (!_revenant_initialized) {
        AUGraphInitialize(_revenant_graph);
        _revenant_initialized = YES;
    }
}

- (BOOL)startAndReturnError:(NSError **)outError
{
    [self prepare];
    if (_revenant_offline) {
        _revenant_running = YES;
        return YES;
    }
    OSStatus status = AUGraphStart(_revenant_graph);
    _revenant_running = status == noErr;
    if (status != noErr && outError)
        *outError = [NSError errorWithDomain:NSOSStatusErrorDomain code:status userInfo:nil];
    return status == noErr;
}

- (void)pause
{
    if (!_revenant_offline)
        AUGraphStop(_revenant_graph);
    _revenant_running = NO;
}

- (void)stop
{
    if (!_revenant_offline)
        AUGraphStop(_revenant_graph);
    _revenant_running = NO;
}

- (void)reset
{
    for (AVAudioNode *node in _revenant_attached)
        [node reset];
}

- (AVAudioOutputNode *)outputNode
{
    return _revenant_output;
}

- (AVAudioInputNode *)inputNode
{
    return _revenant_input;
}

- (AVAudioMixerNode *)mainMixerNode
{
    return _revenant_mainMixer;
}

- (BOOL)isRunning
{
    return _revenant_running;
}

- (BOOL)isAutoShutdownEnabled
{
    return _revenant_autoShutdown;
}

- (void)setAutoShutdownEnabled:(BOOL)autoShutdownEnabled
{
    _revenant_autoShutdown = autoShutdownEnabled;
}


- (BOOL)revenant_replaceOutputWithGeneric
{
    if (_revenant_outputAUNode == 0) {
        return NO;
    }
    AUNode previous = _revenant_outputAUNode;
    AUGraphDisconnectNodeInput(_revenant_graph, _revenant_mainMixerAUNode, 0);
    AUGraphRemoveNode(_revenant_graph, previous);
    AUNode output = 0;
    AudioComponentDescription description = {0};
    description.componentType = kAudioUnitType_Output;
    description.componentSubType = kAudioUnitSubType_GenericOutput;
    description.componentManufacturer = kAudioUnitManufacturer_Apple;
    if (AUGraphAddNode(_revenant_graph, &description, &output) != noErr || output == 0) {
        return NO;
    }
    AUGraphConnectNodeInput(_revenant_graph, _revenant_mainMixerAUNode, 0, output, 0);
    AudioUnit unit = NULL;
    AUGraphNodeInfo(_revenant_graph, output, NULL, &unit);
    _revenant_outputAUNode = output;
    _revenant_outputUnit = unit;
    UInt32 maxFrames = 1024;
    AudioUnitSetProperty(unit, kAudioUnitProperty_MaximumFramesPerSlice, kAudioUnitScope_Global, 0, &maxFrames, sizeof(maxFrames));
    AVAudioFormat *carried = [_revenant_mainMixer outputFormatForBus:0];
    if (carried != nil) {
        AudioStreamBasicDescription described = *carried.streamDescription;
        AudioUnitSetProperty(_revenant_outputUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0,
                             &described, sizeof(described));
        AudioUnitSetProperty(_revenant_outputUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 0,
                             &described, sizeof(described));
    }
    return YES;
}

- (BOOL)enableManualRenderingMode:(AVAudioEngineManualRenderingMode)mode
                           format:(AVAudioFormat *)pcmFormat
                maximumFrameCount:(AVAudioFrameCount)maximumFrameCount
                           error:(NSError **)outError
{
    if (pcmFormat == nil || maximumFrameCount == 0) {
        if (outError) {
            *outError = [NSError errorWithDomain:NSOSStatusErrorDomain code:kAudioUnitErr_InvalidPropertyValue userInfo:nil];
        }
        return NO;
    }
    if (!_revenant_manualRendering) {
        [self prepare];
        if (![self revenant_replaceOutputWithGeneric]) {
            if (outError) {
                *outError = [NSError errorWithDomain:NSOSStatusErrorDomain code:kAudioUnitErr_FailedInitialization userInfo:nil];
            }
            return NO;
        }
    }
    _revenant_manualRendering = YES;
    _revenant_manualMode = mode;
    _revenant_manualFormat = pcmFormat;
    _revenant_manualMaximumFrameCount = maximumFrameCount;
    _revenant_manualSampleTime = 0;
    return YES;
}

- (void)disableManualRenderingMode
{
    _revenant_manualRendering = NO;
    _revenant_manualFormat = nil;
    _revenant_manualBlock = nil;
    _revenant_manualSampleTime = 0;
}

- (AVAudioEngineManualRenderingMode)manualRenderingMode
{
    return _revenant_manualMode;
}

- (AVAudioFormat *)manualRenderingFormat
{
    return _revenant_manualFormat;
}

- (AVAudioFrameCount)manualRenderingMaximumFrameCount
{
    return _revenant_manualMaximumFrameCount;
}

- (AVAudioFramePosition)manualRenderingSampleTime
{
    return _revenant_manualSampleTime;
}

- (AVAudioEngineManualRenderingBlock)manualRenderingBlock
{
    return _revenant_manualBlock;
}

- (void)setManualRenderingBlock:(AVAudioEngineManualRenderingBlock)manualRenderingBlock
{
    _revenant_manualBlock = [manualRenderingBlock copy];
}

- (AVAudioEngineManualRenderingStatus)renderOffline:(AVAudioFrameCount)numberOfFrames
                                          toBuffer:(AVAudioPCMBuffer *)buffer
                                             error:(NSError **)outError
{
    if (!_revenant_manualRendering) {
        if (outError) {
            *outError = [NSError errorWithDomain:NSOSStatusErrorDomain code:kAudioUnitErr_InvalidPropertyValue userInfo:nil];
        }
        return AVAudioEngineManualRenderingStatusError;
    }
    if (buffer == nil || numberOfFrames == 0 || numberOfFrames > _revenant_manualMaximumFrameCount) {
        if (outError) {
            *outError = [NSError errorWithDomain:NSOSStatusErrorDomain code:kAudioUnitErr_InvalidPropertyValue userInfo:nil];
        }
        return AVAudioEngineManualRenderingStatusError;
    }
    AudioBufferList *destination = buffer.mutableAudioBufferList;
    if (destination == NULL) {
        return AVAudioEngineManualRenderingStatusError;
    }
    if (_revenant_manualBlock != nil) {
        OSStatus blockError = noErr;
        AVAudioEngineManualRenderingStatus status = _revenant_manualBlock(numberOfFrames, destination, &blockError);
        if (status == AVAudioEngineManualRenderingStatusSuccess) {
            _revenant_manualSampleTime += numberOfFrames;
            buffer.frameLength = numberOfFrames;
        } else if (outError) {
            *outError = [NSError errorWithDomain:NSOSStatusErrorDomain code:blockError userInfo:nil];
        }
        return status;
    }
    AudioUnitRenderActionFlags flags = 0;
    AudioTimeStamp timestamp = {0};
    timestamp.mFlags = kAudioTimeStampSampleTimeValid;
    timestamp.mSampleTime = _revenant_manualSampleTime;
    OSStatus status = AudioUnitRender(_revenant_outputUnit, &flags, &timestamp, 0, numberOfFrames, destination);
    if (status != noErr) {
        if (outError) {
            *outError = [NSError errorWithDomain:NSOSStatusErrorDomain code:status userInfo:nil];
        }
        return AVAudioEngineManualRenderingStatusError;
    }
    _revenant_manualSampleTime += numberOfFrames;
    buffer.frameLength = numberOfFrames;
    return AVAudioEngineManualRenderingStatusSuccess;
}

@end

@implementation RevenantAudioEngineTestSupport

+ (void)setForcedOfflineOutput:(BOOL)offline
{
    RevenantOfflineOutput = offline;
}

+ (OSStatus)pullOutput:(AudioBufferList *)ioData frames:(AVAudioFrameCount)frames fromEngine:(AVAudioEngine *)engine
{
    RevenantAudioNodeImpl *impl = [[engine outputNode] revenant_impl];
    AudioUnitRenderActionFlags flags = 0;
    AudioTimeStamp timestamp = {0};
    timestamp.mSampleTime = 0;
    timestamp.mFlags = kAudioTimeStampSampleTimeValid;
    return AudioUnitRender(impl->audioUnit, &flags, &timestamp, 0, frames, ioData);
}

@end
