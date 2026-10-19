#import "CharonAVAudioEngine.h"
#import "CharonAVAudioEngineManual.h"
#import "CharonAVAudioBuffer.h"
#import "CharonAVAudioUnit.h"
#import <AVFAudio/AVAudioConnectionPoint.h>

extern OSStatus CharonPlayerRenderCallback(void *inRefCon, AudioUnitRenderActionFlags *ioActionFlags, const AudioTimeStamp *inTimeStamp,
                                           UInt32 inBusNumber, UInt32 inNumberFrames, AudioBufferList *ioData);

// The real topology this port builds, matching Apple's own default engine wiring: mainMixerNode
// is connected to outputNode from the moment the engine exists, before any application code runs.
// This port's engine does the same - AUGraphConnectNodeInput(mixer -> output) happens in -init,
// not left for a caller to do by hand.
//
// A player node carries no AudioUnit (see AVAudioPlayerNode.m); connecting one installs
// CharonPlayerRenderCallback on the destination's real input bus via AUGraphSetNodeInputCallback
// instead of AUGraphConnectNodeInput - the callback *is* the connection for that side.
//
// Test-only offline output: kAudioUnitSubType_GenericOutput needs no mediaserverd (confirmed via
// AudioComponentFindNext on a real 6.1.3 device - see facts/AVFoundation/AVAudioEngine.md) and
// pulls by hand through AudioUnitRender rather than a hardware I/O thread, which is exactly what
// proves a real application's node graph, format negotiation and buffer scheduling move real
// samples without needing a device. A real application still gets kAudioUnitSubType_RemoteIO -
// this switch is off by default and only ever set by a test binary.

static BOOL CharonOfflineOutput = NO;

@implementation AVAudioEngine {
    AUGraph _charon_graph;
    BOOL _charon_initialized;
    BOOL _charon_running;
    BOOL _charon_autoShutdown;
    AVAudioMixerNode *_charon_mainMixer;
    AVAudioOutputNode *_charon_output;
    AVAudioInputNode *_charon_input;
    NSMutableSet<AVAudioNode *> *_charon_attached;
    // player node (NSValue-wrapped pointer identity) -> (destination node, destination bus):
    // tracked so disconnectNodeOutput: knows which real graph entry point a callback source
    // actually landed on.
    NSMutableDictionary<NSValue *, NSArray *> *_charon_playerRoutes;
    BOOL _charon_offline;
    // Manual rendering. The mode itself, the format the offline render is in, the largest pull the
    // caller may ask for, the block that does the rendering, and the sample time the next pull is at.
    AUNode _charon_outputAUNode;
    AUNode _charon_mainMixerAUNode;
    AudioUnit _charon_outputUnit;
    BOOL _charon_manualRendering;
    AVAudioEngineManualRenderingMode _charon_manualMode;
    AVAudioFormat *_charon_manualFormat;
    AVAudioFrameCount _charon_manualMaximumFrameCount;
    AVAudioEngineManualRenderingBlock _charon_manualBlock;
    AVAudioFramePosition _charon_manualSampleTime;
}

static OSStatus CharonAddUnit(AUGraph graph, OSType type, OSType subtype, AUNode *outNode)
{
    AudioComponentDescription desc = {.componentType = type, .componentSubType = subtype, .componentManufacturer = kAudioUnitManufacturer_Apple};
    return AUGraphAddNode(graph, &desc, outNode);
}

- (instancetype)init
{
    if ((self = [super init])) {
        _charon_attached = [NSMutableSet set];
        _charon_playerRoutes = [NSMutableDictionary dictionary];
        _charon_offline = CharonOfflineOutput;

        AUGraph graph = NULL;
        NewAUGraph(&graph);
        AUGraphOpen(graph);
        _charon_graph = graph;

        AUNode outputAUNode = 0, mixerAUNode = 0;
    _charon_outputAUNode = 0;
    _charon_outputUnit = NULL;
    _charon_mainMixerAUNode = 0;
        CharonAddUnit(graph, kAudioUnitType_Output, CharonOfflineOutput ? kAudioUnitSubType_GenericOutput : kAudioUnitSubType_RemoteIO, &outputAUNode);
        CharonAddUnit(graph, kAudioUnitType_Mixer, kAudioUnitSubType_MultiChannelMixer, &mixerAUNode);
        AUGraphConnectNodeInput(graph, mixerAUNode, 0, outputAUNode, 0);

        _charon_outputAUNode = outputAUNode;
        _charon_mainMixerAUNode = mixerAUNode;
        AudioUnit outputUnit = NULL, mixerUnit = NULL;
        AUGraphNodeInfo(graph, outputAUNode, NULL, &outputUnit);
        AUGraphNodeInfo(graph, mixerAUNode, NULL, &mixerUnit);

        UInt32 maxFrames = 4096;
        AudioUnitSetProperty(outputUnit, kAudioUnitProperty_MaximumFramesPerSlice, kAudioUnitScope_Global, 0, &maxFrames, sizeof(maxFrames));

        _charon_output = [AVAudioOutputNode new];
        [_charon_output charon_setEngine:self auNode:outputAUNode audioUnit:outputUnit];

        _charon_mainMixer = [AVAudioMixerNode new];
        [_charon_mainMixer charon_setEngine:self auNode:mixerAUNode audioUnit:mixerUnit];

        _charon_input = [AVAudioInputNode new];   // real capture path is out of this port's scope for now; see facts
    }
    return self;
}

- (void)dealloc
{
    if (_charon_graph) {
        AUGraphStop(_charon_graph);
        AUGraphClose(_charon_graph);
        DisposeAUGraph(_charon_graph);
    }
}

- (void)attachNode:(AVAudioNode *)node
{
    if ([node isKindOfClass:[AVAudioPlayerNode class]]) {
        [node charon_setEngine:self auNode:-1 audioUnit:NULL];
        [_charon_attached addObject:node];
        return;
    }
    if ([node isKindOfClass:[AVAudioUnit class]]) {
        // The graph is already open (AUGraphOpen ran in -init) - AUGraphAddNode instantiates the
        // real component immediately, exactly like the output/mixer nodes created in -init, so
        // AUGraphNodeInfo already returns a real, usable AudioUnit right here, before the graph as
        // a whole is ever initialized.
        AudioComponentDescription desc = [(AVAudioUnit *)node audioComponentDescription];
        AUNode auNode = 0;
        CharonAddUnit(_charon_graph, desc.componentType, desc.componentSubType, &auNode);
        AudioUnit audioUnit = NULL;
        AUGraphNodeInfo(_charon_graph, auNode, NULL, &audioUnit);
        [node charon_setEngine:self auNode:auNode audioUnit:audioUnit];
        [(AVAudioUnit *)node charon_applyPendingParameters];
        [_charon_attached addObject:node];
        return;
    }
    [_charon_attached addObject:node];
}

- (void)detachNode:(AVAudioNode *)node
{
    [self disconnectNodeOutput:node];
    [self disconnectNodeInput:node];
    if ([node isKindOfClass:[AVAudioUnit class]])
        AUGraphRemoveNode(_charon_graph, [node charon_impl]->auNode);
    [node charon_setEngine:nil auNode:0 audioUnit:NULL];
    [_charon_attached removeObject:node];
}

- (void)connect:(AVAudioNode *)node1 to:(AVAudioNode *)node2 fromBus:(AVAudioNodeBus)bus1 toBus:(AVAudioNodeBus)bus2 format:(AVAudioFormat *)format
{
    AVAudioFormat *useFormat = format ?: [node1 outputFormatForBus:bus1];
    [node1 charon_setFormat:useFormat];
    [node2 charon_setFormat:useFormat];

    CharonAudioNodeImpl *destImpl = [node2 charon_impl];
    if (useFormat && destImpl->audioUnit)
        AudioUnitSetProperty(destImpl->audioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, bus2, [useFormat streamDescription], sizeof(AudioStreamBasicDescription));

    // The mixer's own output bus (towards the fixed mixer -> output connection made in -init) is
    // never itself the destination of a -connect:to:format: call, so nothing upstream would ever
    // otherwise set it - propagate here, once, so the whole offline chain shares one format.
    if (node2 == _charon_mainMixer && useFormat) {
        AudioUnitSetProperty(destImpl->audioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 0, [useFormat streamDescription], sizeof(AudioStreamBasicDescription));
        CharonAudioNodeImpl *outImpl = [_charon_output charon_impl];
        if (outImpl->audioUnit) {
            AudioUnitSetProperty(outImpl->audioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, [useFormat streamDescription], sizeof(AudioStreamBasicDescription));
            // The output unit's own Output scope is what AudioUnitRender actually formats `ioData`
            // by - measured, not assumed: every setup call here can return noErr while only the
            // Input scope is set, and AudioUnitRender still fails with -50 (paramErr) on the very
            // first pull. Setting Output scope too is what turned a real signal loss into an exact
            // sample match end to end (a raw AUGraph probe outside this class confirmed it before
            // this fix landed here - see facts/AVFoundation/AVAudioEngine.md).
            AudioUnitSetProperty(outImpl->audioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 0, [useFormat streamDescription], sizeof(AudioStreamBasicDescription));
        }
        [_charon_output charon_setFormat:useFormat];
    }

    if ([node1 isKindOfClass:[AVAudioPlayerNode class]]) {
        AURenderCallbackStruct callback = {.inputProc = CharonPlayerRenderCallback, .inputProcRefCon = (__bridge void *)node1};
        AUGraphSetNodeInputCallback(_charon_graph, destImpl->auNode, bus2, &callback);
        _charon_playerRoutes[[NSValue valueWithNonretainedObject:node1]] = @[node2, @(bus2)];
        return;
    }

    CharonAudioNodeImpl *srcImpl = [node1 charon_impl];
    if (srcImpl->audioUnit)
        AudioUnitSetProperty(srcImpl->audioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, bus1, [useFormat streamDescription], sizeof(AudioStreamBasicDescription));
    AUGraphConnectNodeInput(_charon_graph, srcImpl->auNode, bus1, destImpl->auNode, bus2);
}

- (void)connect:(AVAudioNode *)node1 to:(AVAudioNode *)node2 format:(AVAudioFormat *)format
{
    [self connect:node1 to:node2 fromBus:0 toBus:0 format:format];
}

- (void)disconnectNodeInput:(AVAudioNode *)node bus:(AVAudioNodeBus)bus
{
    CharonAudioNodeImpl *impl = [node charon_impl];
    if (impl->auNode)
        AUGraphDisconnectNodeInput(_charon_graph, impl->auNode, bus);
}

- (void)disconnectNodeInput:(AVAudioNode *)node
{
    [self disconnectNodeInput:node bus:0];
}

- (void)disconnectNodeOutput:(AVAudioNode *)node bus:(AVAudioNodeBus)bus
{
    if ([node isKindOfClass:[AVAudioPlayerNode class]]) {
        NSValue *key = [NSValue valueWithNonretainedObject:node];
        NSArray *route = _charon_playerRoutes[key];
        if (route) {
            AVAudioNode *dest = route[0];
            AVAudioNodeBus destBus = [route[1] unsignedIntValue];
            AURenderCallbackStruct empty = {.inputProc = NULL, .inputProcRefCon = NULL};
            AUGraphSetNodeInputCallback(_charon_graph, [dest charon_impl]->auNode, destBus, &empty);
            [_charon_playerRoutes removeObjectForKey:key];
        }
        return;
    }
    // Disconnecting the output of a real (non-player) node beyond the mixer/output pair this pass
    // wires is future work - see facts/AVFoundation/AVAudioEngine.md.
}

- (void)disconnectNodeOutput:(AVAudioNode *)node
{
    [self disconnectNodeOutput:node bus:0];
}

- (NSArray<AVAudioConnectionPoint *> *)outputConnectionPointsForNode:(AVAudioNode *)node outputBus:(AVAudioNodeBus)bus
{
    if ([node isKindOfClass:[AVAudioPlayerNode class]]) {
        NSArray *route = _charon_playerRoutes[[NSValue valueWithNonretainedObject:node]];
        if (!route)
            return @[];
        return @[[[AVAudioConnectionPoint alloc] initWithNode:route[0] bus:[route[1] unsignedIntValue]]];
    }
    if (node == _charon_mainMixer)
        return @[[[AVAudioConnectionPoint alloc] initWithNode:_charon_output bus:0]];
    return @[];
}

- (void)prepare
{
    if (!_charon_initialized) {
        AUGraphInitialize(_charon_graph);
        _charon_initialized = YES;
    }
}

// A GenericOutput-terminated graph has no I/O thread for AUGraphStart to hand control to -
// AUGraphStart expects a real hardware output driving the pull, which offline rendering never has
// by definition; calling it anyway measured as `AudioUnitRender` returning -50 (paramErr) on every
// following manual pull. AUGraphInitialize is still real work (readies every unit in the graph);
// only the "hand it to a hardware thread" step is specific to a live RemoteIO output and skipped
// here - see facts/AVFoundation/AVAudioEngine.md.
- (BOOL)startAndReturnError:(NSError **)outError
{
    [self prepare];
    if (_charon_offline) {
        _charon_running = YES;
        return YES;
    }
    OSStatus status = AUGraphStart(_charon_graph);
    _charon_running = status == noErr;
    if (status != noErr && outError)
        *outError = [NSError errorWithDomain:NSOSStatusErrorDomain code:status userInfo:nil];
    return status == noErr;
}

- (void)pause
{
    if (!_charon_offline)
        AUGraphStop(_charon_graph);
    _charon_running = NO;
}

- (void)stop
{
    if (!_charon_offline)
        AUGraphStop(_charon_graph);
    _charon_running = NO;
}

- (void)reset
{
    for (AVAudioNode *node in _charon_attached)
        [node reset];
}

- (AVAudioOutputNode *)outputNode
{
    return _charon_output;
}

- (AVAudioInputNode *)inputNode
{
    return _charon_input;
}

- (AVAudioMixerNode *)mainMixerNode
{
    return _charon_mainMixer;
}

- (BOOL)isRunning
{
    return _charon_running;
}

- (BOOL)isAutoShutdownEnabled
{
    return _charon_autoShutdown;
}

- (void)setAutoShutdownEnabled:(BOOL)autoShutdownEnabled
{
    _charon_autoShutdown = autoShutdownEnabled;
}


// ---- manual rendering, iOS 11 ----
//
// The engine's output is a real unit either way, and the difference is which one. In realtime it is
// the release's RemoteIO and an I/O thread drives it; in manual rendering it is a
// kAudioUnitSubType_GenericOutput, which needs no mediaserverd and is never started - the caller
// pulls it, and the pull is the release's own AudioUnitRender, the same call this file's offline
// output already made by hand through CharonAudioEngineTestSupport. The switch replaces the output
// node of the live graph, so an application gets manual rendering by calling the header's method and
// not by setting a flag first.

// Swaps the graph's output node for a generic output, re-connecting the main mixer to it. The mixer
// is the only node the engine connects to its output in -init, so that is the one connection to make.
- (BOOL)charon_replaceOutputWithGeneric
{
    if (_charon_outputAUNode == 0) {
        return NO;
    }
    AUNode previous = _charon_outputAUNode;
    AUGraphDisconnectNodeInput(_charon_graph, _charon_mainMixerAUNode, 0);
    AUGraphRemoveNode(_charon_graph, previous);
    AUNode output = 0;
    AudioComponentDescription description = {0};
    description.componentType = kAudioUnitType_Output;
    description.componentSubType = kAudioUnitSubType_GenericOutput;
    description.componentManufacturer = kAudioUnitManufacturer_Apple;
    if (AUGraphAddNode(_charon_graph, &description, &output) != noErr || output == 0) {
        return NO;
    }
    AUGraphConnectNodeInput(_charon_graph, _charon_mainMixerAUNode, 0, output, 0);
    AudioUnit unit = NULL;
    AUGraphNodeInfo(_charon_graph, output, NULL, &unit);
    _charon_outputAUNode = output;
    _charon_outputUnit = unit;
    UInt32 maxFrames = 1024;
    AudioUnitSetProperty(unit, kAudioUnitProperty_MaximumFramesPerSlice, kAudioUnitScope_Global, 0, &maxFrames, sizeof(maxFrames));
    // The new output takes the format the chain is already carrying, asked of the main mixer, which is
    // the node this graph connects to the output in -init. Both scopes are set, because AudioUnitRender
    // formats ioData by the Output scope and a pull with only the Input scope set fails with -50.
    AVAudioFormat *carried = [_charon_mainMixer outputFormatForBus:0];
    if (carried != nil) {
        AudioStreamBasicDescription described = *carried.streamDescription;
        AudioUnitSetProperty(_charon_outputUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0,
                             &described, sizeof(described));
        AudioUnitSetProperty(_charon_outputUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 0,
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
    if (!_charon_manualRendering) {
        [self prepare];
        if (![self charon_replaceOutputWithGeneric]) {
            if (outError) {
                *outError = [NSError errorWithDomain:NSOSStatusErrorDomain code:kAudioUnitErr_FailedInitialization userInfo:nil];
            }
            return NO;
        }
    }
    _charon_manualRendering = YES;
    _charon_manualMode = mode;
    _charon_manualFormat = pcmFormat;
    _charon_manualMaximumFrameCount = maximumFrameCount;
    _charon_manualSampleTime = 0;
    return YES;
}

- (void)disableManualRenderingMode
{
    _charon_manualRendering = NO;
    _charon_manualFormat = nil;
    _charon_manualBlock = nil;
    _charon_manualSampleTime = 0;
}

- (AVAudioEngineManualRenderingMode)manualRenderingMode
{
    return _charon_manualMode;
}

- (AVAudioFormat *)manualRenderingFormat
{
    return _charon_manualFormat;
}

- (AVAudioFrameCount)manualRenderingMaximumFrameCount
{
    return _charon_manualMaximumFrameCount;
}

- (AVAudioFramePosition)manualRenderingSampleTime
{
    return _charon_manualSampleTime;
}

- (AVAudioEngineManualRenderingBlock)manualRenderingBlock
{
    return _charon_manualBlock;
}

- (void)setManualRenderingBlock:(AVAudioEngineManualRenderingBlock)manualRenderingBlock
{
    // The block takes over the rendering: the caller's block is what the pull runs, and the output
    // unit's own pull is not used while one is set. It is kept in the caller's thread and is called
    // from the caller's pull, never from a thread of ours.
    _charon_manualBlock = [manualRenderingBlock copy];
}

// The offline pull: the release's AudioUnitRender on the engine's own output unit, with the frame
// count the caller asked for, and the sample time advanced by what was rendered. Nothing here is
// started: the output unit is a generic output, which has no I/O thread to start.
- (AVAudioEngineManualRenderingStatus)renderOffline:(AVAudioFrameCount)numberOfFrames
                                          toBuffer:(AVAudioPCMBuffer *)buffer
                                             error:(NSError **)outError
{
    if (!_charon_manualRendering) {
        if (outError) {
            *outError = [NSError errorWithDomain:NSOSStatusErrorDomain code:kAudioUnitErr_InvalidPropertyValue userInfo:nil];
        }
        return AVAudioEngineManualRenderingStatusError;
    }
    if (buffer == nil || numberOfFrames == 0 || numberOfFrames > _charon_manualMaximumFrameCount) {
        if (outError) {
            *outError = [NSError errorWithDomain:NSOSStatusErrorDomain code:kAudioUnitErr_InvalidPropertyValue userInfo:nil];
        }
        return AVAudioEngineManualRenderingStatusError;
    }
    AudioBufferList *destination = buffer.mutableAudioBufferList;
    if (destination == NULL) {
        return AVAudioEngineManualRenderingStatusError;
    }
    if (_charon_manualBlock != nil) {
        // The caller's block does the rendering, in the header's own shape - a frame count, a buffer
        // and an out error - so it is called on the caller's thread with the caller's buffer, and the
        // engine's own pull is not used while one is set.
        OSStatus blockError = noErr;
        AVAudioEngineManualRenderingStatus status = _charon_manualBlock(numberOfFrames, destination, &blockError);
        if (status == AVAudioEngineManualRenderingStatusSuccess) {
            _charon_manualSampleTime += numberOfFrames;
            buffer.frameLength = numberOfFrames;
        } else if (outError) {
            *outError = [NSError errorWithDomain:NSOSStatusErrorDomain code:blockError userInfo:nil];
        }
        return status;
    }
    AudioUnitRenderActionFlags flags = 0;
    AudioTimeStamp timestamp = {0};
    timestamp.mFlags = kAudioTimeStampSampleTimeValid;
    timestamp.mSampleTime = _charon_manualSampleTime;
    OSStatus status = AudioUnitRender(_charon_outputUnit, &flags, &timestamp, 0, numberOfFrames, destination);
    if (status != noErr) {
        if (outError) {
            *outError = [NSError errorWithDomain:NSOSStatusErrorDomain code:status userInfo:nil];
        }
        return AVAudioEngineManualRenderingStatusError;
    }
    _charon_manualSampleTime += numberOfFrames;
    buffer.frameLength = numberOfFrames;
    return AVAudioEngineManualRenderingStatusSuccess;
}

@end

@implementation CharonAudioEngineTestSupport

+ (void)setForcedOfflineOutput:(BOOL)offline
{
    CharonOfflineOutput = offline;
}

+ (OSStatus)pullOutput:(AudioBufferList *)ioData frames:(AVAudioFrameCount)frames fromEngine:(AVAudioEngine *)engine
{
    CharonAudioNodeImpl *impl = [[engine outputNode] charon_impl];
    AudioUnitRenderActionFlags flags = 0;
    AudioTimeStamp timestamp = {0};
    timestamp.mSampleTime = 0;
    timestamp.mFlags = kAudioTimeStampSampleTimeValid;
    return AudioUnitRender(impl->audioUnit, &flags, &timestamp, 0, frames, ioData);
}

@end
