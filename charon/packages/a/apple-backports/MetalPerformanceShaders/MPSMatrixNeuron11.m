// MPSMatrixNeuron, from the header of the SDK of iOS 16.4. One object per release: the band machinery keeps an
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


@implementation MPSMatrixNeuron {
    CHARON_MPS_NEURON_IVARS
    NSUInteger _sourceNumberOfFeatureVectors, _sourceInputFeatureChannels;
    double _alpha;
    MTLOrigin _sourceMatrixOrigin, _resultMatrixOrigin;
    NSUInteger _batchStart, _batchSize;
}

CHARON_MPS_NEURON_COMMON

- (instancetype)initWithDevice:(id<MTLDevice>)device
{
    if ((self = [super initWithDevice:device])) {
        _neuronType = MPSCNNNeuronTypeNone;
        _sourceNumberOfFeatureVectors = NSUIntegerMax;
        _sourceInputFeatureChannels = NSUIntegerMax;
        _alpha = 1.0;
    }
    return self;
}

- (NSUInteger)sourceNumberOfFeatureVectors
{
    return _sourceNumberOfFeatureVectors;
}

- (void)setSourceNumberOfFeatureVectors:(NSUInteger)count
{
    _sourceNumberOfFeatureVectors = count;
}

- (NSUInteger)sourceInputFeatureChannels
{
    return _sourceInputFeatureChannels;
}

- (void)setSourceInputFeatureChannels:(NSUInteger)channels
{
    _sourceInputFeatureChannels = channels;
}

- (double)alpha
{
    return _alpha;
}

- (void)setAlpha:(double)alpha
{
    _alpha = alpha;
}

- (void)encodeToCommandBuffer:(id<MTLCommandBuffer>)commandBuffer
                  inputMatrix:(MPSMatrix *)inputMatrix
                   biasVector:(MPSVector *)biasVector
                 resultMatrix:(MPSMatrix *)resultMatrix
{
    if (!CharonMPSCommandBufferPermits(commandBuffer))
        return;
    CharonMPSMatrixView in = CharonMPSMatrixViewOf(inputMatrix), out = CharonMPSMatrixViewOf(resultMatrix);
    if (!CharonMPSDataTypeIsElement(in.dataType) || !CharonMPSDataTypeIsElement(out.dataType)) {
        CharonMPSRefuse(@"MPSMatrixNeuron: a matrix of a data type that is not one of the eight element types was given");
        return;
    }
    // y = neuron(alpha * x + bias), the bias broadcast across the rows and indexed by the column, which
    // is the channel. The counts are the header's: as many feature vectors and channels as the matrix
    // holds from the source origin, and no more than the caller asked for.
    NSUInteger available = in.rows - _sourceMatrixOrigin.x;
    NSUInteger vectors = _sourceNumberOfFeatureVectors < available ? _sourceNumberOfFeatureVectors : available;
    NSUInteger columns = in.columns - _sourceMatrixOrigin.y;
    NSUInteger channels = _sourceInputFeatureChannels < columns ? _sourceInputFeatureChannels : columns;
    CharonMPSVectorView bias = {0, 0, 0, 0, 0, 0};
    if (biasVector)
        bias = CharonMPSVectorViewOf(biasVector);
    NSUInteger start, count;
    CharonMPSBatch(_batchStart, _batchSize, in.matrices, &start, &count);
    count = count < out.matrices ? count : out.matrices;
    for (NSUInteger b = start; b < start + count; b++) {
        if (!CharonMPSMatrixHolds(&in, b, _sourceMatrixOrigin.x, _sourceMatrixOrigin.y, vectors, channels) ||
            !CharonMPSMatrixHolds(&out, b, _resultMatrixOrigin.x, _resultMatrixOrigin.y, vectors, channels)) {
            CharonMPSRefuse(@"MPSMatrixNeuron: a matrix of the batch [%lu, %lu) does not hold the %lux%lu region its origin names", (unsigned long)start, (unsigned long)(start + count), (unsigned long)vectors, (unsigned long)channels);
            return;
        }
    }
    CharonMPSNeuron neuron = [self charon_mps_neuron];
    for (NSUInteger b = start; b < start + count; b++) {
        for (NSUInteger row = 0; row < vectors; row++) {
            for (NSUInteger column = 0; column < channels; column++) {
                double x = CharonMPSLoad(CharonMPSMatrixElement(&in, b, _sourceMatrixOrigin.x + row, _sourceMatrixOrigin.y + column), in.dataType, 0);
                double b0 = bias.length > column ? CharonMPSLoad(CharonMPSVectorElement(&bias, 0, column), bias.dataType, 0) : 0.0;
                double y = CharonMPSApplyNeuron(neuron.type, _alpha * x + b0, neuron.a, neuron.b, neuron.c, CharonMPSNeuronA(&neuron, column));
                CharonMPSStore(CharonMPSMatrixElement(&out, b, _resultMatrixOrigin.x + row, _resultMatrixOrigin.y + column), out.dataType, 0, y);
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
    MPSMatrixNeuron *copy = [super copyWithZone:zone device:device];
    copy->_neuronType = _neuronType;
    copy->_neuronParameterA = _neuronParameterA;
    copy->_neuronParameterB = _neuronParameterB;
    copy->_neuronParameterC = _neuronParameterC;
    copy->_neuronPrelu = _neuronPrelu;
    copy->_sourceNumberOfFeatureVectors = _sourceNumberOfFeatureVectors;
    copy->_sourceInputFeatureChannels = _sourceInputFeatureChannels;
    copy->_alpha = _alpha;
    return copy;
}

@end
