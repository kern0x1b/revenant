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


@implementation MPSMatrixFullyConnected {
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

- (void)encodeToCommandBuffer:(id<MTLCommandBuffer>)commandBuffer
                  inputMatrix:(MPSMatrix *)inputMatrix
                 weightMatrix:(MPSMatrix *)weightMatrix
                   biasVector:(MPSVector *)biasVector
                 resultMatrix:(MPSMatrix *)resultMatrix
{
    if (!RevenantMPSCommandBufferPermits(commandBuffer))
        return;
    RevenantMPSMatrixView in = RevenantMPSMatrixViewOf(inputMatrix), weights = RevenantMPSMatrixViewOf(weightMatrix), out = RevenantMPSMatrixViewOf(resultMatrix);
    if (!RevenantMPSDataTypeIsElement(in.dataType) || !RevenantMPSDataTypeIsElement(weights.dataType) || !RevenantMPSDataTypeIsElement(out.dataType)) {
        RevenantMPSRefuse(@"MPSMatrixFullyConnected: a matrix of a data type that is not one of the eight element types was given");
        return;
    }
    NSUInteger vectorsAvailable = in.rows - _primarySourceMatrixOrigin.x;
    NSUInteger vectors = _sourceNumberOfFeatureVectors < vectorsAvailable ? _sourceNumberOfFeatureVectors : vectorsAvailable;
    NSUInteger inputsAvailable = in.columns - _primarySourceMatrixOrigin.y;
    NSUInteger inputs = _sourceInputFeatureChannels < inputsAvailable ? _sourceInputFeatureChannels : inputsAvailable;
    NSUInteger outputs = _sourceOutputFeatureChannels < weights.columns ? _sourceOutputFeatureChannels : weights.columns;
    RevenantMPSVectorView bias = {0, 0, 0, 0, 0, 0};
    if (biasVector)
        bias = RevenantMPSVectorViewOf(biasVector);
    NSUInteger start, count;
    RevenantMPSBatch(_batchStart, _batchSize, in.matrices, &start, &count);
    count = count < out.matrices ? count : out.matrices;
    for (NSUInteger b = start; b < start + count; b++) {
        if (!RevenantMPSMatrixHolds(&in, b, _primarySourceMatrixOrigin.x, _primarySourceMatrixOrigin.y, vectors, inputs) ||
            !RevenantMPSMatrixHolds(&weights, b, _secondarySourceMatrixOrigin.x, _secondarySourceMatrixOrigin.y, inputs, outputs) ||
            !RevenantMPSMatrixHolds(&out, b, _resultMatrixOrigin.x, _resultMatrixOrigin.y, vectors, outputs)) {
            RevenantMPSRefuse(@"MPSMatrixFullyConnected: a matrix of the batch [%lu, %lu) does not hold the %lux%lu, %lux%lu, %lux%lu region its origin names", (unsigned long)start, (unsigned long)(start + count), (unsigned long)vectors, (unsigned long)inputs, (unsigned long)inputs, (unsigned long)outputs, (unsigned long)vectors, (unsigned long)outputs);
            return;
        }
    }
    RevenantMPSNeuron neuron = [self revenant_mps_neuron];
    for (NSUInteger b = start; b < start + count; b++) {
        for (NSUInteger row = 0; row < vectors; row++) {
            for (NSUInteger column = 0; column < outputs; column++) {
                double sum = 0.0;
                for (NSUInteger k = 0; k < inputs; k++) {
                    double x = RevenantMPSLoad(RevenantMPSMatrixElement(&in, b, _primarySourceMatrixOrigin.x + row, _primarySourceMatrixOrigin.y + k), in.dataType, 0);
                    double w = RevenantMPSLoad(RevenantMPSMatrixElement(&weights, b, _secondarySourceMatrixOrigin.x + k, _secondarySourceMatrixOrigin.y + column), weights.dataType, 0);
                    sum += x * w;
                }
                double b0 = bias.length > column ? RevenantMPSLoad(RevenantMPSVectorElement(&bias, 0, column), bias.dataType, 0) : 0.0;
                double y = RevenantMPSApplyNeuron(neuron.type, _alpha * sum + b0, neuron.a, neuron.b, neuron.c, RevenantMPSNeuronA(&neuron, column));
                RevenantMPSStore(RevenantMPSMatrixElement(&out, b, _resultMatrixOrigin.x + row, _resultMatrixOrigin.y + column), out.dataType, 0, y);
            }
        }
    }
    RevenantMPSConsumeReadCount(inputMatrix);
    RevenantMPSConsumeReadCount(weightMatrix);
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
