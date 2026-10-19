#define REVENANT_MPS_NEURON_IVARS \
    MPSCNNNeuronType _neuronType; \
    float _neuronParameterA, _neuronParameterB, _neuronParameterC; \
    NSData *_neuronPrelu;

#define REVENANT_MPS_NEURON_COMMON \
    - (RevenantMPSNeuron)revenant_mps_neuron \
    { \
        RevenantMPSNeuron neuron; \
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


#import "RevenantMPS.h"


@implementation MPSMatrixFullyConnectedGradient {
    REVENANT_MPS_NEURON_IVARS
    NSUInteger _sourceNumberOfFeatureVectors, _sourceInputFeatureChannels, _sourceOutputFeatureChannels;
    double _alpha;
    MTLOrigin _primarySourceMatrixOrigin, _secondarySourceMatrixOrigin, _resultMatrixOrigin;
    NSUInteger _batchStart, _batchSize;
}

REVENANT_MPS_NEURON_COMMON

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
    if (!RevenantMPSCommandBufferPermits(commandBuffer))
        return;
    RevenantMPSMatrixView gradient = RevenantMPSMatrixViewOf(gradientMatrix), weights = RevenantMPSMatrixViewOf(weightMatrix), out = RevenantMPSMatrixViewOf(resultGradientForDataMatrix);
    if (!RevenantMPSDataTypeIsElement(gradient.dataType) || !RevenantMPSDataTypeIsElement(weights.dataType) || !RevenantMPSDataTypeIsElement(out.dataType)) {
        RevenantMPSRefuse(@"MPSMatrixFullyConnectedGradient: a matrix of a data type that is not one of the eight element types was given");
        return;
    }
    NSUInteger vectors = _sourceNumberOfFeatureVectors < gradient.rows ? _sourceNumberOfFeatureVectors : gradient.rows;
    NSUInteger outputs = _sourceOutputFeatureChannels < gradient.columns ? _sourceOutputFeatureChannels : gradient.columns;
    NSUInteger inputs = _sourceInputFeatureChannels < weights.rows ? _sourceInputFeatureChannels : weights.rows;
    NSUInteger start, count;
    RevenantMPSBatch(_batchStart, _batchSize, gradient.matrices, &start, &count);
    count = count < out.matrices ? count : out.matrices;
    for (NSUInteger b = start; b < start + count; b++) {
        if (!RevenantMPSMatrixHolds(&gradient, b, _primarySourceMatrixOrigin.x, _primarySourceMatrixOrigin.y, vectors, outputs) ||
            !RevenantMPSMatrixHolds(&weights, b, _secondarySourceMatrixOrigin.x, _secondarySourceMatrixOrigin.y, inputs, outputs) ||
            !RevenantMPSMatrixHolds(&out, b, _resultMatrixOrigin.x, _resultMatrixOrigin.y, vectors, inputs)) {
            RevenantMPSRefuse(@"MPSMatrixFullyConnectedGradient: a matrix of the batch [%lu, %lu) does not hold the region its origin names", (unsigned long)start, (unsigned long)(start + count));
            return;
        }
    }
    for (NSUInteger b = start; b < start + count; b++) {
        for (NSUInteger row = 0; row < vectors; row++) {
            for (NSUInteger k = 0; k < inputs; k++) {
                double sum = 0.0;
                for (NSUInteger column = 0; column < outputs; column++) {
                    double g = RevenantMPSLoad(RevenantMPSMatrixElement(&gradient, b, _primarySourceMatrixOrigin.x + row, _primarySourceMatrixOrigin.y + column), gradient.dataType, 0);
                    double w = RevenantMPSLoad(RevenantMPSMatrixElement(&weights, b, _secondarySourceMatrixOrigin.x + k, _secondarySourceMatrixOrigin.y + column), weights.dataType, 0);
                    sum += g * w;
                }
                RevenantMPSStore(RevenantMPSMatrixElement(&out, b, _resultMatrixOrigin.x + row, _resultMatrixOrigin.y + k), out.dataType, 0, _alpha * sum);
            }
        }
    }
    RevenantMPSConsumeReadCount(gradientMatrix);
    RevenantMPSConsumeReadCount(weightMatrix);
}

- (void)encodeGradientForWeightsAndBiasToCommandBuffer:(id<MTLCommandBuffer>)commandBuffer
                                        gradientMatrix:(MPSMatrix *)gradientMatrix
                                           inputMatrix:(MPSMatrix *)inputMatrix
                         resultGradientForWeightMatrix:(MPSMatrix *)resultGradientForWeightMatrix
                           resultGradientForBiasVector:(MPSVector *)resultGradientForBiasVector
{
    if (!RevenantMPSCommandBufferPermits(commandBuffer))
        return;
    RevenantMPSMatrixView gradient = RevenantMPSMatrixViewOf(gradientMatrix), in = RevenantMPSMatrixViewOf(inputMatrix), weights = RevenantMPSMatrixViewOf(resultGradientForWeightMatrix);
    if (!RevenantMPSDataTypeIsElement(gradient.dataType) || !RevenantMPSDataTypeIsElement(in.dataType) || !RevenantMPSDataTypeIsElement(weights.dataType)) {
        RevenantMPSRefuse(@"MPSMatrixFullyConnectedGradient: a matrix of a data type that is not one of the eight element types was given");
        return;
    }
    NSUInteger vectors = _sourceNumberOfFeatureVectors < gradient.rows ? _sourceNumberOfFeatureVectors : gradient.rows;
    NSUInteger outputs = _sourceOutputFeatureChannels < gradient.columns ? _sourceOutputFeatureChannels : gradient.columns;
    NSUInteger inputs = _sourceInputFeatureChannels < in.columns ? _sourceInputFeatureChannels : in.columns;
    RevenantMPSVectorView bias = {0, 0, 0, 0, 0, 0};
    if (resultGradientForBiasVector)
        bias = RevenantMPSVectorViewOf(resultGradientForBiasVector);
    NSUInteger start, count;
    RevenantMPSBatch(_batchStart, _batchSize, gradient.matrices, &start, &count);
    count = count < weights.matrices ? count : weights.matrices;
    for (NSUInteger b = start; b < start + count; b++) {
        if (!RevenantMPSMatrixHolds(&gradient, b, _primarySourceMatrixOrigin.x, _primarySourceMatrixOrigin.y, vectors, outputs) ||
            !RevenantMPSMatrixHolds(&in, b, _secondarySourceMatrixOrigin.x, _secondarySourceMatrixOrigin.y, vectors, inputs) ||
            !RevenantMPSMatrixHolds(&weights, b, _resultMatrixOrigin.x, _resultMatrixOrigin.y, inputs, outputs)) {
            RevenantMPSRefuse(@"MPSMatrixFullyConnectedGradient: a matrix of the batch [%lu, %lu) does not hold the region its origin names", (unsigned long)start, (unsigned long)(start + count));
            return;
        }
    }
    for (NSUInteger b = start; b < start + count; b++) {
        for (NSUInteger k = 0; k < inputs; k++) {
            for (NSUInteger column = 0; column < outputs; column++) {
                double sum = 0.0;
                for (NSUInteger row = 0; row < vectors; row++) {
                    double x = RevenantMPSLoad(RevenantMPSMatrixElement(&in, b, _secondarySourceMatrixOrigin.x + row, _secondarySourceMatrixOrigin.y + k), in.dataType, 0);
                    double g = RevenantMPSLoad(RevenantMPSMatrixElement(&gradient, b, _primarySourceMatrixOrigin.x + row, _primarySourceMatrixOrigin.y + column), gradient.dataType, 0);
                    sum += x * g;
                }
                RevenantMPSStore(RevenantMPSMatrixElement(&weights, b, _resultMatrixOrigin.x + k, _resultMatrixOrigin.y + column), weights.dataType, 0, _alpha * sum);
            }
        }
        for (NSUInteger column = 0; column < outputs; column++) {
            if (bias.length <= column)
                continue;
            double sum = 0.0;
            for (NSUInteger row = 0; row < vectors; row++)
                sum += RevenantMPSLoad(RevenantMPSMatrixElement(&gradient, b, _primarySourceMatrixOrigin.x + row, _primarySourceMatrixOrigin.y + column), gradient.dataType, 0);
            RevenantMPSStore(RevenantMPSVectorElement(&bias, 0, column), bias.dataType, 0, sum);
        }
    }
    RevenantMPSConsumeReadCount(gradientMatrix);
    RevenantMPSConsumeReadCount(inputMatrix);
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
