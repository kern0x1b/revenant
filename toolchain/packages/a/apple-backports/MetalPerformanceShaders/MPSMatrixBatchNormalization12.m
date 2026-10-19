#ifndef REVENANT_BN_CANDIDATE
#define REVENANT_BN_CANDIDATE 0
#endif

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


@implementation MPSMatrixBatchNormalization {
    REVENANT_MPS_NEURON_IVARS
    NSUInteger _sourceNumberOfFeatureVectors, _sourceInputFeatureChannels;
    float _epsilon;
    BOOL _computeStatistics;
    MTLOrigin _sourceMatrixOrigin, _resultMatrixOrigin;
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
        _computeStatistics = NO;
    }
    return self;
}

- (NSUInteger)sourceNumberOfFeatureVectors { return _sourceNumberOfFeatureVectors; }
- (void)setSourceNumberOfFeatureVectors:(NSUInteger)count { _sourceNumberOfFeatureVectors = count; }
- (NSUInteger)sourceInputFeatureChannels { return _sourceInputFeatureChannels; }
- (void)setSourceInputFeatureChannels:(NSUInteger)channels { _sourceInputFeatureChannels = channels; }
- (float)epsilon { return _epsilon; }
- (void)setEpsilon:(float)epsilon { _epsilon = epsilon; }
- (BOOL)computeStatistics { return _computeStatistics; }
- (void)setComputeStatistics:(BOOL)computeStatistics { _computeStatistics = computeStatistics; }

- (void)encodeToCommandBuffer:(id<MTLCommandBuffer>)commandBuffer
                  inputMatrix:(MPSMatrix *)inputMatrix
                   meanVector:(MPSVector *)meanVector
               varianceVector:(MPSVector *)varianceVector
                  gammaVector:(MPSVector *)gammaVector
                   betaVector:(MPSVector *)betaVector
                 resultMatrix:(MPSMatrix *)resultMatrix
{
    if (!RevenantMPSCommandBufferPermits(commandBuffer))
        return;
    RevenantMPSMatrixView in = RevenantMPSMatrixViewOf(inputMatrix), out = RevenantMPSMatrixViewOf(resultMatrix);
    if (!RevenantMPSDataTypeIsElement(in.dataType) || !RevenantMPSDataTypeIsElement(out.dataType)) {
        RevenantMPSRefuse(@"MPSMatrixBatchNormalization: a matrix of a data type that is not one of the eight element types was given");
        return;
    }
    NSUInteger available = in.rows - _sourceMatrixOrigin.x;
    NSUInteger vectors = _sourceNumberOfFeatureVectors < available ? _sourceNumberOfFeatureVectors : available;
    NSUInteger columns = in.columns - _sourceMatrixOrigin.y;
    NSUInteger channels = _sourceInputFeatureChannels < columns ? _sourceInputFeatureChannels : columns;
    RevenantMPSVectorView mean = RevenantMPSVectorViewOf(meanVector), variance = RevenantMPSVectorViewOf(varianceVector);
    RevenantMPSVectorView gamma = {0, 0, 0, 0, 0, 0}, beta = {0, 0, 0, 0, 0, 0};
    if (gammaVector)
        gamma = RevenantMPSVectorViewOf(gammaVector);
    if (betaVector)
        beta = RevenantMPSVectorViewOf(betaVector);
    NSUInteger start, count;
    RevenantMPSBatch(_batchStart, _batchSize, in.matrices, &start, &count);
    count = count < out.matrices ? count : out.matrices;
    for (NSUInteger b = start; b < start + count; b++) {
        if (!RevenantMPSMatrixHolds(&in, b, _sourceMatrixOrigin.x, _sourceMatrixOrigin.y, vectors, channels) ||
            !RevenantMPSMatrixHolds(&out, b, _resultMatrixOrigin.x, _resultMatrixOrigin.y, vectors, channels)) {
            RevenantMPSRefuse(@"MPSMatrixBatchNormalization: a matrix of the batch [%lu, %lu) does not hold the %lux%lu region its origin names", (unsigned long)start, (unsigned long)(start + count), (unsigned long)vectors, (unsigned long)channels);
            return;
        }
    }
    RevenantMPSNeuron neuron = [self revenant_mps_neuron];
    for (NSUInteger b = start; b < start + count; b++) {
        for (NSUInteger column = 0; column < channels; column++) {
            double total = 0.0, squares = 0.0;
            for (NSUInteger row = 0; row < vectors; row++) {
                double x = RevenantMPSLoad(RevenantMPSMatrixElement(&in, b, _sourceMatrixOrigin.x + row, _sourceMatrixOrigin.y + column), in.dataType, 0);
                total += x;
                squares += x * x;
            }
            double m = vectors ? total / (double)vectors : 0.0;
            double v = vectors ? squares / (double)vectors - m * m : 0.0;
            if (_computeStatistics && mean.length > column)
                RevenantMPSStore(RevenantMPSVectorElement(&mean, 0, column), mean.dataType, 0, m);
            if (_computeStatistics && variance.length > column)
                RevenantMPSStore(RevenantMPSVectorElement(&variance, 0, column), variance.dataType, 0, v);
            double given = variance.length > column ? RevenantMPSLoad(RevenantMPSVectorElement(&variance, 0, column), variance.dataType, 0) : v;
            double mu = mean.length > column ? RevenantMPSLoad(RevenantMPSVectorElement(&mean, 0, column), mean.dataType, 0) : m;
            double g = gamma.length > column ? RevenantMPSLoad(RevenantMPSVectorElement(&gamma, 0, column), gamma.dataType, 0) : 1.0;
            double b0 = beta.length > column ? RevenantMPSLoad(RevenantMPSVectorElement(&beta, 0, column), beta.dataType, 0) : 0.0;
            for (NSUInteger row = 0; row < vectors; row++) {
                double x = RevenantMPSLoad(RevenantMPSMatrixElement(&in, b, _sourceMatrixOrigin.x + row, _sourceMatrixOrigin.y + column), in.dataType, 0);
#if REVENANT_BN_CANDIDATE % 2 == 0
                float root = 1.0f / sqrtf((float)given + _epsilon);
#else
                float root = rsqrtf((float)given + _epsilon);
#endif
                float centred = (float)x - (float)mu;
#if (REVENANT_BN_CANDIDATE / 2) % 2 == 0
                float scaled = g * centred;
#else
                float scaled = centred * g;
#endif
#if (REVENANT_BN_CANDIDATE / 4) % 2 == 0
                float quotient = scaled * root;
#else
                float quotient = fmaf(scaled, root, 0.0f);
#endif
                double y = RevenantMPSApplyNeuron(neuron.type, (double)quotient + b0, neuron.a, neuron.b, neuron.c, RevenantMPSNeuronA(&neuron, column));
                RevenantMPSStore(RevenantMPSMatrixElement(&out, b, _resultMatrixOrigin.x + row, _resultMatrixOrigin.y + column), out.dataType, 0, y);
            }
        }
    }
    RevenantMPSConsumeReadCount(inputMatrix);
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder device:(id<MTLDevice>)device
{
    return [super initWithCoder:aDecoder device:device];
}

- (instancetype)copyWithZone:(NSZone *)zone device:(id<MTLDevice>)device
{
    MPSMatrixBatchNormalization *copy = [super copyWithZone:zone device:device];
    copy->_neuronType = _neuronType;
    copy->_neuronParameterA = _neuronParameterA;
    copy->_neuronParameterB = _neuronParameterB;
    copy->_neuronParameterC = _neuronParameterC;
    copy->_epsilon = _epsilon;
    copy->_computeStatistics = _computeStatistics;
    return copy;
}

@end
