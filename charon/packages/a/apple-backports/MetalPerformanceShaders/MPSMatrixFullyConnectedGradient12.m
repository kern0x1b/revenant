// MPSMatrixFullyConnectedGradient, from the header of the SDK of iOS 16.4. One object per release: the band machinery keeps an
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


@implementation MPSMatrixFullyConnectedGradient {
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

- (void)encodeGradientForDataToCommandBuffer:(id<MTLCommandBuffer>)commandBuffer
                              gradientMatrix:(MPSMatrix *)gradientMatrix
                                weightMatrix:(MPSMatrix *)weightMatrix
                 resultGradientForDataMatrix:(MPSMatrix *)resultGradientForDataMatrix
{
    if (!CharonMPSCommandBufferPermits(commandBuffer))
        return;
    CharonMPSMatrixView gradient = CharonMPSMatrixViewOf(gradientMatrix), weights = CharonMPSMatrixViewOf(weightMatrix), out = CharonMPSMatrixViewOf(resultGradientForDataMatrix);
    if (!CharonMPSDataTypeIsElement(gradient.dataType) || !CharonMPSDataTypeIsElement(weights.dataType) || !CharonMPSDataTypeIsElement(out.dataType)) {
        CharonMPSRefuse(@"MPSMatrixFullyConnectedGradient: a matrix of a data type that is not one of the eight element types was given");
        return;
    }
    // The gradient with respect to the input of y = alpha * x * W + bias is dX = alpha * dY * W^T: each
    // input channel's gradient is the incoming gradient of every output channel scaled by that weight.
    NSUInteger vectors = _sourceNumberOfFeatureVectors < gradient.rows ? _sourceNumberOfFeatureVectors : gradient.rows;
    NSUInteger outputs = _sourceOutputFeatureChannels < gradient.columns ? _sourceOutputFeatureChannels : gradient.columns;
    NSUInteger inputs = _sourceInputFeatureChannels < weights.rows ? _sourceInputFeatureChannels : weights.rows;
    NSUInteger start, count;
    CharonMPSBatch(_batchStart, _batchSize, gradient.matrices, &start, &count);
    count = count < out.matrices ? count : out.matrices;
    for (NSUInteger b = start; b < start + count; b++) {
        if (!CharonMPSMatrixHolds(&gradient, b, _primarySourceMatrixOrigin.x, _primarySourceMatrixOrigin.y, vectors, outputs) ||
            !CharonMPSMatrixHolds(&weights, b, _secondarySourceMatrixOrigin.x, _secondarySourceMatrixOrigin.y, inputs, outputs) ||
            !CharonMPSMatrixHolds(&out, b, _resultMatrixOrigin.x, _resultMatrixOrigin.y, vectors, inputs)) {
            CharonMPSRefuse(@"MPSMatrixFullyConnectedGradient: a matrix of the batch [%lu, %lu) does not hold the region its origin names", (unsigned long)start, (unsigned long)(start + count));
            return;
        }
    }
    for (NSUInteger b = start; b < start + count; b++) {
        for (NSUInteger row = 0; row < vectors; row++) {
            for (NSUInteger k = 0; k < inputs; k++) {
                double sum = 0.0;
                for (NSUInteger column = 0; column < outputs; column++) {
                    double g = CharonMPSLoad(CharonMPSMatrixElement(&gradient, b, _primarySourceMatrixOrigin.x + row, _primarySourceMatrixOrigin.y + column), gradient.dataType, 0);
                    double w = CharonMPSLoad(CharonMPSMatrixElement(&weights, b, _secondarySourceMatrixOrigin.x + k, _secondarySourceMatrixOrigin.y + column), weights.dataType, 0);
                    sum += g * w;
                }
                CharonMPSStore(CharonMPSMatrixElement(&out, b, _resultMatrixOrigin.x + row, _resultMatrixOrigin.y + k), out.dataType, 0, _alpha * sum);
            }
        }
    }
    CharonMPSConsumeReadCount(gradientMatrix);
    CharonMPSConsumeReadCount(weightMatrix);
}

- (void)encodeGradientForWeightsAndBiasToCommandBuffer:(id<MTLCommandBuffer>)commandBuffer
                                        gradientMatrix:(MPSMatrix *)gradientMatrix
                                           inputMatrix:(MPSMatrix *)inputMatrix
                         resultGradientForWeightMatrix:(MPSMatrix *)resultGradientForWeightMatrix
                           resultGradientForBiasVector:(MPSVector *)resultGradientForBiasVector
{
    if (!CharonMPSCommandBufferPermits(commandBuffer))
        return;
    CharonMPSMatrixView gradient = CharonMPSMatrixViewOf(gradientMatrix), in = CharonMPSMatrixViewOf(inputMatrix), weights = CharonMPSMatrixViewOf(resultGradientForWeightMatrix);
    if (!CharonMPSDataTypeIsElement(gradient.dataType) || !CharonMPSDataTypeIsElement(in.dataType) || !CharonMPSDataTypeIsElement(weights.dataType)) {
        CharonMPSRefuse(@"MPSMatrixFullyConnectedGradient: a matrix of a data type that is not one of the eight element types was given");
        return;
    }
    // The gradient with respect to the weights is dW = alpha * X^T * dY, one row of the input per
    // feature vector, and the gradient with respect to the bias is the column sums of dY.
    NSUInteger vectors = _sourceNumberOfFeatureVectors < gradient.rows ? _sourceNumberOfFeatureVectors : gradient.rows;
    NSUInteger outputs = _sourceOutputFeatureChannels < gradient.columns ? _sourceOutputFeatureChannels : gradient.columns;
    NSUInteger inputs = _sourceInputFeatureChannels < in.columns ? _sourceInputFeatureChannels : in.columns;
    CharonMPSVectorView bias = {0, 0, 0, 0, 0, 0};
    if (resultGradientForBiasVector)
        bias = CharonMPSVectorViewOf(resultGradientForBiasVector);
    NSUInteger start, count;
    CharonMPSBatch(_batchStart, _batchSize, gradient.matrices, &start, &count);
    count = count < weights.matrices ? count : weights.matrices;
    for (NSUInteger b = start; b < start + count; b++) {
        if (!CharonMPSMatrixHolds(&gradient, b, _primarySourceMatrixOrigin.x, _primarySourceMatrixOrigin.y, vectors, outputs) ||
            !CharonMPSMatrixHolds(&in, b, _secondarySourceMatrixOrigin.x, _secondarySourceMatrixOrigin.y, vectors, inputs) ||
            !CharonMPSMatrixHolds(&weights, b, _resultMatrixOrigin.x, _resultMatrixOrigin.y, inputs, outputs)) {
            CharonMPSRefuse(@"MPSMatrixFullyConnectedGradient: a matrix of the batch [%lu, %lu) does not hold the region its origin names", (unsigned long)start, (unsigned long)(start + count));
            return;
        }
    }
    for (NSUInteger b = start; b < start + count; b++) {
        for (NSUInteger k = 0; k < inputs; k++) {
            for (NSUInteger column = 0; column < outputs; column++) {
                double sum = 0.0;
                for (NSUInteger row = 0; row < vectors; row++) {
                    double x = CharonMPSLoad(CharonMPSMatrixElement(&in, b, _secondarySourceMatrixOrigin.x + row, _secondarySourceMatrixOrigin.y + k), in.dataType, 0);
                    double g = CharonMPSLoad(CharonMPSMatrixElement(&gradient, b, _primarySourceMatrixOrigin.x + row, _primarySourceMatrixOrigin.y + column), gradient.dataType, 0);
                    sum += x * g;
                }
                CharonMPSStore(CharonMPSMatrixElement(&weights, b, _resultMatrixOrigin.x + k, _resultMatrixOrigin.y + column), weights.dataType, 0, _alpha * sum);
            }
        }
        for (NSUInteger column = 0; column < outputs; column++) {
            if (bias.length <= column)
                continue;
            double sum = 0.0;
            for (NSUInteger row = 0; row < vectors; row++)
                sum += CharonMPSLoad(CharonMPSMatrixElement(&gradient, b, _primarySourceMatrixOrigin.x + row, _primarySourceMatrixOrigin.y + column), gradient.dataType, 0);
            CharonMPSStore(CharonMPSVectorElement(&bias, 0, column), bias.dataType, 0, sum);
        }
    }
    CharonMPSConsumeReadCount(gradientMatrix);
    CharonMPSConsumeReadCount(inputMatrix);
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder device:(id<MTLDevice>)device
{
    return [super initWithCoder:aDecoder device:device];
}

- (instancetype)copyWithZone:(NSZone *)zone device:(id<MTLDevice>)device
{
    MPSMatrixFullyConnectedGradient *copy = [super copyWithZone:zone device:device];
    copy->_alpha = _alpha;
    copy->_sourceNumberOfFeatureVectors = _sourceNumberOfFeatureVectors;
    copy->_sourceInputFeatureChannels = _sourceInputFeatureChannels;
    copy->_sourceOutputFeatureChannels = _sourceOutputFeatureChannels;
    return copy;
}

@end
