// MPSLSTMDescriptor, from the header of MPSRNNLayer.h in the SDK of iOS 16.4: a long short-term memory
// layer's descriptor. It adds twelve weight sources (three per gate, the peephole ones included), the
// memory-diagonal switch and the neuron of the cell-to-output gate to MPSRNNDescriptor.
//
// The defaults are the host's, read from Apple's own object (see facts/MetalPerformanceShaders/MPSLSTMDescriptor.md):
// every weight source is nil, memoryWeightsAreDiagonal is NO, cellToOutputNeuronType is MPSCNNNeuronTypeTanH
// and its three parameters are 1. The host's object also carries cellClipThreshold and
// coupleForgetGateToInputGate, which the 16.4 header does not declare, so they are not here. The object is
// not NSCopying on the host, so this class is not either.

#import "CharonMPS.h"

@implementation MPSLSTMDescriptor {
    BOOL _memoryWeightsAreDiagonal;
    id <MPSCNNConvolutionDataSource> _inputGateInputWeights;
    id <MPSCNNConvolutionDataSource> _inputGateRecurrentWeights;
    id <MPSCNNConvolutionDataSource> _inputGateMemoryWeights;
    id <MPSCNNConvolutionDataSource> _forgetGateInputWeights;
    id <MPSCNNConvolutionDataSource> _forgetGateRecurrentWeights;
    id <MPSCNNConvolutionDataSource> _forgetGateMemoryWeights;
    id <MPSCNNConvolutionDataSource> _outputGateInputWeights;
    id <MPSCNNConvolutionDataSource> _outputGateRecurrentWeights;
    id <MPSCNNConvolutionDataSource> _outputGateMemoryWeights;
    id <MPSCNNConvolutionDataSource> _cellGateInputWeights;
    id <MPSCNNConvolutionDataSource> _cellGateRecurrentWeights;
    id <MPSCNNConvolutionDataSource> _cellGateMemoryWeights;
    MPSCNNNeuronType _cellToOutputNeuronType;
    float _cellToOutputNeuronParamA;
    float _cellToOutputNeuronParamB;
    float _cellToOutputNeuronParamC;
}

+ (instancetype)createLSTMDescriptorWithInputFeatureChannels:(NSUInteger)inputFeatureChannels
                                       outputFeatureChannels:(NSUInteger)outputFeatureChannels
{
    MPSLSTMDescriptor *descriptor = [[self alloc] init];
    descriptor.inputFeatureChannels = inputFeatureChannels;
    descriptor.outputFeatureChannels = outputFeatureChannels;
    return descriptor;
}

- (instancetype)init
{
    if ((self = [super init])) {
        _memoryWeightsAreDiagonal = NO;
        _cellToOutputNeuronType = MPSCNNNeuronTypeTanH;
        _cellToOutputNeuronParamA = 1.0f;
        _cellToOutputNeuronParamB = 1.0f;
        _cellToOutputNeuronParamC = 1.0f;
    }
    return self;
}

- (BOOL)memoryWeightsAreDiagonal
{
    return _memoryWeightsAreDiagonal;
}

- (void)setMemoryWeightsAreDiagonal:(BOOL)value
{
    _memoryWeightsAreDiagonal = value;
}

// The input gate: Wi, Ui and the peephole Vi.

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

- (id <MPSCNNConvolutionDataSource>)inputGateMemoryWeights
{
    return _inputGateMemoryWeights;
}

- (void)setInputGateMemoryWeights:(id <MPSCNNConvolutionDataSource>)weights
{
    _inputGateMemoryWeights = weights;
}

// The forget gate: Wf, Uf and the peephole Vf.

- (id <MPSCNNConvolutionDataSource>)forgetGateInputWeights
{
    return _forgetGateInputWeights;
}

- (void)setForgetGateInputWeights:(id <MPSCNNConvolutionDataSource>)weights
{
    _forgetGateInputWeights = weights;
}

- (id <MPSCNNConvolutionDataSource>)forgetGateRecurrentWeights
{
    return _forgetGateRecurrentWeights;
}

- (void)setForgetGateRecurrentWeights:(id <MPSCNNConvolutionDataSource>)weights
{
    _forgetGateRecurrentWeights = weights;
}

- (id <MPSCNNConvolutionDataSource>)forgetGateMemoryWeights
{
    return _forgetGateMemoryWeights;
}

- (void)setForgetGateMemoryWeights:(id <MPSCNNConvolutionDataSource>)weights
{
    _forgetGateMemoryWeights = weights;
}

// The output gate: Wo, Uo and the peephole Vo.

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

- (id <MPSCNNConvolutionDataSource>)outputGateMemoryWeights
{
    return _outputGateMemoryWeights;
}

- (void)setOutputGateMemoryWeights:(id <MPSCNNConvolutionDataSource>)weights
{
    _outputGateMemoryWeights = weights;
}

// The memory cell gate: Wc, Uc and the peephole Vc.

- (id <MPSCNNConvolutionDataSource>)cellGateInputWeights
{
    return _cellGateInputWeights;
}

- (void)setCellGateInputWeights:(id <MPSCNNConvolutionDataSource>)weights
{
    _cellGateInputWeights = weights;
}

- (id <MPSCNNConvolutionDataSource>)cellGateRecurrentWeights
{
    return _cellGateRecurrentWeights;
}

- (void)setCellGateRecurrentWeights:(id <MPSCNNConvolutionDataSource>)weights
{
    _cellGateRecurrentWeights = weights;
}

- (id <MPSCNNConvolutionDataSource>)cellGateMemoryWeights
{
    return _cellGateMemoryWeights;
}

- (void)setCellGateMemoryWeights:(id <MPSCNNConvolutionDataSource>)weights
{
    _cellGateMemoryWeights = weights;
}

// The neuron of the cell-to-output gate, gh, and its three parameters.

- (MPSCNNNeuronType)cellToOutputNeuronType
{
    return _cellToOutputNeuronType;
}

- (void)setCellToOutputNeuronType:(MPSCNNNeuronType)type
{
    _cellToOutputNeuronType = type;
}

- (float)cellToOutputNeuronParamA
{
    return _cellToOutputNeuronParamA;
}

- (void)setCellToOutputNeuronParamA:(float)value
{
    _cellToOutputNeuronParamA = value;
}

- (float)cellToOutputNeuronParamB
{
    return _cellToOutputNeuronParamB;
}

- (void)setCellToOutputNeuronParamB:(float)value
{
    _cellToOutputNeuronParamB = value;
}

- (float)cellToOutputNeuronParamC
{
    return _cellToOutputNeuronParamC;
}

- (void)setCellToOutputNeuronParamC:(float)value
{
    _cellToOutputNeuronParamC = value;
}

@end
