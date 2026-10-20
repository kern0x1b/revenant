#import "MTLTypeReflectionInternal.h"

@implementation MTLPipelineBufferDescriptor

{
    MTLMutability _mutability;
}

- (instancetype)init
{
    if ((self = [super init]))
        _mutability = MTLMutabilityDefault;
    return self;
}

- (MTLMutability)mutability
{
    return _mutability;
}

- (void)setMutability:(MTLMutability)mutability
{
    _mutability = mutability;
}

- (id)copyWithZone:(NSZone *)zone
{
    (void)zone;
    MTLPipelineBufferDescriptor *copy = [[[self class] alloc] init];
    copy.mutability = _mutability;
    return copy;
}

@end

@implementation MTLPipelineBufferDescriptorArray

{
    NSMutableDictionary *_descriptors;
}

static const NSUInteger RevenantMetalPipelineBufferSlots = 31;

- (instancetype)init
{
    if ((self = [super init]))
        _descriptors = [NSMutableDictionary dictionary];
    return self;
}

- (MTLPipelineBufferDescriptor *)objectAtIndexedSubscript:(NSUInteger)bufferIndex
{
    if (bufferIndex >= RevenantMetalPipelineBufferSlots) {
        [NSException raise:NSRangeException format:@"bufferIndex(%lu) must be < %lu",
                           (unsigned long)bufferIndex, (unsigned long)RevenantMetalPipelineBufferSlots];
        return nil;
    }
    MTLPipelineBufferDescriptor *buffer = _descriptors[@(bufferIndex)];
    if (!buffer) {
        buffer = [[MTLPipelineBufferDescriptor alloc] init];
        _descriptors[@(bufferIndex)] = buffer;
    }
    return buffer;
}

- (void)setObject:(MTLPipelineBufferDescriptor *)buffer atIndexedSubscript:(NSUInteger)bufferIndex
{
    if (bufferIndex >= RevenantMetalPipelineBufferSlots) {
        [NSException raise:NSRangeException format:@"setObject:atIndexedSubscript:%lu: bufferIndex must be < %lu",
                           (unsigned long)bufferIndex, (unsigned long)RevenantMetalPipelineBufferSlots];
        return;
    }
    _descriptors[@(bufferIndex)] = buffer ? [buffer copy] : [[MTLPipelineBufferDescriptor alloc] init];
}

@end
