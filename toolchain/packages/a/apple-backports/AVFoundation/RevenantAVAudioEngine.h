#import <AVFAudio/AVAudioFormat.h>
#import <AVFAudio/AVAudioTypes.h>
#import <AudioToolbox/AudioToolbox.h>

NS_ASSUME_NONNULL_BEGIN

@class AVAudioEngine, AVAudioPCMBuffer, AVAudioTime, AVAudioConnectionPoint;

typedef void (^AVAudioNodeTapBlock)(AVAudioPCMBuffer *buffer, AVAudioTime * __nullable when);

@interface CharonScheduledBuffer : NSObject
@property (nonatomic, strong) AVAudioPCMBuffer *buffer;
@property (nonatomic, copy, nullable) void (^completionHandler)(void);
@property (nonatomic) AVAudioFrameCount framesConsumed;
@end

typedef struct {
    AUNode auNode;
    AudioUnit audioUnit;
    BOOL playing;
    AVAudioFrameCount tapBufferSize;
    BOOL attached;
} CharonAudioNodeImpl;

@interface AVAudioNode : NSObject
- (CharonAudioNodeImpl *)charon_impl;
- (void)charon_setEngine:(nullable AVAudioEngine *)engine auNode:(AUNode)node audioUnit:(nullable AudioUnit)unit;
- (NSMutableArray<CharonScheduledBuffer *> *)charon_queue;
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

@interface CharonAudioEngineTestSupport : NSObject
+ (void)setForcedOfflineOutput:(BOOL)offline;
+ (OSStatus)pullOutput:(AudioBufferList *)ioData frames:(AVAudioFrameCount)frames fromEngine:(AVAudioEngine *)engine;
@end

NS_ASSUME_NONNULL_END
