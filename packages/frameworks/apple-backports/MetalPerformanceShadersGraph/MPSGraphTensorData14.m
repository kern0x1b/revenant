#import "RevenantMPSGraph.h"

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
        _device = [MPSGraphDevice deviceWithMTLDevice:buffer.device];
    }
    return self;
}

- (instancetype)initWithMPSMatrix:(MPSMatrix *)matrix
                       dataOffset:(NSUInteger)offset
                            shape:(NSArray<NSNumber *> *)shape
                         dataType:(MPSDataType)dataType
{
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

- (id<MTLBuffer>)revenant_mps_buffer
{
    return _buffer;
}

- (void *)revenant_mps_bytes
{
    if (_buffer)
        return [_buffer contents];
    if (!_buffer && _owned.length) {
        id<MTLDevice> metal = _device.metalDevice;
        if (!metal) {
            RevenantMPSGraphRefuse(@"MPSGraphTensorData: %lu bytes of data have nowhere to go: the tensor data has no device, so nothing was read",
                                 (unsigned long)_owned.length);
            return NULL;
        }
        _buffer = [metal newBufferWithBytes:_owned.bytes length:_owned.length options:MTLResourceStorageModeShared];
    }
    return _buffer ? [_buffer contents] : NULL;
}

- (NSUInteger)revenant_mps_elementCount
{
    return RevenantMPSGraphElementCount(_shape);
}

@end
