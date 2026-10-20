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

#include <stdio.h>
#include <stdio.h>

@implementation MPSMatrixBatchNormalizationGradient {
    REVENANT_MPS_NEURON_IVARS
    NSUInteger _sourceNumberOfFeatureVectors, _sourceInputFeatureChannels;
    float _epsilon;
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
        _epsilon = 1.17549435e-38f;
    }
    return self;
}

- (NSUInteger)sourceNumberOfFeatureVectors { return _sourceNumberOfFeatureVectors; }
- (void)setSourceNumberOfFeatureVectors:(NSUInteger)count { _sourceNumberOfFeatureVectors = count; }
- (NSUInteger)sourceInputFeatureChannels { return _sourceInputFeatureChannels; }
- (void)setSourceInputFeatureChannels:(NSUInteger)channels { _sourceInputFeatureChannels = channels; }
- (float)epsilon { return _epsilon; }
- (void)setEpsilon:(float)epsilon { _epsilon = epsilon; }

- (void)encodeToCommandBuffer:(id<MTLCommandBuffer>)commandBuffer
               gradientMatrix:(MPSMatrix *)gradientMatrix
                  inputMatrix:(MPSMatrix *)inputMatrix
                   meanVector:(MPSVector *)meanVector
               varianceVector:(MPSVector *)varianceVector
                  gammaVector:(MPSVector *)gammaVector
                   betaVector:(MPSVector *)betaVector
  resultGradientForDataMatrix:(MPSMatrix *)resultGradientForDataMatrix
 resultGradientForGammaVector:(MPSVector *)resultGradientForGammaVector
  resultGradientForBetaVector:(MPSVector *)resultGradientForBetaVector
{
    if (!RevenantMPSCommandBufferPermits(commandBuffer))
        return;
    RevenantMPSMatrixView gradient = RevenantMPSMatrixViewOf(gradientMatrix), in = RevenantMPSMatrixViewOf(inputMatrix), out = RevenantMPSMatrixViewOf(resultGradientForDataMatrix);
    if (!RevenantMPSDataTypeIsElement(gradient.dataType) || !RevenantMPSDataTypeIsElement(in.dataType) || !RevenantMPSDataTypeIsElement(out.dataType)) {
        RevenantMPSRefuse(@"MPSMatrixBatchNormalizationGradient: a matrix of a data type that is not one of the eight element types was given");
        return;
    }
    NSUInteger available = in.rows - _secondarySourceMatrixOrigin.x;
    NSUInteger vectors = _sourceNumberOfFeatureVectors < available ? _sourceNumberOfFeatureVectors : available;
    NSUInteger columns = in.columns - _secondarySourceMatrixOrigin.y;
    NSUInteger channels = _sourceInputFeatureChannels < columns ? _sourceInputFeatureChannels : columns;
    RevenantMPSVectorView mean = RevenantMPSVectorViewOf(meanVector), variance = RevenantMPSVectorViewOf(varianceVector);
    RevenantMPSVectorView gamma = {0, 0, 0, 0, 0, 0};
    if (gammaVector)
        gamma = RevenantMPSVectorViewOf(gammaVector);
    NSUInteger start, count;
    RevenantMPSBatch(_batchStart, _batchSize, in.matrices, &start, &count);
    count = count < gradient.matrices ? count : gradient.matrices;
    count = count < out.matrices ? count : out.matrices;
    for (NSUInteger b = start; b < start + count; b++) {
        if (!RevenantMPSMatrixHolds(&gradient, b, _primarySourceMatrixOrigin.x, _primarySourceMatrixOrigin.y, vectors, channels) ||
            !RevenantMPSMatrixHolds(&in, b, _secondarySourceMatrixOrigin.x, _secondarySourceMatrixOrigin.y, vectors, channels) ||
            !RevenantMPSMatrixHolds(&out, b, _resultMatrixOrigin.x, _resultMatrixOrigin.y, vectors, channels)) {
            RevenantMPSRefuse(@"MPSMatrixBatchNormalizationGradient: a matrix of the batch [%lu, %lu) does not hold the %lux%lu region its origin names", (unsigned long)start, (unsigned long)(start + count), (unsigned long)vectors, (unsigned long)channels);
            return;
        }
    }
    for (NSUInteger b = start; b < start + count; b++) {
        for (NSUInteger column = 0; column < channels; column++) {
            double m = mean.length > column ? RevenantMPSLoad(RevenantMPSVectorElement(&mean, 0, column), mean.dataType, 0) : 0.0;
            double v = variance.length > column ? RevenantMPSLoad(RevenantMPSVectorElement(&variance, 0, column), variance.dataType, 0) : 0.0;
            double g = gamma.length > column ? RevenantMPSLoad(RevenantMPSVectorElement(&gamma, 0, column), gamma.dataType, 0) : 1.0;
#ifdef REVENANT_BN_TRACE
            fprintf(stderr, "BNP ch%lu  mean %g variance %g gamma %g  -> divisor %g  rowBytes(in) %lu\n",
                    (unsigned long)column, m, v, g, g / sqrt(v + (double)_epsilon),
                    (unsigned long)in.rowBytes);
#endif
            double divisor = g / sqrt(v + (double)_epsilon);
            double sum = 0.0, gammaGradient = 0.0, betaGradient = 0.0;
            for (NSUInteger row = 0; row < vectors; row++) {
                double d = RevenantMPSLoad(RevenantMPSMatrixElement(&gradient, b, _primarySourceMatrixOrigin.x + row, _primarySourceMatrixOrigin.y + column), gradient.dataType, 0);
                double x = RevenantMPSLoad(RevenantMPSMatrixElement(&in, b, _secondarySourceMatrixOrigin.x + row, _secondarySourceMatrixOrigin.y + column), in.dataType, 0);
                double normalised = (x - m) / sqrt(v + (double)_epsilon);
                sum += d;
                gammaGradient += d * normalised;
                betaGradient += d;
            }
            double meanGradient = vectors ? sum / (double)vectors : 0.0;
            double scaledSum = vectors ? sum / (double)vectors : 0.0;
            for (NSUInteger row = 0; row < vectors; row++) {
                double d = RevenantMPSLoad(RevenantMPSMatrixElement(&gradient, b, _primarySourceMatrixOrigin.x + row, _primarySourceMatrixOrigin.y + column), gradient.dataType, 0);
                double x = RevenantMPSLoad(RevenantMPSMatrixElement(&in, b, _secondarySourceMatrixOrigin.x + row, _secondarySourceMatrixOrigin.y + column), in.dataType, 0);
                double normalised = (x - m) / sqrt(v + (double)_epsilon);
                double gradientForData = divisor * (d - meanGradient - normalised * scaledSum);
                RevenantMPSStore(RevenantMPSMatrixElement(&out, b, _resultMatrixOrigin.x + row, _resultMatrixOrigin.y + column), out.dataType, 0, gradientForData);
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
    MPSMatrixBatchNormalizationGradient *copy = [super copyWithZone:zone device:device];
    copy->_epsilon = _epsilon;
    copy->_neuronType = _neuronType;
    return copy;
}

@end
