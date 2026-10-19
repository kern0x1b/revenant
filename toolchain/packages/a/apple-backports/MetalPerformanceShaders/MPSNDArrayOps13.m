#import "RevenantMPSNDArray.h"


@interface MPSNDArrayGradientState (RevenantMPSNDArrayOps)
- (NSUInteger)revenant_mps_axis;
- (RevenantMPSNDArrayFilter)revenant_mps_filterOfSource:(NSUInteger)index;
@end

@implementation MPSNDArrayGather {
    NSUInteger _axis;
}

- (instancetype)initWithDevice:(id<MTLDevice>)device
{
    if ((self = [super initWithDevice:device])) {
        _axis = 0;
    }
    return self;
}

- (NSUInteger)axis { return _axis; }

- (void)setAxis:(NSUInteger)axis { _axis = axis; }

- (MPSNDArrayDescriptor *)destinationArrayDescriptorForSourceArrays:(NSArray<MPSNDArray *> *)sources
                                                         sourceState:(MPSState *)state
{
    (void)state;
    if ([sources count] < 2)
        return nil;
    MPSNDArray *source = [sources objectAtIndex:0], *indices = [sources objectAtIndex:1];
    if (!source || !indices || _axis >= source.numberOfDimensions)
        return nil;
    NSUInteger sizes[REVENANT_MPS_NDARRAY_MAX_DIMENSIONS];
    for (NSUInteger d = 0; d < source.numberOfDimensions; d++)
        sizes[d] = (d == _axis) ? [indices lengthOfDimension:0] : [source lengthOfDimension:d];
    return [MPSNDArrayDescriptor descriptorWithDataType:source.dataType
                                         dimensionCount:source.numberOfDimensions
                                         dimensionSizes:sizes];
}

- (void)revenant_mps_fillFromSources:(RevenantMPSNDArrayLayout *)sources count:(NSUInteger)count state:(MPSState *)state into:(RevenantMPSNDArrayLayout *)destination
{
    if (count < 2) {
        RevenantMPSRefuse(@"MPSNDArrayGather: a gather takes a source and an index array, and %lu were given", (unsigned long)count);
        return;
    }
    const RevenantMPSNDArrayLayout *source = &sources[0], *indices = &sources[1];
    NSUInteger axis = _axis;
    if (axis >= source->dimensions) {
        RevenantMPSRefuse(@"MPSNDArrayGather: axis %lu is past the source's %lu dimensions", (unsigned long)axis, (unsigned long)source->dimensions);
        return;
    }
    NSUInteger gathered = RevenantMPSNDArrayElementCount(indices);
    NSUInteger produced = 1;
    for (NSUInteger d = 0; d < source->dimensions; d++)
        produced *= (d == axis) ? gathered : source->lengths[d];
    if (produced != RevenantMPSNDArrayElementCount(destination)) {
        RevenantMPSRefuse(@"MPSNDArrayGather: a gather on axis %lu of a %lux%lux%lu source holds %lu elements, "
                        @"and the destination holds %lu", (unsigned long)axis,
                        (unsigned long)source->lengths[0], (unsigned long)(source->dimensions > 1 ? source->lengths[1] : 1),
                        (unsigned long)(source->dimensions > 2 ? source->lengths[2] : 1),
                        (unsigned long)produced, (unsigned long)RevenantMPSNDArrayElementCount(destination));
        return;
    }
    RevenantMPSNDArrayFilter filter = [self revenant_mps_filterAtSourceIndex:0];
    NSUInteger sourceIndex[REVENANT_MPS_NDARRAY_MAX_DIMENSIONS];
    for (NSUInteger d = 0; d < REVENANT_MPS_NDARRAY_MAX_DIMENSIONS; d++)
        sourceIndex[d] = 0;
    for (NSUInteger linear = 0; linear < RevenantMPSNDArrayElementCount(destination); linear++) {
        RevenantMPSNDArrayIndexOf(destination, linear, sourceIndex);
        NSUInteger at = (NSUInteger)RevenantMPSNDArrayLoad(indices, sourceIndex[axis]);
        NSInteger sourceAt = (NSInteger)at + filter.offsets[axis];
        if (sourceAt < 0 || (NSUInteger)sourceAt >= source->lengths[axis]) {
            sourceAt = RevenantMPSNDArrayApplyEdgeMode(sourceAt, source->lengths[axis], filter.edgeMode);
        }
        if ((NSUInteger)sourceAt >= source->lengths[axis]) {
            RevenantMPSRefuse(@"MPSNDArrayGather: index %lu of the index array is %ld, outside the source's %lu elements on axis %lu",
                            (unsigned long)at, (long)sourceAt, (unsigned long)source->lengths[axis], (unsigned long)axis);
            return;
        }
        NSUInteger read[REVENANT_MPS_NDARRAY_MAX_DIMENSIONS];
        for (NSUInteger d = 0; d < REVENANT_MPS_NDARRAY_MAX_DIMENSIONS; d++)
            read[d] = sourceIndex[d];
        read[axis] = (NSUInteger)sourceAt;
        RevenantMPSNDArrayStore(destination, linear, RevenantMPSNDArrayLoad(source, RevenantMPSNDArrayLinearIndex(source, read)));
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

- (void)revenant_mps_fillFromSources:(RevenantMPSNDArrayLayout *)sources count:(NSUInteger)count state:(MPSState *)state into:(RevenantMPSNDArrayLayout *)destination
{
    if (count < 3) {
        RevenantMPSRefuse(@"MPSNDArrayGatherGradient: a gather gradient takes a source, an index array and a gradient, and %lu were given",
                        (unsigned long)count);
        return;
    }
    const RevenantMPSNDArrayLayout *source = &sources[0], *indices = &sources[1], *gradient = &sources[2];
    if (![state isKindOfClass:[MPSNDArrayGradientState class]]) {
        (void)state;
        RevenantMPSRefuse(@"MPSNDArrayGatherGradient: a gather gradient needs the state its forward pass recorded, which is what "
                        @"-resultStateForSourceArrays:sourceStates:destinationArray: makes, and none was given");
        return;
    }
    MPSNDArrayGradientState *recorded = (MPSNDArrayGradientState *)state;
    RevenantMPSNDArrayFilter filter = [recorded revenant_mps_filterOfSource:0];
    NSUInteger axis = [recorded revenant_mps_axis];
    if (axis >= source->dimensions) {
        RevenantMPSRefuse(@"MPSNDArrayGatherGradient: the state records axis %lu, which is past the source's %lu dimensions",
                        (unsigned long)axis, (unsigned long)source->dimensions);
        return;
    }
    for (NSUInteger linear = 0; linear < RevenantMPSNDArrayElementCount(destination); linear++)
        RevenantMPSNDArrayStore(destination, linear, 0.0);
    NSUInteger position[REVENANT_MPS_NDARRAY_MAX_DIMENSIONS], read[REVENANT_MPS_NDARRAY_MAX_DIMENSIONS];
    for (NSUInteger d = 0; d < REVENANT_MPS_NDARRAY_MAX_DIMENSIONS; d++) {
        position[d] = 0;
        read[d] = 0;
    }
    if (RevenantMPSNDArrayElementCount(gradient) != RevenantMPSNDArrayElementCount(destination)) {
        RevenantMPSRefuse(@"MPSNDArrayGatherGradient: the gradient holds %lu elements and the destination %lu; a gather gradient "
                        @"scatters the result's shape back onto the source's",
                        (unsigned long)RevenantMPSNDArrayElementCount(gradient),
                        (unsigned long)RevenantMPSNDArrayElementCount(destination));
        return;
    }
    for (NSUInteger linear = 0; linear < RevenantMPSNDArrayElementCount(destination); linear++) {
        RevenantMPSNDArrayIndexOf(destination, linear, position);
        NSUInteger indexOfAxis[REVENANT_MPS_NDARRAY_MAX_DIMENSIONS];
        for (NSUInteger d = 0; d < REVENANT_MPS_NDARRAY_MAX_DIMENSIONS; d++)
            indexOfAxis[d] = 0;
        NSUInteger at = (NSUInteger)RevenantMPSNDArrayLoad(indices, position[axis]);
        NSInteger offset = (NSInteger)at + filter.offsets[axis];
        at = offset < 0 ? 0 : (NSUInteger)offset;
        if (at >= source->lengths[axis]) {
            RevenantMPSRefuse(@"MPSNDArrayGatherGradient: position %lu of the result names index %lu, outside the source's %lu "
                            @"elements on axis %lu", (unsigned long)linear, (unsigned long)at,
                            (unsigned long)source->lengths[axis], (unsigned long)axis);
            return;
        }
        for (NSUInteger d = 0; d < REVENANT_MPS_NDARRAY_MAX_DIMENSIONS; d++)
            read[d] = position[d];
        read[axis] = at;
        NSUInteger atLinear = RevenantMPSNDArrayLinearIndex(source, read);
        if (atLinear >= RevenantMPSNDArrayElementCount(destination)) {
            RevenantMPSRefuse(@"MPSNDArrayGatherGradient: position %lu names element %lu of a destination that holds %lu",
                            (unsigned long)linear, (unsigned long)atLinear,
                            (unsigned long)RevenantMPSNDArrayElementCount(destination));
            return;
        }
        double carried = RevenantMPSNDArrayLoad(destination, atLinear) + RevenantMPSNDArrayLoad(gradient, linear);
        RevenantMPSNDArrayStore(destination, atLinear, carried);
    }
}

@end

@implementation MPSNDArrayStridedSlice {
    MPSNDArrayOffsets _strides;
}

- (instancetype)initWithDevice:(id<MTLDevice>)device
{
    if ((self = [super initWithDevice:device])) {
        for (NSUInteger i = 0; i < REVENANT_MPS_NDARRAY_MAX_DIMENSIONS; i++)
            _strides.dimensions[i] = 1;
    }
    return self;
}

- (MPSNDArrayOffsets)strides { return _strides; }

- (void)setStrides:(MPSNDArrayOffsets)strides
{
    _strides = strides;
    RevenantMPSNDArrayFilter filter = [self revenant_mps_filterAtSourceIndex:0];
    for (NSUInteger i = 0; i < REVENANT_MPS_NDARRAY_MAX_DIMENSIONS; i++)
        filter.strides[i] = strides.dimensions[i];
    [self revenant_mps_setFilter:filter atSourceIndex:0];
}

- (void)revenant_mps_fillFromSources:(RevenantMPSNDArrayLayout *)sources count:(NSUInteger)count state:(MPSState *)state into:(RevenantMPSNDArrayLayout *)destination
{
    (void)count;
    (void)state;
    const RevenantMPSNDArrayLayout *source = &sources[0];
    RevenantMPSNDArrayFilter filter = [self revenant_mps_filterAtSourceIndex:0];
    for (NSUInteger d = 0; d < destination->dimensions && d < source->dimensions; d++) {
        NSInteger stride = filter.strides[d];
        if (stride == 0)
            stride = 1;
        NSUInteger held = (NSUInteger)((source->lengths[d] + (NSUInteger)(stride < 0 ? -stride : stride) - 1) /
                                       (NSUInteger)(stride < 0 ? -stride : stride));
        if (destination->lengths[d] != held) {
            RevenantMPSRefuse(@"MPSNDArrayStridedSlice: a stride of %ld over dimension %lu of %lu holds %lu elements, "
                            @"and the destination holds %lu", (long)stride, (unsigned long)d,
                            (unsigned long)source->lengths[d], (unsigned long)held, (unsigned long)destination->lengths[d]);
            return;
        }
    }
    NSUInteger position[REVENANT_MPS_NDARRAY_MAX_DIMENSIONS];
    for (NSUInteger d = 0; d < REVENANT_MPS_NDARRAY_MAX_DIMENSIONS; d++)
        position[d] = 0;
    NSUInteger read[REVENANT_MPS_NDARRAY_MAX_DIMENSIONS];
    for (NSUInteger d = 0; d < REVENANT_MPS_NDARRAY_MAX_DIMENSIONS; d++)
        read[d] = 0;
    for (NSUInteger linear = 0; linear < RevenantMPSNDArrayElementCount(destination); linear++) {
        for (NSUInteger d = 0; d < destination->dimensions && d < source->dimensions; d++) {
            NSInteger stride = filter.strides[d] ? filter.strides[d] : 1;
            read[d] = (NSUInteger)(stride > 0 ? (NSInteger)position[d] * stride
                                              : (NSInteger)(source->lengths[d] - 1 - position[d] * -stride));
            if (read[d] >= source->lengths[d])
                read[d] = source->lengths[d] - 1;
        }
        RevenantMPSNDArrayStore(destination, linear, RevenantMPSNDArrayLoad(source, RevenantMPSNDArrayLinearIndex(source, read)));
        for (NSUInteger d = 0; d < destination->dimensions; d++) {
            if (++position[d] < destination->lengths[d])
                break;
            position[d] = 0;
        }
    }
}

@end

@implementation MPSNDArrayStridedSliceGradient

- (void)revenant_mps_fillFromSources:(RevenantMPSNDArrayLayout *)sources count:(NSUInteger)count state:(MPSState *)state into:(RevenantMPSNDArrayLayout *)destination
{
    (void)state;
    if (count < 2) {
        RevenantMPSRefuse(@"MPSNDArrayStridedSliceGradient: a slice gradient takes a source and a gradient, and %lu were given",
                        (unsigned long)count);
        return;
    }
    const RevenantMPSNDArrayLayout *source = &sources[0], *gradient = &sources[1];
    for (NSUInteger linear = 0; linear < RevenantMPSNDArrayElementCount(destination); linear++)
        RevenantMPSNDArrayStore(destination, linear, 0.0);
    RevenantMPSNDArrayFilter filter = [state isKindOfClass:[MPSNDArrayGradientState class]]
        ? [(MPSNDArrayGradientState *)state revenant_mps_filterOfSource:0]
        : [self revenant_mps_filterAtSourceIndex:0];
    NSUInteger position[REVENANT_MPS_NDARRAY_MAX_DIMENSIONS], read[REVENANT_MPS_NDARRAY_MAX_DIMENSIONS];
    for (NSUInteger d = 0; d < REVENANT_MPS_NDARRAY_MAX_DIMENSIONS; d++) {
        position[d] = 0;
        read[d] = 0;
    }
    for (NSUInteger linear = 0; linear < RevenantMPSNDArrayElementCount(gradient); linear++) {
        for (NSUInteger d = 0; d < gradient->dimensions && d < source->dimensions; d++) {
            NSInteger stride = filter.strides[d] ? filter.strides[d] : 1;
            read[d] = (NSUInteger)(stride > 0 ? (NSInteger)position[d] * stride
                                              : (NSInteger)(source->lengths[d] - 1 - position[d] * -stride));
            if (read[d] >= source->lengths[d])
                read[d] = source->lengths[d] - 1;
        }
        NSUInteger atLinear = RevenantMPSNDArrayLinearIndex(source, read);
        if (atLinear < RevenantMPSNDArrayElementCount(destination))
            RevenantMPSNDArrayStore(destination, atLinear,
                                  RevenantMPSNDArrayLoad(destination, atLinear) + RevenantMPSNDArrayLoad(gradient, linear));
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
        _alpha = 1.0;
        _beta = 1.0;
    }
    return self;
}

- (double)alpha { return _alpha; }
- (void)setAlpha:(double)alpha { _alpha = alpha; }
- (double)beta { return _beta; }
- (void)setBeta:(double)beta { _beta = beta; }

- (void)revenant_mps_fillFromSources:(RevenantMPSNDArrayLayout *)sources count:(NSUInteger)count state:(MPSState *)state into:(RevenantMPSNDArrayLayout *)destination
{
    (void)state;
    if (count < 2) {
        RevenantMPSRefuse(@"MPSNDArrayMatrixMultiplication: a multiplication takes at least a left and a right matrix, and %lu were given",
                        (unsigned long)count);
        return;
    }
    const RevenantMPSNDArrayLayout *left = &sources[0], *right = &sources[1];
    const RevenantMPSNDArrayLayout *addend = count > 2 ? &sources[2] : NULL;
    if (left->dimensions < 2 || right->dimensions < 2 || destination->dimensions < 2) {
        RevenantMPSRefuse(@"MPSNDArrayMatrixMultiplication: a matrix is the two most major dimensions of an array, "
                        @"and the operands hold %lu, %lu and %lu dimensions", (unsigned long)left->dimensions,
                        (unsigned long)right->dimensions, (unsigned long)destination->dimensions);
        return;
    }
    NSUInteger interior = left->lengths[0], rows = left->lengths[1], columns = right->lengths[0];
    if (right->lengths[1] != interior) {
        RevenantMPSRefuse(@"MPSNDArrayMatrixMultiplication: the left matrix is %lux%lu and the right is %lux%lu, "
                        @"so their interior dimensions differ", (unsigned long)interior, (unsigned long)rows,
                        (unsigned long)right->lengths[1], (unsigned long)columns);
        return;
    }
    if (destination->lengths[0] != columns || destination->lengths[1] != rows) {
        RevenantMPSRefuse(@"MPSNDArrayMatrixMultiplication: a %lux%lu by %lux%lu product is held with dimension 0 as the columns "
                        @"and dimension 1 as the rows, so the destination must hold %lu columns and %lu rows, and it holds %lu and %lu",
                        (unsigned long)interior, (unsigned long)rows, (unsigned long)interior, (unsigned long)columns,
                        (unsigned long)columns, (unsigned long)rows,
                        (unsigned long)destination->lengths[0], (unsigned long)destination->lengths[1]);
        return;
    }
    NSUInteger batchDimensions[2] = {1, 1};
    if (destination->dimensions > 2)
        batchDimensions[0] = destination->lengths[2];
    if (destination->dimensions > 3)
        batchDimensions[1] = destination->lengths[3];
    NSUInteger at[REVENANT_MPS_NDARRAY_MAX_DIMENSIONS];
    for (NSUInteger m = 0; m < batchDimensions[1]; m++) {
        for (NSUInteger b = 0; b < batchDimensions[0]; b++) {
            for (NSUInteger column = 0; column < columns; column++) {
                for (NSUInteger row = 0; row < rows; row++) {
                    double sum = 0.0;
                    for (NSUInteger k = 0; k < interior; k++) {
                        RevenantMPSBatchIndex(left, b, m, k, row, at);
                        double a = RevenantMPSNDArrayLoad(left, RevenantMPSNDArrayLinearIndex(left, at));
                        RevenantMPSBatchIndex(right, b, m, column, k, at);
                        sum += a * RevenantMPSNDArrayLoad(right, RevenantMPSNDArrayLinearIndex(right, at));
                    }
                    double value = _alpha * sum;
                    if (addend) {
                        RevenantMPSBatchIndex(addend, b, m, column, row, at);
                        value += _beta * RevenantMPSNDArrayLoad(addend, RevenantMPSNDArrayLinearIndex(addend, at));
                    }
                    RevenantMPSBatchIndex(destination, b, m, column, row, at);
                    RevenantMPSNDArrayStore(destination, RevenantMPSNDArrayLinearIndex(destination, at), value);
                }
            }
        }
    }
}

@end
