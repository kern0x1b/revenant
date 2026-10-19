// MPSCNNFullyConnected, from MPSCNNConvolution.h of the iPhoneOS 16.4 surface: the class the header
// calls "a fully connected convolution layer a.k.a. Inner product" (:1314).
//
// One object for one release: the class's own annotation above its @interface is ios(10.0)
// (MPSCNNConvolution.h:1319) and nothing else is in this file.
//
// WHAT THE CLASS IS FOR, in the header's own terms, and why this file is short. A fully connected layer
// is a convolution whose kernel covers the full extent of the input (:1316-1324): the class exists so that
// a caller can name the layer it means, and the header says the arithmetic is a convolution. Likewise,
// MPSImageLaplacian's fast convolution kernel can be expressed as an MPSImageConvolution object, which
// says the same of MPSImageConvolution (MPSImageConvolution.h:115-117). MPSCNNFullyConnected's own
// discussion says that a convolution with kernel width and height matching the input does the same work,
// while the dedicated class is preferable for speed, since it lets the library pick the most suitable kernel (:1338).
//
// So the walk is MPSCNNConvolution's, which MPSCNNConvolution10.m carries and which is this class's
// superclass - there is no second convolution in this file, and a second one would be a second answer
// to keep in step. What this file adds is the class and the one initializer the class has at 10.0,
// which is the deprecated form MPSCNNConvolution.h:1376-1382 annotates
// MPS_AVAILABLE_STARTING_BUT_DEPRECATED(ios(10.0, 11.0)): the raw float arrays.
//
// The later -initWithDevice:weights: (:1355, ios(11.0)) and -initWithCoder:device: (:1395, ios(11.0))
// are not carried here: they are 11.0 members of an 11.0 surface, this object is a 10.0 one, and
// MPSCNNConvolutionDataSource has no implementation in this package for the first of them to name.
//
// WHAT IS NOT CLAIMED. No number in this file is a measurement of Apple's code. What has been checked
// here is the armv7 link, that this object defines the class it says.

#import "CharonMPSCnn.h"

#pragma clang diagnostic ignored "-Wprotocol"
#pragma clang diagnostic ignored "-Wincomplete-implementation"
// MPSCNNConvolution.h marks -initWithDevice:convolutionDescriptor:kernelWeights:biasTerms:flags: the
// designated initializer of the class (:1376-1382) and MPSCNNFullyConnected's own -initWithDevice:
// unavailable (:1402), and this class cannot chain to the first - it answers it by refusing, as the
// header marks it. The same pragma MPSImage9.m carries for the same reason.
#pragma clang diagnostic ignored "-Wobjc-designated-initializers"

// The initializer MPSCNNConvolution10.m carries. It is not a selector any SDK header declares - the
// release's own form takes an MPSCNNConvolutionWeightsAndBiasesState - so nothing declares it and this
// file has to, and it is here rather than in a shared header because the only caller of it in this
// package is the three lines below.
@interface MPSCNNConvolution (CharonMPSConvolutionWeightsAndBiases)
- (instancetype)initWithDevice:(id<MTLDevice>)device
         convolutionDescriptor:(MPSCNNConvolutionDescriptor *)convolutionDescriptor
                 weightsAndBiases:(MPSCNNConvolutionWeightsAndBiasesState *)weightsAndBiases;
@end

@implementation MPSCNNFullyConnected

// MPSCNNConvolution.h:1402 marks -initWithDevice: NS_UNAVAILABLE with the reason "Use
// initWithDevice:weights instead". The kernel it would make has no weights and no descriptor, so it
// is refused by name rather than answered with a convolution of nothing.
- (instancetype)initWithDevice:(id<MTLDevice>)device
{
    CharonMPSRefuse(@"MPSCNNFullyConnected: -initWithDevice: names neither a descriptor nor weights, and"
                    @" it is unavailable; use"
                    @" -initWithDevice:convolutionDescriptor:kernelWeights:biasTerms:flags:");
    return nil;
}

// The 10.0 initializer. The header is exact about what it takes (:1364-1368): kernelWeights is
// inputFeatureChannels * outputFeatureChannels * kernelHeight * kernelWidth floats laid out as
// weight[outputChannels][kernelHeight][kernelWidth][inputFeatureChannels / groups], and biasTerms is
// outputFeatureMaps floats. Both become MTLBuffers here, because that is where MPSCNNConvolution keeps
// its weights and biases and where its walk reads them from (MPSCNNConvolution10.m). flags is
// "Currently unused. Pass MPSCNNConvolutionFlagsNone" (:1372), so it is not read.
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
    // MTLResourceStorageModeShared, because this port's MTLBuffer is host memory the CPU reads and
    // writes directly (facts/Metal/RenderPath.md) and the convolution's walk reads these two buffers
    // on the CPU. A private or managed buffer would be storage nothing here could read.
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
    // The state is a strong local, so it is alive through the call below and released when this scope
    // ends; the initializer stores it in an ivar, which retains it.
    MPSCNNConvolutionWeightsAndBiasesState *state =
        [[MPSCNNConvolutionWeightsAndBiasesState alloc] initWithWeights:weightBuffer biases:biasBuffer];
    // The header declares this descriptor const (MPSCNNConvolution.h:1377) because the release does not
    // write through it, and MPSCNNConvolution's own initializer takes it without the qualifier; the
    // object is not modified here either way.
    return [super initWithDevice:device
           convolutionDescriptor:(MPSCNNConvolutionDescriptor *)convolutionDescriptor
                   weightsAndBiases:state];
}

@end