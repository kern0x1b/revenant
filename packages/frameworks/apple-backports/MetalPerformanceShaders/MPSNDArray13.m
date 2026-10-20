#import "RevenantMPSNDArray.h"

#pragma clang diagnostic ignored "-Wprotocol"
#pragma clang diagnostic ignored "-Wincomplete-implementation"

#if defined(REVENANT_NDARRAY_PLANT)
static void MPSNDArray_plantedCopy(void *destination, const void *source, size_t bytes)
{
    unsigned char *out = (unsigned char *)destination;
    memcpy(destination, source, bytes);
    if (REVENANT_NDARRAY_PLANT == 1)
        out[0] = (unsigned char)(out[0] + 0x40u);
    else
        out[bytes - 1] = (unsigned char)(out[bytes - 1] + 0x08u);
}
#define MPSNDArray_COPY(destination, source, bytes) MPSNDArray_plantedCopy(destination, source, bytes)
#else
#define MPSNDArray_COPY(destination, source, bytes) memcpy(destination, source, bytes)
#endif

@interface RevenantMPSNDArrayAllocator : NSObject <MPSNDArrayAllocator>
@end

@implementation RevenantMPSNDArrayAllocator

+ (BOOL)supportsSecureCoding
{
    return NO;
}

- (MPSNDArray *)arrayForCommandBuffer:(id<MTLCommandBuffer>)commandBuffer
                       arrayDescriptor:(MPSNDArrayDescriptor *)descriptor
                                kernel:(MPSKernel *)kernel
{
    (void)kernel;
    id<MTLDevice> device = [commandBuffer respondsToSelector:@selector(device)] ? [commandBuffer device] : nil;
    if (!device)
        device = MTLCreateSystemDefaultDevice();
    if (!device || !descriptor)
        return nil;
    return [[MPSNDArray alloc] initWithDevice:device descriptor:descriptor];
}

@end



@implementation MPSNDArrayDescriptor {
    NSUInteger _numberOfDimensions;
    MPSDataType _dataType;
    NSUInteger _lengths[REVENANT_MPS_NDARRAY_MAX_DIMENSIONS];
    MPSDimensionSlice _slices[REVENANT_MPS_NDARRAY_MAX_DIMENSIONS];
    vector_uchar16 _order;
}

- (instancetype)init
{
    if ((self = [super init])) {
        _dataType = MPSDataTypeInvalid;
        _numberOfDimensions = 0;
        for (NSUInteger i = 0; i < REVENANT_MPS_NDARRAY_MAX_DIMENSIONS; i++) {
            _lengths[i] = 1;
            _slices[i].start = 0;
            _slices[i].length = 1;
            _order[i] = (unsigned char)i;
        }
    }
    return self;
}

- (MPSDataType)dataType { return _dataType; }
- (void)setDataType:(MPSDataType)dataType { _dataType = dataType; }

- (NSUInteger)numberOfDimensions { return _numberOfDimensions; }

- (void)setNumberOfDimensions:(NSUInteger)numberOfDimensions
{
    if (numberOfDimensions > REVENANT_MPS_NDARRAY_MAX_DIMENSIONS)
        numberOfDimensions = REVENANT_MPS_NDARRAY_MAX_DIMENSIONS;
    _numberOfDimensions = numberOfDimensions;
    for (NSUInteger i = 0; i < REVENANT_MPS_NDARRAY_MAX_DIMENSIONS; i++) {
        if (i >= numberOfDimensions) {
            _slices[i].start = 0;
            _slices[i].length = 1;
        }
    }
}

- (NSUInteger)lengthOfDimension:(NSUInteger)dimensionIndex
{
    if (dimensionIndex >= _numberOfDimensions)
        return 1;
    return _lengths[_order[dimensionIndex]];
}

- (MPSDimensionSlice)sliceRangeForDimension:(NSUInteger)dimensionIndex
{
    if (dimensionIndex >= _numberOfDimensions) {
        MPSDimensionSlice whole = {0, 1};
        return whole;
    }
    return _slices[dimensionIndex];
}

- (void)sliceDimension:(NSUInteger)dimensionIndex withSubrange:(MPSDimensionSlice)subRange
{
    if (dimensionIndex >= _numberOfDimensions)
        return;
    if (subRange.start > _lengths[dimensionIndex])
        subRange.start = _lengths[dimensionIndex];
    if (subRange.length > _lengths[dimensionIndex] - subRange.start)
        subRange.length = _lengths[dimensionIndex] - subRange.start;
    _slices[dimensionIndex] = subRange;
}

- (vector_uchar16)dimensionOrder { return _order; }

- (void)transposeDimension:(NSUInteger)dimensionIndex withDimension:(NSUInteger)dimensionIndex2
{
    if (dimensionIndex >= REVENANT_MPS_NDARRAY_MAX_DIMENSIONS || dimensionIndex2 >= REVENANT_MPS_NDARRAY_MAX_DIMENSIONS)
        return;
    unsigned char held = _order[dimensionIndex];
    _order[dimensionIndex] = _order[dimensionIndex2];
    _order[dimensionIndex2] = held;
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunavailable-declarations"
+ (instancetype)descriptorWithDataType:(MPSDataType)dataType
                       dimensionCount:(NSUInteger)numberOfDimensions
                       dimensionSizes:(NSUInteger *)dimensionSizes
{
    if (numberOfDimensions == 0 || numberOfDimensions > REVENANT_MPS_NDARRAY_MAX_DIMENSIONS)
        return nil;
    MPSNDArrayDescriptor *descriptor = [[self alloc] init];
    descriptor.dataType = dataType;
    descriptor.numberOfDimensions = numberOfDimensions;
    for (NSUInteger i = 0; i < numberOfDimensions; i++) {
        descriptor->_lengths[i] = dimensionSizes[i];
        descriptor->_slices[i].start = 0;
        descriptor->_slices[i].length = dimensionSizes[i];
    }
    return descriptor;
}
#pragma clang diagnostic pop

+ (instancetype)descriptorWithDataType:(MPSDataType)dataType dimensionSizes:(NSUInteger)dimension0, ...
{
    NSUInteger sizes[REVENANT_MPS_NDARRAY_MAX_DIMENSIONS];
    NSUInteger count = 0;
    va_list arguments;
    va_start(arguments, dimension0);
    for (NSUInteger next = dimension0; next != 0 && count < REVENANT_MPS_NDARRAY_MAX_DIMENSIONS;
         next = va_arg(arguments, NSUInteger))
        sizes[count++] = next;
    va_end(arguments);
    if (count == 0)
        return nil;
    return [self descriptorWithDataType:dataType dimensionCount:count dimensionSizes:sizes];
}

+ (instancetype)descriptorWithDataType:(MPSDataType)dataType shape:(NSArray<NSNumber *> *)shape
{
    if (shape.count == 0 || shape.count > REVENANT_MPS_NDARRAY_MAX_DIMENSIONS)
        return nil;
    NSUInteger sizes[REVENANT_MPS_NDARRAY_MAX_DIMENSIONS];
    for (NSUInteger i = 0; i < shape.count; i++)
        sizes[shape.count - 1 - i] = [shape[i] unsignedIntegerValue];
    return [self descriptorWithDataType:dataType dimensionCount:shape.count dimensionSizes:sizes];
}

- (void)reshapeWithDimensionCount:(NSUInteger)numberOfDimensions dimensionSizes:(NSUInteger *)dimensionSizes
{
    if (numberOfDimensions == 0 || numberOfDimensions > REVENANT_MPS_NDARRAY_MAX_DIMENSIONS)
        return;
    _numberOfDimensions = numberOfDimensions;
    for (NSUInteger i = 0; i < REVENANT_MPS_NDARRAY_MAX_DIMENSIONS; i++) {
        if (i < numberOfDimensions) {
            _lengths[i] = dimensionSizes[i];
            _slices[i].start = 0;
            _slices[i].length = dimensionSizes[i];
        } else {
            _lengths[i] = 1;
            _slices[i].start = 0;
            _slices[i].length = 1;
        }
    }
}

- (void)reshapeWithShape:(NSArray<NSNumber *> *)shape
{
    if (shape.count == 0 || shape.count > REVENANT_MPS_NDARRAY_MAX_DIMENSIONS)
        return;
    NSUInteger sizes[REVENANT_MPS_NDARRAY_MAX_DIMENSIONS];
    for (NSUInteger i = 0; i < shape.count; i++)
        sizes[i] = [shape[i] unsignedIntegerValue];
    [self reshapeWithDimensionCount:shape.count dimensionSizes:sizes];
}

@end

@implementation MPSNDArray {
    id<MTLBuffer> _buffer;
    MPSNDArrayDescriptor *_descriptor;
    MPSNDArrayDescriptor *_shape;
    NSUInteger _byteOffset;
    MPSNDArray *_parent;
    id<MTLDevice> _device;
    NSString *_label;
}

- (instancetype)initWithDevice:(id<MTLDevice>)device descriptor:(MPSNDArrayDescriptor *)descriptor
{
    if (!descriptor) {
        NSLog(@"MPSNDArray: -initWithDevice:descriptor: was given no descriptor, and the shape is what the array holds; "
              @"build one with +[MPSNDArrayDescriptor descriptorWithDataType:dimensionCount:dimensionSizes:]");
        return nil;
    }
    if ((self = [super init])) {
        _device = device;
        _descriptor = descriptor;
        _shape = [self revenant_mps_wholeShapeOf:descriptor];
    }
    return self;
}

- (instancetype)initWithDevice:(id<MTLDevice>)device scalar:(double)value
{
    NSUInteger one = 1;
    MPSNDArrayDescriptor *descriptor = [MPSNDArrayDescriptor descriptorWithDataType:MPSDataTypeFloat32
                                                                    dimensionCount:1
                                                                    dimensionSizes:&one];
    if (!(self = [self initWithDevice:device descriptor:descriptor])) {
        return nil;
    }
    float narrowed = (float)value;
    [self writeBytes:&narrowed strideBytes:NULL];
    return self;
}

- (instancetype)init
{
    NSLog(@"MPSNDArray: -init makes an array of no shape; use -initWithDevice:descriptor: or -initWithDevice:scalar:");
    return nil;
}

+ (id<MPSNDArrayAllocator>)defaultAllocator
{
    static RevenantMPSNDArrayAllocator *allocator = nil;
    if (!allocator)
        allocator = [[RevenantMPSNDArrayAllocator alloc] init];
    return allocator;
}

- (id<MTLDevice>)device { return _device; }
- (MPSDataType)dataType { return _descriptor.dataType; }
- (size_t)dataTypeSize { return MPSSizeofMPSDataType(_descriptor.dataType); }
- (NSUInteger)numberOfDimensions { return _shape.numberOfDimensions; }
- (NSUInteger)lengthOfDimension:(NSUInteger)dimensionIndex { return [_shape lengthOfDimension:dimensionIndex]; }
- (MPSNDArray *)parent { return _parent; }
- (NSString *)label { return _label; }
- (void)setLabel:(NSString *)label { _label = [label copy]; }

- (MPSNDArrayDescriptor *)descriptor
{
    NSUInteger sizes[REVENANT_MPS_NDARRAY_MAX_DIMENSIONS];
    for (NSUInteger i = 0; i < REVENANT_MPS_NDARRAY_MAX_DIMENSIONS; i++)
        sizes[i] = [_descriptor lengthOfDimension:i];
    MPSNDArrayDescriptor *descriptor = [MPSNDArrayDescriptor descriptorWithDataType:_descriptor.dataType
                                                                     dimensionCount:_descriptor.numberOfDimensions
                                                                     dimensionSizes:sizes];
    vector_uchar16 order = [_descriptor dimensionOrder];
    for (NSUInteger i = 0; i < REVENANT_MPS_NDARRAY_MAX_DIMENSIONS; i++)
        [descriptor transposeDimension:i withDimension:order[i]];
    return descriptor;
}

- (MPSNDArrayDescriptor *)revenant_mps_wholeShapeOf:(MPSNDArrayDescriptor *)descriptor
{
    NSUInteger sizes[REVENANT_MPS_NDARRAY_MAX_DIMENSIONS];
    for (NSUInteger i = 0; i < REVENANT_MPS_NDARRAY_MAX_DIMENSIONS; i++)
        sizes[i] = [descriptor sliceRangeForDimension:i].length;
    return [MPSNDArrayDescriptor descriptorWithDataType:descriptor.dataType
                                         dimensionCount:descriptor.numberOfDimensions
                                         dimensionSizes:sizes];
}

- (NSUInteger)resourceSize
{
    if (_parent)
        return [_parent resourceSize];
    if (_buffer)
        return _buffer.length - _byteOffset;
    size_t elementSize = MPSSizeofMPSDataType(_shape.dataType);
    if (elementSize == 0)
        return 0;
    size_t row = MPSNDArrayRoundedRowBytes([_shape lengthOfDimension:0], elementSize);
    NSUInteger rows = 1;
    for (NSUInteger i = 1; i < _shape.numberOfDimensions; i++)
        rows *= [_shape lengthOfDimension:i];
    return (NSUInteger)(row * rows);
}

- (id<MTLBuffer>)revenant_mps_makeBuffer
{
    if (_buffer)
        return _buffer;
    NSUInteger size = [self resourceSize];
    if (size == 0)
        return nil;
    id<MTLBuffer> buffer = [_device newBufferWithLength:size options:MTLResourceStorageModeShared];
    if (!buffer) {
        RevenantMPSRefuse(@"MPSNDArray: the device made no %lu byte buffer for a shape of %lu dimensions",
                        (unsigned long)size, (unsigned long)_descriptor.numberOfDimensions);
        return nil;
    }
    _buffer = buffer;
    return _buffer;
}

static void MPSNDArrayViewLayout(MPSNDArrayDescriptor *view, MPSNDArrayDescriptor *shape,
                                 NSUInteger *strides, NSUInteger *lengths, NSUInteger *offset)
{
    size_t elementSize = MPSSizeofMPSDataType(shape.dataType);
    if (!elementSize)
        elementSize = 1;
    vector_uchar16 order = [view dimensionOrder];
    size_t strideOf[REVENANT_MPS_NDARRAY_MAX_DIMENSIONS];
    strideOf[0] = 1;
    for (NSUInteger d = 1; d < shape.numberOfDimensions && d < REVENANT_MPS_NDARRAY_MAX_DIMENSIONS; d++)
        strideOf[d] = strideOf[d - 1] * [shape lengthOfDimension:d - 1];
    NSUInteger at = 0;
    for (NSUInteger i = 0; i < view.numberOfDimensions && i < REVENANT_MPS_NDARRAY_MAX_DIMENSIONS; i++) {
        NSUInteger dimension = order[i];
        strides[i] = (NSUInteger)(dimension < REVENANT_MPS_NDARRAY_MAX_DIMENSIONS ? strideOf[dimension] : 0);
        lengths[i] = [view sliceRangeForDimension:dimension].length;
        at += [view sliceRangeForDimension:dimension].start * strides[i];
    }
    for (NSUInteger i = view.numberOfDimensions; i < REVENANT_MPS_NDARRAY_MAX_DIMENSIONS; i++) {
        strides[i] = 0;
        lengths[i] = 1;
    }
    *offset = at;
}

- (NSUInteger)revenant_mps_elementCount
{
    NSUInteger count = 1;
    for (NSUInteger i = 0; i < _descriptor.numberOfDimensions && i < REVENANT_MPS_NDARRAY_MAX_DIMENSIONS; i++)
        count *= [_descriptor sliceRangeForDimension:i].length;
    return count;
}

- (void)revenant_mps_bufferStrides:(NSUInteger *)strides
                        lengths:(const NSUInteger *)lengths
                   strideBytes:(NSInteger *)strideBytesPerDimension
{
    size_t elementSize = MPSSizeofMPSDataType(_descriptor.dataType);
    NSUInteger packed = 1;
    for (NSUInteger i = 0; i < REVENANT_MPS_NDARRAY_MAX_DIMENSIONS; i++) {
        strides[i] = strideBytesPerDimension ? (NSUInteger)strideBytesPerDimension[i] : packed * elementSize;
        packed *= lengths[i];
    }
}

- (void)readBytes:(void *)buffer strideBytes:(NSInteger *)strideBytesPerDimension
{
    id<MTLBuffer> storage = _buffer;
    if (!storage) {
        if (!strideBytesPerDimension && buffer) {
            NSUInteger count = [self revenant_mps_elementCount];
            size_t elementSize = MPSSizeofMPSDataType(_descriptor.dataType);
            if (elementSize)
                memset(buffer, 0, count * elementSize);
        }
        return;
    }
    size_t elementSize = MPSSizeofMPSDataType(_descriptor.dataType);
    if (elementSize == 0)
        return;
    MPSNDArrayDescriptor *shape = _parent ? _parent->_shape : _shape;
    NSUInteger strides[REVENANT_MPS_NDARRAY_MAX_DIMENSIONS], lengths[REVENANT_MPS_NDARRAY_MAX_DIMENSIONS];
    NSUInteger at = 0;
    MPSNDArrayViewLayout(_descriptor, shape, strides, lengths, &at);
    NSUInteger destination[REVENANT_MPS_NDARRAY_MAX_DIMENSIONS];
    [self revenant_mps_bufferStrides:destination lengths:lengths strideBytes:strideBytesPerDimension];
    const char *base = (const char *)[storage contents] + _byteOffset;
    NSUInteger index[REVENANT_MPS_NDARRAY_MAX_DIMENSIONS];
    for (NSUInteger i = 0; i < REVENANT_MPS_NDARRAY_MAX_DIMENSIONS; i++)
        index[i] = 0;
    NSUInteger total = [self revenant_mps_elementCount];
    if (buffer)
        memset(buffer, 0, total * elementSize);
    for (NSUInteger linear = 0; linear < total; linear++) {
        size_t source = at * elementSize;
        size_t target = 0;
        for (NSUInteger i = 0; i < _descriptor.numberOfDimensions && i < REVENANT_MPS_NDARRAY_MAX_DIMENSIONS; i++) {
            source += index[i] * strides[i] * elementSize;
            target += index[i] * destination[i];
        }
        MPSNDArray_COPY((char *)buffer + target, base + source, elementSize);
        for (NSUInteger i = 0; i < _descriptor.numberOfDimensions; i++) {
            if (++index[i] < lengths[i])
                break;
            index[i] = 0;
        }
    }
}

- (void)writeBytes:(void *)buffer strideBytes:(NSInteger *)strideBytesPerDimension
{
    id<MTLBuffer> storage = [self revenant_mps_makeBuffer];
    if (!storage)
        return;
    size_t elementSize = MPSSizeofMPSDataType(_descriptor.dataType);
    if (elementSize == 0)
        return;
    MPSNDArrayDescriptor *shape = _parent ? _parent->_shape : _shape;
    NSUInteger strides[REVENANT_MPS_NDARRAY_MAX_DIMENSIONS], lengths[REVENANT_MPS_NDARRAY_MAX_DIMENSIONS];
    NSUInteger at = 0;
    MPSNDArrayViewLayout(_descriptor, shape, strides, lengths, &at);
    NSUInteger source[REVENANT_MPS_NDARRAY_MAX_DIMENSIONS];
    [self revenant_mps_bufferStrides:source lengths:lengths strideBytes:strideBytesPerDimension];
    char *base = (char *)[storage contents] + _byteOffset;
    NSUInteger index[REVENANT_MPS_NDARRAY_MAX_DIMENSIONS];
    for (NSUInteger i = 0; i < REVENANT_MPS_NDARRAY_MAX_DIMENSIONS; i++)
        index[i] = 0;
    NSUInteger total = [self revenant_mps_elementCount];
    for (NSUInteger linear = 0; linear < total; linear++) {
        size_t target = at * elementSize;
        size_t sourceAt = 0;
        for (NSUInteger i = 0; i < _descriptor.numberOfDimensions && i < REVENANT_MPS_NDARRAY_MAX_DIMENSIONS; i++) {
            target += index[i] * strides[i] * elementSize;
            sourceAt += index[i] * source[i];
        }
        MPSNDArray_COPY(base + target, (const char *)buffer + sourceAt, elementSize);
        for (NSUInteger i = 0; i < _descriptor.numberOfDimensions; i++) {
            if (++index[i] < lengths[i])
                break;
            index[i] = 0;
        }
    }
}

- (void)synchronizeOnCommandBuffer:(id<MTLCommandBuffer>)commandBuffer
{
    (void)commandBuffer;
}

- (MPSNDArray *)arrayViewWithCommandBuffer:(id<MTLCommandBuffer>)commandBuffer
                                 descriptor:(MPSNDArrayDescriptor *)descriptor
                                  aliasing:(MPSAliasingStrategy)aliasing
{
    (void)commandBuffer;
    if (!descriptor)
        return nil;
    if (aliasing & MPSAliasingStrategyShallNotAlias) {
        MPSNDArray *copy = [[MPSNDArray alloc] initWithDevice:_device descriptor:descriptor];
        size_t width = MPSSizeofMPSDataType(descriptor.dataType);
        NSUInteger count = 1;
        for (NSUInteger i = 0; i < descriptor.numberOfDimensions; i++)
            count *= [descriptor lengthOfDimension:i];
        void *packed = calloc(count ? count : 1, width ? width : 1);
        if (!packed) {
            RevenantMPSRefuse(@"MPSNDArray: no memory to make the %lu element copy -arrayViewWithCommandBuffer:descriptor:aliasing: asked for",
                            (unsigned long)count);
            return nil;
        }
        [self readBytes:packed strideBytes:NULL];
        [copy writeBytes:packed strideBytes:NULL];
        free(packed);
        return copy;
    }
    MPSNDArray *view = [[MPSNDArray alloc] initWithDevice:_device descriptor:descriptor];
    view->_buffer = _buffer;
    view->_byteOffset = _byteOffset;
    view->_parent = self;
    view->_shape = _shape;
    return view;
}

- (void)exportDataWithCommandBuffer:(id<MTLCommandBuffer>)commandBuffer
                           toBuffer:(id<MTLBuffer>)buffer
                destinationDataType:(MPSDataType)destinationDataType
                             offset:(NSUInteger)offset
                         rowStrides:(NSInteger *)rowStrides
{
    (void)commandBuffer;
    if (!buffer)
        return;
    size_t from = MPSSizeofMPSDataType(_descriptor.dataType);
    size_t to = MPSSizeofMPSDataType(destinationDataType);
    if (from == 0 || to == 0) {
        RevenantMPSRefuse(@"MPSNDArray: -exportDataWithCommandBuffer:toBuffer: was given a data type of %u or %u, which has no width",
                        (unsigned)_descriptor.dataType, (unsigned)destinationDataType);
        return;
    }
    NSUInteger total = [self revenant_mps_elementCount];
    void *source = malloc(total * from);
    if (!source)
        return;
    [self readBytes:source strideBytes:NULL];
    char *destination = (char *)[buffer contents] + offset;
    if (rowStrides) {
        NSUInteger index[REVENANT_MPS_NDARRAY_MAX_DIMENSIONS];
        for (NSUInteger i = 0; i < REVENANT_MPS_NDARRAY_MAX_DIMENSIONS; i++)
            index[i] = 0;
        for (NSUInteger linear = 0; linear < total; linear++) {
            size_t at = 0;
            for (NSUInteger i = 0; i < _descriptor.numberOfDimensions && i < REVENANT_MPS_NDARRAY_MAX_DIMENSIONS; i++)
                at += (size_t)(rowStrides[i] * (NSInteger)index[i]);
            RevenantMPSStore(destination + at, destinationDataType, 0, RevenantMPSLoad(source, _descriptor.dataType, linear));
            for (NSUInteger i = 0; i < _descriptor.numberOfDimensions; i++) {
                if (++index[i] < [_descriptor sliceRangeForDimension:i].length)
                    break;
                index[i] = 0;
            }
        }
    } else {
        for (NSUInteger linear = 0; linear < total; linear++)
            RevenantMPSStore(destination, destinationDataType, linear, RevenantMPSLoad(source, _descriptor.dataType, linear));
    }
    free(source);
}

- (void)importDataWithCommandBuffer:(id<MTLCommandBuffer>)commandBuffer
                         fromBuffer:(id<MTLBuffer>)buffer
                     sourceDataType:(MPSDataType)sourceDataType
                             offset:(NSUInteger)offset
                         rowStrides:(NSInteger *)rowStrides
{
    (void)commandBuffer;
    if (!buffer)
        return;
    size_t from = MPSSizeofMPSDataType(sourceDataType);
    size_t to = MPSSizeofMPSDataType(_descriptor.dataType);
    if (from == 0 || to == 0) {
        RevenantMPSRefuse(@"MPSNDArray: -importDataWithCommandBuffer:fromBuffer: was given a data type of %u or %u, which has no width",
                        (unsigned)sourceDataType, (unsigned)_descriptor.dataType);
        return;
    }
    NSUInteger total = [self revenant_mps_elementCount];
    void *destination = malloc(total * to);
    if (!destination)
        return;
    const char *source = (const char *)[buffer contents] + offset;
    if (rowStrides) {
        NSUInteger index[REVENANT_MPS_NDARRAY_MAX_DIMENSIONS];
        for (NSUInteger i = 0; i < REVENANT_MPS_NDARRAY_MAX_DIMENSIONS; i++)
            index[i] = 0;
        for (NSUInteger linear = 0; linear < total; linear++) {
            size_t at = 0;
            for (NSUInteger i = 0; i < _descriptor.numberOfDimensions && i < REVENANT_MPS_NDARRAY_MAX_DIMENSIONS; i++)
                at += (size_t)(rowStrides[i] * (NSInteger)index[i]);
            RevenantMPSStore(destination, _descriptor.dataType, linear, RevenantMPSLoad(source + at, sourceDataType, 0));
            for (NSUInteger i = 0; i < _descriptor.numberOfDimensions; i++) {
                if (++index[i] < [_descriptor sliceRangeForDimension:i].length)
                    break;
                index[i] = 0;
            }
        }
    } else {
        for (NSUInteger linear = 0; linear < total; linear++)
            RevenantMPSStore(destination, _descriptor.dataType, linear, RevenantMPSLoad(source, sourceDataType, linear));
    }
    [self writeBytes:destination strideBytes:NULL];
    free(destination);
}

@end

@implementation MPSTemporaryNDArray {
    NSUInteger _readCount;
}

+ (instancetype)temporaryNDArrayWithCommandBuffer:(id<MTLCommandBuffer>)commandBuffer
                                      descriptor:(MPSNDArrayDescriptor *)descriptor
{
    id<MTLDevice> device = [commandBuffer respondsToSelector:@selector(device)] ? [commandBuffer device] : nil;
    if (!device)
        device = MTLCreateSystemDefaultDevice();
    if (!device || !descriptor)
        return nil;
    MPSTemporaryNDArray *array = [[MPSTemporaryNDArray alloc] initWithDevice:device descriptor:descriptor];
    [array setReadCount:1];
    return array;
}

+ (id<MPSNDArrayAllocator>)defaultAllocator
{
    static RevenantMPSNDArrayAllocator *allocator = nil;
    if (!allocator)
        allocator = [[RevenantMPSNDArrayAllocator alloc] init];
    return allocator;
}

- (NSUInteger)readCount { return _readCount; }

- (void)setReadCount:(NSUInteger)readCount
{
    if (_readCount == 0) {
        RevenantMPSRefuse(@"MPSTemporaryNDArray: the read count is already 0 and it may not be changed back");
        return;
    }
    _readCount = readCount;
}

@end
