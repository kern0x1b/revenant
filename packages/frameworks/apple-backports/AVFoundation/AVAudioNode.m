#import "RevenantAVAudioEngine.h"

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

- (void)installTapOnBus:(AVAudioNodeBus)bus bufferSize:(AVAudioFrameCount)bufferSize format:(AVAudioFormat *)format block:(AVAudioNodeTapBlock)tapBlock
{
    _revenant_tapBlock = [tapBlock copy];
    _revenant->tapBufferSize = bufferSize;
    if (format)
        _revenant_format = format;
}

- (void)removeTapOnBus:(AVAudioNodeBus)bus
{
    _revenant_tapBlock = nil;
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
