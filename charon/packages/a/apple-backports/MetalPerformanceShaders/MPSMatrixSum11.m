// MPSMatrixSum, from the header of the SDK of iOS 16.4. One object per release: the band machinery keeps an
// object whole or drops it whole, so a file here carries the API of exactly one release.

// The state every one of the neural network matrix kernels carries, and the accessors each of them
// declares. A macro defines no symbol, so a file that uses one needs nothing from another.
#define CHARON_MPS_NEURON_IVARS \
    MPSCNNNeuronType _neuronType; \
    float _neuronParameterA, _neuronParameterB, _neuronParameterC; \
    NSData *_neuronPrelu;

#define CHARON_MPS_NEURON_COMMON \
    - (CharonMPSNeuron)charon_mps_neuron \
    { \
        CharonMPSNeuron neuron; \
        neuron.type = _neuronType; \
        neuron.a = _neuronParameterA; \
        neuron.b = _neuronParameterB; \
        neuron.c = _neuronParameterC; \
        neuron.prelu = (const float *)_neuronPrelu.bytes; \
        neuron.channels = _neuronPrelu.length / sizeof(float); \
        return neuron; \
    } \
    - (void)setNeuronType:(MPSCNNNeuronType)neuronType parameterA:(float)parameterA parameterB:(float)parameterB parameterC:(float)parameterC \
    { \
        _neuronType = neuronType; \
        _neuronParameterA = parameterA; \
        _neuronParameterB = parameterB; \
        _neuronParameterC = parameterC; \
    } \
    - (void)setNeuronToPReLUWithParametersA:(NSData *)A \
    { \
        _neuronType = MPSCNNNeuronTypePReLU; \
        _neuronPrelu = [A copy]; \
    } \
    - (MPSCNNNeuronType)neuronType \
    { \
        return _neuronType; \
    } \
    - (float)neuronParameterA \
    { \
        return _neuronParameterA; \
    } \
    - (float)neuronParameterB \
    { \
        return _neuronParameterB; \
    } \
    - (float)neuronParameterC \
    { \
        return _neuronParameterC; \
    }


#import "CharonMPS.h"


@implementation MPSMatrixSum {
    CHARON_MPS_NEURON_IVARS
    NSUInteger _rows, _columns, _count;
    BOOL _transpose;
    MTLOrigin _resultMatrixOrigin;
}

CHARON_MPS_NEURON_COMMON

- (instancetype)initWithDevice:(id<MTLDevice>)device
{
    NSLog(@"MPSMatrixSum: -initWithDevice: names no shape; use -initWithDevice:count:rows:columns:transpose:");
    return nil;
}

- (instancetype)initWithDevice:(id<MTLDevice>)device count:(NSUInteger)count rows:(NSUInteger)rows columns:(NSUInteger)columns transpose:(BOOL)transpose
{
    if ((self = [super initWithDevice:device])) {
        _neuronType = MPSCNNNeuronTypeNone;
        _count = count;
        _rows = rows;
        _columns = columns;
        _transpose = transpose;
        _resultMatrixOrigin = MTLOriginMake(0, 0, 0);
    }
    return self;
}

- (NSUInteger)rows { return _rows; }
- (NSUInteger)columns { return _columns; }
- (NSUInteger)count { return _count; }
- (BOOL)transpose { return _transpose; }

- (MTLOrigin)resultMatrixOrigin
{
    return _resultMatrixOrigin;
}

- (void)setResultMatrixOrigin:(MTLOrigin)origin
{
    _resultMatrixOrigin = origin;
}

- (void)encodeToCommandBuffer:(id<MTLCommandBuffer>)commandBuffer
               sourceMatrices:(NSArray<MPSMatrix *> *)sourceMatrices
                 resultMatrix:(MPSMatrix *)resultMatrix
                  scaleVector:(MPSVector *)scaleVector
                 offsetVector:(MPSVector *)offsetVector
                   biasVector:(MPSVector *)biasVector
                   startIndex:(NSUInteger)startIndex
{
    if (!CharonMPSCommandBufferPermits(commandBuffer))
        return;
    CharonMPSMatrixView out = CharonMPSMatrixViewOf(resultMatrix);
    if (!CharonMPSDataTypeIsElement(out.dataType)) {
        CharonMPSRefuse(@"MPSMatrixSum: the result matrix has a data type that is not one of the eight element types");
        return;
    }
    // A = sum over the sources of alpha[i] * B[i], with alpha the scale vector's components from
    // startIndex, then the bias broadcast across each row, then the neuron, as MPSMatrixSum.h writes
    // the operation out. The offset vector is a packed array of MPSMatrixOffset, each naming where in
    // its source to start reading in rows and in columns.
    CharonMPSVectorView scales = {0, 0, 0, 0, 0, 0};
    if (scaleVector)
        scales = CharonMPSVectorViewOf(scaleVector);
    CharonMPSVectorView bias = {0, 0, 0, 0, 0, 0};
    if (biasVector)
        bias = CharonMPSVectorViewOf(biasVector);
    const MPSMatrixOffset *offsets = NULL;
    if (offsetVector)
        offsets = (const MPSMatrixOffset *)((const char *)[offsetVector.data contents] + offsetVector.offset);
    CharonMPSNeuron neuron = [self charon_mps_neuron];
    // Under transpose the answer is the columns-by-rows shape, and the release writes only what the
    // result descriptor has room for - min(rows, columns) in each direction - and leaves the rest of
    // the destination alone. Measured with a -1 sentinel in every element: for a 2 x 3 result the
    // release writes 11 44 -1 / 22 55 -1, so the third column is a byte it never touched and not a
    // zero it wrote.
    NSUInteger extent = _transpose ? (_rows < _columns ? _rows : _columns) : _rows;
    NSUInteger extentAcross = _transpose ? extent : _columns;
    for (NSUInteger row = 0; row < extent; row++) {
        for (NSUInteger column = 0; column < extentAcross; column++) {
            double sum = 0.0;
            // The factors left from startIndex, and as many sources as there are of them. Measured in
            // tests/backports/host/mpsmatrix/fixtures/start-index-legible.m: with four factors of 2, 4, 8,
            // 16 and sources of 1, 2, 3, 4, start 0 answers 10 = 1*2 + 2*4, start 1 answers 20 = 1*4 + 2*8,
            // start 2 answers 40 = 1*8 + 2*16, start 3 answers 16 = 1*16 alone, and start 4 answers 0.
            // Three sources give the same answers, so the factors are the bound and not the sources.
            NSUInteger factors = scales.length * scales.vectors ? scales.length * scales.vectors : _count;
            NSUInteger pairs = startIndex < factors ? factors - startIndex : 0;
            if (pairs > _count)
                pairs = _count;
            for (NSUInteger index = 0; index < pairs; index++) {
                if (index >= sourceMatrices.count) {
                    CharonMPSRefuse(@"MPSMatrixSum: %lu matrices were named and only %lu were given", (unsigned long)_count, (unsigned long)sourceMatrices.count);
                    return;
                }
                MPSMatrix *source = sourceMatrices[index];
                CharonMPSMatrixView view = CharonMPSMatrixViewOf(source);
                NSUInteger sourceRow = row, sourceColumn = column;
                if (offsets) {
                    sourceRow += offsets[startIndex + index].rowOffset;
                    sourceColumn += offsets[startIndex + index].columnOffset;
                }
                if (_transpose) {
                    NSUInteger swap = sourceRow;
                    sourceRow = sourceColumn;
                    sourceColumn = swap;
                }
                if (!CharonMPSDataTypeIsElement(view.dataType) || !CharonMPSMatrixHolds(&view, 0, sourceRow, sourceColumn, 1, 1)) {
                    CharonMPSRefuse(@"MPSMatrixSum: source %lu does not hold the element (%lu, %lu) the operation names", (unsigned long)index, (unsigned long)sourceRow, (unsigned long)sourceColumn);
                    return;
                }
                double value = CharonMPSLoad(CharonMPSMatrixElement(&view, 0, sourceRow, sourceColumn), view.dataType, 0);
                // startIndex + index is a position in the flat list of scale factors - the header says
                // startIndex is "the starting index into the scale and offset vectors" - so it is the
                // component, and the vector it belongs to is the one holding this many factors. Read as
                // a vector index it walked past the end of a single-vector scale buffer, which is why
                // sum-start-index answered all zeros and no refusal fired.
                double scale = 1.0;
                // The extent, not the count: the scale factors are a run of values in the vector's
                // data, and startIndex + count of them has to fit in the bytes the vector holds. The
                // guard tested scales.length, which is a number of factors somewhere in the vector and
                // not a byte count, so a startIndex at the end of the list passed it and read past.
                // Per factor, not for the whole list: the release uses the factors that are there and
                // stops at the end of the list. With three factors and two sources, startIndex 1 leaves
                // one and the release uses it, and startIndex 2 leaves none and the release answers
                // zeros - so a factor past the end is not read, and its scale stays one.
                {
                    NSUInteger which = (startIndex + index) / MAX((NSUInteger)1, scales.length);
                    NSUInteger component = (startIndex + index) % MAX((NSUInteger)1, scales.length);
                    if (which < scales.vectors)
                        scale = CharonMPSLoad(CharonMPSVectorElement(&scales, which, component), scales.dataType, 0);
                }
                sum += scale * value;
            }
            if (bias.length > column)
                sum += CharonMPSLoad(CharonMPSVectorElement(&bias, 0, column), bias.dataType, 0);
            double y = CharonMPSApplyNeuron(neuron.type, sum, neuron.a, neuron.b, neuron.c, CharonMPSNeuronA(&neuron, column));
            CharonMPSStore(CharonMPSMatrixElement(&out, 0, _resultMatrixOrigin.x + row, _resultMatrixOrigin.y + column), out.dataType, 0, y);
        }
    }
    for (MPSMatrix *source in sourceMatrices)
        CharonMPSConsumeReadCount(source);
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder device:(id<MTLDevice>)device
{
    return [super initWithCoder:aDecoder device:device];
}

@end
