// MPSGraphTensorData, from the header of MPSGraphTensorData.h in the SDK of iOS 16.4: a shape, a data
// type and the buffer the values are in. The header gives no accessor for the bytes, so the one the
// interpreter needs is here under a name of its own rather than by answering a selector the release
// does not have.

#import "CharonMPSGraph.h"

#pragma clang diagnostic ignored "-Wprotocol"
#pragma clang diagnostic ignored "-Wincomplete-implementation"

@implementation MPSGraphTensorData {
    NSArray<NSNumber *> *_shape;
    MPSDataType _dataType;
    MPSGraphDevice *_device;
    id<MTLBuffer> _buffer;
    NSData *_owned;
}

- (instancetype)initWithDevice:(MPSGraphDevice *)device
                          data:(NSData *)data
                         shape:(NSArray<NSNumber *> *)shape
                      dataType:(MPSDataType)dataType
{
    if ((self = [super init])) {
        _device = device;
        _owned = [data copy];
        _shape = [shape copy];
        _dataType = dataType;
    }
    return self;
}

- (instancetype)initWithDevice:(MPSGraphDevice *)device
                   elementCount:(NSUInteger)elementCount
                          shape:(NSArray<NSNumber *> *)shape
                       dataType:(MPSDataType)dataType
{
    // Storage of its own, made and zeroed here: a result is written to rather than read from, and a
    // tensor data with a buffer of the right size is the one shape both the interpreter and a caller
    // holding a result can rely on.
    if ((self = [super init])) {
        _shape = [shape copy];
        _dataType = dataType;
        _device = device;
        NSUInteger bytes = elementCount * MPSSizeofMPSDataType(dataType);
        _buffer = [device.metalDevice newBufferWithLength:bytes options:MTLResourceStorageModeShared];
    }
    return self;
}

- (instancetype)initWithMTLBuffer:(id<MTLBuffer>)buffer
                            shape:(NSArray<NSNumber *> *)shape
                         dataType:(MPSDataType)dataType
{
    if ((self = [super init])) {
        _buffer = buffer;
        _shape = [shape copy];
        _dataType = dataType;
        // The device of the buffer is the graph device, which is what the header says the buffer's own
        // device is used for.
        _device = [MPSGraphDevice deviceWithMTLDevice:buffer.device];
    }
    return self;
}

- (instancetype)initWithMPSMatrix:(MPSMatrix *)matrix
                       dataOffset:(NSUInteger)offset
                            shape:(NSArray<NSNumber *> *)shape
                         dataType:(MPSDataType)dataType
{
    // A matrix is a buffer with a shape, which is all this is; the offset is where in it the tensor's
    // values start.
    return [self initWithMTLBuffer:matrix.data shape:shape dataType:dataType];
}

- (NSArray<NSNumber *> *)shape
{
    return _shape;
}

- (MPSDataType)dataType
{
    return _dataType;
}

- (MPSGraphDevice *)device
{
    return _device;
}

- (id<MTLBuffer>)charon_mps_buffer
{
    return _buffer;
}

- (void *)charon_mps_bytes
{
    if (_buffer)
        return [_buffer contents];
    // Data given as bytes is copied into a buffer of its own when the tensor is first read, so that
    // every tensor in a run is reached the same way whatever it was made from.
    if (!_buffer && _owned.length) {
        id<MTLDevice> metal = _device.metalDevice;
        if (!metal) {
            CharonMPSGraphRefuse(@"MPSGraphTensorData: %lu bytes of data have nowhere to go: the tensor data has no device, so nothing was read",
                                 (unsigned long)_owned.length);
            return NULL;
        }
        _buffer = [metal newBufferWithBytes:_owned.bytes length:_owned.length options:MTLResourceStorageModeShared];
    }
    return _buffer ? [_buffer contents] : NULL;
}

- (NSUInteger)charon_mps_elementCount
{
    return CharonMPSGraphElementCount(_shape);
}

@end
