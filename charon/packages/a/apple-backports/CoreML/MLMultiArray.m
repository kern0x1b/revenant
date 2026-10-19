/* MLMultiArray: a typed, strided array of numbers, over the C array the interpreter reads.
 *
 * The array the model was given is a window into its bytes: a stride is not necessarily one,
 * and a caller may hand over a view of a larger buffer. What this class does is keep that
 * window and answer the elements through it, so a weight matrix is never copied to be read and
 * a caller writing through `dataPointer` writes the model's own buffer.
 */
#import <CoreML/CoreML.h>

#include "CharonMLBridge.h"
#include "CharonMLTensor.h"

/* The array, and whether its buffer is this object's to free. An array handed over from a value
 * or built here is owned; one that came with a buffer and a deallocator block belongs to
 * whoever gave it, and is only released when the block is. */
/* The array the object keeps, and the block that gives a caller's buffer back, and the pixel
 * buffer a pixel-buffer array is a window into. The array is reached by a method because the
 * bridge in CharonMLBridge.c has to reach it and key-value coding cannot reach a struct ivar. */
@interface MLMultiArray () {
@public
    charon_ml_array _array;
    void (^_deallocator)(void *);
    CVPixelBufferRef _pixelBuffer;
}
- (charon_ml_array *)charonArray;
@end

@implementation MLMultiArray

- (charon_ml_array *)charonArray
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
        charon_ml_array_free(&_array);
    }
}

- (instancetype)initWithShape:(NSArray<NSNumber *> *)shape
                     dataType:(MLMultiArrayDataType)dataType
                        error:(NSError **)error
{
    int64_t dimensions[CHARON_ML_MAX_RANK];
    int rank = 0;
    self = [super init];
    if (self == nil) {
        return nil;
    }
    if (!charon_ml_shape_from_array(shape, dimensions, CHARON_ML_MAX_RANK, &rank)) {
        charon_ml_error(error, CHARON_ML_ERROR_GENERIC,
                        @"the shape of a multi array is one number per dimension, and there are more than eight");
        return nil;
    }
    {
        /* Measured against a real Core ML: an empty shape is a single element -- there is no
         * dimension to multiply, so what is left is the one scalar -- and a dimension of zero is an
         * array of no elements rather than a failure. Only a negative length is refused, because
         * there is no such thing as an array of less than nothing. */
        int axis;
        for (axis = 0; axis < rank; axis++) {
            if (dimensions[axis] < 0) {
                charon_ml_error(error, CHARON_ML_ERROR_GENERIC,
                                @"a dimension of a multi array cannot be of negative length");
                return nil;
            }
        }
        if (rank == 0) {
            dimensions[0] = 1;
            rank = 1;
        }
    }
    _array = charon_ml_array_alloc(charon_ml_type_of_array(dataType), dimensions, rank);
    if (_array.data == NULL) {
        charon_ml_error(error, CHARON_ML_ERROR_GENERIC,
                        @"the multi array of that shape and type has no room for it on this device");
        return nil;
    }
    return self;
}

- (instancetype)initWithShape:(NSArray<NSNumber *> *)shape
                     dataType:(MLMultiArrayDataType)dataType
                      strides:(NSArray<NSNumber *> *)strides
{
    int64_t dimensions[CHARON_ML_MAX_RANK];
    int64_t steps[CHARON_ML_MAX_RANK];
    int rank = 0, stride_rank = 0, index;
    self = [self initWithShape:shape dataType:dataType error:NULL];
    if (self == nil) {
        return nil;
    }
    if (!charon_ml_shape_from_array(strides, steps, CHARON_ML_MAX_RANK, &stride_rank) || stride_rank != rank) {
        return nil;
    }
    /* The strides are the ones the caller asked for, in elements, and they are checked against
     * the shape: strides that do not reach every element of a full array would make some of
     * them unreadable, and an array a caller can read only in part is not an array. */
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
    int64_t dimensions[CHARON_ML_MAX_RANK];
    int rank = 0;
    self = [self initWithShape:shape dataType:dataType error:error];
    if (self == nil) {
        return nil;
    }
    if (!charon_ml_shape_from_array(strides, dimensions, CHARON_ML_MAX_RANK, &rank)) {
        charon_ml_error(error, CHARON_ML_ERROR_GENERIC,
                        @"the strides of a multi array are one number per dimension of its shape");
        return nil;
    }
    /* The caller's buffer replaces the one this object made for itself, and the block is what
     * gives it back: an array that owns a buffer it was handed would free memory it never
     * allocated, and one that dropped the block would leak it. */
    free(_array.data);
    _array = charon_ml_array_make(charon_ml_type_of_array(dataType), _array.shape, _array.rank, dataPointer);
    _deallocator = deallocator;
    return self;
}

- (instancetype)initWithPixelBuffer:(CVPixelBufferRef)pixelBuffer shape:(NSArray<NSNumber *> *)shape
{
    int64_t dimensions[CHARON_ML_MAX_RANK];
    int rank = 0;
    void *bytes = NULL;
    OSType format;
    int data_type;

    self = [self initWithShape:shape dataType:MLMultiArrayDataTypeFloat32 error:NULL];
    if (self == nil || pixelBuffer == NULL) {
        return nil;
    }
    if (!charon_ml_shape_from_array(shape, dimensions, CHARON_ML_MAX_RANK, &rank) ||
        CVPixelBufferLockBaseAddress(pixelBuffer, 0) != kCVReturnSuccess) {
        return nil;
    }
    format = CVPixelBufferGetPixelFormatType(pixelBuffer);
    switch (format) {
    case kCVPixelFormatType_32BGRA:
    case kCVPixelFormatType_32ARGB:
        data_type = CHARON_ML_ARRAY_FLOAT32;
        break;
    default:
        CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
        return nil; /* a format this port does not unpack, and it says so rather than guessing */
    }
    bytes = CVPixelBufferGetBaseAddress(pixelBuffer);
    free(_array.data);
    _array = charon_ml_array_make(data_type, _array.shape, _array.rank, bytes);
    _pixelBuffer = (CVPixelBufferRef)CVPixelBufferRetain(pixelBuffer);
    return self;
}

/* A window over an array the C already has, which is how an MLFeatureValue's array becomes an
 * MLMultiArray without copying it: the two then name one buffer, and writing through either
 * writes the same bytes. The window is not owned, so the object frees no buffer. */
- (instancetype)initWithWindowOf:(charon_ml_array)array
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
    return charon_ml_array_type(_array.data_type);
}

- (NSArray<NSNumber *> *)shape
{
    return charon_ml_shape_to_array(_array.shape, _array.rank);
}

- (NSArray<NSNumber *> *)strides
{
    return charon_ml_shape_to_array(_array.strides, _array.rank);
}

- (NSInteger)count
{
    return (NSInteger)_array.count;
}

- (CVPixelBufferRef)pixelBuffer
{
    return _pixelBuffer;
}

/* The two addressing forms Core ML has. The indexed one is a linear index in C order, the
 * last dimension varying fastest; the keyed one is an array of numbers, one per dimension.
 * Both answer nil and do nothing outside the array: an application addressing past the end of
 * an array is told, not served from whatever lies next. */
- (NSNumber *)objectAtIndexedSubscript:(NSInteger)idx
{
    if (idx < 0 || (size_t)idx >= _array.count) {
        return nil;
    }
    return @(charon_ml_array_get(&_array, (int64_t)idx));
}

/* The two ways Core ML asks a caller to read an array's bytes without the deprecated
 * `dataPointer`: the block is handed the buffer and the length in bytes, and the buffer is only
 * valid for as long as the block runs. Both answer the array's own buffer rather than a copy, so a
 * caller that writes through the mutable one writes the array -- and, for an array over a pixel
 * buffer, the buffer is locked for the length of the block, which is what Core ML's own
 * documentation asks of a caller doing that. */
- (void)getBytesWithHandler:(void (NS_NOESCAPE ^)(const void *bytes, NSInteger size))handler
{
    BOOL locked = NO;
    if (handler == nil) {
        return;
    }
    if (_pixelBuffer != NULL) {
        locked = CVPixelBufferLockBaseAddress(_pixelBuffer, kCVPixelBufferLock_ReadOnly) == kCVReturnSuccess;
    }
    handler(_array.data, (NSInteger)(_array.count * charon_ml_type_size(_array.data_type)));
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
    /* The strides go with the buffer because the framework may hand over a different backing store
     * with different ones: a caller indexing with the strides it read from the property would read
     * the wrong elements. The port's buffer is the array's own, so they are the array's own. */
    handler(_array.data, (NSInteger)(_array.count * charon_ml_type_size(_array.data_type)), self.strides);
    if (locked) {
        CVPixelBufferUnlockBaseAddress(_pixelBuffer, 0);
    }
}

- (void)setObject:(NSNumber *)object atIndexedSubscript:(NSInteger)idx
{
    if (object == nil || idx < 0 || (size_t)idx >= _array.count) {
        return;
    }
    charon_ml_array_set(&_array, (int64_t)idx, object.doubleValue);
}

- (NSNumber *)objectForKeyedSubscript:(NSArray<NSNumber *> *)key
{
    int64_t position[CHARON_ML_MAX_RANK];
    int rank = 0;
    int64_t offset;
    if (!charon_ml_shape_from_array(key, position, CHARON_ML_MAX_RANK, &rank) || rank != _array.rank) {
        return nil;
    }
    offset = charon_ml_array_offset(&_array, position, rank);
    if (offset < 0) {
        return nil;
    }
    return @(charon_ml_array_get(&_array, offset));
}

- (void)setObject:(NSNumber *)object forKeyedSubscript:(NSArray<NSNumber *> *)key
{
    int64_t position[CHARON_ML_MAX_RANK];
    int rank = 0;
    int64_t offset;
    if (object == nil || !charon_ml_shape_from_array(key, position, CHARON_ML_MAX_RANK, &rank) ||
        rank != _array.rank) {
        return;
    }
    offset = charon_ml_array_offset(&_array, position, rank);
    if (offset < 0) {
        return;
    }
    charon_ml_array_set(&_array, offset, object.doubleValue);
}

+ (MLMultiArray *)multiArrayByConcatenatingMultiArrays:(NSArray<MLMultiArray *> *)arrays
                                             alongAxis:(NSInteger)axis
                                              dataType:(MLMultiArrayDataType)dataType
{
    NSUInteger count = arrays.count, index;
    int64_t shape[CHARON_ML_MAX_RANK];
    int64_t strides[CHARON_ML_MAX_RANK];
    int rank = 0, axis_index;
    int64_t total = 0, at_axis = 0;
    MLMultiArray *joined;
    charon_ml_array *out;

    if (count == 0 || charon_ml_type_size(charon_ml_type_of_array(dataType)) == 0) {
        return nil;
    }
    /* Every input must have the same rank, must agree on every dimension but the one joined
     * along, and the axis must be one of that rank: values that do not line up cannot be
     * concatenated, and saying so is better than placing them where they do not belong. */
    for (index = 0; index < count; index++) {
        int64_t one[CHARON_ML_MAX_RANK];
        int one_rank = 0;
        if (!charon_ml_shape_from_array(arrays[index].shape, one, CHARON_ML_MAX_RANK, &one_rank) ||
            one_rank > CHARON_ML_MAX_RANK) {
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
    joined = [[MLMultiArray alloc] initWithShape:charon_ml_shape_to_array(shape, rank) dataType:dataType error:NULL];
    if (joined == nil) {
        return nil;
    }
    out = [joined charonArray];
    /* Each input's values are written at its own position along the joined axis and the same
     * position on every other one, element by element through the input's own strides, so a
     * strided or a windowed input concatenates where it lies. */
    for (index = 0; index < count; index++) {
        charon_ml_array *one = [arrays[index] charonArray];
        size_t element;
        for (element = 0; element < one->count; element++) {
            int64_t position[CHARON_ML_MAX_RANK];
            int64_t destination;
            charon_ml_unravel((int64_t)element, one->rank, one->shape, position);
            destination = charon_ml_ravel(position, out->rank, out->strides);
            /* Only the joined axis moves: every other position is the same one, which is what
             * makes the elements line up. */
            destination += (at_axis + position[axis] - position[axis]) * out->strides[axis];
            charon_ml_array_set(out, destination, charon_ml_array_get(one, (int64_t)element));
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
        int64_t steps[CHARON_ML_MAX_RANK];
        int rank = 0;
        if (charon_ml_shape_from_array(strides, steps, CHARON_ML_MAX_RANK, &rank)) {
            memcpy(_array.strides, steps, (size_t)MIN(rank, _array.rank) * sizeof *steps);
        }
    }
    if (bytes != nil) {
        size_t width = charon_ml_type_size(_array.data_type);
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
    [coder encodeObject:[NSData dataWithBytes:_array.data length:_array.count * charon_ml_type_size(_array.data_type)]
                 forKey:@"data"];
}

@end
