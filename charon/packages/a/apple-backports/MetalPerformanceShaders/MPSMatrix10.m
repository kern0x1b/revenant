// MPSMatrix, from the header of the SDK of iOS 16.4. One object per release: the band machinery keeps an
// object whole or drops it whole, so a file here carries the API of exactly one release.

#import "CharonMPS.h"


@implementation MPSMatrix {
    id<MTLBuffer> _buffer;
    MPSMatrixDescriptor *_descriptor;
    NSUInteger _offset;
    id<MTLDevice> _device;
}

- (instancetype)initWithBuffer:(id<MTLBuffer>)buffer descriptor:(MPSMatrixDescriptor *)descriptor
{
    if ((self = [super init])) {
        _buffer = buffer;
        _descriptor = descriptor;
        _device = [buffer device];
    }
    return self;
}

- (instancetype)initWithBuffer:(id<MTLBuffer>)buffer offset:(NSUInteger)offset descriptor:(MPSMatrixDescriptor *)descriptor
{
    if ((self = [super init])) {
        _buffer = buffer;
        _descriptor = descriptor;
        _offset = offset;
        _device = [buffer device];
    }
    return self;
}

- (instancetype)initWithDevice:(id<MTLDevice>)device descriptor:(MPSMatrixDescriptor *)descriptor
{
    if ((self = [super init])) {
        _descriptor = descriptor;
        _device = device;
    }
    return self;
}

- (instancetype)init
{
    NSLog(@"MPSMatrix: -init makes a matrix of no shape; use -initWithBuffer:descriptor: or -initWithDevice:descriptor:");
    return nil;
}

- (id<MTLBuffer>)data
{
    if (!_buffer) {
        // The release makes the backing store when -data is first asked for, so that a matrix's
        // -resourceSize can be asked before anything is allocated. The storage it then makes is the
        // (matrices - 1) * matrixBytes + (rows - 1) * rowBytes + columns * elementSize bytes its own
        // header specifies.
        size_t elementSize = MPSSizeofMPSDataType(_descriptor.dataType);
        size_t bytes = (_descriptor.matrices - 1) * _descriptor.matrixBytes + (_descriptor.rows - 1) * _descriptor.rowBytes + _descriptor.columns * elementSize;
        _buffer = [_device newBufferWithLength:bytes options:MTLResourceStorageModeShared];
    }
    return _buffer;
}

- (id<MTLDevice>)device
{
    return _device;
}

- (NSUInteger)rows
{
    return _descriptor.rows;
}

- (NSUInteger)columns
{
    return _descriptor.columns;
}

- (NSUInteger)matrices
{
    return _descriptor.matrices;
}

- (MPSDataType)dataType
{
    return _descriptor.dataType;
}

- (NSUInteger)rowBytes
{
    return _descriptor.rowBytes;
}

- (NSUInteger)matrixBytes
{
    return _descriptor.matrixBytes;
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
    size_t elementSize = MPSSizeofMPSDataType(_descriptor.dataType);
    return (_descriptor.matrices - 1) * _descriptor.matrixBytes + (_descriptor.rows - 1) * _descriptor.rowBytes + _descriptor.columns * elementSize;
}

@end
