#import "RevenantMPS.h"


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

- (BOOL)revenant_mps_permitsExecution
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
