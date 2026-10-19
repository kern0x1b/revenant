// MPSMatrixFindTopK, from the header of the SDK of iOS 16.4. One object per release: the band machinery keeps an
// object whole or drops it whole, so a file here carries the API of exactly one release.

#import "CharonMPS.h"


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
    if (!CharonMPSCommandBufferPermits(commandBuffer))
        return;
    CharonMPSMatrixView in = CharonMPSMatrixViewOf(inputMatrix), indices = CharonMPSMatrixViewOf(resultIndexMatrix), values = CharonMPSMatrixViewOf(resultValueMatrix);
    if (!CharonMPSDataTypeIsElement(in.dataType) || !CharonMPSDataTypeIsElement(indices.dataType) || !CharonMPSDataTypeIsElement(values.dataType)) {
        CharonMPSRefuse(@"MPSMatrixFindTopK: a matrix of a data type that is not one of the eight element types was given");
        return;
    }
    // The k largest values of each row, largest first. The index matrix holds the column each value
    // came from, counted from indexOffset, and the value matrix the values themselves. A row narrower
    // than k gives the whole row.
    NSUInteger rows = _sourceRows == NSUIntegerMax ? in.rows : _sourceRows;
    NSUInteger columns = _sourceColumns == NSUIntegerMax ? in.columns : _sourceColumns;
    NSUInteger wanted = _numberOfTopKValues < columns ? _numberOfTopKValues : columns;
    NSUInteger start, count;
    CharonMPSBatch(_batchStart, _batchSize, in.matrices, &start, &count);
    count = count < indices.matrices ? count : indices.matrices;
    count = count < values.matrices ? count : values.matrices;
    for (NSUInteger b = 0; b < count; b++) {
        if (!CharonMPSMatrixHolds(&in, b, _sourceMatrixOrigin.x, _sourceMatrixOrigin.y, rows, columns) ||
            !CharonMPSMatrixHolds(&indices, b, _resultMatrixOrigin.x, _resultMatrixOrigin.y, rows, wanted) ||
            !CharonMPSMatrixHolds(&values, b, _resultMatrixOrigin.x, _resultMatrixOrigin.y, rows, wanted)) {
            CharonMPSRefuse(@"MPSMatrixFindTopK: a matrix of the batch [%lu, %lu) does not hold the region its origin names", (unsigned long)start, (unsigned long)(start + count));
            return;
        }
    }
    for (NSUInteger b = 0; b < count; b++) {
        for (NSUInteger row = 0; row < rows; row++) {
            // The k largest of the row, in order. Each column is inserted into the list the row has
            // built so far, which keeps the order exact where a partial sort of equal values would not
            // decide it, and what falls off the end is the k-th largest seen so far.
            NSUInteger *order = (NSUInteger *)calloc(wanted ? wanted : 1, sizeof(NSUInteger));
            double *best = (double *)calloc(wanted ? wanted : 1, sizeof(double));
            NSUInteger filled = 0;
            for (NSUInteger column = 0; column < columns; column++) {
                double v = CharonMPSLoad(CharonMPSMatrixElement(&in, b, _sourceMatrixOrigin.x + row, _sourceMatrixOrigin.y + column), in.dataType, 0);
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
                CharonMPSStore(CharonMPSMatrixElement(&indices, b, _resultMatrixOrigin.x + row, _resultMatrixOrigin.y + place), indices.dataType, 0, (double)(order[place] + _indexOffset));
                CharonMPSStore(CharonMPSMatrixElement(&values, b, _resultMatrixOrigin.x + row, _resultMatrixOrigin.y + place), values.dataType, 0, best[place]);
            }
            free(order);
            free(best);
        }
    }
    CharonMPSConsumeReadCount(inputMatrix);
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
