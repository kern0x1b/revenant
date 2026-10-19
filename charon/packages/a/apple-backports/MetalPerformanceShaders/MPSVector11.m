// MPSVector, from the header of the SDK of iOS 16.4. One object per release: the band machinery keeps an
// object whole or drops it whole, so a file here carries the API of exactly one release.

#import "CharonMPS.h"


@implementation MPSVector {
    id<MTLBuffer> _buffer;
    MPSVectorDescriptor *_descriptor;
    NSUInteger _offset;
    id<MTLDevice> _device;
}

- (instancetype)initWithBuffer:(id<MTLBuffer>)buffer descriptor:(MPSVectorDescriptor *)descriptor
{
    if ((self = [super init])) {
        _buffer = buffer;
        _descriptor = descriptor;
        _device = [buffer device];
    }
    return self;
}

- (instancetype)initWithBuffer:(id<MTLBuffer>)buffer offset:(NSUInteger)offset descriptor:(MPSVectorDescriptor *)descriptor
{
    if ((self = [super init])) {
        _buffer = buffer;
        _descriptor = descriptor;
        _offset = offset;
        _device = [buffer device];
    }
    return self;
}

- (instancetype)initWithDevice:(id<MTLDevice>)device descriptor:(MPSVectorDescriptor *)descriptor
{
    if ((self = [super init])) {
        _descriptor = descriptor;
        _device = device;
    }
    return self;
}

- (instancetype)init
{
    NSLog(@"MPSVector: -init makes a vector of no length; use -initWithBuffer:descriptor: or -initWithDevice:descriptor:");
    return nil;
}

- (id<MTLBuffer>)data
{
    if (!_buffer) {
        size_t elementSize = MPSSizeofMPSDataType(_descriptor.dataType);
        size_t bytes = (_descriptor.vectors - 1) * _descriptor.vectorBytes + _descriptor.length * elementSize;
        _buffer = [_device newBufferWithLength:bytes options:MTLResourceStorageModeShared];
    }
    return _buffer;
}

- (id<MTLDevice>)device
{
    return _device;
}

- (NSUInteger)length
{
    return _descriptor.length;
}

- (NSUInteger)vectors
{
    return _descriptor.vectors;
}

- (MPSDataType)dataType
{
    return _descriptor.dataType;
}

- (NSUInteger)vectorBytes
{
    return _descriptor.vectorBytes;
}

- (NSUInteger)offset
{
    return _offset;
}

- (void)synchronizeOnCommandBuffer:(id<MTLCommandBuffer>)commandBuffer
{
    (void)commandBuffer;
}

- (NSUInteger)resourceSize
{
    if (_buffer)
        return _buffer.length;
    if (!_descriptor)
        return 0;
    return (_descriptor.vectors - 1) * _descriptor.vectorBytes + _descriptor.length * MPSSizeofMPSDataType(_descriptor.dataType);
}

@end
