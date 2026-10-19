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

#include <stdio.h>
#include <stdio.h>

@implementation MPSMatrixBatchNormalizationGradient {
    CHARON_MPS_NEURON_IVARS
    NSUInteger _sourceNumberOfFeatureVectors, _sourceInputFeatureChannels;
    float _epsilon;
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
    if (!CharonMPSCommandBufferPermits(commandBuffer))
        return;
    CharonMPSMatrixView gradient = CharonMPSMatrixViewOf(gradientMatrix), in = CharonMPSMatrixViewOf(inputMatrix), out = CharonMPSMatrixViewOf(resultGradientForDataMatrix);
    if (!CharonMPSDataTypeIsElement(gradient.dataType) || !CharonMPSDataTypeIsElement(in.dataType) || !CharonMPSDataTypeIsElement(out.dataType)) {
        CharonMPSRefuse(@"MPSMatrixBatchNormalizationGradient: a matrix of a data type that is not one of the eight element types was given");
        return;
    }
    NSUInteger available = in.rows - _secondarySourceMatrixOrigin.x;
    NSUInteger vectors = _sourceNumberOfFeatureVectors < available ? _sourceNumberOfFeatureVectors : available;
    NSUInteger columns = in.columns - _secondarySourceMatrixOrigin.y;
    NSUInteger channels = _sourceInputFeatureChannels < columns ? _sourceInputFeatureChannels : columns;
    CharonMPSVectorView mean = CharonMPSVectorViewOf(meanVector), variance = CharonMPSVectorViewOf(varianceVector);
    CharonMPSVectorView gamma = {0, 0, 0, 0, 0, 0};
    if (gammaVector)
        gamma = CharonMPSVectorViewOf(gammaVector);
    NSUInteger start, count;
    CharonMPSBatch(_batchStart, _batchSize, in.matrices, &start, &count);
    count = count < gradient.matrices ? count : gradient.matrices;
    count = count < out.matrices ? count : out.matrices;
    for (NSUInteger b = start; b < start + count; b++) {
        if (!CharonMPSMatrixHolds(&gradient, b, _primarySourceMatrixOrigin.x, _primarySourceMatrixOrigin.y, vectors, channels) ||
            !CharonMPSMatrixHolds(&in, b, _secondarySourceMatrixOrigin.x, _secondarySourceMatrixOrigin.y, vectors, channels) ||
            !CharonMPSMatrixHolds(&out, b, _resultMatrixOrigin.x, _resultMatrixOrigin.y, vectors, channels)) {
            CharonMPSRefuse(@"MPSMatrixBatchNormalizationGradient: a matrix of the batch [%lu, %lu) does not hold the %lux%lu region its origin names", (unsigned long)start, (unsigned long)(start + count), (unsigned long)vectors, (unsigned long)channels);
            return;
        }
    }
    for (NSUInteger b = start; b < start + count; b++) {
        for (NSUInteger column = 0; column < channels; column++) {
            double m = mean.length > column ? CharonMPSLoad(CharonMPSVectorElement(&mean, 0, column), mean.dataType, 0) : 0.0;
            double v = variance.length > column ? CharonMPSLoad(CharonMPSVectorElement(&variance, 0, column), variance.dataType, 0) : 0.0;
            double g = gamma.length > column ? CharonMPSLoad(CharonMPSVectorElement(&gamma, 0, column), gamma.dataType, 0) : 1.0;
#ifdef CHARON_BN_TRACE
            fprintf(stderr, "BNP ch%lu  mean %g variance %g gamma %g  -> divisor %g  rowBytes(in) %lu\n",
                    (unsigned long)column, m, v, g, g / sqrt(v + (double)_epsilon),
                    (unsigned long)in.rowBytes);
#endif
            double divisor = g / sqrt(v + (double)_epsilon);
            double sum = 0.0, gammaGradient = 0.0, betaGradient = 0.0;
            for (NSUInteger row = 0; row < vectors; row++) {
                double d = CharonMPSLoad(CharonMPSMatrixElement(&gradient, b, _primarySourceMatrixOrigin.x + row, _primarySourceMatrixOrigin.y + column), gradient.dataType, 0);
                double x = CharonMPSLoad(CharonMPSMatrixElement(&in, b, _secondarySourceMatrixOrigin.x + row, _secondarySourceMatrixOrigin.y + column), in.dataType, 0);
                double normalised = (x - m) / sqrt(v + (double)_epsilon);
                sum += d;
                gammaGradient += d * normalised;
                betaGradient += d;
            }
            double meanGradient = vectors ? sum / (double)vectors : 0.0;
            double scaledSum = vectors ? sum / (double)vectors : 0.0;
            for (NSUInteger row = 0; row < vectors; row++) {
                double d = CharonMPSLoad(CharonMPSMatrixElement(&gradient, b, _primarySourceMatrixOrigin.x + row, _primarySourceMatrixOrigin.y + column), gradient.dataType, 0);
                double x = CharonMPSLoad(CharonMPSMatrixElement(&in, b, _secondarySourceMatrixOrigin.x + row, _secondarySourceMatrixOrigin.y + column), in.dataType, 0);
                double normalised = (x - m) / sqrt(v + (double)_epsilon);
                double gradientForData = divisor * (d - meanGradient - normalised * scaledSum);
                CharonMPSStore(CharonMPSMatrixElement(&out, b, _resultMatrixOrigin.x + row, _resultMatrixOrigin.y + column), out.dataType, 0, gradientForData);
            }
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
    MPSMatrixBatchNormalizationGradient *copy = [super copyWithZone:zone device:device];
    copy->_epsilon = _epsilon;
    copy->_neuronType = _neuronType;
    return copy;
}

@end
