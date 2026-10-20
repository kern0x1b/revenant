#import <CoreML/CoreML.h>

#include "RevenantMLBridge.h"
#include "RevenantMLTensor.h"

@interface MLMultiArray () {
@public
    revenant_ml_array _array;
    void (^_deallocator)(void *);
    CVPixelBufferRef _pixelBuffer;
}
- (revenant_ml_array *)revenantArray;
@end

@implementation MLMultiArray

- (revenant_ml_array *)revenantArray
{
    return &_array;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (void)dealloc
{
    if (_pixelBuffer != NULL) {
        CVPixelBufferRelease(_pixelBuffer);
        _pixelBuffer = NULL;
    }
    if (_deallocator != nil) {
        _deallocator((void *)_array.data);
        _deallocator = nil;
    } else {
        revenant_ml_array_free(&_array);
    }
}

- (instancetype)initWithShape:(NSArray<NSNumber *> *)shape
                     dataType:(MLMultiArrayDataType)dataType
                        error:(NSError **)error
{
    int64_t dimensions[REVENANT_ML_MAX_RANK];
    int rank = 0;
    self = [super init];
    if (self == nil) {
        return nil;
    }
    if (!revenant_ml_shape_from_array(shape, dimensions, REVENANT_ML_MAX_RANK, &rank)) {
        revenant_ml_error(error, REVENANT_ML_ERROR_GENERIC,
                        @"the shape of a multi array is one number per dimension, and there are more than eight");
        return nil;
    }
    {
        int axis;
        for (axis = 0; axis < rank; axis++) {
            if (dimensions[axis] < 0) {
                revenant_ml_error(error, REVENANT_ML_ERROR_GENERIC,
                                @"a dimension of a multi array cannot be of negative length");
                return nil;
            }
        }
        if (rank == 0) {
            dimensions[0] = 1;
            rank = 1;
        }
    }
    _array = revenant_ml_array_alloc(revenant_ml_type_of_array(dataType), dimensions, rank);
    if (_array.data == NULL) {
        revenant_ml_error(error, REVENANT_ML_ERROR_GENERIC,
                        @"the multi array of that shape and type has no room for it on this device");
        return nil;
    }
    return self;
}

- (instancetype)initWithShape:(NSArray<NSNumber *> *)shape
                     dataType:(MLMultiArrayDataType)dataType
                      strides:(NSArray<NSNumber *> *)strides
{
    int64_t dimensions[REVENANT_ML_MAX_RANK];
    int64_t steps[REVENANT_ML_MAX_RANK];
    int rank = 0, stride_rank = 0, index;
    self = [self initWithShape:shape dataType:dataType error:NULL];
    if (self == nil) {
        return nil;
    }
    if (!revenant_ml_shape_from_array(strides, steps, REVENANT_ML_MAX_RANK, &stride_rank) || stride_rank != rank) {
        return nil;
    }
    for (index = 0; index < rank; index++) {
        if (steps[index] < 0) {
            return nil;
        }
    }
    {
        int64_t seen = 0;
        int axis;
        for (axis = rank - 1; axis >= 0; axis--) {
            seen += steps[axis];
        }
        if (seen > 0) {
            int64_t reach = 0, stride = 1;
            for (axis = rank - 1; axis >= 0; axis--) {
                reach += (dimensions[axis] - 1) * steps[axis];
                stride *= dimensions[axis];
            }
            if (reach + 1 > stride) {
                return nil;
            }
        }
    }
    memcpy(_array.strides, steps, (size_t)rank * sizeof *steps);
    return self;
}

- (instancetype)initWithDataPointer:(void *)dataPointer
                              shape:(NSArray<NSNumber *> *)shape
                           dataType:(MLMultiArrayDataType)dataType
                            strides:(NSArray<NSNumber *> *)strides
                        deallocator:(void (^)(void *))deallocator
                              error:(NSError **)error
{
    int64_t dimensions[REVENANT_ML_MAX_RANK];
    int rank = 0;
    self = [self initWithShape:shape dataType:dataType error:error];
    if (self == nil) {
        return nil;
    }
    if (!revenant_ml_shape_from_array(strides, dimensions, REVENANT_ML_MAX_RANK, &rank)) {
        revenant_ml_error(error, REVENANT_ML_ERROR_GENERIC,
                        @"the strides of a multi array are one number per dimension of its shape");
        return nil;
    }
    free(_array.data);
    _array = revenant_ml_array_make(revenant_ml_type_of_array(dataType), _array.shape, _array.rank, dataPointer);
    _deallocator = deallocator;
    return self;
}

- (instancetype)initWithPixelBuffer:(CVPixelBufferRef)pixelBuffer shape:(NSArray<NSNumber *> *)shape
{
    int64_t dimensions[REVENANT_ML_MAX_RANK];
    int rank = 0;
    void *bytes = NULL;
    OSType format;
    int data_type;

    self = [self initWithShape:shape dataType:MLMultiArrayDataTypeFloat32 error:NULL];
    if (self == nil || pixelBuffer == NULL) {
        return nil;
    }
    if (!revenant_ml_shape_from_array(shape, dimensions, REVENANT_ML_MAX_RANK, &rank) ||
        CVPixelBufferLockBaseAddress(pixelBuffer, 0) != kCVReturnSuccess) {
        return nil;
    }
    format = CVPixelBufferGetPixelFormatType(pixelBuffer);
    switch (format) {
    case kCVPixelFormatType_32BGRA:
    case kCVPixelFormatType_32ARGB:
        data_type = REVENANT_ML_ARRAY_FLOAT32;
        break;
    default:
        CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
        return nil;
    }
    bytes = CVPixelBufferGetBaseAddress(pixelBuffer);
    free(_array.data);
    _array = revenant_ml_array_make(data_type, _array.shape, _array.rank, bytes);
    _pixelBuffer = (CVPixelBufferRef)CVPixelBufferRetain(pixelBuffer);
    return self;
}

- (instancetype)initWithWindowOf:(revenant_ml_array)array
{
    self = [super init];
    if (self == nil) {
        return nil;
    }
    _array = array;
    _array.owns_data = 0;
    return self;
}

#pragma mark - reading and writing the elements

- (void *)dataPointer
{
    return _array.data;
}

- (MLMultiArrayDataType)dataType
{
    return revenant_ml_array_type(_array.data_type);
}

- (NSArray<NSNumber *> *)shape
{
    return revenant_ml_shape_to_array(_array.shape, _array.rank);
}

- (NSArray<NSNumber *> *)strides
{
    return revenant_ml_shape_to_array(_array.strides, _array.rank);
}

- (NSInteger)count
{
    return (NSInteger)_array.count;
}

- (CVPixelBufferRef)pixelBuffer
{
    return _pixelBuffer;
}

- (NSNumber *)objectAtIndexedSubscript:(NSInteger)idx
{
    if (idx < 0 || (size_t)idx >= _array.count) {
        return nil;
    }
    return @(revenant_ml_array_get(&_array, (int64_t)idx));
}

- (void)getBytesWithHandler:(void (NS_NOESCAPE ^)(const void *bytes, NSInteger size))handler
{
    BOOL locked = NO;
    if (handler == nil) {
        return;
    }
    if (_pixelBuffer != NULL) {
        locked = CVPixelBufferLockBaseAddress(_pixelBuffer, kCVPixelBufferLock_ReadOnly) == kCVReturnSuccess;
    }
    handler(_array.data, (NSInteger)(_array.count * revenant_ml_type_size(_array.data_type)));
    if (locked) {
        CVPixelBufferUnlockBaseAddress(_pixelBuffer, kCVPixelBufferLock_ReadOnly);
    }
}

- (void)getMutableBytesWithHandler:(void (NS_NOESCAPE ^)(void *bytes, NSInteger size, NSArray<NSNumber *> *strides))handler
{
    BOOL locked = NO;
    if (handler == nil) {
        return;
    }
    if (_pixelBuffer != NULL) {
        locked = CVPixelBufferLockBaseAddress(_pixelBuffer, 0) == kCVReturnSuccess;
    }
    handler(_array.data, (NSInteger)(_array.count * revenant_ml_type_size(_array.data_type)), self.strides);
    if (locked) {
        CVPixelBufferUnlockBaseAddress(_pixelBuffer, 0);
    }
}

- (void)setObject:(NSNumber *)object atIndexedSubscript:(NSInteger)idx
{
    if (object == nil || idx < 0 || (size_t)idx >= _array.count) {
        return;
    }
    revenant_ml_array_set(&_array, (int64_t)idx, object.doubleValue);
}

- (NSNumber *)objectForKeyedSubscript:(NSArray<NSNumber *> *)key
{
    int64_t position[REVENANT_ML_MAX_RANK];
    int rank = 0;
    int64_t offset;
    if (!revenant_ml_shape_from_array(key, position, REVENANT_ML_MAX_RANK, &rank) || rank != _array.rank) {
        return nil;
    }
    offset = revenant_ml_array_offset(&_array, position, rank);
    if (offset < 0) {
        return nil;
    }
    return @(revenant_ml_array_get(&_array, offset));
}

- (void)setObject:(NSNumber *)object forKeyedSubscript:(NSArray<NSNumber *> *)key
{
    int64_t position[REVENANT_ML_MAX_RANK];
    int rank = 0;
    int64_t offset;
    if (object == nil || !revenant_ml_shape_from_array(key, position, REVENANT_ML_MAX_RANK, &rank) ||
        rank != _array.rank) {
        return;
    }
    offset = revenant_ml_array_offset(&_array, position, rank);
    if (offset < 0) {
        return;
    }
    revenant_ml_array_set(&_array, offset, object.doubleValue);
}

+ (MLMultiArray *)multiArrayByConcatenatingMultiArrays:(NSArray<MLMultiArray *> *)arrays
                                             alongAxis:(NSInteger)axis
                                              dataType:(MLMultiArrayDataType)dataType
{
    NSUInteger count = arrays.count, index;
    int64_t shape[REVENANT_ML_MAX_RANK];
    int64_t strides[REVENANT_ML_MAX_RANK];
    int rank = 0, axis_index;
    int64_t total = 0, at_axis = 0;
    MLMultiArray *joined;
    revenant_ml_array *out;

    if (count == 0 || revenant_ml_type_size(revenant_ml_type_of_array(dataType)) == 0) {
        return nil;
    }
    for (index = 0; index < count; index++) {
        int64_t one[REVENANT_ML_MAX_RANK];
        int one_rank = 0;
        if (!revenant_ml_shape_from_array(arrays[index].shape, one, REVENANT_ML_MAX_RANK, &one_rank) ||
            one_rank > REVENANT_ML_MAX_RANK) {
            return nil;
        }
        if (axis < 0 || axis >= one_rank) {
            return nil;
        }
        if (index == 0) {
            rank = one_rank;
            memcpy(shape, one, (size_t)rank * sizeof *one);
        } else if (one_rank != rank) {
            return nil;
        }
        for (axis_index = 0; axis_index < rank; axis_index++) {
            if (axis_index != (int)axis && one[axis_index] != shape[axis_index]) {
                return nil;
            }
        }
        total += one[axis];
    }
    shape[axis] = total;
    joined = [[MLMultiArray alloc] initWithShape:revenant_ml_shape_to_array(shape, rank) dataType:dataType error:NULL];
    if (joined == nil) {
        return nil;
    }
    out = [joined revenantArray];
    for (index = 0; index < count; index++) {
        revenant_ml_array *one = [arrays[index] revenantArray];
        size_t element;
        for (element = 0; element < one->count; element++) {
            int64_t position[REVENANT_ML_MAX_RANK];
            int64_t destination;
            revenant_ml_unravel((int64_t)element, one->rank, one->shape, position);
            destination = revenant_ml_ravel(position, out->rank, out->strides);
            destination += (at_axis + position[axis] - position[axis]) * out->strides[axis];
            revenant_ml_array_set(out, destination, revenant_ml_array_get(one, (int64_t)element));
        }
        at_axis += one->shape[axis];
    }
    (void)strides;
    return joined;
}

#pragma mark - NSSecureCoding

- (instancetype)initWithCoder:(NSCoder *)coder
{
    NSArray<NSNumber *> *shape = [coder decodeObjectOfClass:[NSArray class] forKey:@"shape"];
    NSArray<NSNumber *> *strides = [coder decodeObjectOfClass:[NSArray class] forKey:@"strides"];
    NSNumber *type = [coder decodeObjectOfClass:[NSNumber class] forKey:@"dataType"];
    NSData *bytes = [coder decodeObjectOfClass:[NSData class] forKey:@"data"];
    self = [self initWithShape:shape dataType:(MLMultiArrayDataType)type.unsignedIntegerValue error:NULL];
    if (self == nil) {
        return nil;
    }
    if (strides != nil) {
        int64_t steps[REVENANT_ML_MAX_RANK];
        int rank = 0;
        if (revenant_ml_shape_from_array(strides, steps, REVENANT_ML_MAX_RANK, &rank)) {
            memcpy(_array.strides, steps, (size_t)MIN(rank, _array.rank) * sizeof *steps);
        }
    }
    if (bytes != nil) {
        size_t width = revenant_ml_type_size(_array.data_type);
        size_t room = _array.count * width;
        [bytes getBytes:_array.data length:MIN(room, bytes.length)];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:self.shape forKey:@"shape"];
    [coder encodeObject:self.strides forKey:@"strides"];
    [coder encodeObject:@(_array.data_type) forKey:@"dataType"];
    [coder encodeObject:[NSData dataWithBytes:_array.data length:_array.count * revenant_ml_type_size(_array.data_type)]
                 forKey:@"data"];
}

@end
