#import "RevenantMetal.h"
#import "RevenantMetalProtocols.h"

#pragma clang diagnostic ignored "-Wprotocol"
#pragma clang diagnostic ignored "-Wincomplete-implementation"

#pragma mark - the acceleration structure pass

@implementation MTLAccelerationStructurePassSampleBufferAttachmentDescriptor {
    id<MTLCounterSampleBuffer> _sampleBuffer;
    NSUInteger _startOfEncoderSampleIndex;
    NSUInteger _endOfEncoderSampleIndex;
}

- (instancetype)init
{
    if ((self = [super init])) {
        _startOfEncoderSampleIndex = MTLCounterDontSample;
        _endOfEncoderSampleIndex = MTLCounterDontSample;
    }
    return self;
}

@synthesize sampleBuffer = _sampleBuffer;
@synthesize startOfEncoderSampleIndex = _startOfEncoderSampleIndex;
@synthesize endOfEncoderSampleIndex = _endOfEncoderSampleIndex;

- (id)copyWithZone:(NSZone *)zone
{
    MTLAccelerationStructurePassSampleBufferAttachmentDescriptor *copy =
        [[MTLAccelerationStructurePassSampleBufferAttachmentDescriptor alloc] init];
    copy.sampleBuffer = _sampleBuffer;
    copy.startOfEncoderSampleIndex = _startOfEncoderSampleIndex;
    copy.endOfEncoderSampleIndex = _endOfEncoderSampleIndex;
    return copy;
}

@end

@interface MTLAccelerationStructurePassSampleBufferAttachmentDescriptorArray () {
    MTLAccelerationStructurePassSampleBufferAttachmentDescriptor *_slots[4];
}
@end

static void RevenantMetalRefuseAttachmentIndex(NSString *selector, NSUInteger index)
{
    [NSException raise:NSInvalidArgumentException
                format:@"%@: attachmentIndex(%lu) must be < 4", selector, (unsigned long)index];
}

@implementation MTLAccelerationStructurePassSampleBufferAttachmentDescriptorArray

- (MTLAccelerationStructurePassSampleBufferAttachmentDescriptor *)objectAtIndexedSubscript:(NSUInteger)index
{
    if (index >= 4) {
        RevenantMetalRefuseAttachmentIndex(@"objectAtIndexedSubscript:", index);
        return nil;
    }
    if (!_slots[index]) {
        _slots[index] = [[MTLAccelerationStructurePassSampleBufferAttachmentDescriptor alloc] init];
    }
    return _slots[index];
}

- (void)setObject:(MTLAccelerationStructurePassSampleBufferAttachmentDescriptor *)attachment
    atIndexedSubscript:(NSUInteger)index
{
    if (index >= 4) {
        RevenantMetalRefuseAttachmentIndex(@"setObject:atIndexedSubscript:", index);
        return;
    }
    _slots[index] = attachment ? [attachment copy] : nil;
}

@end

@interface MTLAccelerationStructurePassDescriptor () {
    MTLAccelerationStructurePassSampleBufferAttachmentDescriptorArray *_sampleBufferAttachments;
}
@end

@implementation MTLAccelerationStructurePassDescriptor

@synthesize sampleBufferAttachments = _sampleBufferAttachments;

- (instancetype)init
{
    if ((self = [super init]))
        _sampleBufferAttachments = [[MTLAccelerationStructurePassSampleBufferAttachmentDescriptorArray alloc] init];
    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    MTLAccelerationStructurePassDescriptor *copy = [[MTLAccelerationStructurePassDescriptor alloc] init];
    MTLAccelerationStructurePassSampleBufferAttachmentDescriptorArray *from = _sampleBufferAttachments;
    MTLAccelerationStructurePassSampleBufferAttachmentDescriptorArray *into = copy.sampleBufferAttachments;
    for (NSUInteger index = 0; index < 4; index++) {
        [into setObject:[from objectAtIndexedSubscript:index] atIndexedSubscript:index];
    }
    return copy;
}

@end

#pragma mark - the IO command queue

@implementation MTLIOCommandQueueDescriptor {
    NSUInteger _maxCommandBufferCount;
    MTLIOPriority _priority;
    MTLIOCommandQueueType _type;
    NSUInteger _maxCommandsInFlight;
    id<MTLIOScratchBufferAllocator> _scratchBufferAllocator;
}

@synthesize maxCommandBufferCount = _maxCommandBufferCount;
@synthesize priority = _priority;
@synthesize type = _type;
@synthesize maxCommandsInFlight = _maxCommandsInFlight;
@synthesize scratchBufferAllocator = _scratchBufferAllocator;

- (instancetype)init
{
    if ((self = [super init])) {
        _maxCommandBufferCount = 64;
        _priority = MTLIOPriorityNormal;
        _type = MTLIOCommandQueueTypeConcurrent;
        _maxCommandsInFlight = 0;
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    MTLIOCommandQueueDescriptor *copy = [[MTLIOCommandQueueDescriptor alloc] init];
    copy.maxCommandBufferCount = _maxCommandBufferCount;
    copy.priority = _priority;
    copy.type = _type;
    copy.scratchBufferAllocator = _scratchBufferAllocator;
    return copy;
}

@end
