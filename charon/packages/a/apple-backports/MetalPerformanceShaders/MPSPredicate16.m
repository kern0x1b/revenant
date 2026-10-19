// MPSPredicate, from the header of the SDK of iOS 16.4. One object per release: the band machinery keeps an
// object whole or drops it whole, so a file here carries the API of exactly one release.

#import "CharonMPS.h"


@implementation MPSPredicate {
    id<MTLBuffer> _buffer;
    NSUInteger _offset;
    id<MTLDevice> _device;
}

+ (instancetype)predicateWithBuffer:(id<MTLBuffer>)buffer offset:(NSUInteger)offset
{
    return [[self alloc] initWithBuffer:buffer offset:offset];
}

- (instancetype)initWithBuffer:(id<MTLBuffer>)buffer offset:(NSUInteger)offset
{
    if ((self = [super init])) {
        _buffer = buffer;
        _offset = offset;
    }
    return self;
}

- (instancetype)initWithDevice:(id<MTLDevice>)device
{
    // The release takes a device and draws its predicate bytes from a heap MPS manages, so the
    // caller never sees the buffer. This port has no MPS heap, so the predicate is backed by a
    // buffer of its own, made here, that the caller can reach through -predicateBuffer and write
    // through. A predicate of this kind is the same object the header describes: a uint32 that is
    // not zero lets the kernel run.
    if ((self = [super init])) {
        _device = device;
        _buffer = [device newBufferWithLength:4 options:MTLResourceStorageModeShared];
    }
    return self;
}

- (id<MTLBuffer>)predicateBuffer
{
    return _buffer;
}

- (NSUInteger)predicateOffset
{
    return _offset;
}

// Whether the kernel this predicate is attached to runs. The header's rule is the release's own: the
// uint32 at the offset is not zero for true.
- (BOOL)charon_mps_permitsExecution
{
    if (!_buffer)
        return YES;
    if (_offset + 4 > _buffer.length)
        return NO;
    uint32_t value = 0;
    memcpy(&value, (const char *)[_buffer contents] + _offset, 4);
    return value != 0;
}

@end
