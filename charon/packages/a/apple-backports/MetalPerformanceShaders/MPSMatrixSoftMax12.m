// MPSMatrixSoftMax, from the header of the SDK of iOS 16.4. One object per release: the band machinery keeps an
// object whole or drops it whole, so a file here carries the API of exactly one release.

#import "CharonMPS.h"


@implementation MPSMatrixSoftMax {
    NSUInteger _sourceRows, _sourceColumns;
    MTLOrigin _sourceMatrixOrigin, _resultMatrixOrigin;
    NSUInteger _batchStart, _batchSize;
    BOOL _logarithmic;
}

- (instancetype)initWithDevice:(id<MTLDevice>)device
{
    if ((self = [super initWithDevice:device])) {
        // NSUIntegerMax is the header's "take the shape from the matrix": a row count of that size
        // never fits, so a sourceRows of it means the rows of the matrix as it is.
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
    if (!CharonMPSCommandBufferPermits(commandBuffer))
        return;
    CharonMPSMatrixView in = CharonMPSMatrixViewOf(inputMatrix), out = CharonMPSMatrixViewOf(resultMatrix);
    if (!CharonMPSDataTypeIsElement(in.dataType) || !CharonMPSDataTypeIsElement(out.dataType)) {
        CharonMPSRefuse(@"MPSMatrixSoftMax: a matrix of a data type that is not one of the eight element types was given");
        return;
    }
    // Softmax normalises each row: every element becomes its own value over the sum of the exponentials
    // of its row, and the log form subtracts the row's largest value first, which is what keeps the
    // exponentials from overflowing and cancels in the ratio. The row is sourceColumns wide, taken
    // from the matrix's own shape when sourceColumns is the header's "as the matrix is".
    NSUInteger rows = _sourceRows == NSUIntegerMax ? in.rows : _sourceRows;
    NSUInteger columns = _sourceColumns == NSUIntegerMax ? in.columns : _sourceColumns;
    NSUInteger start, count;
    CharonMPSBatch(_batchStart, _batchSize, in.matrices, &start, &count);
    count = count < out.matrices ? count : out.matrices;
    for (NSUInteger b = 0; b < count; b++) {
        if (!CharonMPSMatrixHolds(&in, b, _sourceMatrixOrigin.x, _sourceMatrixOrigin.y, rows, columns) ||
            !CharonMPSMatrixHolds(&out, b, _resultMatrixOrigin.x, _resultMatrixOrigin.y, rows, columns)) {
            CharonMPSRefuse(@"MPSMatrixSoftMax: a matrix of the batch [%lu, %lu) does not hold the %lux%lu region its origin names", (unsigned long)start, (unsigned long)(start + count), (unsigned long)rows, (unsigned long)columns);
            return;
        }
    }
    for (NSUInteger b = 0; b < count; b++) {
        for (NSUInteger row = 0; row < rows; row++) {
            double largest = -INFINITY, sum = 0.0;
            for (NSUInteger column = 0; column < columns; column++) {
                double v = CharonMPSLoad(CharonMPSMatrixElement(&in, b, _sourceMatrixOrigin.x + row, _sourceMatrixOrigin.y + column), in.dataType, 0);
                if (v > largest)
                    largest = v;
            }
            for (NSUInteger column = 0; column < columns; column++) {
                double v = CharonMPSLoad(CharonMPSMatrixElement(&in, b, _sourceMatrixOrigin.x + row, _sourceMatrixOrigin.y + column), in.dataType, 0);
                sum += _logarithmic ? exp(v - largest) : exp(v);
            }
            for (NSUInteger column = 0; column < columns; column++) {
                double v = CharonMPSLoad(CharonMPSMatrixElement(&in, b, _sourceMatrixOrigin.x + row, _sourceMatrixOrigin.y + column), in.dataType, 0);
                double e = _logarithmic ? exp(v - largest) : exp(v);
                double result = _logarithmic ? (v - largest) - log(sum) : e / sum;
                CharonMPSStore(CharonMPSMatrixElement(&out, b, _resultMatrixOrigin.x + row, _resultMatrixOrigin.y + column), out.dataType, 0, result);
            }
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

// A log softmax's own flag, which its subclass sets. -logSoftMax is the same kernel with the row's
// exponentials taken in logarithms, so the flag is the only difference between the two classes.
- (void)charon_mps_setLogarithmic:(BOOL)logarithmic
{
    _logarithmic = logarithmic;
}

@end
