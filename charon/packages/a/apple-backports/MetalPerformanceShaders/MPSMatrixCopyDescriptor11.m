// MPSMatrixCopyDescriptor, from the header of the SDK of iOS 16.4. One object per release: the band machinery keeps an
// object whole or drops it whole, so a file here carries the API of exactly one release.

#import "CharonMPS.h"


@implementation MPSMatrixCopyDescriptor {
    NSMutableArray *_sources;
    NSMutableArray *_destinations;
    NSMutableArray *_offsets;
    NSUInteger _count;
}

- (instancetype)init
{
    NSLog(@"MPSMatrixCopyDescriptor: -init makes a copy of nothing; use +descriptorWithSourceMatrix:destinationMatrix:offsets: or -initWithSourceMatrices:destinationMatrices:offsetVector:offset:");
    return nil;
}

// A copy descriptor holds no storage and runs on no device, so it is made from its count alone; the
// initialiser its header declares takes a device because the release's descriptor is a kernel-adjacent
// object, and this one takes the device and does not keep it.
- (id)charon_mps_withCount:(NSUInteger)count
{
    _sources = [NSMutableArray array];
    _destinations = [NSMutableArray array];
    _offsets = [NSMutableArray array];
    _count = count;
    return self;
}

- (instancetype)initWithDevice:(id<MTLDevice>)device count:(NSUInteger)count
{
    (void)device;
    return [[[self class] alloc] charon_mps_withCount:count];
}

+ (instancetype)descriptorWithSourceMatrix:(MPSMatrix *)sourceMatrix destinationMatrix:(MPSMatrix *)destinationMatrix offsets:(MPSMatrixCopyOffsets)offsets
{
    MPSMatrixCopyDescriptor *descriptor = [[[self class] alloc] charon_mps_withCount:1];
    [descriptor setCopyOperationAtIndex:0 sourceMatrix:sourceMatrix destinationMatrix:destinationMatrix offsets:offsets];
    return descriptor;
}

- (void)setCopyOperationAtIndex:(NSUInteger)index sourceMatrix:(MPSMatrix *)sourceMatrix destinationMatrix:(MPSMatrix *)destinationMatrix offsets:(MPSMatrixCopyOffsets)offsets
{
    if (index >= _count) {
        CharonMPSRefuse(@"MPSMatrixCopy: a copy descriptor of %lu operations has no operation %lu", (unsigned long)_count, (unsigned long)index);
        return;
    }
    while (_sources.count <= index) {
        [_sources addObject:[NSNull null]];
        [_destinations addObject:[NSNull null]];
        MPSMatrixCopyOffsets none = {0, 0, 0, 0};
        [_offsets addObject:[NSValue valueWithBytes:&none objCType:@encode(MPSMatrixCopyOffsets)]];
    }
    [_sources replaceObjectAtIndex:index withObject:sourceMatrix];
    [_destinations replaceObjectAtIndex:index withObject:destinationMatrix];
    [_offsets replaceObjectAtIndex:index withObject:[NSValue valueWithBytes:&offsets objCType:@encode(MPSMatrixCopyOffsets)]];
}

- (instancetype)initWithSourceMatrices:(NSArray<MPSMatrix *> *)sourceMatrices
                   destinationMatrices:(NSArray<MPSMatrix *> *)destinationMatrices
                          offsetVector:(MPSVector *)offsets
                                offset:(NSUInteger)byteOffset
{
    NSUInteger count = sourceMatrices.count < destinationMatrices.count ? sourceMatrices.count : destinationMatrices.count;
    MPSMatrixCopyDescriptor *descriptor = [[[self class] alloc] charon_mps_withCount:count];
    for (NSUInteger index = 0; index < count; index++) {
        MPSMatrixCopyOffsets zero = {0, 0, 0, 0};
        if (offsets) {
            // A packed array of MPSMatrixOffset, one per copy, whose elements the header says begin at
            // the vector's own offset plus the byte offset given here.
            const MPSMatrixOffset *packed = (const MPSMatrixOffset *)((const char *)[offsets.data contents] + offsets.offset + byteOffset) + index;
            zero.sourceRowOffset = packed->rowOffset;
            zero.sourceColumnOffset = packed->columnOffset;
        }
        [descriptor setCopyOperationAtIndex:index sourceMatrix:sourceMatrices[index] destinationMatrix:destinationMatrices[index] offsets:zero];
    }
    return descriptor;
}

- (NSUInteger)charon_mps_count
{
    return _count;
}

- (MPSMatrix *)charon_mps_sourceAtIndex:(NSUInteger)index
{
    return _sources[index];
}

- (MPSMatrix *)charon_mps_destinationAtIndex:(NSUInteger)index
{
    return _destinations[index];
}

- (MPSMatrixCopyOffsets)charon_mps_offsetsAtIndex:(NSUInteger)index
{
    MPSMatrixCopyOffsets offsets = {0, 0, 0, 0};
    [_offsets[index] getValue:&offsets];
    return offsets;
}

@end
