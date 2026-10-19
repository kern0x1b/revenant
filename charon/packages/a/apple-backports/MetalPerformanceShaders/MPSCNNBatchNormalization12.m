// MPSCNNBatchNormalization, from the header of MPSCNNBatchNormalization.h in the SDK of iOS 16.4: the
// normalisation of each feature channel by its own mean, variance, gamma and beta.
//
// The algebra is ncnn's, read from BatchNorm::load_model at
// c6b351b56fbe32e0381ae00331e3df649b20d7b7 (BSD 3-Clause), which folds it once when the parameters are
// given rather than per call:
//
//     a = beta  - gamma * mean / sqrt(variance + epsilon)
//     b = gamma /               sqrt(variance + epsilon)
//     value = b * value + a
//
// So the loop that normalises an image is a multiply and an add per value, with no division and no
// square root in it, and the divisor a zero variance would otherwise make is sanitised the way ncnn
// sanitises it.

#import "CharonMPSCnn.h"

#pragma clang diagnostic ignored "-Wprotocol"
#pragma clang diagnostic ignored "-Wincomplete-implementation"

@implementation MPSCNNBatchNormalization {
    NSUInteger _channels;
    float _epsilon;
    double *_a, *_b;             // the folded pair, per feature channel
    MPSNNNeuronDescriptor *_fusedNeuronDescriptor;
    id<MPSCNNBatchNormalizationDataSource> _dataSource;
    MPSCNNNeuronType _neuronType;
    float _neuronA, _neuronB, _neuronC;
}

- (instancetype)initWithDevice:(id<MTLDevice>)device
                    dataSource:(id<MPSCNNBatchNormalizationDataSource>)dataSource
{
    if ((self = [super initWithDevice:device])) {
        _epsilon = 1.0e-5f;
        _neuronType = MPSCNNNeuronTypeNone;
        _neuronC = 1.0f;
        _dataSource = dataSource;
        _channels = [dataSource numberOfFeatureChannels];
        [dataSource load];
        [self charon_mps_foldFromDataSource:dataSource];
    }
    return self;
}

- (instancetype)initWithDevice:(id<MTLDevice>)device
                    dataSource:(id<MPSCNNBatchNormalizationDataSource>)dataSource
        fusedNeuronDescriptor:(MPSNNNeuronDescriptor *)fusedNeuronDescriptor
{
    if (!(self = [self initWithDevice:device dataSource:dataSource]))
        return nil;
    self.fusedNeuronDescriptor = fusedNeuronDescriptor;
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder device:(id<MTLDevice>)device
{
    if ((self = [super initWithDevice:device])) {
        _epsilon = 1.0e-5f;
        _neuronType = MPSCNNNeuronTypeNone;
        _neuronC = 1.0f;
    }
    return self;
}

- (instancetype)initWithDevice:(id<MTLDevice>)device
{
    NSLog(@"MPSCNNBatchNormalization: -initWithDevice: names no data source; use -initWithDevice:dataSource:");
    return nil;
}

// The fold, once, from the data source's four per-channel arrays. What the loop below then applies is
// two numbers per channel, and this is where they come from.
- (void)charon_mps_foldFromDataSource:(id<MPSCNNBatchNormalizationDataSource>)dataSource
{
    // The data source's own four per-channel arrays, under the names the protocol gives them.
    const float *mean = [dataSource mean];
    const float *variance = [dataSource variance];
    const float *gamma = [dataSource gamma];
    const float *beta = [dataSource beta];
    if (!_channels)
        return;
    _a = (double *)calloc(_channels, sizeof(double));
    _b = (double *)calloc(_channels, sizeof(double));
    for (NSUInteger c = 0; c < _channels; c++) {
        double m = mean ? mean[c] : 0.0;
        double v = variance ? variance[c] : 0.0;
        double g = gamma ? gamma[c] : 1.0;
        double be = beta ? beta[c] : 0.0;
        double root = sqrt(v + (double)_epsilon);
        if (root == 0.0)
            root = 0.0001;    // the divisor a zero variance would otherwise make, as ncnn sanitises it
        _b[c] = g / root;
        _a[c] = be - g * m / root;
    }
}

- (MPSNNNeuronDescriptor *)fusedNeuronDescriptor
{
    return _fusedNeuronDescriptor;
}

- (void)setFusedNeuronDescriptor:(MPSNNNeuronDescriptor *)descriptor
{
    _fusedNeuronDescriptor = descriptor;
}

- (NSUInteger)numberOfFeatureChannels
{
    return _channels;
}

- (float)epsilon
{
    return _epsilon;
}

- (void)setEpsilon:(float)epsilon
{
    // Epsilon is inside the square root the fold divides by, so changing it after the state is made
    // has to fold again - otherwise the value a caller sets has no effect on what is written, which
    // the host differential caught: with epsilon 0.25 the release answers -4.0356 for the first value
    // and a fold made with the default epsilon answers -4.3990.
    if (_epsilon == epsilon)
        return;
    _epsilon = epsilon;
    if (_dataSource)
        [self charon_mps_foldFromDataSource:_dataSource];
}

- (void)setNeuronType:(MPSCNNNeuronType)neuronType parameterA:(float)parameterA parameterB:(float)parameterB
{
    _neuronType = neuronType;
    _neuronA = parameterA;
    _neuronB = parameterB;
}

- (void)encodeToCommandBuffer:(id<MTLCommandBuffer>)commandBuffer
                  sourceImage:(MPSImage *)sourceImage
               destinationImage:(MPSImage *)destinationImage
{
    if (!CharonMPSCommandBufferPermits(commandBuffer))
        return;
    if (sourceImage.featureChannelFormat != MPSImageFeatureChannelFormatFloat32 ||
        destinationImage.featureChannelFormat != MPSImageFeatureChannelFormatFloat32) {
        CharonMPSRefuse(@"MPSCNNBatchNormalization: only single precision images are carried, so nothing was written");
        return;
    }
    if (!_a || !_b) {
        CharonMPSRefuse(@"MPSCNNBatchNormalization: the state was not given a data source, so there is nothing to normalise by");
        return;
    }
    CharonMPSCnnPlane from, to;
    size_t inWidth, inHeight, inChannels, outWidth, outHeight, outChannels;
    CharonMPSCnnTake(sourceImage, &from, &inWidth, &inHeight, &inChannels);
    CharonMPSCnnTake(destinationImage, &to, &outWidth, &outHeight, &outChannels);
    for (NSUInteger channel = 0; channel < outChannels; channel++) {
        NSUInteger c = channel < _channels ? channel : _channels - 1;
        for (NSUInteger y = 0; y < outHeight; y++) {
            for (NSUInteger x = 0; x < outWidth; x++) {
                double value = CharonMPSLoad(CharonMPSCnnPixel(&from, x < inWidth ? x : inWidth - 1,
                                                                  y < inHeight ? y : inHeight - 1,
                                                                  channel < inChannels ? channel : inChannels - 1),
                                             MPSDataTypeFloat32, 0);
                double y1 = _b[c] * value + _a[c];
                double result = CharonMPSApplyNeuron(_neuronType, y1, _neuronA, _neuronB, _neuronC, _neuronA);
                CharonMPSStore(CharonMPSCnnPixelMutable(&to, x, y, channel), MPSDataTypeFloat32, 0, result);
            }
        }
    }
    CharonMPSCnnGive(destinationImage, &to);
    CharonMPSCnnGive(sourceImage, &from);
    CharonMPSConsumeReadCount(sourceImage);
}

- (id)copyWithZone:(NSZone *)zone
{
    return self;
}

@end
