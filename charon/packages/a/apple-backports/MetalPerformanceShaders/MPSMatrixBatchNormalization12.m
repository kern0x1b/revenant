// MPSMatrixBatchNormalization, from the header of the SDK of iOS 16.4. One object per release: the band machinery keeps an
// object whole or drops it whole, so a file here carries the API of exactly one release.

// The rounding of the normalisation below is chosen at build time; the default is the plain form.
#ifndef CHARON_BN_CANDIDATE
#define CHARON_BN_CANDIDATE 0
#endif

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


@implementation MPSMatrixBatchNormalization {
    CHARON_MPS_NEURON_IVARS
    NSUInteger _sourceNumberOfFeatureVectors, _sourceInputFeatureChannels;
    float _epsilon;
    BOOL _computeStatistics;
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
        // The header's own default: the smallest positive normal single precision value, so a variance
        // of zero does not divide by zero in a caller who has not chosen one.
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
    if (!CharonMPSCommandBufferPermits(commandBuffer))
        return;
    CharonMPSMatrixView in = CharonMPSMatrixViewOf(inputMatrix), out = CharonMPSMatrixViewOf(resultMatrix);
    if (!CharonMPSDataTypeIsElement(in.dataType) || !CharonMPSDataTypeIsElement(out.dataType)) {
        CharonMPSRefuse(@"MPSMatrixBatchNormalization: a matrix of a data type that is not one of the eight element types was given");
        return;
    }
    // y[i,j] = gamma[j] * (x[i,j] - mean(x[:,j])) / sqrt(variance(x[:,j]) + epsilon) + beta[j], the
    // normalisation along the columns of the input, each column a feature channel's values across the
    // feature vectors. computeStatistics asks for the mean and variance to be written back, which is
    // what a training pass needs; the mean and variance the call gives are used either way.
    NSUInteger available = in.rows - _sourceMatrixOrigin.x;
    NSUInteger vectors = _sourceNumberOfFeatureVectors < available ? _sourceNumberOfFeatureVectors : available;
    NSUInteger columns = in.columns - _sourceMatrixOrigin.y;
    NSUInteger channels = _sourceInputFeatureChannels < columns ? _sourceInputFeatureChannels : columns;
    CharonMPSVectorView mean = CharonMPSVectorViewOf(meanVector), variance = CharonMPSVectorViewOf(varianceVector);
    CharonMPSVectorView gamma = {0, 0, 0, 0, 0, 0}, beta = {0, 0, 0, 0, 0, 0};
    if (gammaVector)
        gamma = CharonMPSVectorViewOf(gammaVector);
    if (betaVector)
        beta = CharonMPSVectorViewOf(betaVector);
    NSUInteger start, count;
    CharonMPSBatch(_batchStart, _batchSize, in.matrices, &start, &count);
    count = count < out.matrices ? count : out.matrices;
    for (NSUInteger b = start; b < start + count; b++) {
        if (!CharonMPSMatrixHolds(&in, b, _sourceMatrixOrigin.x, _sourceMatrixOrigin.y, vectors, channels) ||
            !CharonMPSMatrixHolds(&out, b, _resultMatrixOrigin.x, _resultMatrixOrigin.y, vectors, channels)) {
            CharonMPSRefuse(@"MPSMatrixBatchNormalization: a matrix of the batch [%lu, %lu) does not hold the %lux%lu region its origin names", (unsigned long)start, (unsigned long)(start + count), (unsigned long)vectors, (unsigned long)channels);
            return;
        }
    }
    CharonMPSNeuron neuron = [self charon_mps_neuron];
    for (NSUInteger b = start; b < start + count; b++) {
        for (NSUInteger column = 0; column < channels; column++) {
            double total = 0.0, squares = 0.0;
            for (NSUInteger row = 0; row < vectors; row++) {
                double x = CharonMPSLoad(CharonMPSMatrixElement(&in, b, _sourceMatrixOrigin.x + row, _sourceMatrixOrigin.y + column), in.dataType, 0);
                total += x;
                squares += x * x;
            }
            double m = vectors ? total / (double)vectors : 0.0;
            double v = vectors ? squares / (double)vectors - m * m : 0.0;
            if (_computeStatistics && mean.length > column)
                CharonMPSStore(CharonMPSVectorElement(&mean, 0, column), mean.dataType, 0, m);
            if (_computeStatistics && variance.length > column)
                CharonMPSStore(CharonMPSVectorElement(&variance, 0, column), variance.dataType, 0, v);
            double given = variance.length > column ? CharonMPSLoad(CharonMPSVectorElement(&variance, 0, column), variance.dataType, 0) : v;
            // The mean to normalise by is the one the caller gives, not the one computed from the data.
            // The formula is gamma * (x - mean) / sqrt(variance + epsilon) + beta, and the mean there is
            // the caller's. The port used the computed one, which is only the same when they agree - and
            // for this case's column 1 the two differ (given 5, computed 4), which is why that column was
            // out and the others exact. With computeStatistics the store happens first, so what is read
            // back for the mean is the computed one, which is the intended behaviour and not this.
            double mu = mean.length > column ? CharonMPSLoad(CharonMPSVectorElement(&mean, 0, column), mean.dataType, 0) : m;
            double g = gamma.length > column ? CharonMPSLoad(CharonMPSVectorElement(&gamma, 0, column), gamma.dataType, 0) : 1.0;
            double b0 = beta.length > column ? CharonMPSLoad(CharonMPSVectorElement(&beta, 0, column), beta.dataType, 0) : 0.0;
            for (NSUInteger row = 0; row < vectors; row++) {
                double x = CharonMPSLoad(CharonMPSMatrixElement(&in, b, _sourceMatrixOrigin.x + row, _sourceMatrixOrigin.y + column), in.dataType, 0);
                // gamma * (x - mean) / sqrt(variance + epsilon) + beta: the root, not the variance.
                // The rounding is a build flag, so the eight candidates of the ulp search are eight
                // builds of this one file and not eight edits of it: bit 0 takes the root by
                // division or by rsqrtf, bit 1 applies gamma before or after the divide, and bit 2
                // fuses the two products or not. The default is the plain form the port has.
#if CHARON_BN_CANDIDATE % 2 == 0
                float root = 1.0f / sqrtf((float)given + _epsilon);
#else
                float root = rsqrtf((float)given + _epsilon);
#endif
                float centred = (float)x - (float)mu;
#if (CHARON_BN_CANDIDATE / 2) % 2 == 0
                float scaled = g * centred;
#else
                float scaled = centred * g;
#endif
#if (CHARON_BN_CANDIDATE / 4) % 2 == 0
                float quotient = scaled * root;
#else
                float quotient = fmaf(scaled, root, 0.0f);
#endif
                double y = CharonMPSApplyNeuron(neuron.type, (double)quotient + b0, neuron.a, neuron.b, neuron.c, CharonMPSNeuronA(&neuron, column));
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
