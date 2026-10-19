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


@implementation MPSMatrixNeuronGradient {
    REVENANT_MPS_NEURON_IVARS
    NSUInteger _sourceNumberOfFeatureVectors, _sourceInputFeatureChannels;
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
                gradientMatrix:(MPSMatrix *)gradientMatrix
                   inputMatrix:(MPSMatrix *)inputMatrix
                    biasVector:(MPSVector *)biasVector
  resultGradientForDataMatrix:(MPSMatrix *)resultGradientForDataMatrix
  resultGradientForBiasVector:(MPSVector *)resultGradientForBiasVector
{
    if (!RevenantMPSCommandBufferPermits(commandBuffer))
        return;
    RevenantMPSMatrixView gradient = RevenantMPSMatrixViewOf(gradientMatrix), in = RevenantMPSMatrixViewOf(inputMatrix), out = RevenantMPSMatrixViewOf(resultGradientForDataMatrix);
    if (!RevenantMPSDataTypeIsElement(gradient.dataType) || !RevenantMPSDataTypeIsElement(in.dataType) || !RevenantMPSDataTypeIsElement(out.dataType)) {
        RevenantMPSRefuse(@"MPSMatrixNeuronGradient: a matrix of a data type that is not one of the eight element types was given");
        return;
    }
    NSUInteger available = in.rows - _secondarySourceMatrixOrigin.x;
    NSUInteger vectors = _sourceNumberOfFeatureVectors < available ? _sourceNumberOfFeatureVectors : available;
    NSUInteger columns = in.columns - _secondarySourceMatrixOrigin.y;
    NSUInteger channels = _sourceInputFeatureChannels < columns ? _sourceInputFeatureChannels : columns;
    RevenantMPSVectorView bias = {0, 0, 0, 0, 0, 0}, biasGradient = {0, 0, 0, 0, 0, 0};
    if (biasVector)
        bias = RevenantMPSVectorViewOf(biasVector);
    if (resultGradientForBiasVector)
        biasGradient = RevenantMPSVectorViewOf(resultGradientForBiasVector);
    NSUInteger start, count;
    RevenantMPSBatch(_batchStart, _batchSize, in.matrices, &start, &count);
    count = count < gradient.matrices ? count : gradient.matrices;
    count = count < out.matrices ? count : out.matrices;
    for (NSUInteger b = start; b < start + count; b++) {
        if (!RevenantMPSMatrixHolds(&gradient, b, _primarySourceMatrixOrigin.x, _primarySourceMatrixOrigin.y, vectors, channels) ||
            !RevenantMPSMatrixHolds(&in, b, _secondarySourceMatrixOrigin.x, _secondarySourceMatrixOrigin.y, vectors, channels) ||
            !RevenantMPSMatrixHolds(&out, b, _resultMatrixOrigin.x, _resultMatrixOrigin.y, vectors, channels)) {
            RevenantMPSRefuse(@"MPSMatrixNeuronGradient: a matrix of the batch [%lu, %lu) does not hold the %lux%lu region its origin names", (unsigned long)start, (unsigned long)(start + count), (unsigned long)vectors, (unsigned long)channels);
            return;
        }
    }
    RevenantMPSNeuron neuron = [self revenant_mps_neuron];
    for (NSUInteger b = start; b < start + count; b++) {
        for (NSUInteger column = 0; column < channels; column++) {
            double total = 0.0;
            for (NSUInteger row = 0; row < vectors; row++) {
                double g = RevenantMPSLoad(RevenantMPSMatrixElement(&gradient, b, _primarySourceMatrixOrigin.x + row, _primarySourceMatrixOrigin.y + column), gradient.dataType, 0);
                double x = RevenantMPSLoad(RevenantMPSMatrixElement(&in, b, _secondarySourceMatrixOrigin.x + row, _secondarySourceMatrixOrigin.y + column), in.dataType, 0);
                double b0 = bias.length > column ? RevenantMPSLoad(RevenantMPSVectorElement(&bias, 0, column), bias.dataType, 0) : 0.0;
                double intermediate = _alpha * x + b0;
                double y = RevenantMPSApplyNeuron(neuron.type, intermediate, neuron.a, neuron.b, neuron.c, RevenantMPSNeuronA(&neuron, column));
                double d = RevenantMPSApplyNeuronGradient(neuron.type, intermediate, y, neuron.a, neuron.b, neuron.c, RevenantMPSNeuronA(&neuron, column));
                total += g * d;
            }
            if (biasGradient.length > column)
                RevenantMPSStore(RevenantMPSVectorElement(&biasGradient, 0, column), biasGradient.dataType, 0, total);
        }
        for (NSUInteger row = 0; row < vectors; row++) {
            for (NSUInteger column = 0; column < channels; column++) {
                double g = RevenantMPSLoad(RevenantMPSMatrixElement(&gradient, b, _primarySourceMatrixOrigin.x + row, _primarySourceMatrixOrigin.y + column), gradient.dataType, 0);
                double x = RevenantMPSLoad(RevenantMPSMatrixElement(&in, b, _secondarySourceMatrixOrigin.x + row, _secondarySourceMatrixOrigin.y + column), in.dataType, 0);
                double b0 = bias.length > column ? RevenantMPSLoad(RevenantMPSVectorElement(&bias, 0, column), bias.dataType, 0) : 0.0;
                double intermediate = _alpha * x + b0;
                double y = RevenantMPSApplyNeuron(neuron.type, intermediate, neuron.a, neuron.b, neuron.c, RevenantMPSNeuronA(&neuron, column));
                double d = RevenantMPSApplyNeuronGradient(neuron.type, intermediate, y, neuron.a, neuron.b, neuron.c, RevenantMPSNeuronA(&neuron, column));
                RevenantMPSStore(RevenantMPSMatrixElement(&out, b, _resultMatrixOrigin.x + row, _resultMatrixOrigin.y + column), out.dataType, 0, g * d * _alpha);
            }
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
    MPSMatrixNeuronGradient *copy = [super copyWithZone:zone device:device];
    copy->_neuronType = _neuronType;
    copy->_neuronParameterA = _neuronParameterA;
    copy->_neuronParameterB = _neuronParameterB;
    copy->_neuronParameterC = _neuronParameterC;
    copy->_neuronPrelu = _neuronPrelu;
    copy->_alpha = _alpha;
    return copy;
}

@end
