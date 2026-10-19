#import "MTLTypeReflectionInternal.h"

// The 11.0 half of the reflection classes: a pipeline buffer descriptor and the array of them.
//
// MTLPipeline.h places both at 11.0, and they are the two that describe how a stage's buffers are
// BOUND rather than what they are - a mutability, and a place to keep a descriptor per index.
//
// What the plist carries decides the contents, not the shape. It writes a function's arguments and nothing
// about a pipeline's bindings, so a buffer descriptor here is NOT built from the file: the mutability
// is MTLMutabilityDefault - the enumeration's own zero and what a descriptor the port did not author
// means. The array has Apple's 31 slots and every one answers a descriptor, a fresh default until it is
// set. An earlier revision made the array empty on the reasoning that the plist has no bindings; Apple's
// own array answers a descriptor at every index, measured, so the empty array was a divergence.

@implementation MTLPipelineBufferDescriptor

{
    MTLMutability _mutability;
}

// The mutability, and the enum's own default for a descriptor this port did not author: the plist
// carries no bindings, so there is nothing to say a buffer is mutable or immutable, and
// MTLMutabilityDefault is the enumeration's zero (MTLPipeline.h:20).
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

// The protocol is <NSCopying> and the copy is the descriptor with the same mutability - a copy that
// dropped it would not be a copy of anything the caller can use.
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

// Apple's array has 31 slots: measured on the host, indices 0 to 30 answer and index 31 is a failed
// assertion that stops the process. The port raises NSRangeException there, the way the tile attachment
// array does, because an assertion cannot be reproduced in-process without taking the caller down.
static const NSUInteger CharonMetalPipelineBufferSlots = 31;

- (instancetype)init
{
    if ((self = [super init]))
        _descriptors = [NSMutableDictionary dictionary];
    return self;
}

// Every slot answers a descriptor. A slot nobody has set answers a fresh default one, and the same one on
// every read after that: measured on Apple's array, the second read of slot 0 is the first object. The
// storage is a DICTIONARY keyed by index, so the slots are separate objects and nothing is padded.
- (MTLPipelineBufferDescriptor *)objectAtIndexedSubscript:(NSUInteger)bufferIndex
{
    if (bufferIndex >= CharonMetalPipelineBufferSlots) {
        [NSException raise:NSRangeException format:@"bufferIndex(%lu) must be < %lu",
                           (unsigned long)bufferIndex, (unsigned long)CharonMetalPipelineBufferSlots];
        return nil;
    }
    MTLPipelineBufferDescriptor *buffer = _descriptors[@(bufferIndex)];
    if (!buffer) {
        buffer = [[MTLPipelineBufferDescriptor alloc] init];
        _descriptors[@(bufferIndex)] = buffer;
    }
    return buffer;
}

// A set keeps a COPY of the caller's descriptor, not the object itself: measured on Apple's array, the read
// back is a different object and it keeps the mutability it was set with. nil resets the slot to a fresh
// default, which is what the nullable setter does there (measured: the slot reads back non-nil, mutability
// MTLMutabilityDefault).
- (void)setObject:(MTLPipelineBufferDescriptor *)buffer atIndexedSubscript:(NSUInteger)bufferIndex
{
    if (bufferIndex >= CharonMetalPipelineBufferSlots) {
        [NSException raise:NSRangeException format:@"setObject:atIndexedSubscript:%lu: bufferIndex must be < %lu",
                           (unsigned long)bufferIndex, (unsigned long)CharonMetalPipelineBufferSlots];
        return;
    }
    _descriptors[@(bufferIndex)] = buffer ? [buffer copy] : [[MTLPipelineBufferDescriptor alloc] init];
}

@end
