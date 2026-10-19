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
    NSUInteger extent = _transpose ? (_rows < _columns ? _rows : _columns) : _rows;
    NSUInteger extentAcross = _transpose ? extent : _columns;
    for (NSUInteger row = 0; row < extent; row++) {
        for (NSUInteger column = 0; column < extentAcross; column++) {
            double sum = 0.0;
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
                double scale = 1.0;
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
