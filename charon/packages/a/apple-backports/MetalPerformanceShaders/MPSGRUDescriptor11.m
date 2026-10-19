// MPSGRUDescriptor, from the header of MPSRNNLayer.h in the SDK of iOS 16.4: a gated recurrent unit's
// descriptor. It adds seven weight sources, the p-norm value and the output-gate switch to MPSRNNDescriptor.
//
// The defaults are the host's, read from Apple's own object (see facts/MetalPerformanceShaders/MPSGRUDescriptor.md):
// every weight source is nil, gatePnormValue is 1 and flipOutputGates is NO. The base class's defaults stand for
// the rest. The object is not NSCopying on the host, so this class is not either.

#import "CharonMPS.h"

@implementation MPSGRUDescriptor {
    id <MPSCNNConvolutionDataSource> _inputGateInputWeights;
    id <MPSCNNConvolutionDataSource> _inputGateRecurrentWeights;
    id <MPSCNNConvolutionDataSource> _recurrentGateInputWeights;
    id <MPSCNNConvolutionDataSource> _recurrentGateRecurrentWeights;
    id <MPSCNNConvolutionDataSource> _outputGateInputWeights;
    id <MPSCNNConvolutionDataSource> _outputGateRecurrentWeights;
    id <MPSCNNConvolutionDataSource> _outputGateInputGateWeights;
    float _gatePnormValue;
    BOOL _flipOutputGates;
}

+ (instancetype)createGRUDescriptorWithInputFeatureChannels:(NSUInteger)inputFeatureChannels
                                      outputFeatureChannels:(NSUInteger)outputFeatureChannels
{
    MPSGRUDescriptor *descriptor = [[self alloc] init];
    descriptor.inputFeatureChannels = inputFeatureChannels;
    descriptor.outputFeatureChannels = outputFeatureChannels;
    return descriptor;
}

- (instancetype)init
{
    if ((self = [super init])) {
        _gatePnormValue = 1.0f;
        _flipOutputGates = NO;
    }
    return self;
}

// The input gate: Wz, Uz and the gate's own neuron.

- (id <MPSCNNConvolutionDataSource>)inputGateInputWeights
{
    return _inputGateInputWeights;
}

- (void)setInputGateInputWeights:(id <MPSCNNConvolutionDataSource>)weights
{
    _inputGateInputWeights = weights;
}

- (id <MPSCNNConvolutionDataSource>)inputGateRecurrentWeights
{
    return _inputGateRecurrentWeights;
}

- (void)setInputGateRecurrentWeights:(id <MPSCNNConvolutionDataSource>)weights
{
    _inputGateRecurrentWeights = weights;
}

// The recurrent gate: Wr and Ur.

- (id <MPSCNNConvolutionDataSource>)recurrentGateInputWeights
{
    return _recurrentGateInputWeights;
}

- (void)setRecurrentGateInputWeights:(id <MPSCNNConvolutionDataSource>)weights
{
    _recurrentGateInputWeights = weights;
}

- (id <MPSCNNConvolutionDataSource>)recurrentGateRecurrentWeights
{
    return _recurrentGateRecurrentWeights;
}

- (void)setRecurrentGateRecurrentWeights:(id <MPSCNNConvolutionDataSource>)weights
{
    _recurrentGateRecurrentWeights = weights;
}

// The proposed output: Wh, Uh and Vh.

- (id <MPSCNNConvolutionDataSource>)outputGateInputWeights
{
    return _outputGateInputWeights;
}

- (void)setOutputGateInputWeights:(id <MPSCNNConvolutionDataSource>)weights
{
    _outputGateInputWeights = weights;
}

- (id <MPSCNNConvolutionDataSource>)outputGateRecurrentWeights
{
    return _outputGateRecurrentWeights;
}

- (void)setOutputGateRecurrentWeights:(id <MPSCNNConvolutionDataSource>)weights
{
    _outputGateRecurrentWeights = weights;
}

- (id <MPSCNNConvolutionDataSource>)outputGateInputGateWeights
{
    return _outputGateInputGateWeights;
}

- (void)setOutputGateInputGateWeights:(id <MPSCNNConvolutionDataSource>)weights
{
    _outputGateInputGateWeights = weights;
}

- (float)gatePnormValue
{
    return _gatePnormValue;
}

- (void)setGatePnormValue:(float)value
{
    _gatePnormValue = value;
}

- (BOOL)flipOutputGates
{
    return _flipOutputGates;
}

- (void)setFlipOutputGates:(BOOL)value
{
    _flipOutputGates = value;
}

@end
