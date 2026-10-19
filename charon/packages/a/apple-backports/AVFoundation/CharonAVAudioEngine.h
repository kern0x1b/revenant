#import <AVFAudio/AVAudioFormat.h>
#import <AVFAudio/AVAudioTypes.h>
#import <AudioToolbox/AudioToolbox.h>

// Shared private plumbing for AVAudioNode/AVAudioEngine/AVAudioPlayerNode/AVAudioMixerNode/
// AVAudioOutputNode/AVAudioInputNode - one AUGraph per engine, real AUNodes and AudioUnits, no
// class name this port needs collides with anything native to 6.0/6.1.3 (checked with
// objc.inventory against the real armv7 shared cache before any of this was written - see
// facts/AVFoundation/AVAudioEngine.md).
//
// AVAudioPlayerNode carries no AudioUnit of its own. It is a buffer queue read from a C render
// callback wired onto whatever real node it is connected to via AUGraphSetNodeInputCallback -
// there is no stock Apple component that takes arbitrary AVAudioPCMBuffers as input the way this
// port's own scheduleBuffer: needs, so the callback *is* the source, exactly the way a synth or a
// generator unit would be if this device shipped one for that job.

NS_ASSUME_NONNULL_BEGIN

@class AVAudioEngine, AVAudioPCMBuffer, AVAudioTime, AVAudioConnectionPoint;

typedef void (^AVAudioNodeTapBlock)(AVAudioPCMBuffer *buffer, AVAudioTime * __nullable when);

// One scheduled buffer waiting in an AVAudioPlayerNode's queue.
@interface CharonScheduledBuffer : NSObject
@property (nonatomic, strong) AVAudioPCMBuffer *buffer;
@property (nonatomic, copy, nullable) void (^completionHandler)(void);
@property (nonatomic) AVAudioFrameCount framesConsumed;
@end

// Only plain C data here - the same lesson AVAudioBuffer already paid for (see
// AVFoundation/CharonAVAudioBuffer.h): ARC does not retain an Objective-C pointer just because a
// malloc'd struct field's declared type says it is one. `engine` is genuinely `__unsafe_unretained`
// here (there is no ARC-managed weak table entry for a plain malloc'd struct field either - a real
// `__weak` ivar is needed for that, which AVAudioNode carries instead), matching that the engine
// already owns every node's lifetime, never the reverse. format/queue/tapBlock are real ivars on
// AVAudioNode, declared below, not in this struct.
typedef struct {
    AUNode auNode;
    AudioUnit audioUnit;             // NULL for a pure-callback source (AVAudioPlayerNode)
    BOOL playing;                    // AVAudioPlayerNode only
    AVAudioFrameCount tapBufferSize;
    BOOL attached;
} CharonAudioNodeImpl;

@interface AVAudioNode : NSObject
- (CharonAudioNodeImpl *)charon_impl;
- (void)charon_setEngine:(nullable AVAudioEngine *)engine auNode:(AUNode)node audioUnit:(nullable AudioUnit)unit;
- (NSMutableArray<CharonScheduledBuffer *> *)charon_queue;   // AVAudioPlayerNode only, locked by @synchronized(self)
- (nullable AVAudioNodeTapBlock)charon_tapBlock;
- (void)charon_setFormat:(nullable AVAudioFormat *)format;
@property (nonatomic, readonly, nullable) AVAudioEngine *engine;
@property (nonatomic, readonly) NSUInteger numberOfInputs;
@property (nonatomic, readonly) NSUInteger numberOfOutputs;
- (void)reset;
- (AVAudioFormat *)inputFormatForBus:(AVAudioNodeBus)bus;
- (AVAudioFormat *)outputFormatForBus:(AVAudioNodeBus)bus;
- (void)installTapOnBus:(AVAudioNodeBus)bus bufferSize:(AVAudioFrameCount)bufferSize format:(nullable AVAudioFormat *)format block:(AVAudioNodeTapBlock)tapBlock;
- (void)removeTapOnBus:(AVAudioNodeBus)bus;
@end

@interface AVAudioIONode : AVAudioNode
@end

@interface AVAudioMixerNode : AVAudioNode
@end

@interface AVAudioOutputNode : AVAudioIONode
@end

@interface AVAudioInputNode : AVAudioIONode
@end

@interface AVAudioPlayerNode : AVAudioNode
- (void)scheduleBuffer:(AVAudioPCMBuffer *)buffer completionHandler:(nullable void (^)(void))completionHandler;
- (void)scheduleBuffer:(AVAudioPCMBuffer *)buffer atTime:(nullable AVAudioTime *)when options:(NSUInteger)options completionHandler:(nullable void (^)(void))completionHandler;
- (void)play;
- (void)pause;
- (void)stop;
@property (nonatomic, readonly) BOOL isPlaying;
@end

@interface AVAudioEngine : NSObject
- (void)attachNode:(AVAudioNode *)node;
- (void)detachNode:(AVAudioNode *)node;
- (void)connect:(AVAudioNode *)node1 to:(AVAudioNode *)node2 fromBus:(AVAudioNodeBus)bus1 toBus:(AVAudioNodeBus)bus2 format:(nullable AVAudioFormat *)format;
- (void)connect:(AVAudioNode *)node1 to:(AVAudioNode *)node2 format:(nullable AVAudioFormat *)format;
- (void)disconnectNodeInput:(AVAudioNode *)node bus:(AVAudioNodeBus)bus;
- (void)disconnectNodeInput:(AVAudioNode *)node;
- (void)disconnectNodeOutput:(AVAudioNode *)node bus:(AVAudioNodeBus)bus;
- (void)disconnectNodeOutput:(AVAudioNode *)node;
- (void)prepare;
- (BOOL)startAndReturnError:(NSError **)outError;
- (void)pause;
- (void)stop;
- (void)reset;
- (NSArray<AVAudioConnectionPoint *> *)outputConnectionPointsForNode:(AVAudioNode *)node outputBus:(AVAudioNodeBus)bus;
@property (nonatomic, readonly) AVAudioOutputNode *outputNode;
@property (nonatomic, readonly) AVAudioInputNode *inputNode;
@property (nonatomic, readonly) AVAudioMixerNode *mainMixerNode;
@property (nonatomic, readonly, getter=isRunning) BOOL running;
@property (nonatomic, getter=isAutoShutdownEnabled) BOOL autoShutdownEnabled;
@end

// Test-only, on a class of its own, never `AVAudioEngine` itself - two separate, both measured,
// not guessed:
//
// First: a method added straight onto a *registered* class's own @implementation
// (+charon_setForcedOfflineOutput: on AVAudioEngine itself, a class registry/AVFoundation/*.json
// names) linked fine and then raised "unrecognized selector sent to class" at runtime - the class
// was found, dispatch reached it, nothing in its metaclass's method list matched. Packaging
// appears to prune a registered class's method list down to what the registry actually names,
// which is reasonable: the registry is this port's honest claim about what a real API surface
// carries, and a stray test hook is not part of that claim.
//
// Second, found moving the hooks here: this project deliberately hides every symbol whose bare
// name starts with "charon_"/"Charon" from a dylib's exported symbol table -
// modules/apple/backports.lua's internal_symbol(), by design, driving an explicit
// -Wl,-unexported_symbols_list at link time (not a compiler visibility attribute, which does not
// touch it - tried first, had no effect). The classes this port ships under Apple's own real
// names are its API; a "Charon"-prefixed one is never meant to be linked against from outside,
// and `CharonAudioEngineTestSupport` is exactly such a name, on purpose. `CharonAudioBuffer` never
// exposed this because nothing outside this dylib ever references it *by name* - only through
// inheritance, resolved internally at build time. A probe binary needing to reach this class does
// what the Objective-C runtime always allows regardless of static/dynamic symbol export: look it
// up by name (`NSClassFromString`) and send by name (`objc_msgSend` through `NSSelectorFromString`)
// - the class is still fully registered in `__objc_classlist` at load time either way, only
// *static linking* against its symbol was ever blocked. See engine-probe.m for the caller side.
@interface CharonAudioEngineTestSupport : NSObject
// Forces the engine's output terminal to kAudioUnitSubType_GenericOutput (needs no mediaserverd)
// instead of the real kAudioUnitSubType_RemoteIO an application gets by default. Never set outside
// a device-probe/test binary; must be called before +[AVAudioEngine new]/-init.
+ (void)setForcedOfflineOutput:(BOOL)offline;
// Pulls `frames` sample frames from the engine's real output unit by hand, the same
// AudioUnitRender a live RemoteIO's I/O thread would call, except driven here rather than by a
// hardware clock - the whole point of terminating the graph in GenericOutput. Returns the OSStatus
// AudioUnitRender itself returned.
+ (OSStatus)pullOutput:(AudioBufferList *)ioData frames:(AVAudioFrameCount)frames fromEngine:(AVAudioEngine *)engine;
@end

NS_ASSUME_NONNULL_END
