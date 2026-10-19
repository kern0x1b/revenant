// MPSMatrixFullyConnected, from the header of the SDK of iOS 16.4. One object per release: the band machinery keeps an
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


@implementation MPSMatrixFullyConnected {
    CHARON_MPS_NEURON_IVARS
    NSUInteger _sourceNumberOfFeatureVectors, _sourceInputFeatureChannels, _sourceOutputFeatureChannels;
    double _alpha;
    MTLOrigin _primarySourceMatrixOrigin, _secondarySourceMatrixOrigin, _resultMatrixOrigin;
    NSUInteger _batchStart, _batchSize;
}

CHARON_MPS_NEURON_COMMON

- (instancetype)initWithDevice:(id<MTLDevice>)device
{
    if ((self = [super initWithDevice:device])) {
        _neuronType = MPSCNNNeuronTypeNone;
        _sourceNumberOfFeatureVectors = NSUIntegerMax;
        _sourceInputFeatureChannels = NSUIntegerMax;
        _sourceOutputFeatureChannels = NSUIntegerMax;
        _alpha = 1.0;
    }
    return self;
}

- (NSUInteger)sourceNumberOfFeatureVectors { return _sourceNumberOfFeatureVectors; }
- (void)setSourceNumberOfFeatureVectors:(NSUInteger)count { _sourceNumberOfFeatureVectors = count; }
- (NSUInteger)sourceInputFeatureChannels { return _sourceInputFeatureChannels; }
- (void)setSourceInputFeatureChannels:(NSUInteger)channels { _sourceInputFeatureChannels = channels; }
- (NSUInteger)sourceOutputFeatureChannels { return _sourceOutputFeatureChannels; }
- (void)setSourceOutputFeatureChannels:(NSUInteger)channels { _sourceOutputFeatureChannels = channels; }
- (double)alpha { return _alpha; }
- (void)setAlpha:(double)alpha { _alpha = alpha; }

- (void)encodeToCommandBuffer:(id<MTLCommandBuffer>)commandBuffer
                  inputMatrix:(MPSMatrix *)inputMatrix
                 weightMatrix:(MPSMatrix *)weightMatrix
                   biasVector:(MPSVector *)biasVector
                 resultMatrix:(MPSMatrix *)resultMatrix
{
    if (!CharonMPSCommandBufferPermits(commandBuffer))
        return;
    CharonMPSMatrixView in = CharonMPSMatrixViewOf(inputMatrix), weights = CharonMPSMatrixViewOf(weightMatrix), out = CharonMPSMatrixViewOf(resultMatrix);
    if (!CharonMPSDataTypeIsElement(in.dataType) || !CharonMPSDataTypeIsElement(weights.dataType) || !CharonMPSDataTypeIsElement(out.dataType)) {
        CharonMPSRefuse(@"MPSMatrixFullyConnected: a matrix of a data type that is not one of the eight element types was given");
        return;
    }
    // y = neuron(alpha * x * W + bias). The input holds one feature vector per row, the weight matrix
    // is inputFeatureChannels x outputFeatureChannels, and the bias is indexed by the output channel.
    NSUInteger vectorsAvailable = in.rows - _primarySourceMatrixOrigin.x;
    NSUInteger vectors = _sourceNumberOfFeatureVectors < vectorsAvailable ? _sourceNumberOfFeatureVectors : vectorsAvailable;
    NSUInteger inputsAvailable = in.columns - _primarySourceMatrixOrigin.y;
    NSUInteger inputs = _sourceInputFeatureChannels < inputsAvailable ? _sourceInputFeatureChannels : inputsAvailable;
    NSUInteger outputs = _sourceOutputFeatureChannels < weights.columns ? _sourceOutputFeatureChannels : weights.columns;
    CharonMPSVectorView bias = {0, 0, 0, 0, 0, 0};
    if (biasVector)
        bias = CharonMPSVectorViewOf(biasVector);
    NSUInteger start, count;
    CharonMPSBatch(_batchStart, _batchSize, in.matrices, &start, &count);
    count = count < out.matrices ? count : out.matrices;
    for (NSUInteger b = start; b < start + count; b++) {
        if (!CharonMPSMatrixHolds(&in, b, _primarySourceMatrixOrigin.x, _primarySourceMatrixOrigin.y, vectors, inputs) ||
            !CharonMPSMatrixHolds(&weights, b, _secondarySourceMatrixOrigin.x, _secondarySourceMatrixOrigin.y, inputs, outputs) ||
            !CharonMPSMatrixHolds(&out, b, _resultMatrixOrigin.x, _resultMatrixOrigin.y, vectors, outputs)) {
            CharonMPSRefuse(@"MPSMatrixFullyConnected: a matrix of the batch [%lu, %lu) does not hold the %lux%lu, %lux%lu, %lux%lu region its origin names", (unsigned long)start, (unsigned long)(start + count), (unsigned long)vectors, (unsigned long)inputs, (unsigned long)inputs, (unsigned long)outputs, (unsigned long)vectors, (unsigned long)outputs);
            return;
        }
    }
    CharonMPSNeuron neuron = [self charon_mps_neuron];
    for (NSUInteger b = start; b < start + count; b++) {
        for (NSUInteger row = 0; row < vectors; row++) {
            for (NSUInteger column = 0; column < outputs; column++) {
                double sum = 0.0;
                for (NSUInteger k = 0; k < inputs; k++) {
                    double x = CharonMPSLoad(CharonMPSMatrixElement(&in, b, _primarySourceMatrixOrigin.x + row, _primarySourceMatrixOrigin.y + k), in.dataType, 0);
                    double w = CharonMPSLoad(CharonMPSMatrixElement(&weights, b, _secondarySourceMatrixOrigin.x + k, _secondarySourceMatrixOrigin.y + column), weights.dataType, 0);
                    sum += x * w;
                }
                double b0 = bias.length > column ? CharonMPSLoad(CharonMPSVectorElement(&bias, 0, column), bias.dataType, 0) : 0.0;
                double y = CharonMPSApplyNeuron(neuron.type, _alpha * sum + b0, neuron.a, neuron.b, neuron.c, CharonMPSNeuronA(&neuron, column));
                CharonMPSStore(CharonMPSMatrixElement(&out, b, _resultMatrixOrigin.x + row, _resultMatrixOrigin.y + column), out.dataType, 0, y);
            }
        }
    }
    CharonMPSConsumeReadCount(inputMatrix);
    CharonMPSConsumeReadCount(weightMatrix);
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder device:(id<MTLDevice>)device
{
    return [super initWithCoder:aDecoder device:device];
}

- (instancetype)copyWithZone:(NSZone *)zone device:(id<MTLDevice>)device
{
    MPSMatrixFullyConnected *copy = [super copyWithZone:zone device:device];
    copy->_neuronType = _neuronType;
    copy->_neuronPrelu = _neuronPrelu;
    copy->_alpha = _alpha;
    copy->_sourceNumberOfFeatureVectors = _sourceNumberOfFeatureVectors;
    copy->_sourceInputFeatureChannels = _sourceInputFeatureChannels;
    copy->_sourceOutputFeatureChannels = _sourceOutputFeatureChannels;
    return copy;
}

@end
