#import "RevenantMPS.h"


@implementation MPSMatrixFindTopK {
    NSUInteger _sourceRows, _sourceColumns, _indexOffset, _numberOfTopKValues;
    MTLOrigin _sourceMatrixOrigin, _resultMatrixOrigin;
    NSUInteger _batchStart, _batchSize;
}

- (instancetype)initWithDevice:(id<MTLDevice>)device
{
    NSLog(@"MPSMatrixFindTopK: -initWithDevice: names no count; use -initWithDevice:numberOfTopKValues:");
    return nil;
}

- (instancetype)initWithDevice:(id<MTLDevice>)device numberOfTopKValues:(NSUInteger)numberOfTopKValues
{
    if ((self = [super initWithDevice:device])) {
        _numberOfTopKValues = numberOfTopKValues;
        _indexOffset = 0;
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

- (NSUInteger)indexOffset
{
    return _indexOffset;
}

- (void)setIndexOffset:(NSUInteger)offset
{
    _indexOffset = offset;
}

- (NSUInteger)numberOfTopKValues
{
    return _numberOfTopKValues;
}

- (void)encodeToCommandBuffer:(id<MTLCommandBuffer>)commandBuffer inputMatrix:(MPSMatrix *)inputMatrix resultIndexMatrix:(MPSMatrix *)resultIndexMatrix resultValueMatrix:(MPSMatrix *)resultValueMatrix
{
    if (!RevenantMPSCommandBufferPermits(commandBuffer))
        return;
    RevenantMPSMatrixView in = RevenantMPSMatrixViewOf(inputMatrix), indices = RevenantMPSMatrixViewOf(resultIndexMatrix), values = RevenantMPSMatrixViewOf(resultValueMatrix);
    if (!RevenantMPSDataTypeIsElement(in.dataType) || !RevenantMPSDataTypeIsElement(indices.dataType) || !RevenantMPSDataTypeIsElement(values.dataType)) {
        RevenantMPSRefuse(@"MPSMatrixFindTopK: a matrix of a data type that is not one of the eight element types was given");
        return;
    }
    NSUInteger rows = _sourceRows == NSUIntegerMax ? in.rows : _sourceRows;
    NSUInteger columns = _sourceColumns == NSUIntegerMax ? in.columns : _sourceColumns;
    NSUInteger wanted = _numberOfTopKValues < columns ? _numberOfTopKValues : columns;
    NSUInteger start, count;
    RevenantMPSBatch(_batchStart, _batchSize, in.matrices, &start, &count);
    count = count < indices.matrices ? count : indices.matrices;
    count = count < values.matrices ? count : values.matrices;
    for (NSUInteger b = 0; b < count; b++) {
        if (!RevenantMPSMatrixHolds(&in, b, _sourceMatrixOrigin.x, _sourceMatrixOrigin.y, rows, columns) ||
            !RevenantMPSMatrixHolds(&indices, b, _resultMatrixOrigin.x, _resultMatrixOrigin.y, rows, wanted) ||
            !RevenantMPSMatrixHolds(&values, b, _resultMatrixOrigin.x, _resultMatrixOrigin.y, rows, wanted)) {
            RevenantMPSRefuse(@"MPSMatrixFindTopK: a matrix of the batch [%lu, %lu) does not hold the region its origin names", (unsigned long)start, (unsigned long)(start + count));
            return;
        }
    }
    for (NSUInteger b = 0; b < count; b++) {
        for (NSUInteger row = 0; row < rows; row++) {
            NSUInteger *order = (NSUInteger *)calloc(wanted ? wanted : 1, sizeof(NSUInteger));
            double *best = (double *)calloc(wanted ? wanted : 1, sizeof(double));
            NSUInteger filled = 0;
            for (NSUInteger column = 0; column < columns; column++) {
                double v = RevenantMPSLoad(RevenantMPSMatrixElement(&in, b, _sourceMatrixOrigin.x + row, _sourceMatrixOrigin.y + column), in.dataType, 0);
                NSUInteger place = filled < wanted ? filled : wanted - 1;
                NSUInteger last = place;
                while (last > 0 && best[last - 1] < v) {
                    best[last] = best[last - 1];
                    order[last] = order[last - 1];
                    last--;
                }
                best[last] = v;
                order[last] = column;
                if (filled < wanted)
                    filled++;
            }
            for (NSUInteger place = 0; place < filled; place++) {
                RevenantMPSStore(RevenantMPSMatrixElement(&indices, b, _resultMatrixOrigin.x + row, _resultMatrixOrigin.y + place), indices.dataType, 0, (double)(order[place] + _indexOffset));
                RevenantMPSStore(RevenantMPSMatrixElement(&values, b, _resultMatrixOrigin.x + row, _resultMatrixOrigin.y + place), values.dataType, 0, best[place]);
            }
            free(order);
            free(best);
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
    MPSMatrixFindTopK *copy = [super copyWithZone:zone device:device];
    copy->_sourceRows = _sourceRows;
    copy->_sourceColumns = _sourceColumns;
    copy->_indexOffset = _indexOffset;
    copy->_numberOfTopKValues = _numberOfTopKValues;
    return copy;
}

@end
