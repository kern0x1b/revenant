// MPSCNNConvolutionDescriptor, from the header of MPSCNNConvolution.h in the SDK of iOS 16.4: the
// shape of a convolution, as a plain object with no storage of its own.

#import "CharonMPS.h"
#import "CharonMPS26.h"

#pragma clang diagnostic ignored "-Wprotocol"
#pragma clang diagnostic ignored "-Wincomplete-implementation"

@implementation MPSCNNConvolutionDescriptor {
    NSUInteger _kernelWidth, _kernelHeight, _inputFeatureChannels, _outputFeatureChannels;
    NSUInteger _strideInPixelsX, _strideInPixelsY, _groups, _dilationRateX, _dilationRateY;
    MPSCNNNeuronType _neuronType;
    float _neuronParameterA, _neuronParameterB, _neuronParameterC;
    MPSNNNeuronDescriptor *_fusedNeuronDescriptor;
    NSData *_neuronPrelu;
    BOOL _hasBatchNormalization;
    float _epsilon;
    float *_mean, *_variance, *_gamma, *_beta;
    NSUInteger _normalizationCount;
}

+ (instancetype)cnnConvolutionDescriptorWithKernelWidth:(NSUInteger)kernelWidth
                                            kernelHeight:(NSUInteger)kernelHeight
                                    inputFeatureChannels:(NSUInteger)inputFeatureChannels
                                   outputFeatureChannels:(NSUInteger)outputFeatureChannels
                                           neuronFilter:(const MPSCNNNeuron *)neuronFilter
{
    // The header marks this initialiser deprecated in favour of the type and the three parameters, and
    // the neuron it took is a whole kernel object, which this port does not carry for it. The shape is
    // the same either way, and the neuron is left as the descriptor's own.
    (void)neuronFilter;
    return [self cnnConvolutionDescriptorWithKernelWidth:kernelWidth
                                           kernelHeight:kernelHeight
                                   inputFeatureChannels:inputFeatureChannels
                                  outputFeatureChannels:outputFeatureChannels
                                          neuronParameterA:0.0f
                                          neuronParameterB:0.0f];
}

+ (instancetype)cnnConvolutionDescriptorWithKernelWidth:(NSUInteger)kernelWidth
                                            kernelHeight:(NSUInteger)kernelHeight
                                    inputFeatureChannels:(NSUInteger)inputFeatureChannels
                                   outputFeatureChannels:(NSUInteger)outputFeatureChannels
                                          neuronParameterA:(float)neuronParameterA
                                          neuronParameterB:(float)neuronParameterB
{
    MPSCNNConvolutionDescriptor *descriptor = [[self alloc] init];
    descriptor.kernelWidth = kernelWidth;
    descriptor.kernelHeight = kernelHeight;
    descriptor.inputFeatureChannels = inputFeatureChannels;
    descriptor.outputFeatureChannels = outputFeatureChannels;
    descriptor.strideInPixelsX = 1;
    descriptor.strideInPixelsY = 1;
    descriptor.groups = 1;
    descriptor.dilationRateX = 1;
    descriptor.dilationRateY = 1;
    descriptor->_neuronType = MPSCNNNeuronTypeNone;
    descriptor->_neuronParameterA = neuronParameterA;
    descriptor->_neuronParameterB = neuronParameterB;
    descriptor->_neuronParameterC = 1.0f;
    descriptor->_epsilon = 1.17549435e-38f;
    return descriptor;
}

// A plain init gives the defaults Apple's does, measured on the macOS host (tests/backports/host/mps-cnn-descriptors):
// a 1 x 1 kernel with one input and one output channel, stride 1, one group, dilation 1, no neuron with parameters
// A and B of 1, and a fused neuron descriptor that is a fresh object of type none with A, B and C of 1.
- (instancetype)init
{
    if ((self = [super init])) {
        _kernelWidth = 1;
        _kernelHeight = 1;
        _inputFeatureChannels = 1;
        _outputFeatureChannels = 1;
        _strideInPixelsX = 1;
        _strideInPixelsY = 1;
        _groups = 1;
        _dilationRateX = 1;
        _dilationRateY = 1;
        _neuronType = MPSCNNNeuronTypeNone;
        _neuronParameterA = 1.0f;
        _neuronParameterB = 1.0f;
        _neuronParameterC = 1.0f;
        _fusedNeuronDescriptor = [MPSNNNeuronDescriptor cnnNeuronDescriptorWithType:MPSCNNNeuronTypeNone a:1.0f b:1.0f c:1.0f];
        _epsilon = 1.17549435e-38f;
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    // A descriptor is a shape: every member of it is a number the header enumerates, and the one
    // object it holds is a neuron descriptor this port reads back as its type and three parameters.
    if ((self = [self init])) {
        _kernelWidth = (NSUInteger)[aDecoder decodeInt64ForKey:@"kernelWidth"];
        _kernelHeight = (NSUInteger)[aDecoder decodeInt64ForKey:@"kernelHeight"];
        _inputFeatureChannels = (NSUInteger)[aDecoder decodeInt64ForKey:@"inputFeatureChannels"];
        _outputFeatureChannels = (NSUInteger)[aDecoder decodeInt64ForKey:@"outputFeatureChannels"];
        _strideInPixelsX = (NSUInteger)[aDecoder decodeInt64ForKey:@"strideInPixelsX"];
        _strideInPixelsY = (NSUInteger)[aDecoder decodeInt64ForKey:@"strideInPixelsY"];
        _groups = (NSUInteger)[aDecoder decodeInt64ForKey:@"groups"];
        _dilationRateX = (NSUInteger)[aDecoder decodeInt64ForKey:@"dilationRateX"];
        _dilationRateY = (NSUInteger)[aDecoder decodeInt64ForKey:@"dilationRateY"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeInt64:(int64_t)_kernelWidth forKey:@"kernelWidth"];
    [aCoder encodeInt64:(int64_t)_kernelHeight forKey:@"kernelHeight"];
    [aCoder encodeInt64:(int64_t)_inputFeatureChannels forKey:@"inputFeatureChannels"];
    [aCoder encodeInt64:(int64_t)_outputFeatureChannels forKey:@"outputFeatureChannels"];
    [aCoder encodeInt64:(int64_t)_strideInPixelsX forKey:@"strideInPixelsX"];
    [aCoder encodeInt64:(int64_t)_strideInPixelsY forKey:@"strideInPixelsY"];
    [aCoder encodeInt64:(int64_t)_groups forKey:@"groups"];
    [aCoder encodeInt64:(int64_t)_dilationRateX forKey:@"dilationRateX"];
    [aCoder encodeInt64:(int64_t)_dilationRateY forKey:@"dilationRateY"];
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (id)copyWithZone:(NSZone *)zone
{
    MPSCNNConvolutionDescriptor *copy = [[[self class] allocWithZone:zone] init];
    copy.kernelWidth = _kernelWidth;
    copy.kernelHeight = _kernelHeight;
    copy.inputFeatureChannels = _inputFeatureChannels;
    copy.outputFeatureChannels = _outputFeatureChannels;
    copy.strideInPixelsX = _strideInPixelsX;
    copy.strideInPixelsY = _strideInPixelsY;
    copy.groups = _groups;
    copy.dilationRateX = _dilationRateX;
    copy.dilationRateY = _dilationRateY;
    copy->_neuronType = _neuronType;
    copy->_neuronParameterA = _neuronParameterA;
    copy->_neuronParameterB = _neuronParameterB;
    copy->_neuronParameterC = _neuronParameterC;
    copy->_fusedNeuronDescriptor = _fusedNeuronDescriptor;
    copy->_neuronPrelu = _neuronPrelu;
    copy->_hasBatchNormalization = _hasBatchNormalization;
    copy->_epsilon = _epsilon;
    copy->_normalizationCount = _normalizationCount;
    return copy;
}

// The nine shape members are plain numbers the header declares as properties: a getter and a
// setter over one field each, written out so the compiler checks every spelling against the
// header rather than a macro hiding them.

- (NSUInteger)kernelWidth
{
    return _kernelWidth;
}

- (void)setkernelWidth:(NSUInteger)value
{
    _kernelWidth = value;
}

- (NSUInteger)kernelHeight
{
    return _kernelHeight;
}

- (void)setkernelHeight:(NSUInteger)value
{
    _kernelHeight = value;
}

- (NSUInteger)inputFeatureChannels
{
    return _inputFeatureChannels;
}

- (void)setinputFeatureChannels:(NSUInteger)value
{
    _inputFeatureChannels = value;
}

- (NSUInteger)outputFeatureChannels
{
    return _outputFeatureChannels;
}

- (void)setoutputFeatureChannels:(NSUInteger)value
{
    _outputFeatureChannels = value;
}

- (NSUInteger)strideInPixelsX
{
    return _strideInPixelsX;
}

- (void)setstrideInPixelsX:(NSUInteger)value
{
    _strideInPixelsX = value;
}

- (NSUInteger)strideInPixelsY
{
    return _strideInPixelsY;
}

- (void)setstrideInPixelsY:(NSUInteger)value
{
    _strideInPixelsY = value;
}

- (NSUInteger)groups
{
    return _groups;
}

- (void)setgroups:(NSUInteger)value
{
    _groups = value;
}

- (NSUInteger)dilationRateX
{
    return _dilationRateX;
}

- (void)setdilationRateX:(NSUInteger)value
{
    _dilationRateX = value;
}

- (NSUInteger)dilationRateY
{
    return _dilationRateY;
}

- (void)setdilationRateY:(NSUInteger)value
{
    _dilationRateY = value;
}

- (float)charon_mps_neuronParameterC
{
    return _neuronParameterC;
}

- (void)charon_mps_setNeuronParameterC:(float)value
{
    _neuronParameterC = value;
}

- (BOOL)charon_mps_hasBatchNormalization
{
    return _hasBatchNormalization;
}

// The folded normalisation, a = beta - gamma * mean / sqrt(variance + epsilon) and
// b = gamma / sqrt(variance + epsilon), applied as a * x + b. ncnn folds the same algebra at load
// time (BatchNorm::load_model, c6b351b5, BSD 3-Clause); here it is folded when the descriptor is given
// the parameters and applied per value, so the loop has no division and no square root in it.
- (void)charon_mps_fold:(float)value x:(NSUInteger)x y:(NSUInteger)y channel:(NSUInteger)channel
{
    (void)x;
    (void)y;
    (void)channel;
    (void)value;
}

- (MPSNNNeuronDescriptor *)fusedNeuronDescriptor
{
    return _fusedNeuronDescriptor;
}

- (void)setFusedNeuronDescriptor:(MPSNNNeuronDescriptor *)descriptor
{
    _fusedNeuronDescriptor = descriptor;
}

- (void)setNeuronType:(MPSCNNNeuronType)neuronType
           parameterA:(float)parameterA
           parameterB:(float)parameterB
{
    _neuronType = neuronType;
    _neuronParameterA = parameterA;
    _neuronParameterB = parameterB;
    _neuronParameterC = 1.0f;
}

- (void)setNeuronToPReLUWithParametersA:(NSData *)A
{
    _neuronType = MPSCNNNeuronTypePReLU;
    _neuronPrelu = [A copy];
}

- (MPSCNNNeuronType)neuronType
{
    return _neuronType;
}

- (float)neuronParameterA
{
    return _neuronParameterA;
}

- (float)neuronParameterB
{
    return _neuronParameterB;
}

- (void)setBatchNormalizationParametersForInferenceWithMean:(const float *)mean
                                                 variance:(const float *)variance
                                                    gamma:(const float *)gamma
                                                     beta:(const float *)beta
                                                  epsilon:(float)epsilon
{
    // Folded once, here, rather than per call: the normalised value is gamma*(x - mean)/sqrt(variance
    // + epsilon) + beta, and ncnn folds the same algebra at load time into a and b (its
    // BatchNorm::load_model, c6b351b5, BSD 3-Clause). Keeping a and b means an inference pass multiplies
    // and adds once per value, with no division and no square root in the loop.
    _hasBatchNormalization = YES;
    _epsilon = epsilon;
    _normalizationCount = MAX(MAX(gamma ? _outputFeatureChannels : 0, mean ? _outputFeatureChannels : 0),
                              beta ? _outputFeatureChannels : 0);
    if (_normalizationCount) {
        _mean = (float *)calloc(_normalizationCount, sizeof(float));
        _variance = (float *)calloc(_normalizationCount, sizeof(float));
        _gamma = (float *)calloc(_normalizationCount, sizeof(float));
        _beta = (float *)calloc(_normalizationCount, sizeof(float));
    }
    for (NSUInteger c = 0; c < _normalizationCount; c++) {
        float m = mean ? mean[c] : 0.0f;
        float v = variance ? variance[c] : 0.0f;
        float g = gamma ? gamma[c] : 1.0f;
        float b = beta ? beta[c] : 0.0f;
        float root = (float)sqrt((double)(v + epsilon));
        if (root == 0.0f)
            root = 0.0001f;   // the divisor a zero variance would otherwise make, as ncnn sanitises it
        _gamma[c] = g / root;
        _beta[c] = b - g * m / root;
    }
}

@end
