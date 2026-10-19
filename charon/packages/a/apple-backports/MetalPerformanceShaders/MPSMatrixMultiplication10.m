// MPSMatrixMultiplication, from the header of the SDK of iOS 16.4. One object per release: the band machinery keeps an
// object whole or drops it whole, so a file here carries the API of exactly one release.

#import "CharonMPS.h"


@implementation MPSMatrixMultiplication {
    NSUInteger _resultRows, _resultColumns, _interiorColumns;
    BOOL _transposeLeft, _transposeRight;
    double _alpha, _beta;
    MTLOrigin _leftMatrixOrigin, _rightMatrixOrigin, _resultMatrixOrigin;
    NSUInteger _batchStart, _batchSize;
}

- (instancetype)initWithDevice:(id<MTLDevice>)device
{
    NSLog(@"MPSMatrixMultiplication: -initWithDevice: names no shape; use -initWithDevice:resultRows:resultColumns:interiorColumns: or the initialiser that takes the transpositions and the scales");
    return nil;
}

- (instancetype)initWithDevice:(id<MTLDevice>)device
               transposeLeft:(BOOL)transposeLeft
              transposeRight:(BOOL)transposeRight
                  resultRows:(NSUInteger)resultRows
               resultColumns:(NSUInteger)resultColumns
             interiorColumns:(NSUInteger)interiorColumns
                       alpha:(double)alpha
                        beta:(double)beta
{
    if ((self = [super initWithDevice:device])) {
        _transposeLeft = transposeLeft;
        _transposeRight = transposeRight;
        _resultRows = resultRows;
        _resultColumns = resultColumns;
        _interiorColumns = interiorColumns;
        _alpha = alpha;
        _beta = beta;
        _leftMatrixOrigin = MTLOriginMake(0, 0, 0);
        _rightMatrixOrigin = MTLOriginMake(0, 0, 0);
        _resultMatrixOrigin = MTLOriginMake(0, 0, 0);
        _batchStart = 0;
        _batchSize = 0;
    }
    return self;
}

- (instancetype)initWithDevice:(id<MTLDevice>)device resultRows:(NSUInteger)resultRows resultColumns:(NSUInteger)resultColumns interiorColumns:(NSUInteger)interiorColumns
{
    return [self initWithDevice:device transposeLeft:NO transposeRight:NO resultRows:resultRows resultColumns:resultColumns interiorColumns:interiorColumns alpha:1.0 beta:0.0];
}

- (MTLOrigin)leftMatrixOrigin
{
    return _leftMatrixOrigin;
}

- (void)setLeftMatrixOrigin:(MTLOrigin)origin
{
    _leftMatrixOrigin = origin;
}

- (MTLOrigin)rightMatrixOrigin
{
    return _rightMatrixOrigin;
}

- (void)setRightMatrixOrigin:(MTLOrigin)origin
{
    _rightMatrixOrigin = origin;
}

- (MTLOrigin)resultMatrixOrigin
{
    return _resultMatrixOrigin;
}

- (void)setResultMatrixOrigin:(MTLOrigin)origin
{
    _resultMatrixOrigin = origin;
}

- (NSUInteger)batchStart
{
    return _batchStart;
}

- (void)setBatchStart:(NSUInteger)batchStart
{
    _batchStart = batchStart;
}

- (NSUInteger)batchSize
{
    return _batchSize;
}

- (void)setBatchSize:(NSUInteger)batchSize
{
    _batchSize = batchSize;
}

- (void)encodeToCommandBuffer:(id<MTLCommandBuffer>)commandBuffer
                   leftMatrix:(MPSMatrix *)leftMatrix
                  rightMatrix:(MPSMatrix *)rightMatrix
                 resultMatrix:(MPSMatrix *)resultMatrix
{
    if (!CharonMPSCommandBufferPermits(commandBuffer))
        return;
    CharonMPSMatrixView left = CharonMPSMatrixViewOf(leftMatrix), right = CharonMPSMatrixViewOf(rightMatrix), result = CharonMPSMatrixViewOf(resultMatrix);
    if (!CharonMPSDataTypeIsElement(left.dataType) || !CharonMPSDataTypeIsElement(right.dataType) || !CharonMPSDataTypeIsElement(result.dataType)) {
        CharonMPSRefuse(@"MPSMatrixMultiplication: a matrix of data type %u, %u or %u is not one of the eight element types", (unsigned)left.dataType, (unsigned)right.dataType, (unsigned)result.dataType);
        return;
    }
    // The left matrix holds op(A) as resultRows x interiorColumns, the right one op(B) as
    // interiorColumns x resultColumns, and the result resultRows x resultColumns, each from its own
    // origin, and each may be transposed on the way in. A matrix that does not hold the region is
    // refused rather than read past its end.
    NSUInteger leftRows = _transposeLeft ? _interiorColumns : _resultRows;
    NSUInteger leftColumns = _transposeLeft ? _resultRows : _interiorColumns;
    NSUInteger rightRows = _transposeRight ? _resultColumns : _interiorColumns;
    NSUInteger rightColumns = _transposeRight ? _interiorColumns : _resultColumns;
    NSUInteger start, count;
    CharonMPSBatch(_batchStart, _batchSize, result.matrices, &start, &count);
    count = count < left.matrices ? count : left.matrices;
    count = count < right.matrices ? count : right.matrices;
    BOOL whole = YES;
    // From the batch's first index, which is what batchStart names - the header says it is "the index of
    // the first matrix to process". Starting at zero processes a batch that was not asked for and skips
    // the one that was, which is what multiply-batch caught: with batchStart 1 and batchSize 2 the port
    // wrote matrices 0 and 1 and left 2 alone.
    for (NSUInteger b = start; b < start + count; b++) {
        if (!CharonMPSMatrixHolds(&left, b, _leftMatrixOrigin.x, _leftMatrixOrigin.y, leftRows, leftColumns) ||
            !CharonMPSMatrixHolds(&right, b, _rightMatrixOrigin.x, _rightMatrixOrigin.y, rightRows, rightColumns) ||
            !CharonMPSMatrixHolds(&result, b, _resultMatrixOrigin.x, _resultMatrixOrigin.y, _resultRows, _resultColumns)) {
            whole = NO;
            break;
        }
    }
    if (!whole) {
        CharonMPSRefuse(@"MPSMatrixMultiplication: a matrix of the batch [%lu, %lu) does not hold the %lux%lu, %lux%lu, %lux%lu region its origin names", (unsigned long)start, (unsigned long)(start + count), (unsigned long)leftRows, (unsigned long)leftColumns, (unsigned long)rightRows, (unsigned long)rightColumns, (unsigned long)_resultRows, (unsigned long)_resultColumns);
        return;
    }
    for (NSUInteger b = start; b < start + count; b++) {
        for (NSUInteger row = 0; row < _resultRows; row++) {
            for (NSUInteger column = 0; column < _resultColumns; column++) {
                double sum = 0.0;
                for (NSUInteger k = 0; k < _interiorColumns; k++) {
                    NSUInteger lr = _transposeLeft ? k : row, lc = _transposeLeft ? row : k;
                    NSUInteger rr = _transposeRight ? column : k, rc = _transposeRight ? k : column;
                    double a = CharonMPSLoad(CharonMPSMatrixElement(&left, b, _leftMatrixOrigin.x + lr, _leftMatrixOrigin.y + lc), left.dataType, 0);
                    double c = CharonMPSLoad(CharonMPSMatrixElement(&right, b, _rightMatrixOrigin.x + rr, _rightMatrixOrigin.y + rc), right.dataType, 0);
                    sum += a * c;
                }
                void *element = CharonMPSMatrixElement(&result, b, _resultMatrixOrigin.x + row, _resultMatrixOrigin.y + column);
                double value = CharonMPSLoad(element, result.dataType, 0);
                CharonMPSStore(element, result.dataType, 0, _alpha * sum + _beta * value);
            }
        }
    }
    CharonMPSConsumeReadCount(leftMatrix);
    CharonMPSConsumeReadCount(rightMatrix);
}

@end
