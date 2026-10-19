#import "CharonMPS.h"


NSUInteger MPSStateBatchIncrementReadCount(NSArray<MPSState *> *batch, NSInteger amount)
{
    for (MPSState *state in batch) {
        uint64_t wanted = (uint64_t)state.readCount + (uint64_t)(int64_t)amount;
        if ((int64_t)amount < 0 && wanted > (uint64_t)state.readCount)
            wanted = 0;
        if ((int64_t)amount >= 0 && wanted < (uint64_t)state.readCount)
            wanted = UINT64_MAX;
        state.readCount = (NSUInteger)wanted;
    }
    return batch.count;
}

void MPSStateBatchSynchronize(NSArray<MPSState *> *batch, id<MTLCommandBuffer>cmdBuf)
{
    for (MPSState *state in batch)
        [state synchronizeOnCommandBuffer:cmdBuf];
}

NSUInteger MPSStateBatchResourceSize(NSArray<MPSState *> *batch)
{
    NSUInteger total = 0;
    for (MPSState *state in batch)
        total += [state resourceSize];
    return total;
}
@implementation MPSStateResourceList {
    NSMutableArray *_sizes;
    NSMutableArray *_textures;
}

+ (instancetype)resourceList
{
    return [[self alloc] init];
}

+ (instancetype)resourceListWithTextureDescriptors:(MTLTextureDescriptor *)d, ...
{
    MPSStateResourceList *list = [[self alloc] init];
    va_list arguments;
    va_start(arguments, d);
    for (MTLTextureDescriptor *descriptor = d; descriptor; descriptor = va_arg(arguments, MTLTextureDescriptor *))
        [list appendTexture:descriptor];
    va_end(arguments);
    return list;
}

+ (instancetype)resourceListWithBufferSizes:(NSUInteger)firstSize, ...
{
    MPSStateResourceList *list = [[self alloc] init];
    va_list arguments;
    va_start(arguments, firstSize);
    for (NSUInteger size = firstSize; size; size = va_arg(arguments, NSUInteger))
        [list appendBuffer:size];
    va_end(arguments);
    return list;
}

- (instancetype)init
{
    if ((self = [super init])) {
        _sizes = [NSMutableArray array];
        _textures = [NSMutableArray array];
    }
    return self;
}

- (void)appendBuffer:(NSUInteger)size
{
    [_sizes addObject:[NSNumber numberWithUnsignedInteger:size]];
}

- (void)appendTexture:(MTLTextureDescriptor *)descriptor
{
    [_textures addObject:descriptor];
}

- (NSArray<NSNumber *> *)charon_mps_bufferSizes
{
    return _sizes;
}

- (NSArray<MTLTextureDescriptor *> *)charon_mps_textureDescriptors
{
    return _textures;
}

@end
