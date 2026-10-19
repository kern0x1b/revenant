// MPSCNNConvolutionWeightsAndBiasesState, from the header of MPSCNNConvolution.h in the SDK of iOS
// 16.4: the storage a convolution reads its weights and biases from, over an MPSState's description.

#import "CharonMPSCnn.h"

#pragma clang diagnostic ignored "-Wprotocol"
#pragma clang diagnostic ignored "-Wincomplete-implementation"

@implementation MPSCNNConvolutionWeightsAndBiasesState {
    id<MTLBuffer> _weights;
    id<MTLBuffer> _biases;
    NSUInteger _weightsOffset;
    NSUInteger _biasesOffset;
}

- (instancetype)initWithDevice:(id<MTLDevice>)device
         cnnConvolutionDescriptor:(MPSCNNConvolutionDescriptor *)descriptor
{
    // A convolution's weights are kernel_w * kernel_h * inputChannels * outputChannels, in the OHWI
    // layout, and its biases are one per output channel.
    NSUInteger element = MPSSizeofMPSDataType(MPSDataTypeFloat32);
    NSUInteger weights = descriptor.kernelWidth * descriptor.kernelHeight *
                         descriptor.inputFeatureChannels * descriptor.outputFeatureChannels * element;
    NSUInteger biases = descriptor.outputFeatureChannels * element;
    if ((self = [super initWithDevice:device resourceList:
                 [self charon_mps_listOfBufferSizes:weights, biases, nil]])) {
        _weights = [self resourceAtIndex:0 allocateMemory:YES];
        _biases = [self resourceAtIndex:1 allocateMemory:YES];
    }
    return self;
}

- (MPSStateResourceList *)charon_mps_listOfBufferSizes:(NSUInteger)first, ...
{
    NSMutableArray<NSNumber *> *sizes = [NSMutableArray array];
    va_list arguments;
    va_start(arguments, first);
    for (NSUInteger size = first; size; size = va_arg(arguments, NSUInteger))
        [sizes addObject:[NSNumber numberWithUnsignedInteger:size]];
    va_end(arguments);
    MPSStateResourceList *list = [[MPSStateResourceList alloc] init];
    for (NSNumber *size in sizes)
        [list appendBuffer:[size unsignedIntegerValue]];
    return list;
}

- (instancetype)initWithWeights:(id<MTLBuffer>)weights biases:(id<MTLBuffer>)biases
{
    if ((self = [super initWithResource:weights])) {
        _weights = weights;
        _biases = biases;
    }
    return self;
}

- (instancetype)initWithWeights:(id<MTLBuffer>)weights
                    weightsOffset:(NSUInteger)weightsOffset
                          biases:(id<MTLBuffer>)biases
                    biasesOffset:(NSUInteger)biasesOffset
{
    if ((self = [super initWithResource:weights])) {
        _weights = weights;
        _weightsOffset = weightsOffset;
        _biases = biases;
        _biasesOffset = biasesOffset;
    }
    return self;
}

+ (instancetype)temporaryCNNConvolutionWeightsAndBiasesStateWithCommandBuffer:(id<MTLCommandBuffer>)commandBuffer
                                                        cnnConvolutionDescriptor:(MPSCNNConvolutionDescriptor *)descriptor
{
    return [[MPSCNNConvolutionWeightsAndBiasesState alloc] initWithDevice:[commandBuffer device]
                                            cnnConvolutionDescriptor:descriptor];
}

- (id<MTLBuffer>)weights
{
    return _weights;
}

- (NSUInteger)weightsOffset
{
    return _weightsOffset;
}

- (id<MTLBuffer>)biases
{
    return _biases;
}

- (NSUInteger)biasesOffset
{
    return _biasesOffset;
}

@end
