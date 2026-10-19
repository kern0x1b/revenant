#import "CharonAVAudioEngine.h"

@implementation CharonScheduledBuffer
@synthesize buffer = _buffer;
@synthesize completionHandler = _completionHandler;
@synthesize framesConsumed = _framesConsumed;
@end

@implementation AVAudioNode {
    CharonAudioNodeImpl *_charon;
    AVAudioEngine * __weak _charon_engine;
    AVAudioFormat *_charon_format;
    NSMutableArray<CharonScheduledBuffer *> *_charon_queue;
    AVAudioNodeTapBlock _charon_tapBlock;
}

- (instancetype)init
{
    if ((self = [super init])) {
        _charon = calloc(1, sizeof(CharonAudioNodeImpl));
        _charon_queue = [NSMutableArray array];
    }
    return self;
}

- (void)dealloc
{
    free(_charon);
}

- (CharonAudioNodeImpl *)charon_impl
{
    return _charon;
}

- (void)charon_setEngine:(AVAudioEngine *)engine auNode:(AUNode)node audioUnit:(AudioUnit)unit
{
    _charon_engine = engine;
    _charon->auNode = node;
    _charon->audioUnit = unit;
    _charon->attached = engine != nil;
}

- (NSMutableArray<CharonScheduledBuffer *> *)charon_queue
{
    return _charon_queue;
}

- (AVAudioNodeTapBlock)charon_tapBlock
{
    return _charon_tapBlock;
}

- (void)charon_setFormat:(AVAudioFormat *)format
{
    _charon_format = format;
}

- (AVAudioEngine *)engine
{
    return _charon_engine;
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
    return _charon_format;
}

- (AVAudioFormat *)outputFormatForBus:(AVAudioNodeBus)bus
{
    return _charon_format;
}

- (nullable NSString *)nameForInputBus:(AVAudioNodeBus)bus
{
    return nil;
}

- (nullable NSString *)nameForOutputBus:(AVAudioNodeBus)bus
{
    return nil;
}

- (void)installTapOnBus:(AVAudioNodeBus)bus bufferSize:(AVAudioFrameCount)bufferSize format:(AVAudioFormat *)format block:(AVAudioNodeTapBlock)tapBlock
{
    _charon_tapBlock = [tapBlock copy];
    _charon->tapBufferSize = bufferSize;
    if (format)
        _charon_format = format;
}

- (void)removeTapOnBus:(AVAudioNodeBus)bus
{
    _charon_tapBlock = nil;
}

@end

@implementation AVAudioIONode
@end

@implementation AVAudioMixerNode
@end

@implementation AVAudioOutputNode
@end

@implementation AVAudioInputNode
@end
