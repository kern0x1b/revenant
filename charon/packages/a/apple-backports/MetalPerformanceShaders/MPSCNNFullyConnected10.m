#import "CharonMPSCnn.h"

#pragma clang diagnostic ignored "-Wprotocol"
#pragma clang diagnostic ignored "-Wincomplete-implementation"
#pragma clang diagnostic ignored "-Wobjc-designated-initializers"

@interface MPSCNNConvolution (CharonMPSConvolutionWeightsAndBiases)
- (instancetype)initWithDevice:(id<MTLDevice>)device
         convolutionDescriptor:(MPSCNNConvolutionDescriptor *)convolutionDescriptor
                 weightsAndBiases:(MPSCNNConvolutionWeightsAndBiasesState *)weightsAndBiases;
@end

@implementation MPSCNNFullyConnected

- (instancetype)initWithDevice:(id<MTLDevice>)device
{
    CharonMPSRefuse(@"MPSCNNFullyConnected: -initWithDevice: names neither a descriptor nor weights, and"
                    @" it is unavailable; use"
                    @" -initWithDevice:convolutionDescriptor:kernelWeights:biasTerms:flags:");
    return nil;
}

- (instancetype)initWithDevice:(id<MTLDevice>)device
         convolutionDescriptor:(const MPSCNNConvolutionDescriptor *)convolutionDescriptor
                 kernelWeights:(const float *)kernelWeights
                     biasTerms:(const float *)biasTerms
                         flags:(MPSCNNConvolutionFlags)flags
{
    (void)flags;
    if (!convolutionDescriptor || !kernelWeights) {
        CharonMPSRefuse(@"MPSCNNFullyConnected: -initWithDevice:convolutionDescriptor:kernelWeights:biasTerms:flags:"
                        @" was given no descriptor or no weights, so there is no convolution to make");
        return nil;
    }
    NSUInteger weights = convolutionDescriptor.kernelWidth * convolutionDescriptor.kernelHeight *
                         convolutionDescriptor.inputFeatureChannels * convolutionDescriptor.outputFeatureChannels;
    NSUInteger biases = convolutionDescriptor.outputFeatureChannels;
    if (!weights || !biases) {
        CharonMPSRefuse(@"MPSCNNFullyConnected: a descriptor of %lu by %lu over %lu into %lu channels names no"
                        @" weights, so there is no convolution to make",
                        (unsigned long)convolutionDescriptor.kernelWidth, (unsigned long)convolutionDescriptor.kernelHeight,
                        (unsigned long)convolutionDescriptor.inputFeatureChannels,
                        (unsigned long)convolutionDescriptor.outputFeatureChannels);
        return nil;
    }
    id<MTLBuffer> weightBuffer = [device newBufferWithBytes:kernelWeights
                                                     length:weights * sizeof(float)
                                                    options:MTLResourceStorageModeShared];
    if (!weightBuffer) {
        CharonMPSRefuse(@"MPSCNNFullyConnected: the device made no %lu byte weights buffer, so there is no"
                        @" convolution to make", (unsigned long)(weights * sizeof(float)));
        return nil;
    }
    id<MTLBuffer> biasBuffer = nil;
    if (biasTerms) {
        biasBuffer = [device newBufferWithBytes:biasTerms
                                          length:biases * sizeof(float)
                                         options:MTLResourceStorageModeShared];
        if (!biasBuffer) {
            CharonMPSRefuse(@"MPSCNNFullyConnected: the device made no %lu byte biases buffer, so the weights"
                            @" alone would not make the convolution the header describes",
                            (unsigned long)(biases * sizeof(float)));
            return nil;
        }
    }
    MPSCNNConvolutionWeightsAndBiasesState *state =
        [[MPSCNNConvolutionWeightsAndBiasesState alloc] initWithWeights:weightBuffer biases:biasBuffer];
    return [super initWithDevice:device
           convolutionDescriptor:(MPSCNNConvolutionDescriptor *)convolutionDescriptor
                   weightsAndBiases:state];
}

@end
