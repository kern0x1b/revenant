// MPSNDArray, MPSNDArrayDescriptor, MPSTemporaryNDArray and the allocator that makes them: the
// storage half of the 13.0 NDArray family, from the headers of the SDK of iOS 16.4.
//
// WHAT THIS IS. The class discussion in MPSCore/MPSNDArray.h is the source of the design. An
// MPSNDArray is a storage container over an MTLBuffer for multi-dimensional data; the major row (the
// dimension whose neighbouring elements sit next to each other in memory) is the 0th; the dimensions after
// it make up a tightly packed set of rows, each rowBytes long; and a transpose or a slice is a VIEW, which
// the framework usually defers as a physical transpose until one is actually required. Where both happen,
// the slice comes first and then the transpose. So a descriptor here is a shape (a slice range
// per dimension) with a permutation over it, and a view is that descriptor applied to its parent's
// storage: the parent's buffer, an offset, a permutation of the parent's strides, and no copy.
//
// The 16-byte row the header recommends (MPSCore/MPSNDArray.h's class discussion, which advises a multiple of 16 bytes)
// is what MPSNDArrayRoundedRowBytes() produces, so the 0th
// dimension's stride is a rounded row rather than an element and every later dimension is a whole
// number of rows.
//
// The storage is ONE MTLBuffer, which is what charon's own device makes of it: its MTLBuffer is host
// memory the CPU reads and writes directly (CharonMPS.h's own note, and facts/Metal/RenderPath.md),
// so the release's own accessors - -readBytes:strideBytes: and -writeBytes:strideBytes:,
// MPSCore/MPSNDArray.h:383 and :397 - are a strided gather and scatter over that buffer, and the whole
// family is a loop over what they produce. A view needs no buffer of its own, which is exactly what
// the class discussion's "Two MPSNDArrays alias if they share a common ancestor" and the `parent`
// property mean.

#import "CharonMPSNDArray.h"

#pragma clang diagnostic ignored "-Wprotocol"
#pragma clang diagnostic ignored "-Wincomplete-implementation"

// THE PLANT, and it is this object's own rather than the family-wide one in CharonMPS.h. That one
// perturbs what CharonMPSStore WRITES, and this object never calls it: -writeBytes:strideBytes: and
// -readBytes:strideBytes: copy BYTES, and the release's own accessors copy bytes too - "Copy bytes
// from MPSNDArray into buffer" and "Copy bytes from a buffer into the MPSNDArray"
// (MPSCore/MPSNDArray.h:383 and :397). A plant on the store path therefore cannot reach this file, and
// a harness that used one would print a green run it had not earned - measured, and the fix is the
// second macro below rather than a harness that stopped asking. Plant 1 shifts the FIRST byte of
// every element copied and plant 2 the LAST, so a comparison that reads only one end of a case
// cannot see one of them.
#if defined(CHARON_NDARRAY_PLANT)
static void MPSNDArray_plantedCopy(void *destination, const void *source, size_t bytes)
{
    unsigned char *out = (unsigned char *)destination;
    memcpy(destination, source, bytes);
    // ADDED, not exclusive-ored, and that is not a style choice: the same macro is on both the write
    // and the read, so an exclusive-or would be applied twice over the same element - once storing it
    // into the array and once gathering it out - and the two applications would cancel and the
    // planted build would print exactly the unplanted bytes. Measured, and the harness caught it by
    // reporting the plant survived. An addition accumulates instead, so a round trip through a
    // planted array cannot come back unchanged.
    if (CHARON_NDARRAY_PLANT == 1)
        out[0] = (unsigned char)(out[0] + 0x40u);
    else
        out[bytes - 1] = (unsigned char)(out[bytes - 1] + 0x08u);
}
#define MPSNDArray_COPY(destination, source, bytes) MPSNDArray_plantedCopy(destination, source, bytes)
#else
#define MPSNDArray_COPY(destination, source, bytes) memcpy(destination, source, bytes)
#endif

// The allocator, which MPSCore/MPSNDArray.h:217 asks for by name. Its one method names the kernel
// that will write over the array it makes, and says of that argument that the MPS implementations do not
// need the field, which exists for the convenience of other implementers (MPSCore/MPSNDArray.h:165-167). So
// (MPSCore/MPSNDArray.h:165-167). So the kernel is accepted and not asked anything, which is what
// the release's own allocators do; an allocator that made the array a kernel's private scratch would
// have to read it, and this one does not pretend to.
@interface CharonMPSNDArrayAllocator : NSObject <MPSNDArrayAllocator>
@end

@implementation CharonMPSNDArrayAllocator

// The protocol inherits NSSecureCoding (MPSCore/MPSNDArray.h:162) and this allocator implements
// neither -encodeWithCoder: nor -initWithCoder:device:, so the honest answer is NO: it will not
// round-trip. Answering YES would promise an archive path that is not here.
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
    NSUInteger _lengths[CHARON_MPS_NDARRAY_MAX_DIMENSIONS];
    MPSDimensionSlice _slices[CHARON_MPS_NDARRAY_MAX_DIMENSIONS];
    vector_uchar16 _order;
}

- (instancetype)init
{
    if ((self = [super init])) {
        _dataType = MPSDataTypeInvalid;
        _numberOfDimensions = 0;
        for (NSUInteger i = 0; i < CHARON_MPS_NDARRAY_MAX_DIMENSIONS; i++) {
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

// The number of dimensions a descriptor reports, which is the SLICE count: a slice is what makes a
// view smaller than the array it is a view of, and MPSCore/MPSNDArray.h:33-35 says "Undefined
// dimensions are implicitly length 1", so a dimension the caller has not sliced does not lengthen a
// view and is not counted in it.
- (NSUInteger)numberOfDimensions { return _numberOfDimensions; }

- (void)setNumberOfDimensions:(NSUInteger)numberOfDimensions
{
    if (numberOfDimensions > CHARON_MPS_NDARRAY_MAX_DIMENSIONS)
        numberOfDimensions = CHARON_MPS_NDARRAY_MAX_DIMENSIONS;
    _numberOfDimensions = numberOfDimensions;
    for (NSUInteger i = 0; i < CHARON_MPS_NDARRAY_MAX_DIMENSIONS; i++) {
        if (i >= numberOfDimensions) {
            _slices[i].start = 0;
            _slices[i].length = 1;
        }
    }
}

// "If dimensionIndex >= numberOfDimensions, 1 will be returned" (MPSCore/MPSNDArray.h:42-45).
//
// The answer is read THROUGH the order, not beside it, and that is measured rather than assumed:
// tests/backports/host/mpsndarray/run.sh builds a [2,3] descriptor, transposes dimensions 0 and 1 -
// the header's own worked example at MPSCore/MPSNDArray.h:70-74 - and the release's
// -lengthOfDimension:0 answers 3 and -lengthOfDimension:1 answers 2. So a transposed descriptor
// reports the SHAPE in the new order, which is what makes a transpose observable at all: the order
// getter alone would say a [2,3] and a [3,2] are the same numbers in a different sequence, and this
// says they are different shapes.
//
// It is the WHOLE length, not the slice's, and the header permits exactly that: a dimension may keep a
// length no shorter than the existing slice (MPSCore/MPSNDArray.h:235-237). The
// release's own answer for a view whose dimension 1 is sliced to 2 of 4 is 4, so a walk that used
// this number to bound itself would run past the slice - which is why the packed walk below takes
// its lengths from the slice and only its strides from here.
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
    // A slice cannot read past the array it is a slice OF, so a range that runs off the end is
    // pulled back to the end. The alternative - honouring the caller's length - makes -lengthOf-
    // Dimension: report more elements than the descriptor holds, and every walk that answers to
    // that count then reads memory the shape does not own.
    if (subRange.start > _lengths[dimensionIndex])
        subRange.start = _lengths[dimensionIndex];
    if (subRange.length > _lengths[dimensionIndex] - subRange.start)
        subRange.length = _lengths[dimensionIndex] - subRange.start;
    _slices[dimensionIndex] = subRange;
}

// The order the dimensions run in. The header gives the default as 0 through 15 in turn (:70-74), and once the axes have been permuted,
// swapping dimensions 0 and 1 gives the order 1, 0, 2, 3 and so on, with each entry holding the new position
// of its dimension. So a transpose swaps the two entries and
// touches nothing else - which is why this is two array writes and no shape arithmetic, and why a
// transposed shape of [a,b] still holds a and b elements and only changes which runs first.
- (vector_uchar16)dimensionOrder { return _order; }

- (void)transposeDimension:(NSUInteger)dimensionIndex withDimension:(NSUInteger)dimensionIndex2
{
    if (dimensionIndex >= CHARON_MPS_NDARRAY_MAX_DIMENSIONS || dimensionIndex2 >= CHARON_MPS_NDARRAY_MAX_DIMENSIONS)
        return;
    unsigned char held = _order[dimensionIndex];
    _order[dimensionIndex] = _order[dimensionIndex2];
    _order[dimensionIndex2] = held;
}

// The whole shape, which the three initialisers below all name. Dimension 0 is the fastest moving
// one, as MPSCore/MPSNDArray.h:93-104 states for this form: the lengths given run from the fastest moving
// dimension to the slowest moving one.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunavailable-declarations"
+ (instancetype)descriptorWithDataType:(MPSDataType)dataType
                       dimensionCount:(NSUInteger)numberOfDimensions
                       dimensionSizes:(NSUInteger *)dimensionSizes
{
    if (numberOfDimensions == 0 || numberOfDimensions > CHARON_MPS_NDARRAY_MAX_DIMENSIONS)
        return nil;
    // MPSCore/MPSNDArray.h:150 marks -init unavailable to a CALLER ("Please use -descriptorWith-
    // DataType:... instead"). The class building its own object is not that caller, and every
    // factory below goes through this one, so the one internal call is made here and nowhere else.
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

// The variadic form, which MPSCore/MPSNDArray.h:120-124 gives as "a 0-terminated variadric list of
// NSUIntegers ... --<--list terminator!". A zero terminates the list and is never a length, so it is
// not stored; a shape with a zero-length dimension is not describable through this form at all.
+ (instancetype)descriptorWithDataType:(MPSDataType)dataType dimensionSizes:(NSUInteger)dimension0, ...
{
    NSUInteger sizes[CHARON_MPS_NDARRAY_MAX_DIMENSIONS];
    NSUInteger count = 0;
    va_list arguments;
    va_start(arguments, dimension0);
    for (NSUInteger next = dimension0; next != 0 && count < CHARON_MPS_NDARRAY_MAX_DIMENSIONS;
         next = va_arg(arguments, NSUInteger))
        sizes[count++] = next;
    va_end(arguments);
    if (count == 0)
        return nil;
    return [self descriptorWithDataType:dataType dimensionCount:count dimensionSizes:sizes];
}

// The shape factory, whose order the header gives separately (MPSCore/MPSNDArray.h:111-119): the array runs
// from the slowest moving dimension to the fastest, which is what MLMultiArray (CoreML) and many Python
// frameworks do. MPSCoreTypes.h:472 gives the example of a shape [5, 4, 2]: dimension 0 of size 2 moves
// fastest, then dimension 1 of size 4, and dimension 2 of size 5 moves slowest. So this is the REVERSE of the dimensionCount:
// form above, and a caller that used both on the same numbers gets two different arrays, which is the
// header's design and not a slip to be smoothed over here.
+ (instancetype)descriptorWithDataType:(MPSDataType)dataType shape:(NSArray<NSNumber *> *)shape
{
    if (shape.count == 0 || shape.count > CHARON_MPS_NDARRAY_MAX_DIMENSIONS)
        return nil;
    NSUInteger sizes[CHARON_MPS_NDARRAY_MAX_DIMENSIONS];
    for (NSUInteger i = 0; i < shape.count; i++)
        sizes[shape.count - 1 - i] = [shape[i] unsignedIntegerValue];
    return [self descriptorWithDataType:dataType dimensionCount:shape.count dimensionSizes:sizes];
}

- (void)reshapeWithDimensionCount:(NSUInteger)numberOfDimensions dimensionSizes:(NSUInteger *)dimensionSizes
{
    if (numberOfDimensions == 0 || numberOfDimensions > CHARON_MPS_NDARRAY_MAX_DIMENSIONS)
        return;
    _numberOfDimensions = numberOfDimensions;
    for (NSUInteger i = 0; i < CHARON_MPS_NDARRAY_MAX_DIMENSIONS; i++) {
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
    if (shape.count == 0 || shape.count > CHARON_MPS_NDARRAY_MAX_DIMENSIONS)
        return;
    NSUInteger sizes[CHARON_MPS_NDARRAY_MAX_DIMENSIONS];
    for (NSUInteger i = 0; i < shape.count; i++)
        sizes[i] = [shape[i] unsignedIntegerValue];
    [self reshapeWithDimensionCount:shape.count dimensionSizes:sizes];
}

@end

@implementation MPSNDArray {
    id<MTLBuffer> _buffer;
    MPSNDArrayDescriptor *_descriptor;   // the VIEW: lengths, slices, permutation
    MPSNDArrayDescriptor *_shape;        // the WHOLE shape, which is what the accessors answer
    NSUInteger _byteOffset;
    MPSNDArray *_parent;
    id<MTLDevice> _device;
    NSString *_label;
}

- (instancetype)initWithDevice:(id<MTLDevice>)device descriptor:(MPSNDArrayDescriptor *)descriptor
{
    // A descriptor is what gives the array its shape, and MPSCore/MPSNDArray.h:266 names it the
    // designated initializer's own argument, so an array made without one has no shape to hold. The
    // release would not make one; refusing says so rather than answering an array of no shape.
    if (!descriptor) {
        NSLog(@"MPSNDArray: -initWithDevice:descriptor: was given no descriptor, and the shape is what the array holds; "
              @"build one with +[MPSNDArrayDescriptor descriptorWithDataType:dimensionCount:dimensionSizes:]");
        return nil;
    }
    if ((self = [super init])) {
        _device = device;
        _descriptor = descriptor;
        _shape = [self charon_mps_wholeShapeOf:descriptor];
    }
    return self;
}

- (instancetype)initWithDevice:(id<MTLDevice>)device scalar:(double)value
{
    // "Create a 1-Dimensional length=1 NDArray to hold a scalar" (MPSCore/MPSNDArray.h:270-272).
    // The type is float32: it is the width a double is lossless in, and the one this header's
    // element table carries as a float.
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
    // The header marks it unavailable and says why: "Please use -initWithDevice:descriptor: instead"
    // (MPSCore/MPSNDArray.h:256).
    NSLog(@"MPSNDArray: -init makes an array of no shape; use -initWithDevice:descriptor: or -initWithDevice:scalar:");
    return nil;
}

// "Get a well known <MPSNDArrayAllocator> that makes standard MTLBuffers" (MPSCore/MPSNDArray.h:217).
// One allocator for the whole process, as the class methods of the release's own allocators are, and
// it makes plain MPSNDArrays: the temporary ones come from MPSTemporaryNDArray's own below.
+ (id<MPSNDArrayAllocator>)defaultAllocator
{
    static CharonMPSNDArrayAllocator *allocator = nil;
    if (!allocator)
        allocator = [[CharonMPSNDArrayAllocator alloc] init];
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

// A NEW descriptor of this array's own shape, which the header promises is made each time so the app
// can customise it (MPSCore/MPSNDArray.h:243-251).
// So the lengths are copied and the order is re-applied by transposing: a caller that transposes
// the descriptor it is handed must not transpose the array it describes.
- (MPSNDArrayDescriptor *)descriptor
{
    NSUInteger sizes[CHARON_MPS_NDARRAY_MAX_DIMENSIONS];
    for (NSUInteger i = 0; i < CHARON_MPS_NDARRAY_MAX_DIMENSIONS; i++)
        sizes[i] = [_descriptor lengthOfDimension:i];
    MPSNDArrayDescriptor *descriptor = [MPSNDArrayDescriptor descriptorWithDataType:_descriptor.dataType
                                                                     dimensionCount:_descriptor.numberOfDimensions
                                                                     dimensionSizes:sizes];
    vector_uchar16 order = [_descriptor dimensionOrder];
    for (NSUInteger i = 0; i < CHARON_MPS_NDARRAY_MAX_DIMENSIONS; i++)
        [descriptor transposeDimension:i withDimension:order[i]];
    return descriptor;
}

// The WHOLE shape behind a descriptor: its lengths in their own order, with every slice at its full
// range and no permutation. This is the shape of the storage a view is a window onto, and it is
// separate from the view's own descriptor because the release keeps the two apart - which
// tests/backports/host/mpsndarray/run.sh measures rather than assumes, and the measurement is the
// reason this method exists:
//
//   - a transposed DESCRIPTOR reports the shape in the new order - a [2,3] transposed answers
//     -lengthOfDimension:0 with 3 (case 4) - because -lengthOfDimension: on a descriptor reads
//     through the order;
//   - a transposed VIEW of a [2,3] array reports 2 and 3, the array's own shape (case 7), and a view
//     of a [3,4,2] array sliced on dimension 1 reports 3, 4 and 2 (case 6) - the whole shape, with the
//     slice not narrowing it, which MPSCore/MPSNDArray.h:235-237 permits: a dimension may keep a length no shorter than its slice.
//
// So the accessors answer from the shape and the packed walk answers from the view, and a walk that
// bounded itself by -lengthOfDimension: would run off the end of every slice.
- (MPSNDArrayDescriptor *)charon_mps_wholeShapeOf:(MPSNDArrayDescriptor *)descriptor
{
    NSUInteger sizes[CHARON_MPS_NDARRAY_MAX_DIMENSIONS];
    for (NSUInteger i = 0; i < CHARON_MPS_NDARRAY_MAX_DIMENSIONS; i++)
        sizes[i] = [descriptor sliceRangeForDimension:i].length;
    return [MPSNDArrayDescriptor descriptorWithDataType:descriptor.dataType
                                         dimensionCount:descriptor.numberOfDimensions
                                         dimensionSizes:sizes];
}

// The bytes this array's own shape occupies: one rounded row of the 0th dimension, times every
// dimension after it. A view answers with the whole of its parent's storage, because a view occupies
// no storage of its own - it is a window onto the parent's - and the header's -resourceSize
// discussion is about "the size of the backing store of underlying MTLResources".
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

// The buffer, made on the first ask. That is the release's own order, from -resourceSize's own
// discussion: the header says an array starts with no backing store, that the store is allocated lazily (typically
// on the first write), so measuring an unbacked array is cheap, and a caller may build a throwaway MPSImage and ask it
// how big the backing store would be and discard it if that is too large (MPSCore/MPSNDArray.h:279-286). So
// -resourceSize is answerable before anything exists, and this is where the allocation happens.
- (id<MTLBuffer>)charon_mps_makeBuffer
{
    if (_buffer)
        return _buffer;
    NSUInteger size = [self resourceSize];
    if (size == 0)
        return nil;
    id<MTLBuffer> buffer = [_device newBufferWithLength:size options:MTLResourceStorageModeShared];
    if (!buffer) {
        CharonMPSRefuse(@"MPSNDArray: the device made no %lu byte buffer for a shape of %lu dimensions",
                        (unsigned long)size, (unsigned long)_descriptor.numberOfDimensions);
        return nil;
    }
    _buffer = buffer;
    return _buffer;
}

// THE TWO LAYOUTS, and keeping them apart is the whole of a readBytes:/writeBytes:.
//
// THE TWO SIDES OF A COPY, which is the whole of -readBytes:strideBytes:.
//
// The STORAGE side is PACKED: dimension 0's elements are adjacent and every dimension after it is a
// whole number of the ones before, with no padding between rows.
//
// The BUFFER side is what the caller's stride array says, and a nil stride array is the packed form
// the header documents: with no stride array given, the strides are worked out on the assumption of no
// padding between elements or rows (MPSCore/MPSNDArray.h:389-392), so with
// a nil array the two sides agree and the copy is a straight gather, and with a caller's own strides
// it is the gather those strides describe.
//
// `strides` is the STORAGE stride in elements per view dimension, `lengths` is the extent the walk
// covers, and `offset` is where the view's {0,...,0} element sits. The slice is applied here and the
// permutation is applied here, once, in the order the class discussion fixes: the slice first, and
// the result of the slice transposed.
static void MPSNDArrayViewLayout(MPSNDArrayDescriptor *view, MPSNDArrayDescriptor *shape,
                                 NSUInteger *strides, NSUInteger *lengths, NSUInteger *offset)
{
    size_t elementSize = MPSSizeofMPSDataType(shape.dataType);
    if (!elementSize)
        elementSize = 1;
    // The STORAGE is packed: dimension 0's elements are adjacent and each dimension after it is a
    // whole number of the dimensions before it, with no padding between rows. The 16-byte row is
    // therefore an ALLOCATION size and not an address - and saying so is what the release's own
    // answers forced, because a [2,3,4,5] float32 array reports -resourceSize 960 (16 bytes a row
    // over 3*4*5 rows, the rounded row of a 2-element row) while its element at (1,2,3,4) is at
    // 1 + 2*2 + 3*6 + 4*24 and not at 1 + 2*4 + 3*12 + 4*48. Cases 5, 6, 7 and 8 of
    // tests/backports/host/mpsndarray/run.sh are the four that would disagree if the two were
    // confused, and each of them names the numbers.
    vector_uchar16 order = [view dimensionOrder];
    size_t strideOf[CHARON_MPS_NDARRAY_MAX_DIMENSIONS];
    strideOf[0] = 1;
    for (NSUInteger d = 1; d < shape.numberOfDimensions && d < CHARON_MPS_NDARRAY_MAX_DIMENSIONS; d++)
        strideOf[d] = strideOf[d - 1] * [shape lengthOfDimension:d - 1];
    NSUInteger at = 0;
    for (NSUInteger i = 0; i < view.numberOfDimensions && i < CHARON_MPS_NDARRAY_MAX_DIMENSIONS; i++) {
        NSUInteger dimension = order[i];
        strides[i] = (NSUInteger)(dimension < CHARON_MPS_NDARRAY_MAX_DIMENSIONS ? strideOf[dimension] : 0);
        lengths[i] = [view sliceRangeForDimension:dimension].length;
        at += [view sliceRangeForDimension:dimension].start * strides[i];
    }
    for (NSUInteger i = view.numberOfDimensions; i < CHARON_MPS_NDARRAY_MAX_DIMENSIONS; i++) {
        strides[i] = 0;
        lengths[i] = 1;
    }
    *offset = at;
}

// The number of elements THIS array's packed walk visits, which is the SLICE's product and not the
// whole shape's. The two differ for a view, and which one the release uses is measured: a [3,4,2]
// array whose dimension 1 is sliced to 2 of 4 reads twelve elements - 7 8 9 10 11 12 and then 19 20
// 21 22 23 24, the slice's own values in the slice's own order - while -lengthOfDimension: on the
// same view still answers 4. So the walk is bounded by the slice and the shape accessors report the
// shape, and a walk bounded by the shape would read twelve elements past the slice.
- (NSUInteger)charon_mps_elementCount
{
    NSUInteger count = 1;
    for (NSUInteger i = 0; i < _descriptor.numberOfDimensions && i < CHARON_MPS_NDARRAY_MAX_DIMENSIONS; i++)
        count *= [_descriptor sliceRangeForDimension:i].length;
    return count;
}

// The byte stride of one step along each view dimension on the CALLER'S side of a copy: the caller's
// own when one was given, and the PACKED one when none was, which is elementSize over the product of
// the lengths before it. Nothing here knows about the padded row: that is the storage's business and
// the two are not the same number, which is the distinction MPSNDArrayViewLayout's own comment makes.
- (void)charon_mps_bufferStrides:(NSUInteger *)strides
                        lengths:(const NSUInteger *)lengths
                   strideBytes:(NSInteger *)strideBytesPerDimension
{
    size_t elementSize = MPSSizeofMPSDataType(_descriptor.dataType);
    NSUInteger packed = 1;
    for (NSUInteger i = 0; i < CHARON_MPS_NDARRAY_MAX_DIMENSIONS; i++) {
        strides[i] = strideBytesPerDimension ? (NSUInteger)strideBytesPerDimension[i] : packed * elementSize;
        packed *= lengths[i];
    }
}

// -readBytes:strideBytes:, the release's own accessor (MPSCore/MPSNDArray.h:383-392). A nil stride
// array is the packed form it documents, with the strides worked out for the caller on the assumption of no
// padding between elements or rows, and a non-nil one is a caller's own byte
// stride per dimension, which is what an export with rowStrides writes through.
//
// The walk is an odometer over this array's own shape, dim 0 the fastest running, gathering through
// the view's strides. That is where a slice and a transpose are applied, once, in the order the
// class discussion gives: the slice first, and the result of the slice transposed.
- (void)readBytes:(void *)buffer strideBytes:(NSInteger *)strideBytesPerDimension
{
    id<MTLBuffer> storage = _buffer;
    if (!storage) {
        // Reading an array that was never written is the release's own case: a fresh array holds
        // whatever its storage holds, and a fresh array has none. A destination-sized zero is the
        // honest answer for a packed read, and the caller's stride walk cannot be invented.
        if (!strideBytesPerDimension && buffer) {
            NSUInteger count = [self charon_mps_elementCount];
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
    NSUInteger strides[CHARON_MPS_NDARRAY_MAX_DIMENSIONS], lengths[CHARON_MPS_NDARRAY_MAX_DIMENSIONS];
    NSUInteger at = 0;
    MPSNDArrayViewLayout(_descriptor, shape, strides, lengths, &at);
    NSUInteger destination[CHARON_MPS_NDARRAY_MAX_DIMENSIONS];
    [self charon_mps_bufferStrides:destination lengths:lengths strideBytes:strideBytesPerDimension];
    // A read leaves the caller's buffer holding exactly what the array holds and nothing else. The
    // array's own extent and the caller's requested extent can differ - a caller that sizes its
    // buffer from -lengthOfDimension: on a SLICED view gets the whole shape, which is larger than the
    // slice - so the tail is cleared rather than left holding whatever was in the buffer. The
    // release's own answer for that tail is zero, measured in case 6.
    const char *base = (const char *)[storage contents] + _byteOffset;
    NSUInteger index[CHARON_MPS_NDARRAY_MAX_DIMENSIONS];
    for (NSUInteger i = 0; i < CHARON_MPS_NDARRAY_MAX_DIMENSIONS; i++)
        index[i] = 0;
    NSUInteger total = [self charon_mps_elementCount];
    if (buffer)
        memset(buffer, 0, total * elementSize);
    for (NSUInteger linear = 0; linear < total; linear++) {
        size_t source = at * elementSize;
        size_t target = 0;
        for (NSUInteger i = 0; i < _descriptor.numberOfDimensions && i < CHARON_MPS_NDARRAY_MAX_DIMENSIONS; i++) {
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

// -writeBytes:strideBytes:, the mirror of the read above over the same shape
// (MPSCore/MPSNDArray.h:397-401), so the two agree by construction: the same strides, the same
// order, the same odometer, with the roles of source and destination exchanged.
- (void)writeBytes:(void *)buffer strideBytes:(NSInteger *)strideBytesPerDimension
{
    id<MTLBuffer> storage = [self charon_mps_makeBuffer];
    if (!storage)
        return;
    size_t elementSize = MPSSizeofMPSDataType(_descriptor.dataType);
    if (elementSize == 0)
        return;
    MPSNDArrayDescriptor *shape = _parent ? _parent->_shape : _shape;
    NSUInteger strides[CHARON_MPS_NDARRAY_MAX_DIMENSIONS], lengths[CHARON_MPS_NDARRAY_MAX_DIMENSIONS];
    NSUInteger at = 0;
    MPSNDArrayViewLayout(_descriptor, shape, strides, lengths, &at);
    NSUInteger source[CHARON_MPS_NDARRAY_MAX_DIMENSIONS];
    [self charon_mps_bufferStrides:source lengths:lengths strideBytes:strideBytesPerDimension];
    char *base = (char *)[storage contents] + _byteOffset;
    NSUInteger index[CHARON_MPS_NDARRAY_MAX_DIMENSIONS];
    for (NSUInteger i = 0; i < CHARON_MPS_NDARRAY_MAX_DIMENSIONS; i++)
        index[i] = 0;
    NSUInteger total = [self charon_mps_elementCount];
    for (NSUInteger linear = 0; linear < total; linear++) {
        size_t target = at * elementSize;
        size_t sourceAt = 0;
        for (NSUInteger i = 0; i < _descriptor.numberOfDimensions && i < CHARON_MPS_NDARRAY_MAX_DIMENSIONS; i++) {
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
    // The header's own use for this is narrow: on a discrete device it brings the CPU-side copy of the buffer up to date
    // with the latest GPU value (MPSCore/MPSNDArray.h:403). The
    // buffer here is host memory and both accessors above have already written it, so there is no
    // discrete device and nothing to transfer.
    (void)commandBuffer;
}

// -arrayViewWithCommandBuffer:descriptor:aliasing:, which the class discussion describes as the way
// a slice, a transpose or another property change is made, and as usually ALIASING: the header says a new array
// is likely to share the parent's MTLBuffer and so alias its memory (MPSCore/MPSNDArray.h:255-262). So the view
// shares this array's buffer and answers -parent with it, which is the property the header gives for exactly that test.
- (MPSNDArray *)arrayViewWithCommandBuffer:(id<MTLCommandBuffer>)commandBuffer
                                 descriptor:(MPSNDArrayDescriptor *)descriptor
                                  aliasing:(MPSAliasingStrategy)aliasing
{
    (void)commandBuffer;
    if (!descriptor)
        return nil;
    // MPSAliasingStrategyShallNotAlias is "Always make a copy" (MPSCoreTypes.h:329), the strategy a
    // caller asks for precisely to force the repacking the class discussion says is otherwise
    // deferred. A view here is a window onto a shared buffer, so honouring the request means
    // materializing it: read this array packed, write the result into a new array of the
    // descriptor's own shape, and hand that back. Not honouring it would answer a request the
    // header defines with a view that aliases.
    if (aliasing & MPSAliasingStrategyShallNotAlias) {
        MPSNDArray *copy = [[MPSNDArray alloc] initWithDevice:_device descriptor:descriptor];
        size_t width = MPSSizeofMPSDataType(descriptor.dataType);
        NSUInteger count = 1;
        for (NSUInteger i = 0; i < descriptor.numberOfDimensions; i++)
            count *= [descriptor lengthOfDimension:i];
        void *packed = calloc(count ? count : 1, width ? width : 1);
        if (!packed) {
            CharonMPSRefuse(@"MPSNDArray: no memory to make the %lu element copy -arrayViewWithCommandBuffer:descriptor:aliasing: asked for",
                            (unsigned long)count);
            return nil;
        }
        [self readBytes:packed strideBytes:NULL];
        [copy writeBytes:packed strideBytes:NULL];
        free(packed);
        return copy;
    }
    // The view's four ivars below are strong, so each store retains the value it is given and
    // releases the one it held, and the local owns the alloc/init pair until `return` autoreleases
    // it into the caller's pool - which is what the retain/autorelease/release dance this replaced
    // arranged by hand, to the same net ownership.
    MPSNDArray *view = [[MPSNDArray alloc] initWithDevice:_device descriptor:descriptor];
    view->_buffer = _buffer;
    view->_byteOffset = _byteOffset;
    view->_parent = self;
    // The shape a view reports is its PARENT's, not its own descriptor's slice: a view of a [3,4,2]
    // array whose dimension 1 is sliced to 2 of 4 reports 3, 4 and 2, not 3, 2 and 2. Measured in cases
    // 6 and 8 of tests/backports/host/mpsndarray/run.sh, and the header permits a dimension to keep a length no shorter than its slice
    // (MPSCore/MPSNDArray.h:235-237).
    view->_shape = _shape;
    return view;
}

// -exportDataWithCommandBuffer:toBuffer:destinationDataType:offset:rowStrides: - the release's own
// copy out (MPSCore/MPSNDArray.h:322-331). The values go through this array's -readBytes: and are
// stored at the destination's OWN data type, so a float32 array exported into a uint8 buffer lands
// as the numbers those types hold rather than as the bytes of the other; that conversion is what
// destinationDataType is for, and skipping it would make the method's own argument inert.
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
        CharonMPSRefuse(@"MPSNDArray: -exportDataWithCommandBuffer:toBuffer: was given a data type of %u or %u, which has no width",
                        (unsigned)_descriptor.dataType, (unsigned)destinationDataType);
        return;
    }
    NSUInteger total = [self charon_mps_elementCount];
    void *source = malloc(total * from);
    if (!source)
        return;
    [self readBytes:source strideBytes:NULL];
    char *destination = (char *)[buffer contents] + offset;
    if (rowStrides) {
        NSUInteger index[CHARON_MPS_NDARRAY_MAX_DIMENSIONS];
        for (NSUInteger i = 0; i < CHARON_MPS_NDARRAY_MAX_DIMENSIONS; i++)
            index[i] = 0;
        for (NSUInteger linear = 0; linear < total; linear++) {
            size_t at = 0;
            for (NSUInteger i = 0; i < _descriptor.numberOfDimensions && i < CHARON_MPS_NDARRAY_MAX_DIMENSIONS; i++)
                at += (size_t)(rowStrides[i] * (NSInteger)index[i]);
            CharonMPSStore(destination + at, destinationDataType, 0, CharonMPSLoad(source, _descriptor.dataType, linear));
            for (NSUInteger i = 0; i < _descriptor.numberOfDimensions; i++) {
                if (++index[i] < [_descriptor sliceRangeForDimension:i].length)
                    break;
                index[i] = 0;
            }
        }
    } else {
        for (NSUInteger linear = 0; linear < total; linear++)
            CharonMPSStore(destination, destinationDataType, linear, CharonMPSLoad(source, _descriptor.dataType, linear));
    }
    free(source);
}

// -importDataWithCommandBuffer:fromBuffer:sourceDataType:offset:rowStrides: - the reverse
// (MPSCore/MPSNDArray.h:336-342), and the mirror of the export above: the source's own data type is
// read and the values stored at this array's, through this array's -writeBytes:.
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
        CharonMPSRefuse(@"MPSNDArray: -importDataWithCommandBuffer:fromBuffer: was given a data type of %u or %u, which has no width",
                        (unsigned)sourceDataType, (unsigned)_descriptor.dataType);
        return;
    }
    NSUInteger total = [self charon_mps_elementCount];
    void *destination = malloc(total * to);
    if (!destination)
        return;
    const char *source = (const char *)[buffer contents] + offset;
    if (rowStrides) {
        NSUInteger index[CHARON_MPS_NDARRAY_MAX_DIMENSIONS];
        for (NSUInteger i = 0; i < CHARON_MPS_NDARRAY_MAX_DIMENSIONS; i++)
            index[i] = 0;
        for (NSUInteger linear = 0; linear < total; linear++) {
            size_t at = 0;
            for (NSUInteger i = 0; i < _descriptor.numberOfDimensions && i < CHARON_MPS_NDARRAY_MAX_DIMENSIONS; i++)
                at += (size_t)(rowStrides[i] * (NSInteger)index[i]);
            CharonMPSStore(destination, _descriptor.dataType, linear, CharonMPSLoad(source + at, sourceDataType, 0));
            for (NSUInteger i = 0; i < _descriptor.numberOfDimensions; i++) {
                if (++index[i] < [_descriptor sliceRangeForDimension:i].length)
                    break;
                index[i] = 0;
            }
        }
    } else {
        for (NSUInteger linear = 0; linear < total; linear++)
            CharonMPSStore(destination, _descriptor.dataType, linear, CharonMPSLoad(source, sourceDataType, linear));
    }
    [self writeBytes:destination strideBytes:NULL];
    free(destination);
}

// No -dealloc: every ivar above is strong, so ARC releases them and calls [super dealloc] itself.
// Spelling either out is what ARC forbids, and there is nothing here for it to do that it does not.

@end

@implementation MPSTemporaryNDArray {
    NSUInteger _readCount;
}

// The header describes a temporary as one whose data lives in command-buffer-specific memory
// (MPSCore/MPSNDArray.h:407-416). There is no command-buffer-specific pool to draw from on a device
// whose buffer is host memory, so what makes this a temporary array is the readCount and the
// allocator, not a different kind of storage: the readCount starts at the header's documented
// value of 1, which means the array can be rewritten as often as needed but read just once
// (MPSCore/MPSNDArray.h:456-458), and every kernel that reads one decrements it, which is
// what CharonMPSConsumeReadCount() does for the whole family.
+ (instancetype)temporaryNDArrayWithCommandBuffer:(id<MTLCommandBuffer>)commandBuffer
                                      descriptor:(MPSNDArrayDescriptor *)descriptor
{
    id<MTLDevice> device = [commandBuffer respondsToSelector:@selector(device)] ? [commandBuffer device] : nil;
    if (!device)
        device = MTLCreateSystemDefaultDevice();
    if (!device || !descriptor)
        return nil;
    // -initWithDevice:descriptor: is the designated initializer MPSCore/MPSNDArray.h:266 gives and
    // is what a view of this array is built from as well, so the temporary class inherits it rather
    // than refusing it: it is the one path a temporary array can be made without a private seam this
    // band would then have to carry a registry row for.
    MPSTemporaryNDArray *array = [[MPSTemporaryNDArray alloc] initWithDevice:device descriptor:descriptor];
    [array setReadCount:1];
    return array;
}

+ (id<MPSNDArrayAllocator>)defaultAllocator
{
    static CharonMPSNDArrayAllocator *allocator = nil;
    if (!allocator)
        allocator = [[CharonMPSNDArrayAllocator alloc] init];
    return allocator;
}

- (NSUInteger)readCount { return _readCount; }

// The header calls it an error to change readCount once it has reached zero (MPSCore/MPSNDArray.h:446-448), which is
// a promise about when a temporary's storage may be reused. Here there is no pool to return the
// storage to, so the count is a counter a caller reads rather than one that frees anything - and
// raising it from zero is refused rather than allowed, so the error the header describes is still
// an error here.
- (void)setReadCount:(NSUInteger)readCount
{
    if (_readCount == 0) {
        CharonMPSRefuse(@"MPSTemporaryNDArray: the read count is already 0 and it may not be changed back");
        return;
    }
    _readCount = readCount;
}

@end
