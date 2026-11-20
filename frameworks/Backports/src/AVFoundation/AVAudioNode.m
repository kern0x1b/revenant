#import "RevenantAVAudioEngine.h"
#import "RevenantAVAudioTap.h"
#import <AVFoundation/AVAudioSession.h>

@implementation RevenantScheduledBuffer
@synthesize buffer = _buffer;
@synthesize completionHandler = _completionHandler;
@synthesize framesConsumed = _framesConsumed;
@end

@implementation AVAudioNode {
    RevenantAudioNodeImpl *_revenant;
    AVAudioEngine * __weak _revenant_engine;
    AVAudioFormat *_revenant_format;
    NSMutableArray<RevenantScheduledBuffer *> *_revenant_queue;
    AVAudioNodeTapBlock _revenant_tapBlock;
    RevenantTapPump *_revenant_pump;
    NSMutableArray<RevenantTapPump *> *_revenant_retired;
    BOOL _revenant_notifyInstalled;
}

- (instancetype)init
{
    if ((self = [super init])) {
        _revenant = calloc(1, sizeof(RevenantAudioNodeImpl));
        _revenant_queue = [NSMutableArray array];
    }
    return self;
}

- (void)dealloc
{
    free(_revenant);
}

- (RevenantAudioNodeImpl *)revenant_impl
{
    return _revenant;
}

- (void)revenant_setEngine:(AVAudioEngine *)engine auNode:(AUNode)node audioUnit:(AudioUnit)unit
{
    _revenant_engine = engine;
    _revenant->auNode = node;
    _revenant->audioUnit = unit;
    _revenant->attached = engine != nil;
}

- (NSMutableArray<RevenantScheduledBuffer *> *)revenant_queue
{
    return _revenant_queue;
}

- (AVAudioNodeTapBlock)revenant_tapBlock
{
    return _revenant_tapBlock;
}

- (void)revenant_setFormat:(AVAudioFormat *)format
{
    _revenant_format = format;
}

- (AVAudioEngine *)engine
{
    return _revenant_engine;
}

- (NSUInteger)numberOfInputs
{
    return [self isKindOfClass:[AVAudioPlayerNode class]] || [self isKindOfClass:[AVAudioInputNode class]] ? 0 : 1;
}

- (NSUInteger)numberOfOutputs
{
    return 1;
}

- (void)reset
{
}

- (AVAudioFormat *)inputFormatForBus:(AVAudioNodeBus)bus
{
    return _revenant_format;
}


- (AVAudioFormat *)outputFormatForBus:(AVAudioNodeBus)bus
{
    return _revenant_format;
}

- (nullable NSString *)nameForInputBus:(AVAudioNodeBus)bus
{
    return nil;
}

- (nullable NSString *)nameForOutputBus:(AVAudioNodeBus)bus
{
    return nil;
}

- (RevenantTapPump *)revenant_pump
{
    return _revenant_pump;
}

- (void)revenant_retirePump
{
    if (_revenant_pump == nil)
        return;
    [_revenant_pump stop];
    if (_revenant_notifyInstalled && _revenant->audioUnit) {
        AudioUnitRemoveRenderNotify(_revenant->audioUnit, RevenantTapRenderNotify, (__bridge void *)_revenant_pump);
        _revenant_notifyInstalled = NO;
    }
    if (_revenant_retired == nil)
        _revenant_retired = [NSMutableArray array];
    [_revenant_retired addObject:_revenant_pump];
    _revenant_pump = nil;
}

- (void)installTapOnBus:(AVAudioNodeBus)bus bufferSize:(AVAudioFrameCount)bufferSize format:(AVAudioFormat *)format block:(AVAudioNodeTapBlock)tapBlock
{
    _revenant_tapBlock = [tapBlock copy];
    _revenant->tapBufferSize = bufferSize;
    if (format)
        _revenant_format = format;
    if ([self isKindOfClass:[AVAudioInputNode class]])
        [(AVAudioInputNode *)self revenant_inputState]->pump = NULL;
    [self revenant_retirePump];
    AVAudioFormat *tapFormat = format ?: _revenant_format ?: [self outputFormatForBus:bus];
    if (tapFormat == nil || tapBlock == nil)
        return;
    _revenant_pump = [[RevenantTapPump alloc] initWithFormat:tapFormat bufferSize:bufferSize block:tapBlock];
    if (![self isKindOfClass:[AVAudioInputNode class]] && _revenant->audioUnit) {
        AudioUnitAddRenderNotify(_revenant->audioUnit, RevenantTapRenderNotify, (__bridge void *)_revenant_pump);
        _revenant_notifyInstalled = YES;
    }
    if ([self isKindOfClass:[AVAudioInputNode class]])
        [(AVAudioInputNode *)self revenant_inputState]->pump = (__bridge void *)_revenant_pump;
    [_revenant_engine revenant_inputChanged];
}

- (void)removeTapOnBus:(AVAudioNodeBus)bus
{
    _revenant_tapBlock = nil;
    if ([self isKindOfClass:[AVAudioInputNode class]])
        [(AVAudioInputNode *)self revenant_inputState]->pump = NULL;
    [self revenant_retirePump];
}

@end

@implementation AVAudioIONode {
    BOOL _revenant_voiceProcessing;
}

- (BOOL)setVoiceProcessingEnabled:(BOOL)enabled error:(NSError **)outError
{
    if (enabled == _revenant_voiceProcessing)
        return YES;
    AVAudioEngine *engine = self.engine;
    if (engine != nil && ![engine revenant_setVoiceProcessingEnabled:enabled error:outError])
        return NO;
    _revenant_voiceProcessing = enabled;
    [engine revenant_inputChanged];
    return YES;
}

- (BOOL)isVoiceProcessingEnabled
{
    return _revenant_voiceProcessing;
}

@end

@implementation AVAudioMixerNode
@end

@implementation AVAudioOutputNode
@end

@implementation AVAudioInputNode {
    RevenantInputState *_revenant_state;
    BOOL _revenant_bypassed;
    BOOL _revenant_agc;
    BOOL _revenant_muted;
}

- (instancetype)init
{
    if ((self = [super init])) {
        _revenant_state = calloc(1, sizeof(RevenantInputState));
        _revenant_state->scratchFrames = 4096;
        _revenant_state->scratch = calloc(_revenant_state->scratchFrames, sizeof(int16_t));
        _revenant_agc = YES;
    }
    return self;
}

- (void)dealloc
{
    _revenant_state->pump = NULL;
    free(_revenant_state->scratch);
    free(_revenant_state);
}

- (RevenantInputState *)revenant_inputState
{
    return _revenant_state;
}

- (AVAudioFormat *)outputFormatForBus:(AVAudioNodeBus)bus
{
    AVAudioFormat *set = [super outputFormatForBus:bus];
    if (set)
        return set;
    double rate = [AVAudioSession sharedInstance].sampleRate;
    return [[AVAudioFormat alloc] initWithCommonFormat:AVAudioPCMFormatFloat32 sampleRate:rate > 0 ? rate : 44100 channels:1 interleaved:NO];
}

- (AVAudioFormat *)inputFormatForBus:(AVAudioNodeBus)bus
{
    return [self outputFormatForBus:bus];
}

- (BOOL)isVoiceProcessingBypassed
{
    return _revenant_bypassed;
}

- (void)setVoiceProcessingBypassed:(BOOL)bypassed
{
    _revenant_bypassed = bypassed;
    [self.engine revenant_applyVoiceProcessing];
}

- (BOOL)isVoiceProcessingAGCEnabled
{
    return _revenant_agc;
}

- (void)setVoiceProcessingAGCEnabled:(BOOL)enabled
{
    _revenant_agc = enabled;
    [self.engine revenant_applyVoiceProcessing];
}

- (BOOL)isVoiceProcessingInputMuted
{
    return _revenant_muted;
}

- (void)setVoiceProcessingInputMuted:(BOOL)muted
{
    _revenant_muted = muted;
    _revenant_state->muted = muted ? 1 : 0;
}

@end
