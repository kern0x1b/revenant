// MPSMatrixVectorMultiplication, from the header of the SDK of iOS 16.4. One object per release: the band machinery keeps an
// object whole or drops it whole, so a file here carries the API of exactly one release.

#import "CharonMPS.h"


@implementation MPSMatrixVectorMultiplication {
    NSUInteger _rows, _columns;
    BOOL _transpose;
    double _alpha, _beta;
    MTLOrigin _primarySourceMatrixOrigin, _secondarySourceMatrixOrigin, _resultMatrixOrigin;
    NSUInteger _batchStart, _batchSize;
}

- (instancetype)initWithDevice:(id<MTLDevice>)device
{
    NSLog(@"MPSMatrixVectorMultiplication: -initWithDevice: names no shape; use -initWithDevice:rows:columns: or the initialiser that takes the transposition and the scales");
    return nil;
}

- (instancetype)initWithDevice:(id<MTLDevice>)device transpose:(BOOL)transpose rows:(NSUInteger)rows columns:(NSUInteger)columns alpha:(double)alpha beta:(double)beta
{
    if ((self = [super initWithDevice:device])) {
        _transpose = transpose;
        _rows = rows;
        _columns = columns;
        _alpha = alpha;
        _beta = beta;
        _primarySourceMatrixOrigin = MTLOriginMake(0, 0, 0);
        _secondarySourceMatrixOrigin = MTLOriginMake(0, 0, 0);
        _resultMatrixOrigin = MTLOriginMake(0, 0, 0);
    }
    return self;
}

- (instancetype)initWithDevice:(id<MTLDevice>)device rows:(NSUInteger)rows columns:(NSUInteger)columns
{
    return [self initWithDevice:device transpose:NO rows:rows columns:columns alpha:1.0 beta:0.0];
}

- (void)encodeToCommandBuffer:(id<MTLCommandBuffer>)commandBuffer
                  inputMatrix:(MPSMatrix *)inputMatrix
                  inputVector:(MPSVector *)inputVector
                 resultVector:(MPSVector *)resultVector
{
    if (!CharonMPSCommandBufferPermits(commandBuffer))
        return;
    CharonMPSMatrixView matrix = CharonMPSMatrixViewOf(inputMatrix);
    CharonMPSVectorView x = CharonMPSVectorViewOf(inputVector), y = CharonMPSVectorViewOf(resultVector);
    if (!CharonMPSDataTypeIsElement(matrix.dataType) || !CharonMPSDataTypeIsElement(x.dataType) || !CharonMPSDataTypeIsElement(y.dataType)) {
        CharonMPSRefuse(@"MPSMatrixVectorMultiplication: a matrix or vector of a data type that is not one of the eight element types was given");
        return;
    }
    // op(A) is _rows x _columns, x holds its _columns components and y the result's _rows, and the
    // batch is the matrices and vectors the origins and the batch range name together.
    NSUInteger matrixRows = _transpose ? _columns : _rows;
    NSUInteger matrixColumns = _transpose ? _rows : _columns;
    NSUInteger start, count;
    CharonMPSBatch(_batchStart, _batchSize, matrix.matrices, &start, &count);
    count = count < x.vectors ? count : x.vectors;
    count = count < y.vectors ? count : y.vectors;
    BOOL whole = YES;
    for (NSUInteger b = 0; b < count; b++) {
        if (!CharonMPSMatrixHolds(&matrix, b, _primarySourceMatrixOrigin.x, _primarySourceMatrixOrigin.y, matrixRows, matrixColumns) ||
            !CharonMPSVectorHolds(&x, b, _columns) || !CharonMPSVectorHolds(&y, b, _rows)) {
            whole = NO;
            break;
        }
    }
    if (!whole) {
        CharonMPSRefuse(@"MPSMatrixVectorMultiplication: the matrix or a vector of the batch [%lu, %lu) does not hold the %lux%lu region its origin names", (unsigned long)start, (unsigned long)(start + count), (unsigned long)matrixRows, (unsigned long)matrixColumns);
        return;
    }
    for (NSUInteger b = 0; b < count; b++) {
        for (NSUInteger row = 0; row < _rows; row++) {
            double sum = 0.0;
            for (NSUInteger column = 0; column < _columns; column++) {
                NSUInteger mr = _transpose ? column : row, mc = _transpose ? row : column;
                double a = CharonMPSLoad(CharonMPSMatrixElement(&matrix, b, _primarySourceMatrixOrigin.x + mr, _primarySourceMatrixOrigin.y + mc), matrix.dataType, 0);
                double v = CharonMPSLoad(CharonMPSVectorElement(&x, b, column), x.dataType, 0);
                sum += a * v;
            }
            void *element = CharonMPSVectorElement(&y, b, row);
            double value = CharonMPSLoad(element, y.dataType, 0);
            CharonMPSStore(element, y.dataType, 0, _alpha * sum + _beta * value);
        }
    }
    CharonMPSConsumeReadCount(inputMatrix);
    CharonMPSConsumeReadCount(inputVector);
}

@end
