// MPSMatrixSoftMaxGradient, from the header of the SDK of iOS 16.4. One object per release: the band machinery keeps an
// object whole or drops it whole, so a file here carries the API of exactly one release.

#import "CharonMPS.h"


@implementation MPSMatrixSoftMaxGradient {
    NSUInteger _sourceRows, _sourceColumns;
    MTLOrigin _primarySourceMatrixOrigin, _secondarySourceMatrixOrigin, _resultMatrixOrigin;
    NSUInteger _batchStart, _batchSize;
}

- (instancetype)initWithDevice:(id<MTLDevice>)device
{
    if ((self = [super initWithDevice:device])) {
        _sourceRows = NSUIntegerMax;
        _sourceColumns = NSUIntegerMax;
        _primarySourceMatrixOrigin = MTLOriginMake(0, 0, 0);
        _secondarySourceMatrixOrigin = MTLOriginMake(0, 0, 0);
        _resultMatrixOrigin = MTLOriginMake(0, 0, 0);
    }
    return self;
}

- (NSUInteger)sourceRows
{
    return _sourceRows;
}

- (void)setSourceRows:(NSUInteger)rows
{
    _sourceRows = rows;
}

- (NSUInteger)sourceColumns
{
    return _sourceColumns;
}

- (void)setSourceColumns:(NSUInteger)columns
{
    _sourceColumns = columns;
}

- (void)encodeToCommandBuffer:(id<MTLCommandBuffer>)commandBuffer
                gradientMatrix:(MPSMatrix *)gradientMatrix
           forwardOutputMatrix:(MPSMatrix *)forwardOutputMatrix
                  resultMatrix:(MPSMatrix *)resultMatrix
{
    if (!CharonMPSCommandBufferPermits(commandBuffer))
        return;
    CharonMPSMatrixView gradient = CharonMPSMatrixViewOf(gradientMatrix), forward = CharonMPSMatrixViewOf(forwardOutputMatrix), out = CharonMPSMatrixViewOf(resultMatrix);
    if (!CharonMPSDataTypeIsElement(gradient.dataType) || !CharonMPSDataTypeIsElement(forward.dataType) || !CharonMPSDataTypeIsElement(out.dataType)) {
        CharonMPSRefuse(@"MPSMatrixSoftMaxGradient: a matrix of a data type that is not one of the eight element types was given");
        return;
    }
    // The gradient of a softmax row, in the formula MPSMatrixSoftMax.h gives for it:
    //     dL_dX_ij = Y_ij * (dL_dY_ij - sum_k(dL_dY_ik * Y_ik))
    // where Y is the forward kernel's output and dL_dY the incoming gradient.
    NSUInteger rows = _sourceRows == NSUIntegerMax ? forward.rows : _sourceRows;
    NSUInteger columns = _sourceColumns == NSUIntegerMax ? forward.columns : _sourceColumns;
    NSUInteger start, count;
    CharonMPSBatch(_batchStart, _batchSize, forward.matrices, &start, &count);
    count = count < gradient.matrices ? count : gradient.matrices;
    count = count < out.matrices ? count : out.matrices;
    for (NSUInteger b = start; b < start + count; b++) {
        if (!CharonMPSMatrixHolds(&gradient, b, _primarySourceMatrixOrigin.x, _primarySourceMatrixOrigin.y, rows, columns) ||
            !CharonMPSMatrixHolds(&forward, b, _secondarySourceMatrixOrigin.x, _secondarySourceMatrixOrigin.y, rows, columns) ||
            !CharonMPSMatrixHolds(&out, b, _resultMatrixOrigin.x, _resultMatrixOrigin.y, rows, columns)) {
            CharonMPSRefuse(@"MPSMatrixSoftMaxGradient: a matrix of the batch [%lu, %lu) does not hold the %lux%lu region its origin names", (unsigned long)start, (unsigned long)(start + count), (unsigned long)rows, (unsigned long)columns);
            return;
        }
    }
    for (NSUInteger b = start; b < start + count; b++) {
        for (NSUInteger row = 0; row < rows; row++) {
            double total = 0.0;
            for (NSUInteger column = 0; column < columns; column++) {
                double g = CharonMPSLoad(CharonMPSMatrixElement(&gradient, b, _primarySourceMatrixOrigin.x + row, _primarySourceMatrixOrigin.y + column), gradient.dataType, 0);
                double y = CharonMPSLoad(CharonMPSMatrixElement(&forward, b, _secondarySourceMatrixOrigin.x + row, _secondarySourceMatrixOrigin.y + column), forward.dataType, 0);
                total += g * y;
            }
            for (NSUInteger column = 0; column < columns; column++) {
                double g = CharonMPSLoad(CharonMPSMatrixElement(&gradient, b, _primarySourceMatrixOrigin.x + row, _primarySourceMatrixOrigin.y + column), gradient.dataType, 0);
                double y = CharonMPSLoad(CharonMPSMatrixElement(&forward, b, _secondarySourceMatrixOrigin.x + row, _secondarySourceMatrixOrigin.y + column), forward.dataType, 0);
                CharonMPSStore(CharonMPSMatrixElement(&out, b, _resultMatrixOrigin.x + row, _resultMatrixOrigin.y + column), out.dataType, 0, y * (g - total));
            }
        }
    }
    CharonMPSConsumeReadCount(gradientMatrix);
    CharonMPSConsumeReadCount(forwardOutputMatrix);
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder device:(id<MTLDevice>)device
{
    return [super initWithCoder:aDecoder device:device];
}

- (instancetype)copyWithZone:(NSZone *)zone device:(id<MTLDevice>)device
{
    MPSMatrixSoftMaxGradient *copy = [super copyWithZone:zone device:device];
    copy->_sourceRows = _sourceRows;
    copy->_sourceColumns = _sourceColumns;
    return copy;
}

@end
