// The three NDArray kernels of iOS 13 that declare arithmetic: MPSNDArrayGather and its gradient,
// MPSNDArrayStridedSlice and its gradient, and MPSNDArrayMatrixMultiplication. From
// MPSNDArray/MPSNDArrayGather.h, MPSNDArray/MPSNDArrayStridedSlice.h and
// MPSNDArray/MPSNDArrayMatrixMultiplication.h in the SDK of iOS 16.4.
//
// These are the three classes of the family whose bodies are specified well enough to write from the
// header, and each one's loop below is the header's own wording rather than a paraphrase of it:
//
//   MPSNDArrayGather (MPSNDArrayGather.h:39-46): off the gather axis, result[i] is source[i] over the slice's length;
//       along the axis, result[i] is the source at indices[i], for each index in turn. So the result has the source's
//       shape on every axis but the gather's, and on the gather's axis it has one element for each
//       there are indices - which is the one place the result is NOT the source's shape, and an
//       implementation that kept the source's length there would answer a different question.
//
//   MPSNDArrayStridedSlice (MPSNDArrayStridedSlice.h:20-21): the slice keeps a selected subset of the source array,
//       taking every s-th element along each dimension. A stride of s in a dimension of length n therefore holds
//       ceil(n/s) elements taken at 0, s, 2s, ... - the count is a CEILING, not a division, which is
//       what makes a dimension of 5 with a stride of 2 hold three and not two.
//
//   MPSNDArrayMatrixMultiplication (MPSNDArrayMatrixMultiplication.h:33-37): the result is alpha times A times B
//       plus beta times C, with each of A, B, C and D held in the two major dimensions of the array. Where an input's
//       third or fourth dimension is 1, its data is broadcast to the corresponding axis of the other input (:36-37).
//       So a 4-D array is a BATCH of 2-D matrices, dimension 2 and 3 being the batch
//       and the matrices' two most major dimensions, and a 1 there broadcasts.
//
// The two gradients are the reverse of their forward passes and are the reason the state exists: a
// gather's gradient SCATTER-ACCUMULATES the incoming gradient into the rows the forward pass read, and
// a strided slice's scatter-accumulates it into the positions it read. A scatter-accumulate and not a
// scatter, because two indices of a gather may name the same row and the gradient of that row is the
// SUM of the two - which is what makes a gather with repeated indices answer something at all.
//
// Every one of these encodes into a command buffer, so -CharonMPSCommandBufferPermits is the gate
// MPSNDArray13.m's own comment describes: the port's kernels are synchronous and the result is in the
// destination when the encode RETURNS, which is at least as strong as the release's own contract.

#import "CharonMPSNDArray.h"


// The state's recorded axis, a method on a class the port DEFINES and therefore its own machinery
// rather than a seam needing a registry row: added_members() in modules/apple/backports.lua:1398 counts
// a member only when its class is neither one the release carries nor one the object exports.
@interface MPSNDArrayGradientState (CharonMPSNDArrayOps)
- (NSUInteger)charon_mps_axis;
- (CharonMPSNDArrayFilter)charon_mps_filterOfSource:(NSUInteger)index;
@end

@implementation MPSNDArrayGather {
    NSUInteger _axis;
}

- (instancetype)initWithDevice:(id<MTLDevice>)device
{
    if ((self = [super initWithDevice:device])) {
        // the header's axis property is the dimension the gather runs along, and it defaults to zero
        // (MPSNDArrayGather.h:44-48).
        _axis = 0;
    }
    return self;
}

- (NSUInteger)axis { return _axis; }

- (void)setAxis:(NSUInteger)axis { _axis = axis; }

// The gather's OWN result shape, which the base class's answer cannot be: the base builds it from the
// LAST source (MPSNDArrayKernel13.m), and a gather's second source is the 1-D INDEX array, which the
// header describes as a one-dimensional array of indices (MPSNDArrayGather.h:33-35), so the
// base's descriptor would be a one-dimensional array of the index count. The result is the PRIMARY
// source's shape with the axis replaced by that count: every other dimension copies the source, and along the axis
// each entry is taken from the source at the index given (:39-46). And the header
// asks for exactly this when it says the object's own properties must be configured before
// -destinationArrayDescriptorForSourceArrays: is called, since they may affect the results
// (MPSNDArrayKernel.h:152-155). The axis is such a property.
//
// This was a defect the harness found rather than a reading of the header: with the base's descriptor
// a [3,2] source gathered on axis 0 came back as 3x1, and the reference for that case is 3x2.
- (MPSNDArrayDescriptor *)destinationArrayDescriptorForSourceArrays:(NSArray<MPSNDArray *> *)sources
                                                         sourceState:(MPSState *)state
{
    (void)state;
    if ([sources count] < 2)
        return nil;
    MPSNDArray *source = [sources objectAtIndex:0], *indices = [sources objectAtIndex:1];
    if (!source || !indices || _axis >= source.numberOfDimensions)
        return nil;
    NSUInteger sizes[CHARON_MPS_NDARRAY_MAX_DIMENSIONS];
    for (NSUInteger d = 0; d < source.numberOfDimensions; d++)
        sizes[d] = (d == _axis) ? [indices lengthOfDimension:0] : [source lengthOfDimension:d];
    return [MPSNDArrayDescriptor descriptorWithDataType:source.dataType
                                         dimensionCount:source.numberOfDimensions
                                         dimensionSizes:sizes];
}

// The gather, in the header's own two sentences: the source's own shape on every dimension but the
// axis, and the number of indices on the axis. A source of [a,b,c] gathered on axis 1 with k indices
// is [a,k,c] - and the indices array is the SECONDARY source, "a 1-D MPSNDArray containing the
// indices" (MPSNDArrayGather.h:33-35).
- (void)charon_mps_fillFromSources:(CharonMPSNDArrayLayout *)sources count:(NSUInteger)count state:(MPSState *)state into:(CharonMPSNDArrayLayout *)destination
{
    if (count < 2) {
        CharonMPSRefuse(@"MPSNDArrayGather: a gather takes a source and an index array, and %lu were given", (unsigned long)count);
        return;
    }
    const CharonMPSNDArrayLayout *source = &sources[0], *indices = &sources[1];
    NSUInteger axis = _axis;
    if (axis >= source->dimensions) {
        CharonMPSRefuse(@"MPSNDArrayGather: axis %lu is past the source's %lu dimensions", (unsigned long)axis, (unsigned long)source->dimensions);
        return;
    }
    NSUInteger gathered = CharonMPSNDArrayElementCount(indices);
    // The result's shape: the source's, with the gathered axis replaced by the index count. The
    // element count is recomputed rather than taken from the destination, because a caller that handed
    // in a destination of another shape is asking for a different array and refusing is the honest
    // answer - the release's own encode writes into a destination the caller sized.
    NSUInteger produced = 1;
    for (NSUInteger d = 0; d < source->dimensions; d++)
        produced *= (d == axis) ? gathered : source->lengths[d];
    if (produced != CharonMPSNDArrayElementCount(destination)) {
        CharonMPSRefuse(@"MPSNDArrayGather: a gather on axis %lu of a %lux%lux%lu source holds %lu elements, "
                        @"and the destination holds %lu", (unsigned long)axis,
                        (unsigned long)source->lengths[0], (unsigned long)(source->dimensions > 1 ? source->lengths[1] : 1),
                        (unsigned long)(source->dimensions > 2 ? source->lengths[2] : 1),
                        (unsigned long)produced, (unsigned long)CharonMPSNDArrayElementCount(destination));
        return;
    }
    CharonMPSNDArrayFilter filter = [self charon_mps_filterAtSourceIndex:0];
    NSUInteger sourceIndex[CHARON_MPS_NDARRAY_MAX_DIMENSIONS];
    for (NSUInteger d = 0; d < CHARON_MPS_NDARRAY_MAX_DIMENSIONS; d++)
        sourceIndex[d] = 0;
    for (NSUInteger linear = 0; linear < CharonMPSNDArrayElementCount(destination); linear++) {
        CharonMPSNDArrayIndexOf(destination, linear, sourceIndex);
        // The INDEX, not the coordinate: the header's rule is "result[i] = source[indices[i]]"
        // (MPSNDArrayGather.h:43), so the row of the source that result position i reads is the value
        // of the index array at i, and the destination's own coordinate on the axis is only what says
        // WHICH index. Reading the source at the coordinate instead - which is what this did first -
        // answers the identity, and the harness caught it: a [3,2] gathered on axis 0 by [2,0,2] came
        // back as 1 2 3 4 5 6 where the reference is 5 6 1 2 5 6.
        NSUInteger at = (NSUInteger)CharonMPSNDArrayLoad(indices, sourceIndex[axis]);
        // The offset is where, in this source array, the value at the origin gets its input (MPSNDArrayKernel.h:31-35), and
        // the edge rule is that filter's own - the zero rule by default, which is what the header gives
        // (:227-236) and what CharonMPSNDArrayApplyEdgeMode reads.
        NSInteger sourceAt = (NSInteger)at + filter.offsets[axis];
        if (sourceAt < 0 || (NSUInteger)sourceAt >= source->lengths[axis]) {
            sourceAt = CharonMPSNDArrayApplyEdgeMode(sourceAt, source->lengths[axis], filter.edgeMode);
        }
        if ((NSUInteger)sourceAt >= source->lengths[axis]) {
            CharonMPSRefuse(@"MPSNDArrayGather: index %lu of the index array is %ld, outside the source's %lu elements on axis %lu",
                            (unsigned long)at, (long)sourceAt, (unsigned long)source->lengths[axis], (unsigned long)axis);
            return;
        }
        NSUInteger read[CHARON_MPS_NDARRAY_MAX_DIMENSIONS];
        for (NSUInteger d = 0; d < CHARON_MPS_NDARRAY_MAX_DIMENSIONS; d++)
            read[d] = sourceIndex[d];
        read[axis] = (NSUInteger)sourceAt;
        CharonMPSNDArrayStore(destination, linear, CharonMPSNDArrayLoad(source, CharonMPSNDArrayLinearIndex(source, read)));
        for (NSUInteger d = 0; d < destination->dimensions; d++) {
            if (++sourceIndex[d] < destination->lengths[d])
                break;
            sourceIndex[d] = 0;
        }
    }
}

@end

@implementation MPSNDArrayGatherGradientState
@end

@implementation MPSNDArrayGatherGradient

- (void)charon_mps_fillFromSources:(CharonMPSNDArrayLayout *)sources count:(NSUInteger)count state:(MPSState *)state into:(CharonMPSNDArrayLayout *)destination
{
    // The sources of a gradient pass are the forward pass's sources with the incoming gradient
    // appended, which is how -encodeToCommandBuffer:sourceArrays:sourceGradient:gradientState:
    // hands them over. So [0] is the gathered source, [1] the index array and [2] the gradient.
    if (count < 3) {
        CharonMPSRefuse(@"MPSNDArrayGatherGradient: a gather gradient takes a source, an index array and a gradient, and %lu were given",
                        (unsigned long)count);
        return;
    }
    const CharonMPSNDArrayLayout *source = &sources[0], *indices = &sources[1], *gradient = &sources[2];
    // The axis, from the STATE the forward pass recorded, which is where the header puts it: the RFC
    // comment above MPSNDArrayUnaryGradientKernel's declarations says the gradient cannot be given this by hand, and the
    // gradient state fills it in, which the header does not count as a problem (MPSNDArrayKernel.h:318-321), and
    // MPSNDArrayGatherGradient declares no axis of its own to carry it.
    //
    // It cannot be recovered from the two shapes, and this tried that first and the harness caught it:
    // a gather on axis 0 of a [3,2] source by THREE indices has a result of the same [3,2] shape as its
    // source, so the shapes differ in no dimension at all and a shape-difference derivation refuses
    // the one case where the index count happens to equal the axis length. The axis is a property of
    // the forward kernel and of nothing in the data.
    if (![state isKindOfClass:[MPSNDArrayGradientState class]]) {
        (void)state;
        CharonMPSRefuse(@"MPSNDArrayGatherGradient: a gather gradient needs the state its forward pass recorded, which is what "
                        @"-resultStateForSourceArrays:sourceStates:destinationArray: makes, and none was given");
        return;
    }
    MPSNDArrayGradientState *recorded = (MPSNDArrayGradientState *)state;
    CharonMPSNDArrayFilter filter = [recorded charon_mps_filterOfSource:0];
    NSUInteger axis = [recorded charon_mps_axis];
    if (axis >= source->dimensions) {
        CharonMPSRefuse(@"MPSNDArrayGatherGradient: the state records axis %lu, which is past the source's %lu dimensions",
                        (unsigned long)axis, (unsigned long)source->dimensions);
        return;
    }
    // A SCATTER-ACCUMULATE over the DESTINATION'S OWN positions, which is what a gather's gradient is
    // and the only formulation that is right when the index count and the axis length differ.
    //
    // The forward pass read source[indices[r], ...] into result[r, ...] for every r, so the incoming
    // gradient at result position (r, rest) belongs at SOURCE position (indices[r], rest). The walk is
    // therefore over the destination's positions, and the index array only REMAPS the axis
    // coordinate - it does not enumerate the gradient's elements.
    //
    // The first version walked the INDEX array and took one gradient element per index, which is
    // right only when the gradient has exactly as many elements as there are indices. For the
    // measured case - a [3,2] source gathered on axis 0 by three indices, so a [3,2] gradient of six
    // elements - it wrote 0 0 60 0 0 0 where the answer is 20 0 40 50 0 100.
    for (NSUInteger linear = 0; linear < CharonMPSNDArrayElementCount(destination); linear++)
        CharonMPSNDArrayStore(destination, linear, 0.0);
    NSUInteger position[CHARON_MPS_NDARRAY_MAX_DIMENSIONS], read[CHARON_MPS_NDARRAY_MAX_DIMENSIONS];
    for (NSUInteger d = 0; d < CHARON_MPS_NDARRAY_MAX_DIMENSIONS; d++) {
        position[d] = 0;
        read[d] = 0;
    }
    if (CharonMPSNDArrayElementCount(gradient) != CharonMPSNDArrayElementCount(destination)) {
        CharonMPSRefuse(@"MPSNDArrayGatherGradient: the gradient holds %lu elements and the destination %lu; a gather gradient "
                        @"scatters the result's shape back onto the source's",
                        (unsigned long)CharonMPSNDArrayElementCount(gradient),
                        (unsigned long)CharonMPSNDArrayElementCount(destination));
        return;
    }
    for (NSUInteger linear = 0; linear < CharonMPSNDArrayElementCount(destination); linear++) {
        CharonMPSNDArrayIndexOf(destination, linear, position);
        NSUInteger indexOfAxis[CHARON_MPS_NDARRAY_MAX_DIMENSIONS];
        for (NSUInteger d = 0; d < CHARON_MPS_NDARRAY_MAX_DIMENSIONS; d++)
            indexOfAxis[d] = 0;
        NSUInteger at = (NSUInteger)CharonMPSNDArrayLoad(indices, position[axis]);
        NSInteger offset = (NSInteger)at + filter.offsets[axis];
        at = offset < 0 ? 0 : (NSUInteger)offset;
        if (at >= source->lengths[axis]) {
            CharonMPSRefuse(@"MPSNDArrayGatherGradient: position %lu of the result names index %lu, outside the source's %lu "
                            @"elements on axis %lu", (unsigned long)linear, (unsigned long)at,
                            (unsigned long)source->lengths[axis], (unsigned long)axis);
            return;
        }
        for (NSUInteger d = 0; d < CHARON_MPS_NDARRAY_MAX_DIMENSIONS; d++)
            read[d] = position[d];
        read[axis] = at;
        NSUInteger atLinear = CharonMPSNDArrayLinearIndex(source, read);
        if (atLinear >= CharonMPSNDArrayElementCount(destination)) {
            CharonMPSRefuse(@"MPSNDArrayGatherGradient: position %lu names element %lu of a destination that holds %lu",
                            (unsigned long)linear, (unsigned long)atLinear,
                            (unsigned long)CharonMPSNDArrayElementCount(destination));
            return;
        }
        double carried = CharonMPSNDArrayLoad(destination, atLinear) + CharonMPSNDArrayLoad(gradient, linear);
        CharonMPSNDArrayStore(destination, atLinear, carried);
    }
}

@end

@implementation MPSNDArrayStridedSlice {
    MPSNDArrayOffsets _strides;
}

- (instancetype)initWithDevice:(id<MTLDevice>)device
{
    if ((self = [super initWithDevice:device])) {
        // "The strides to use when slicing the input array" (MPSNDArrayStridedSlice.h:24-28). The
        // default is 1 in every dimension, which is the header's own default for a filter's strides
        // (MPSNDArrayKernel.h:250-257) and is the only value that makes the slice the whole array.
        for (NSUInteger i = 0; i < CHARON_MPS_NDARRAY_MAX_DIMENSIONS; i++)
            _strides.dimensions[i] = 1;
    }
    return self;
}

- (MPSNDArrayOffsets)strides { return _strides; }

- (void)setStrides:(MPSNDArrayOffsets)strides
{
    _strides = strides;
    // The property IS the filter's stride, and the two have to agree: the destination descriptor is
    // built from the filter and the loop walks the same numbers, so a stride set here and not there
    // would size the result one way and fill it another. This is the same trap
    // MPSCNNBatchNormalization12.m records for epsilon - a value the caller sets that changes nothing
    // because the object read it at initialisation.
    CharonMPSNDArrayFilter filter = [self charon_mps_filterAtSourceIndex:0];
    for (NSUInteger i = 0; i < CHARON_MPS_NDARRAY_MAX_DIMENSIONS; i++)
        filter.strides[i] = strides.dimensions[i];
    [self charon_mps_setFilter:filter atSourceIndex:0];
}

// The strided slice keeps every s-th element of a dimension (MPSNDArrayStridedSlice.h:20-21), so a stride of s in a
// dimension of length n holds the elements at 0, s, 2s, ... and there are ceil(n/s) of them. The
// count is a CEILING and not a division: a dimension of 5 with a stride of 2 holds three (0, 2, 4) and
// a division would say two and drop the last element of every odd dimension.
- (void)charon_mps_fillFromSources:(CharonMPSNDArrayLayout *)sources count:(NSUInteger)count state:(MPSState *)state into:(CharonMPSNDArrayLayout *)destination
{
    (void)count;
    (void)state;
    const CharonMPSNDArrayLayout *source = &sources[0];
    CharonMPSNDArrayFilter filter = [self charon_mps_filterAtSourceIndex:0];
    for (NSUInteger d = 0; d < destination->dimensions && d < source->dimensions; d++) {
        NSInteger stride = filter.strides[d];
        if (stride == 0)
            stride = 1;
        NSUInteger held = (NSUInteger)((source->lengths[d] + (NSUInteger)(stride < 0 ? -stride : stride) - 1) /
                                       (NSUInteger)(stride < 0 ? -stride : stride));
        if (destination->lengths[d] != held) {
            CharonMPSRefuse(@"MPSNDArrayStridedSlice: a stride of %ld over dimension %lu of %lu holds %lu elements, "
                            @"and the destination holds %lu", (long)stride, (unsigned long)d,
                            (unsigned long)source->lengths[d], (unsigned long)held, (unsigned long)destination->lengths[d]);
            return;
        }
    }
    NSUInteger position[CHARON_MPS_NDARRAY_MAX_DIMENSIONS];
    for (NSUInteger d = 0; d < CHARON_MPS_NDARRAY_MAX_DIMENSIONS; d++)
        position[d] = 0;
    NSUInteger read[CHARON_MPS_NDARRAY_MAX_DIMENSIONS];
    for (NSUInteger d = 0; d < CHARON_MPS_NDARRAY_MAX_DIMENSIONS; d++)
        read[d] = 0;
    for (NSUInteger linear = 0; linear < CharonMPSNDArrayElementCount(destination); linear++) {
        for (NSUInteger d = 0; d < destination->dimensions && d < source->dimensions; d++) {
            NSInteger stride = filter.strides[d] ? filter.strides[d] : 1;
            read[d] = (NSUInteger)(stride > 0 ? (NSInteger)position[d] * stride
                                              : (NSInteger)(source->lengths[d] - 1 - position[d] * -stride));
            if (read[d] >= source->lengths[d])
                read[d] = source->lengths[d] - 1;
        }
        CharonMPSNDArrayStore(destination, linear, CharonMPSNDArrayLoad(source, CharonMPSNDArrayLinearIndex(source, read)));
        for (NSUInteger d = 0; d < destination->dimensions; d++) {
            if (++position[d] < destination->lengths[d])
                break;
            position[d] = 0;
        }
    }
}

@end

@implementation MPSNDArrayStridedSliceGradient

- (void)charon_mps_fillFromSources:(CharonMPSNDArrayLayout *)sources count:(NSUInteger)count state:(MPSState *)state into:(CharonMPSNDArrayLayout *)destination
{
    // [0] the sliced source, [1] the incoming gradient. The gradient of a slice is the scatter of the
    // incoming gradient back onto the positions the forward pass read, and the positions it did NOT
    // read are zero - which is why the destination is cleared first rather than only the read
    // positions being written.
    (void)state;
    if (count < 2) {
        CharonMPSRefuse(@"MPSNDArrayStridedSliceGradient: a slice gradient takes a source and a gradient, and %lu were given",
                        (unsigned long)count);
        return;
    }
    const CharonMPSNDArrayLayout *source = &sources[0], *gradient = &sources[1];
    for (NSUInteger linear = 0; linear < CharonMPSNDArrayElementCount(destination); linear++)
        CharonMPSNDArrayStore(destination, linear, 0.0);
    // The STRIDES from the state the forward pass recorded, not from this object's own filter. The
    // header gives MPSNDArrayStridedSliceGradient no `strides` property of its own, and says why: the gradient cannot
    // be handed this by hand, and the gradient state supplies it instead (MPSNDArrayKernel.h:318-321). Reading
    // the gradient's own filter instead - which is all ones, the default - scattered the incoming
    // gradient PACKED: a stride of 2 over 5 landed on 0 1 2 where the forward pass read 0 2 4, and the
    // harness reported 7 8 9 0 0 against the reference's 7 0 8 0 9.
    CharonMPSNDArrayFilter filter = [state isKindOfClass:[MPSNDArrayGradientState class]]
        ? [(MPSNDArrayGradientState *)state charon_mps_filterOfSource:0]
        : [self charon_mps_filterAtSourceIndex:0];
    NSUInteger position[CHARON_MPS_NDARRAY_MAX_DIMENSIONS], read[CHARON_MPS_NDARRAY_MAX_DIMENSIONS];
    for (NSUInteger d = 0; d < CHARON_MPS_NDARRAY_MAX_DIMENSIONS; d++) {
        position[d] = 0;
        read[d] = 0;
    }
    for (NSUInteger linear = 0; linear < CharonMPSNDArrayElementCount(gradient); linear++) {
        for (NSUInteger d = 0; d < gradient->dimensions && d < source->dimensions; d++) {
            NSInteger stride = filter.strides[d] ? filter.strides[d] : 1;
            read[d] = (NSUInteger)(stride > 0 ? (NSInteger)position[d] * stride
                                              : (NSInteger)(source->lengths[d] - 1 - position[d] * -stride));
            if (read[d] >= source->lengths[d])
                read[d] = source->lengths[d] - 1;
        }
        NSUInteger atLinear = CharonMPSNDArrayLinearIndex(source, read);
        if (atLinear < CharonMPSNDArrayElementCount(destination))
            CharonMPSNDArrayStore(destination, atLinear,
                                  CharonMPSNDArrayLoad(destination, atLinear) + CharonMPSNDArrayLoad(gradient, linear));
        for (NSUInteger d = 0; d < gradient->dimensions; d++) {
            if (++position[d] < gradient->lengths[d])
                break;
            position[d] = 0;
        }
    }
}

@end

@implementation MPSNDArrayMatrixMultiplication {
    double _alpha, _beta;
}

- (instancetype)initWithDevice:(id<MTLDevice>)device sourceCount:(NSUInteger)count
{
    if ((self = [super initWithDevice:device sourceCount:count])) {
        // "Defaults to 1.0 at initialization time" for BOTH scales
        // (MPSNDArrayMatrixMultiplication.h:44 and :55). alpha's 1.0 makes the product the answer and
        // beta's 1.0 would make the addend count once - and the header's own discussion gives no C at
        // all for a two-source call, so a caller that supplied one is the only way beta is reached.
        _alpha = 1.0;
        _beta = 1.0;
    }
    return self;
}

- (double)alpha { return _alpha; }
- (void)setAlpha:(double)alpha { _alpha = alpha; }
- (double)beta { return _beta; }
- (void)setBeta:(double)beta { _beta = beta; }

// D is alpha times A times B plus beta times C, for each 2-D matrix of a 4-D array, with a third or fourth dimension
// of 1 BROADCAST. The header (:33-35) places the four matrices in the two major dimensions of the array, so a
// [rows, columns, batch, matrices] array is a batch of matrices, dimensions 2 and 3 being the batch indices and
// dimensions 0 and 1 the matrix - and the header's rule for a dimension of 1 (:36-37) is that the one element is
// reused for the other input's index there, which is a stride of zero on that axis and nothing else: the same
// element read for every matrix of the batch.
- (void)charon_mps_fillFromSources:(CharonMPSNDArrayLayout *)sources count:(NSUInteger)count state:(MPSState *)state into:(CharonMPSNDArrayLayout *)destination
{
    (void)state;
    if (count < 2) {
        CharonMPSRefuse(@"MPSNDArrayMatrixMultiplication: a multiplication takes at least a left and a right matrix, and %lu were given",
                        (unsigned long)count);
        return;
    }
    const CharonMPSNDArrayLayout *left = &sources[0], *right = &sources[1];
    const CharonMPSNDArrayLayout *addend = count > 2 ? &sources[2] : NULL;
    if (left->dimensions < 2 || right->dimensions < 2 || destination->dimensions < 2) {
        CharonMPSRefuse(@"MPSNDArrayMatrixMultiplication: a matrix is the two most major dimensions of an array, "
                        @"and the operands hold %lu, %lu and %lu dimensions", (unsigned long)left->dimensions,
                        (unsigned long)right->dimensions, (unsigned long)destination->dimensions);
        return;
    }
    // DIMENSION 0 IS THE COLUMN. The class discussion (MPSCore/MPSNDArray.h) makes the major row, the dimension whose
    // neighbours sit next to each other in memory, the 0th, and a matrix's major row is its COLUMNS - the same way
    // MPSMatrix's own descriptor counts, where `columns` is the fast dimension and `rows` the slow one.
    // So for a two dimensional
    // array dimension 1 counts rows and dimension 0 counts columns, and D = A * B of an M by K and a K
    // by N is an M by N held as [N, M]: the destination's dimension 0 is N and its dimension 1 is M.
    //
    // This had it the other way round, and the harness is what said so: a [2,3] by a [3,2] whose
    // elements are the 2x2 result 58 64 139 154 came back 76 100 103 136, which is the product of the
    // same six numbers read as a 2x3 times a 3x2 - a different question with the same operands.
    NSUInteger interior = left->lengths[0], rows = left->lengths[1], columns = right->lengths[0];
    if (right->lengths[1] != interior) {
        CharonMPSRefuse(@"MPSNDArrayMatrixMultiplication: the left matrix is %lux%lu and the right is %lux%lu, "
                        @"so their interior dimensions differ", (unsigned long)interior, (unsigned long)rows,
                        (unsigned long)right->lengths[1], (unsigned long)columns);
        return;
    }
    if (destination->lengths[0] != columns || destination->lengths[1] != rows) {
        CharonMPSRefuse(@"MPSNDArrayMatrixMultiplication: a %lux%lu by %lux%lu product is held with dimension 0 as the columns "
                        @"and dimension 1 as the rows, so the destination must hold %lu columns and %lu rows, and it holds %lu and %lu",
                        (unsigned long)interior, (unsigned long)rows, (unsigned long)interior, (unsigned long)columns,
                        (unsigned long)columns, (unsigned long)rows,
                        (unsigned long)destination->lengths[0], (unsigned long)destination->lengths[1]);
        return;
    }
    // The batch is the two dimensions past the matrix, and a 1 there is a broadcast: the same matrix
    // for every index, which is a stride of zero and not a loop of one.
    NSUInteger batchDimensions[2] = {1, 1};
    if (destination->dimensions > 2)
        batchDimensions[0] = destination->lengths[2];
    if (destination->dimensions > 3)
        batchDimensions[1] = destination->lengths[3];
    NSUInteger at[CHARON_MPS_NDARRAY_MAX_DIMENSIONS];
    for (NSUInteger m = 0; m < batchDimensions[1]; m++) {
        for (NSUInteger b = 0; b < batchDimensions[0]; b++) {
            for (NSUInteger column = 0; column < columns; column++) {
                for (NSUInteger row = 0; row < rows; row++) {
                    double sum = 0.0;
                    for (NSUInteger k = 0; k < interior; k++) {
                        CharonMPSBatchIndex(left, b, m, k, row, at);   // A[row][k]: column k, row row
                        double a = CharonMPSNDArrayLoad(left, CharonMPSNDArrayLinearIndex(left, at));
                        CharonMPSBatchIndex(right, b, m, column, k, at);  // B[k][column]: column column, row k
                        sum += a * CharonMPSNDArrayLoad(right, CharonMPSNDArrayLinearIndex(right, at));
                    }
                    double value = _alpha * sum;
                    if (addend) {
                        // The addend's own data type, read through its own index: an addend of a
                        // different width is converted per element rather than reinterpretted, which is
                        // what the matrix family's CharonMPSLoad and CharonMPSStore pair is for.
                        CharonMPSBatchIndex(addend, b, m, column, row, at);
                        value += _beta * CharonMPSNDArrayLoad(addend, CharonMPSNDArrayLinearIndex(addend, at));
                    }
                    CharonMPSBatchIndex(destination, b, m, column, row, at);
                    CharonMPSNDArrayStore(destination, CharonMPSNDArrayLinearIndex(destination, at), value);
                }
            }
        }
    }
}

@end
