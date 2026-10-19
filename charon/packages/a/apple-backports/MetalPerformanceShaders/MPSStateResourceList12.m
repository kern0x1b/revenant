// MPSStateResourceList, from the header of the SDK of iOS 16.4. One object per release: the band machinery keeps an
// object whole or drops it whole, so a file here carries the API of exactly one release.

#import "CharonMPS.h"


NSUInteger MPSStateBatchIncrementReadCount(NSArray<MPSState *> *batch, NSInteger amount)
{
    // What the release's own answers say this returns, measured rather than assumed: a batch of one,
    // two and three states all answer their own number of states, whatever the counts become, so the
    // return value is the size of the batch and not a read count
    // (tests/backports/host/mpsmatrix/run.sh prints the table). The counts themselves move by the
    // amount, stopping at zero and saturating at the top rather than wrapping, and the addition is
    // done in the wider of the two types: NSUIntegerMax written as an int64_t is negative, which
    // would make every count the largest.
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

// What a state made from this list holds: the buffers first, in the order they were appended, then
// the textures, as the release's own list does.
- (NSArray<NSNumber *> *)charon_mps_bufferSizes
{
    return _sizes;
}

- (NSArray<MTLTextureDescriptor *> *)charon_mps_textureDescriptors
{
    return _textures;
}

@end
