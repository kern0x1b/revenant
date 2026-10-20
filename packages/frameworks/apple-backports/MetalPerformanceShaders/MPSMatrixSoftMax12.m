#import "RevenantMPS.h"


@implementation MPSMatrixSoftMax {
    NSUInteger _sourceRows, _sourceColumns;
    MTLOrigin _sourceMatrixOrigin, _resultMatrixOrigin;
    NSUInteger _batchStart, _batchSize;
    BOOL _logarithmic;
}

- (instancetype)initWithDevice:(id<MTLDevice>)device
{
    if ((self = [super initWithDevice:device])) {
        _sourceRows = NSUIntegerMax;
        _sourceColumns = NSUIntegerMax;
        _sourceMatrixOrigin = MTLOriginMake(0, 0, 0);
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

- (void)encodeToCommandBuffer:(id<MTLCommandBuffer>)commandBuffer inputMatrix:(MPSMatrix *)inputMatrix resultMatrix:(MPSMatrix *)resultMatrix
{
    if (!RevenantMPSCommandBufferPermits(commandBuffer))
        return;
    RevenantMPSMatrixView in = RevenantMPSMatrixViewOf(inputMatrix), out = RevenantMPSMatrixViewOf(resultMatrix);
    if (!RevenantMPSDataTypeIsElement(in.dataType) || !RevenantMPSDataTypeIsElement(out.dataType)) {
        RevenantMPSRefuse(@"MPSMatrixSoftMax: a matrix of a data type that is not one of the eight element types was given");
        return;
    }
    NSUInteger rows = _sourceRows == NSUIntegerMax ? in.rows : _sourceRows;
    NSUInteger columns = _sourceColumns == NSUIntegerMax ? in.columns : _sourceColumns;
    NSUInteger start, count;
    RevenantMPSBatch(_batchStart, _batchSize, in.matrices, &start, &count);
    count = count < out.matrices ? count : out.matrices;
    for (NSUInteger b = 0; b < count; b++) {
        if (!RevenantMPSMatrixHolds(&in, b, _sourceMatrixOrigin.x, _sourceMatrixOrigin.y, rows, columns) ||
            !RevenantMPSMatrixHolds(&out, b, _resultMatrixOrigin.x, _resultMatrixOrigin.y, rows, columns)) {
            RevenantMPSRefuse(@"MPSMatrixSoftMax: a matrix of the batch [%lu, %lu) does not hold the %lux%lu region its origin names", (unsigned long)start, (unsigned long)(start + count), (unsigned long)rows, (unsigned long)columns);
            return;
        }
    }
    for (NSUInteger b = 0; b < count; b++) {
        for (NSUInteger row = 0; row < rows; row++) {
            double largest = -INFINITY, sum = 0.0;
            for (NSUInteger column = 0; column < columns; column++) {
                double v = RevenantMPSLoad(RevenantMPSMatrixElement(&in, b, _sourceMatrixOrigin.x + row, _sourceMatrixOrigin.y + column), in.dataType, 0);
                if (v > largest)
                    largest = v;
            }
            for (NSUInteger column = 0; column < columns; column++) {
                double v = RevenantMPSLoad(RevenantMPSMatrixElement(&in, b, _sourceMatrixOrigin.x + row, _sourceMatrixOrigin.y + column), in.dataType, 0);
                sum += _logarithmic ? exp(v - largest) : exp(v);
            }
            for (NSUInteger column = 0; column < columns; column++) {
                double v = RevenantMPSLoad(RevenantMPSMatrixElement(&in, b, _sourceMatrixOrigin.x + row, _sourceMatrixOrigin.y + column), in.dataType, 0);
                double e = _logarithmic ? exp(v - largest) : exp(v);
                double result = _logarithmic ? (v - largest) - log(sum) : e / sum;
                RevenantMPSStore(RevenantMPSMatrixElement(&out, b, _resultMatrixOrigin.x + row, _resultMatrixOrigin.y + column), out.dataType, 0, result);
            }
        }
    }
    RevenantMPSConsumeReadCount(inputMatrix);
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder device:(id<MTLDevice>)device
{
    return [super initWithCoder:aDecoder device:device];
}

- (instancetype)copyWithZone:(NSZone *)zone device:(id<MTLDevice>)device
{
    MPSMatrixSoftMax *copy = [super copyWithZone:zone device:device];
    copy->_sourceRows = _sourceRows;
    copy->_sourceColumns = _sourceColumns;
    copy->_sourceMatrixOrigin = _sourceMatrixOrigin;
    copy->_resultMatrixOrigin = _resultMatrixOrigin;
    copy->_batchStart = _batchStart;
    copy->_batchSize = _batchSize;
    copy->_logarithmic = _logarithmic;
    return copy;
}

- (void)revenant_mps_setLogarithmic:(BOOL)logarithmic
{
    _logarithmic = logarithmic;
}

@end
