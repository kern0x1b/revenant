// CharonMPSNDArray.h - the addressing an MPSNDArray and the NDArray kernels share.
//
// Every function here is static, so no backport file depends on another one's symbols: a band that
// leaves a file out does not leave the others with undefined ones. CharonMPS.h's own note says the
// same for the matrix family, and the reason is mechanical: the band machinery keeps an object whole
// or drops it whole, so a C function defined in a file that also exports a class is undefined in
// every band that object is not carried in.
//
// WHAT AN NDARRAY IS HERE, and why a kernel reads it into a host buffer first. MPSCore/MPSNDArray.h
// has no accessor for an array's bytes: the release's own way in and out is
// -readBytes:strideBytes: and -writeBytes:strideBytes: (MPSCore/MPSNDArray.h:383 and :397), and with
// a nil stride array they pack the copy with "no additional space in between elements, rows, etc".
// So a kernel below materializes each source into a packed host buffer through that method, does its
// arithmetic there, and writes the destination back through the other. That is the release's own
// route to the data, not a seam invented for the port, and it is what a view forces: a transposed or
// sliced array is a VIEW, recorded rather than performed (MPSCore/MPSNDArray.h's class discussion),
// so its elements are not adjacent in memory and there is no single pointer to walk.
//
// The class discussion also fixes the ORDER every walk below uses: the major row, the dimension whose
// neighbouring elements sit next to each other in memory, is the 0th, and the dimensions after it are a
// densely packed block of rows. So a packed host buffer is indexed with dim 0 the fastest running, and
// MPSNDArray.h's own initialisers agree - the dimensionSizes array runs from the dimension moving fastest
// down to the one moving slowest.

#import "CharonMPS.h"

NS_ASSUME_NONNULL_BEGIN

#define CHARON_MPS_NDARRAY_MAX_DIMENSIONS 16

// A materialized MPSNDArray: a packed host copy of its elements, the data type they are stored as,
// and the length of each of its sixteen dimensions. dim 0 is the fastest running, so the element at
// the multi-dimensional `index` is at the linear offset
//
//     index[0] + index[1]*lengths[0] + index[2]*lengths[0]*lengths[1] + ...
//
// and CharonMPSNDArrayLinearIndex() is that sum. `bytes` is owned by the holder, which is a struct on
// the caller's stack frame, so every CharonMPSNDArrayTake() is paired with a
// CharonMPSNDArrayGive() - including on the refusing paths, which is why the two are separate calls
// and not a constructor.
typedef struct {
    void *bytes;
    MPSDataType dataType;
    size_t elementSize;
    NSUInteger dimensions;
    NSUInteger lengths[CHARON_MPS_NDARRAY_MAX_DIMENSIONS];
} CharonMPSNDArrayLayout;

// YES when the array can be read at all: a data type the eight element types name, a shape with a
// length in every dimension, and dimensions. A kernel handed the other answers NO from its encode and
// says which, rather than reading a buffer that was never filled.
//
// A dimension count above the sixteen MPSNDArraySizes.dimensions holds is refused rather than
// truncated: MPSCore/MPSNDArray.h:33-34 says "May not exceed 16" for the descriptor, so an array
// claiming more has already left the shape the header describes and a walk over the first sixteen
// would answer for a shape nobody asked for.
static inline BOOL CharonMPSNDArrayUsable(MPSNDArray *_Nullable array, NSString *what)
{
    if (!array) {
        CharonMPSRefuse(@"%@: no array", what);
        return NO;
    }
    if (!CharonMPSDataTypeIsElement(array.dataType)) {
        CharonMPSRefuse(@"%@: an array of data type %u is not one of the eight element types", what, (unsigned)array.dataType);
        return NO;
    }
    if (array.numberOfDimensions == 0 || array.numberOfDimensions > CHARON_MPS_NDARRAY_MAX_DIMENSIONS) {
        CharonMPSRefuse(@"%@: an array of %lu dimensions, and the header allows 1 to 16", what, (unsigned long)array.numberOfDimensions);
        return NO;
    }
    for (NSUInteger i = 0; i < array.numberOfDimensions; i++) {
        if ([array lengthOfDimension:i] == 0) {
            CharonMPSRefuse(@"%@: dimension %lu of the array is empty", what, (unsigned long)i);
            return NO;
        }
    }
    return YES;
}

// The bytes one row of the major row occupies: `elements` values of `elementSize` bytes, padded
// to a multiple of 16. The rounding is the header's own advice, from the class discussion of
// MPSCore/MPSNDArray.h, which wants each row kept on a 16-byte boundary, and it is why dimension 0's
// stride is this and not the element's own width: a row that starts mid-line is what the advice is about.
static inline size_t MPSNDArrayRoundedRowBytes(NSUInteger elements, size_t elementSize)
{
    size_t bytes = elements * elementSize;
    return (bytes + 15u) & ~(size_t)15u;
}

// The number of elements the shape holds, and the bytes they occupy at the data type's own width.
static inline NSUInteger CharonMPSNDArrayElementCount(const CharonMPSNDArrayLayout *layout)
{
    NSUInteger count = 1;
    for (NSUInteger i = 0; i < layout->dimensions && i < CHARON_MPS_NDARRAY_MAX_DIMENSIONS; i++)
        count *= layout->lengths[i];
    return count;
}

// Read `array` into a packed host buffer, filling `layout`. A nil stride array is what asks the
// release for the packed form (MPSCore/MPSNDArray.h:389-392), so this is that call and no other.
//
// The buffer is malloc'd rather than a C array because the shape is the caller's: sixteen dimensions
// of the caller's own lengths, whose product the header caps below 2**31. A length of zero is
// refused by CharonMPSNDArrayUsable before here, so the count is at least one and the call is
// non-empty.
static inline BOOL CharonMPSNDArrayTake(MPSNDArray *array, CharonMPSNDArrayLayout *layout, NSString *what)
{
    memset(layout, 0, sizeof(*layout));
    for (NSUInteger i = 0; i < CHARON_MPS_NDARRAY_MAX_DIMENSIONS; i++)
        layout->lengths[i] = 1;
    if (!CharonMPSNDArrayUsable(array, what))
        return NO;
    layout->dataType = array.dataType;
    layout->elementSize = MPSSizeofMPSDataType(array.dataType);
    layout->dimensions = array.numberOfDimensions;
    for (NSUInteger i = 0; i < layout->dimensions; i++)
        layout->lengths[i] = [array lengthOfDimension:i];
    NSUInteger count = CharonMPSNDArrayElementCount(layout);
    layout->bytes = malloc(count * layout->elementSize);
    if (!layout->bytes) {
        CharonMPSRefuse(@"%@: no memory for %lu elements of %lu bytes", what, (unsigned long)count, (unsigned long)layout->elementSize);
        return NO;
    }
    // The release's own accessor, with a nil stride array, which is the packed form it documents.
    [array readBytes:layout->bytes strideBytes:NULL];
    return YES;
}

// Give back what CharonMPSNDArrayTake() took. A layout that never got its buffer is left alone, so
// this is safe on the paths where the take refused.
static inline void CharonMPSNDArrayGive(CharonMPSNDArrayLayout *layout)
{
    free(layout->bytes);
    layout->bytes = NULL;
    layout->dimensions = 0;
}

// Write a packed host buffer back into `array`, and release the buffer: the write is the last thing
// the caller needs it for, so taking and giving straddle the whole operation.
static inline void CharonMPSNDArrayPut(MPSNDArray *array, CharonMPSNDArrayLayout *layout)
{
    [array writeBytes:layout->bytes strideBytes:NULL];
    CharonMPSNDArrayGive(layout);
}

// The linear offset of one position, from a multi-dimensional index whose dim 0 is the fastest
// running. A position at or past a dimension's own length is the caller's mistake and reads as
// given, which is why every kernel below bounds its own coordinates first.
static inline NSUInteger CharonMPSNDArrayLinearIndex(const CharonMPSNDArrayLayout *layout, const NSUInteger *index)
{
    NSUInteger linear = 0, stride = 1;
    for (NSUInteger i = 0; i < layout->dimensions && i < CHARON_MPS_NDARRAY_MAX_DIMENSIONS; i++) {
        linear += index[i] * stride;
        stride *= layout->lengths[i];
    }
    return linear;
}

// One element, read and written through the data type it is stored as. A double carries every value
// an 8, 16 or 32 bit element can hold exactly, so one representation serves the floating and the
// integer types alike, and the arithmetic around it reads the way the header writes it. These are
// the matrix family's own CharonMPSLoad/CharonMPSStore, which is why they are not re-implemented
// here - the two answer for the same data types in both families.
static inline double CharonMPSNDArrayLoad(const CharonMPSNDArrayLayout *layout, NSUInteger linear)
{
    return CharonMPSLoad(layout->bytes, layout->dataType, linear);
}

static inline void CharonMPSNDArrayStore(CharonMPSNDArrayLayout *layout, NSUInteger linear, double value)
{
    CharonMPSStore(layout->bytes, layout->dataType, linear, value);
}

// YES when two layouts hold the same number of elements in the same shape, which is the condition
// under which a binary kernel may walk one and write the other position by position. The dimension
// COUNT is compared as well as the lengths: MPSCore/MPSNDArray.h:33-34 allows a 1-dimension array of
// length 4 and a 4-dimension array of 1,1,1,4, and the header treats them as different shapes -
// -reshapeWithDimensionCount:dimensionSizes: exists to move between them - so a kernel that treated
// them as equal would answer for a reshape nobody asked for.
static inline BOOL CharonMPSNDArraySameShape(const CharonMPSNDArrayLayout *a, const CharonMPSNDArrayLayout *b)
{
    if (a->dimensions != b->dimensions)
        return NO;
    for (NSUInteger i = 0; i < a->dimensions && i < CHARON_MPS_NDARRAY_MAX_DIMENSIONS; i++)
        if (a->lengths[i] != b->lengths[i])
            return NO;
    return YES;
}

// Fill `index` with a position laid out in `layout`'s own shape, counting `linear` from 0 with dim 0
// the fastest running - the inverse of CharonMPSNDArrayLinearIndex, so a kernel walks one of these and
// both sides of its operation read through it.
static inline void CharonMPSNDArrayIndexOf(const CharonMPSNDArrayLayout *layout, NSUInteger linear, NSUInteger *index)
{
    for (NSUInteger i = 0; i < CHARON_MPS_NDARRAY_MAX_DIMENSIONS; i++)
        index[i] = 0;
    for (NSUInteger i = 0; i < layout->dimensions && i < CHARON_MPS_NDARRAY_MAX_DIMENSIONS; i++) {
        index[i] = linear % layout->lengths[i];
        linear /= layout->lengths[i];
    }
}

// The four-index form a 4-D matrix multiplication addresses with: a (row, column) pair inside a
// matrix, and the matrix's two batch coordinates. A dimension of 1 is a BROADCAST: the header defines it
// as the one element's data being reused for whatever index the other input has in that dimension
// (MPSNDArrayMatrixMultiplication.h:36-37), so a coordinate past that dimension's own length is its zero,
// and no loop is run at all.
static inline void CharonMPSBatchIndex(const CharonMPSNDArrayLayout *layout, NSUInteger batch,
                                       NSUInteger matrices, NSUInteger first, NSUInteger second,
                                       NSUInteger *index)
{
    for (NSUInteger i = 0; i < CHARON_MPS_NDARRAY_MAX_DIMENSIONS; i++)
        index[i] = 0;
    index[0] = first;
    if (layout->dimensions > 1)
        index[1] = second;
    if (layout->dimensions > 2)
        index[2] = (batch < layout->lengths[2]) ? batch : 0;
    if (layout->dimensions > 3)
        index[3] = (matrices < layout->lengths[3]) ? matrices : 0;
}

// A coordinate brought inside a dimension by the zero edge rule, which MPSNDArrayKernel.h:44 gives as
// the default: "Default: MPSImageEdgeModeZero". A kernel that honours another edge mode clamps or
// mirrors through this function's caller instead, and says which in its own row.
static inline NSUInteger CharonMPSNDArrayZeroEdge(NSInteger position, NSUInteger length)
{
    if (position < 0)
        return 0;
    if ((NSUInteger)position >= length)
        return 0;
    return (NSUInteger)position;
}

// A kernel that names an axis of its own, which is how a gradient pass learns which one: the release
// declares `axis` on MPSNDArrayGather (MPSNDArrayGather.h:44-48) and its RFC comment says the gradient
// takes such a value from the gradient state "automatically" (MPSNDArrayKernel.h:318-321), so the state
// asks through this rather than the two classes being named in each other's file.
@protocol CharonMPSNDArrayAxisKernel <NSObject>
- (NSUInteger)axis;
@end

// One source's filter, which is the five values MPSNDArrayMultiaryBase declares a getter for.
typedef struct {
    NSInteger offsets[CHARON_MPS_NDARRAY_MAX_DIMENSIONS];
    NSUInteger kernelSizes[CHARON_MPS_NDARRAY_MAX_DIMENSIONS];
    NSInteger strides[CHARON_MPS_NDARRAY_MAX_DIMENSIONS];
    NSUInteger dilationRates[CHARON_MPS_NDARRAY_MAX_DIMENSIONS];
    MPSImageEdgeMode edgeMode;
} CharonMPSNDArrayFilter;

// The defaults the header gives, applied once. offsets 0, kernelSizes 1, strides 1, dilationRates 1
// (MPSNDArrayKernel.h:227-266 for the unary spelling, :389-470 for the binary one), and the edge mode
// MPSImageEdgeModeZero, which is MPSCoreTypes.h's case 0 and what the kernel's own comment names.
static inline CharonMPSNDArrayFilter CharonMPSNDArrayDefaultFilter(void)
{
    CharonMPSNDArrayFilter filter;
    for (NSUInteger i = 0; i < CHARON_MPS_NDARRAY_MAX_DIMENSIONS; i++) {
        filter.offsets[i] = 0;
        filter.kernelSizes[i] = 1;
        filter.strides[i] = 1;
        filter.dilationRates[i] = 1;
    }
    filter.edgeMode = MPSImageEdgeModeZero;
    return filter;
}


// The filter of one source and the shapes a gradient state recorded, which the subclass of this file
// reads. These are methods on classes the port DEFINES, so they are its own machinery and carry no
// registry row: added_members() in modules/apple/backports.lua:1398 counts a member only when its
// class is neither one the release carries nor one this object exports, and MPSCNNKernel's
// charon_mps_setWindowWidth: is the same case already in the tree with cnn.json carrying no row for it.
@interface MPSNDArrayMultiaryBase (CharonMPSNDArrayKernel)
- (CharonMPSNDArrayFilter)charon_mps_filterAtSourceIndex:(NSUInteger)sourceIndex;
- (void)charon_mps_setFilter:(CharonMPSNDArrayFilter)filter atSourceIndex:(NSUInteger)sourceIndex;
- (NSUInteger)charon_mps_sourceCount;
- (NSUInteger)charon_mps_sourceGradientIndex;
@end

@interface MPSNDArrayMultiaryKernel (CharonMPSNDArrayKernel)
- (BOOL)charon_mps_run:(NSArray<MPSNDArray *> *)sources destination:(MPSNDArray *)destination;
- (void)charon_mps_fillFromSources:(CharonMPSNDArrayLayout *)sources count:(NSUInteger)count into:(CharonMPSNDArrayLayout *)destination;
@end

@interface MPSNDArrayGradientState (CharonMPSNDArrayKernel)
- (void)charon_mps_recordFor:(MPSNDArrayMultiaryBase *)kernel sources:(NSArray<MPSNDArray *> *)sources;
- (CharonMPSNDArrayFilter)charon_mps_filterOfSource:(NSUInteger)index;
- (NSUInteger)charon_mps_dimensionsOfSource:(NSUInteger)index;
- (NSUInteger)charon_mps_lengthOfSource:(NSUInteger)index dimension:(NSUInteger)dimension;
@end

// The edge rule of one source, applied to a coordinate. The five modes are MPSCoreTypes.h's, and this
// is the only place in the file that reads one - so a kernel that honours a mode the release defines
// does so through here and a row that claims which modes it honours is claiming this function.
static inline NSInteger CharonMPSNDArrayApplyEdgeMode(NSInteger position, NSUInteger length, MPSImageEdgeMode mode)
{
    if (length == 0)
        return 0;
    switch (mode) {
    case MPSImageEdgeModeZero:
        return (position < 0 || (NSUInteger)position >= length) ? 0 : position;
    case MPSImageEdgeModeClamp:
        return CharonMPSNDArrayZeroEdge(position, length) == (NSUInteger)position ? position
             : (position < 0 ? 0 : (NSInteger)(length - 1));
    case MPSImageEdgeModeMirror: {
        // The mirror that reflects about the edge sample: -1 is 1, length is length-2. A period of
        // 2*(length-1) makes every position land inside by one subtraction, and length 1 has no
        // interior to mirror about, so it is its own answer - which is the whole of a one-element
        // axis under every mode here.
        if (length == 1)
            return 0;
        NSInteger span = 2 * (NSInteger)(length - 1);
        NSInteger at = position % span;
        if (at < 0)
            at += span;
        return at < (NSInteger)length ? at : span - at;
    }
    case MPSImageEdgeModeMirrorWithEdge: {
        // The mirror that repeats the edge sample: -1 is 0, length is length-1. The period is 2*length
        // and the second half folds back, so one subtraction and one comparison answer it.
        NSInteger span = 2 * (NSInteger)length;
        NSInteger at = position % span;
        if (at < 0)
            at += span;
        return at < (NSInteger)length ? at : span - at - 1;
    }
    case MPSImageEdgeModeConstant:
    default:
        // "the edge pixels are set to the constant value provided" - and the value the release uses
        // when none is provided is zero, which is the only constant a source of numbers carries.
        return (position < 0 || (NSUInteger)position >= length) ? 0 : position;
    }
}

NS_ASSUME_NONNULL_END
