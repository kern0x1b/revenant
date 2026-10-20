#import "RevenantMPSCnn.h"

#pragma clang diagnostic ignored "-Wprotocol"
#pragma clang diagnostic ignored "-Wincomplete-implementation"

@implementation MPSCNNBatchNormalization {
    NSUInteger _channels;
    float _epsilon;
    double *_a, *_b;
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
        [self revenant_mps_foldFromDataSource:dataSource];
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

- (void)revenant_mps_foldFromDataSource:(id<MPSCNNBatchNormalizationDataSource>)dataSource
{
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
            root = 0.0001;
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
    if (_epsilon == epsilon)
        return;
    _epsilon = epsilon;
    if (_dataSource)
        [self revenant_mps_foldFromDataSource:_dataSource];
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
    if (!RevenantMPSCommandBufferPermits(commandBuffer))
        return;
    if (sourceImage.featureChannelFormat != MPSImageFeatureChannelFormatFloat32 ||
        destinationImage.featureChannelFormat != MPSImageFeatureChannelFormatFloat32) {
        RevenantMPSRefuse(@"MPSCNNBatchNormalization: only single precision images are carried, so nothing was written");
        return;
    }
    if (!_a || !_b) {
        RevenantMPSRefuse(@"MPSCNNBatchNormalization: the state was not given a data source, so there is nothing to normalise by");
        return;
    }
    RevenantMPSCnnPlane from, to;
    size_t inWidth, inHeight, inChannels, outWidth, outHeight, outChannels;
    RevenantMPSCnnTake(sourceImage, &from, &inWidth, &inHeight, &inChannels);
    RevenantMPSCnnTake(destinationImage, &to, &outWidth, &outHeight, &outChannels);
    for (NSUInteger channel = 0; channel < outChannels; channel++) {
        NSUInteger c = channel < _channels ? channel : _channels - 1;
        for (NSUInteger y = 0; y < outHeight; y++) {
            for (NSUInteger x = 0; x < outWidth; x++) {
                double value = RevenantMPSLoad(RevenantMPSCnnPixel(&from, x < inWidth ? x : inWidth - 1,
                                                                  y < inHeight ? y : inHeight - 1,
                                                                  channel < inChannels ? channel : inChannels - 1),
                                             MPSDataTypeFloat32, 0);
                double y1 = _b[c] * value + _a[c];
                double result = RevenantMPSApplyNeuron(_neuronType, y1, _neuronA, _neuronB, _neuronC, _neuronA);
                RevenantMPSStore(RevenantMPSCnnPixelMutable(&to, x, y, channel), MPSDataTypeFloat32, 0, result);
            }
        }
    }
    RevenantMPSCnnGive(destinationImage, &to);
    RevenantMPSCnnGive(sourceImage, &from);
    RevenantMPSConsumeReadCount(sourceImage);
}

- (id)copyWithZone:(NSZone *)zone
{
    return self;
}

@end
