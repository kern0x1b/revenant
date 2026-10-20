#import "RevenantMPS.h"


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
    if (!RevenantMPSCommandBufferPermits(commandBuffer))
        return;
    RevenantMPSMatrixView gradient = RevenantMPSMatrixViewOf(gradientMatrix), forward = RevenantMPSMatrixViewOf(forwardOutputMatrix), out = RevenantMPSMatrixViewOf(resultMatrix);
    if (!RevenantMPSDataTypeIsElement(gradient.dataType) || !RevenantMPSDataTypeIsElement(forward.dataType) || !RevenantMPSDataTypeIsElement(out.dataType)) {
        RevenantMPSRefuse(@"MPSMatrixSoftMaxGradient: a matrix of a data type that is not one of the eight element types was given");
        return;
    }
    NSUInteger rows = _sourceRows == NSUIntegerMax ? forward.rows : _sourceRows;
    NSUInteger columns = _sourceColumns == NSUIntegerMax ? forward.columns : _sourceColumns;
    NSUInteger start, count;
    RevenantMPSBatch(_batchStart, _batchSize, forward.matrices, &start, &count);
    count = count < gradient.matrices ? count : gradient.matrices;
    count = count < out.matrices ? count : out.matrices;
    for (NSUInteger b = start; b < start + count; b++) {
        if (!RevenantMPSMatrixHolds(&gradient, b, _primarySourceMatrixOrigin.x, _primarySourceMatrixOrigin.y, rows, columns) ||
            !RevenantMPSMatrixHolds(&forward, b, _secondarySourceMatrixOrigin.x, _secondarySourceMatrixOrigin.y, rows, columns) ||
            !RevenantMPSMatrixHolds(&out, b, _resultMatrixOrigin.x, _resultMatrixOrigin.y, rows, columns)) {
            RevenantMPSRefuse(@"MPSMatrixSoftMaxGradient: a matrix of the batch [%lu, %lu) does not hold the %lux%lu region its origin names", (unsigned long)start, (unsigned long)(start + count), (unsigned long)rows, (unsigned long)columns);
            return;
        }
    }
    for (NSUInteger b = start; b < start + count; b++) {
        for (NSUInteger row = 0; row < rows; row++) {
            double total = 0.0;
            for (NSUInteger column = 0; column < columns; column++) {
                double g = RevenantMPSLoad(RevenantMPSMatrixElement(&gradient, b, _primarySourceMatrixOrigin.x + row, _primarySourceMatrixOrigin.y + column), gradient.dataType, 0);
                double y = RevenantMPSLoad(RevenantMPSMatrixElement(&forward, b, _secondarySourceMatrixOrigin.x + row, _secondarySourceMatrixOrigin.y + column), forward.dataType, 0);
                total += g * y;
            }
            for (NSUInteger column = 0; column < columns; column++) {
                double g = RevenantMPSLoad(RevenantMPSMatrixElement(&gradient, b, _primarySourceMatrixOrigin.x + row, _primarySourceMatrixOrigin.y + column), gradient.dataType, 0);
                double y = RevenantMPSLoad(RevenantMPSMatrixElement(&forward, b, _secondarySourceMatrixOrigin.x + row, _secondarySourceMatrixOrigin.y + column), forward.dataType, 0);
                RevenantMPSStore(RevenantMPSMatrixElement(&out, b, _resultMatrixOrigin.x + row, _resultMatrixOrigin.y + column), out.dataType, 0, y * (g - total));
            }
        }
    }
    RevenantMPSConsumeReadCount(gradientMatrix);
    RevenantMPSConsumeReadCount(forwardOutputMatrix);
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
