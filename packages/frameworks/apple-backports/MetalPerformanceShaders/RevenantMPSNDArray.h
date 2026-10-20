#import "RevenantMPS.h"

NS_ASSUME_NONNULL_BEGIN

#define REVENANT_MPS_NDARRAY_MAX_DIMENSIONS 16

typedef struct {
    void *bytes;
    MPSDataType dataType;
    size_t elementSize;
    NSUInteger dimensions;
    NSUInteger lengths[REVENANT_MPS_NDARRAY_MAX_DIMENSIONS];
} RevenantMPSNDArrayLayout;

static inline BOOL RevenantMPSNDArrayUsable(MPSNDArray *_Nullable array, NSString *what)
{
    if (!array) {
        RevenantMPSRefuse(@"%@: no array", what);
        return NO;
    }
    if (!RevenantMPSDataTypeIsElement(array.dataType)) {
        RevenantMPSRefuse(@"%@: an array of data type %u is not one of the eight element types", what, (unsigned)array.dataType);
        return NO;
    }
    if (array.numberOfDimensions == 0 || array.numberOfDimensions > REVENANT_MPS_NDARRAY_MAX_DIMENSIONS) {
        RevenantMPSRefuse(@"%@: an array of %lu dimensions, and the header allows 1 to 16", what, (unsigned long)array.numberOfDimensions);
        return NO;
    }
    for (NSUInteger i = 0; i < array.numberOfDimensions; i++) {
        if ([array lengthOfDimension:i] == 0) {
            RevenantMPSRefuse(@"%@: dimension %lu of the array is empty", what, (unsigned long)i);
            return NO;
        }
    }
    return YES;
}

static inline size_t MPSNDArrayRoundedRowBytes(NSUInteger elements, size_t elementSize)
{
    size_t bytes = elements * elementSize;
    return (bytes + 15u) & ~(size_t)15u;
}

static inline NSUInteger RevenantMPSNDArrayElementCount(const RevenantMPSNDArrayLayout *layout)
{
    NSUInteger count = 1;
    for (NSUInteger i = 0; i < layout->dimensions && i < REVENANT_MPS_NDARRAY_MAX_DIMENSIONS; i++)
        count *= layout->lengths[i];
    return count;
}

static inline BOOL RevenantMPSNDArrayTake(MPSNDArray *array, RevenantMPSNDArrayLayout *layout, NSString *what)
{
    memset(layout, 0, sizeof(*layout));
    for (NSUInteger i = 0; i < REVENANT_MPS_NDARRAY_MAX_DIMENSIONS; i++)
        layout->lengths[i] = 1;
    if (!RevenantMPSNDArrayUsable(array, what))
        return NO;
    layout->dataType = array.dataType;
    layout->elementSize = MPSSizeofMPSDataType(array.dataType);
    layout->dimensions = array.numberOfDimensions;
    for (NSUInteger i = 0; i < layout->dimensions; i++)
        layout->lengths[i] = [array lengthOfDimension:i];
    NSUInteger count = RevenantMPSNDArrayElementCount(layout);
    layout->bytes = malloc(count * layout->elementSize);
    if (!layout->bytes) {
        RevenantMPSRefuse(@"%@: no memory for %lu elements of %lu bytes", what, (unsigned long)count, (unsigned long)layout->elementSize);
        return NO;
    }
    [array readBytes:layout->bytes strideBytes:NULL];
    return YES;
}

static inline void RevenantMPSNDArrayGive(RevenantMPSNDArrayLayout *layout)
{
    free(layout->bytes);
    layout->bytes = NULL;
    layout->dimensions = 0;
}

static inline void RevenantMPSNDArrayPut(MPSNDArray *array, RevenantMPSNDArrayLayout *layout)
{
    [array writeBytes:layout->bytes strideBytes:NULL];
    RevenantMPSNDArrayGive(layout);
}

static inline NSUInteger RevenantMPSNDArrayLinearIndex(const RevenantMPSNDArrayLayout *layout, const NSUInteger *index)
{
    NSUInteger linear = 0, stride = 1;
    for (NSUInteger i = 0; i < layout->dimensions && i < REVENANT_MPS_NDARRAY_MAX_DIMENSIONS; i++) {
        linear += index[i] * stride;
        stride *= layout->lengths[i];
    }
    return linear;
}

static inline double RevenantMPSNDArrayLoad(const RevenantMPSNDArrayLayout *layout, NSUInteger linear)
{
    return RevenantMPSLoad(layout->bytes, layout->dataType, linear);
}

static inline void RevenantMPSNDArrayStore(RevenantMPSNDArrayLayout *layout, NSUInteger linear, double value)
{
    RevenantMPSStore(layout->bytes, layout->dataType, linear, value);
}

static inline BOOL RevenantMPSNDArraySameShape(const RevenantMPSNDArrayLayout *a, const RevenantMPSNDArrayLayout *b)
{
    if (a->dimensions != b->dimensions)
        return NO;
    for (NSUInteger i = 0; i < a->dimensions && i < REVENANT_MPS_NDARRAY_MAX_DIMENSIONS; i++)
        if (a->lengths[i] != b->lengths[i])
            return NO;
    return YES;
}

static inline void RevenantMPSNDArrayIndexOf(const RevenantMPSNDArrayLayout *layout, NSUInteger linear, NSUInteger *index)
{
    for (NSUInteger i = 0; i < REVENANT_MPS_NDARRAY_MAX_DIMENSIONS; i++)
        index[i] = 0;
    for (NSUInteger i = 0; i < layout->dimensions && i < REVENANT_MPS_NDARRAY_MAX_DIMENSIONS; i++) {
        index[i] = linear % layout->lengths[i];
        linear /= layout->lengths[i];
    }
}

static inline void RevenantMPSBatchIndex(const RevenantMPSNDArrayLayout *layout, NSUInteger batch,
                                       NSUInteger matrices, NSUInteger first, NSUInteger second,
                                       NSUInteger *index)
{
    for (NSUInteger i = 0; i < REVENANT_MPS_NDARRAY_MAX_DIMENSIONS; i++)
        index[i] = 0;
    index[0] = first;
    if (layout->dimensions > 1)
        index[1] = second;
    if (layout->dimensions > 2)
        index[2] = (batch < layout->lengths[2]) ? batch : 0;
    if (layout->dimensions > 3)
        index[3] = (matrices < layout->lengths[3]) ? matrices : 0;
}

static inline NSUInteger RevenantMPSNDArrayZeroEdge(NSInteger position, NSUInteger length)
{
    if (position < 0)
        return 0;
    if ((NSUInteger)position >= length)
        return 0;
    return (NSUInteger)position;
}

@protocol RevenantMPSNDArrayAxisKernel <NSObject>
- (NSUInteger)axis;
@end

typedef struct {
    NSInteger offsets[REVENANT_MPS_NDARRAY_MAX_DIMENSIONS];
    NSUInteger kernelSizes[REVENANT_MPS_NDARRAY_MAX_DIMENSIONS];
    NSInteger strides[REVENANT_MPS_NDARRAY_MAX_DIMENSIONS];
    NSUInteger dilationRates[REVENANT_MPS_NDARRAY_MAX_DIMENSIONS];
    MPSImageEdgeMode edgeMode;
} RevenantMPSNDArrayFilter;

static inline RevenantMPSNDArrayFilter RevenantMPSNDArrayDefaultFilter(void)
{
    RevenantMPSNDArrayFilter filter;
    for (NSUInteger i = 0; i < REVENANT_MPS_NDARRAY_MAX_DIMENSIONS; i++) {
        filter.offsets[i] = 0;
        filter.kernelSizes[i] = 1;
        filter.strides[i] = 1;
        filter.dilationRates[i] = 1;
    }
    filter.edgeMode = MPSImageEdgeModeZero;
    return filter;
}


@interface MPSNDArrayMultiaryBase (RevenantMPSNDArrayKernel)
- (RevenantMPSNDArrayFilter)revenant_mps_filterAtSourceIndex:(NSUInteger)sourceIndex;
- (void)revenant_mps_setFilter:(RevenantMPSNDArrayFilter)filter atSourceIndex:(NSUInteger)sourceIndex;
- (NSUInteger)revenant_mps_sourceCount;
- (NSUInteger)revenant_mps_sourceGradientIndex;
@end

@interface MPSNDArrayMultiaryKernel (RevenantMPSNDArrayKernel)
- (BOOL)revenant_mps_run:(NSArray<MPSNDArray *> *)sources destination:(MPSNDArray *)destination;
- (void)revenant_mps_fillFromSources:(RevenantMPSNDArrayLayout *)sources count:(NSUInteger)count into:(RevenantMPSNDArrayLayout *)destination;
@end

@interface MPSNDArrayGradientState (RevenantMPSNDArrayKernel)
- (void)revenant_mps_recordFor:(MPSNDArrayMultiaryBase *)kernel sources:(NSArray<MPSNDArray *> *)sources;
- (RevenantMPSNDArrayFilter)revenant_mps_filterOfSource:(NSUInteger)index;
- (NSUInteger)revenant_mps_dimensionsOfSource:(NSUInteger)index;
- (NSUInteger)revenant_mps_lengthOfSource:(NSUInteger)index dimension:(NSUInteger)dimension;
@end

static inline NSInteger RevenantMPSNDArrayApplyEdgeMode(NSInteger position, NSUInteger length, MPSImageEdgeMode mode)
{
    if (length == 0)
        return 0;
    switch (mode) {
    case MPSImageEdgeModeZero:
        return (position < 0 || (NSUInteger)position >= length) ? 0 : position;
    case MPSImageEdgeModeClamp:
        return RevenantMPSNDArrayZeroEdge(position, length) == (NSUInteger)position ? position
             : (position < 0 ? 0 : (NSInteger)(length - 1));
    case MPSImageEdgeModeMirror: {
        if (length == 1)
            return 0;
        NSInteger span = 2 * (NSInteger)(length - 1);
        NSInteger at = position % span;
        if (at < 0)
            at += span;
        return at < (NSInteger)length ? at : span - at;
    }
    case MPSImageEdgeModeMirrorWithEdge: {
        NSInteger span = 2 * (NSInteger)length;
        NSInteger at = position % span;
        if (at < 0)
            at += span;
        return at < (NSInteger)length ? at : span - at - 1;
    }
    case MPSImageEdgeModeConstant:
    default:
        return (position < 0 || (NSUInteger)position >= length) ? 0 : position;
    }
}

NS_ASSUME_NONNULL_END
