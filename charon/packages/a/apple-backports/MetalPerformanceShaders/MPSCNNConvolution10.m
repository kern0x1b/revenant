// MPSCNNConvolution, from the header of MPSCNNConvolution.h in the SDK of iOS 16.4: a 2D convolution
// over feature channels, with an optional bias, an optional folded batch normalisation and an optional
// neuron applied to the result.
//
// The walk is ncnn's, read from Convolution::convolution at
// c6b351b56fbe32e0381ae00331e3df649b20d7b7 (BSD 3-Clause): a table of the kernel's taps, one
// accumulator per output channel seeded with that channel's bias, walked over the input channels and
// the taps, with the neuron's function applied once to the accumulator. What is different here is where
// the values live - an MPSImage is a plane per feature channel rather than an ncnn Mat per channel - and
// that a tap outside the image contributes nothing rather than reading a bordered copy.

#import "CharonMPSCnn.h"
#import "CharonMPS.h"
#import "CharonMPS26.h"

#pragma clang diagnostic ignored "-Wprotocol"
#pragma clang diagnostic ignored "-Wincomplete-implementation"

@implementation MPSCNNConvolution {
    MPSCNNConvolutionDescriptor *_descriptor;
    id<MTLBuffer> _weights;
    NSUInteger _weightsOffset;
    id<MTLBuffer> _biases;
    NSUInteger _biasesOffset;
    NSUInteger _edgeMode;
    NSUInteger _centerWindowSize;
}

- (instancetype)initWithDevice:(id<MTLDevice>)device
                 convolutionDescriptor:(MPSCNNConvolutionDescriptor *)convolutionDescriptor
               weightsAndBiases:(MPSCNNConvolutionWeightsAndBiasesState *)weightsAndBiasesState
{
    if ((self = [super initWithDevice:device])) {
        _descriptor = [convolutionDescriptor copy];
        _weights = weightsAndBiasesState.weights;
        _weightsOffset = weightsAndBiasesState.weightsOffset;
        _biases = weightsAndBiasesState.biases;
        _biasesOffset = weightsAndBiasesState.biasesOffset;
    }
    return self;
}

- (MPSCNNConvolutionDescriptor *)convolutionDescriptor
{
    return _descriptor;
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

- (void)setEdgeMode:(MPSImageEdgeMode)edgeMode
{
    _edgeMode = (NSUInteger)edgeMode;
}

- (MPSImageEdgeMode)edgeMode
{
    return (MPSImageEdgeMode)_edgeMode;
}

- (void)setCenterWindowSize:(NSUInteger)centerWindowSize
{
    _centerWindowSize = centerWindowSize;
}

- (NSUInteger)centerWindowSize
{
    return _centerWindowSize;
}

// The source and destination of one convolution, as planes over their own memory. An MPSImage keeps
// its values in a texture the CPU reads through -[MPSImage readBytes:...], so the walk is over a copy
// of the source and a copy of the destination handed back at the end; nothing here writes into a
// texture the caller owns.
- (void)encodeToCommandBuffer:(id<MTLCommandBuffer>)commandBuffer
                  sourceImage:(MPSImage *)sourceImage
               destinationImage:(MPSImage *)destinationImage
{
    if (!CharonMPSCommandBufferPermits(commandBuffer))
        return;
    MPSCNNConvolutionDescriptor *d = _descriptor;
    if (!d || !_weights) {
        CharonMPSRefuse(@"MPSCNNConvolution: the kernel has no descriptor or no weights, so nothing was written");
        return;
    }
    NSUInteger kernelWidth = d.kernelWidth, kernelHeight = d.kernelHeight;
    NSUInteger inChannels = d.inputFeatureChannels, outChannels = d.outputFeatureChannels;
    NSUInteger strideX = d.strideInPixelsX ? d.strideInPixelsX : 1;
    NSUInteger strideY = d.strideInPixelsY ? d.strideInPixelsY : 1;
    NSUInteger dilationX = d.dilationRateX ? d.dilationRateX : 1;
    NSUInteger dilationY = d.dilationRateY ? d.dilationRateY : 1;
    if (d.groups != 1) {
        CharonMPSRefuse(@"MPSCNNConvolution: %lu groups is not carried yet, so nothing was written", (unsigned long)d.groups);
        return;
    }
    NSUInteger leftPad = (kernelWidth - 1) * dilationX / 2;
    NSUInteger topPad = (kernelHeight - 1) * dilationY / 2;
    size_t element = MPSSizeofMPSDataType(destinationImage.featureChannelFormat == MPSImageFeatureChannelFormatFloat32
                                         ? MPSDataTypeFloat32 : MPSDataTypeFloat32);

    size_t sourceWidth = sourceImage.width, sourceHeight = sourceImage.height;
    size_t destWidth = destinationImage.width, destHeight = destinationImage.height;
    if (sourceImage.featureChannels != inChannels) {
        CharonMPSRefuse(@"MPSCNNConvolution: the source has %lu feature channels and the descriptor names %lu",
                        (unsigned long)sourceImage.featureChannels, (unsigned long)inChannels);
        return;
    }
    if (destinationImage.featureChannels != outChannels) {
        CharonMPSRefuse(@"MPSCNNConvolution: the destination has %lu feature channels and the descriptor names %lu",
                        (unsigned long)destinationImage.featureChannels, (unsigned long)outChannels);
        return;
    }
    size_t sourceBytes = sourceWidth * sourceHeight * inChannels * element;
    size_t destBytes = destWidth * destHeight * outChannels * element;
    void *source = calloc(sourceBytes ? sourceBytes : 1, 1);
    void *destination = calloc(destBytes ? destBytes : 1, 1);
    // -[MPSImage readBytes:...] answers nothing in this SDK, so what is checked is the format: a
    // single-precision image is the one this walk reads, and anything else is refused rather than
    // reinterpreted.
    if (sourceImage.featureChannelFormat != MPSImageFeatureChannelFormatFloat32 ||
        destinationImage.featureChannelFormat != MPSImageFeatureChannelFormatFloat32) {
        CharonMPSRefuse(@"MPSCNNConvolution: only single precision images are carried, so nothing was written");
        free(source);
        free(destination);
        return;
    }
    [sourceImage readBytes:source
                dataLayout:MPSDataLayoutHeightxWidthxFeatureChannels
                bytesPerRow:sourceWidth * element
                     region:MTLRegionMake3D(0, 0, 0, sourceWidth, sourceHeight, inChannels)
        featureChannelInfo:(MPSImageReadWriteParams){0, 0}
                imageIndex:0];
    [destinationImage readBytes:destination
                     dataLayout:MPSDataLayoutHeightxWidthxFeatureChannels
                     bytesPerRow:destWidth * element
                          region:MTLRegionMake3D(0, 0, 0, destWidth, destHeight, outChannels)
                featureChannelInfo:(MPSImageReadWriteParams){0, 0}
                        imageIndex:0];
    CharonMPSCnnPlane from = {source, sourceWidth, sourceHeight, inChannels, sourceWidth * element};
    CharonMPSCnnPlane to = {destination, destWidth, destHeight, outChannels, destWidth * element};

    // ncnn's tap table, built once for the kernel's shape.
    NSUInteger tapCount = kernelWidth * kernelHeight;
    CharonMPSCnnTap *taps = (CharonMPSCnnTap *)calloc(tapCount ? tapCount : 1, sizeof(CharonMPSCnnTap));
    CharonMPSCnnTaps(kernelWidth, kernelHeight, strideX, strideY, taps);

    MPSCNNNeuronType neuronType = d.neuronType;
    // The 16.4 header declares only parameters A and B on the descriptor; C arrived with the 26.2
    // surface and is read through the descriptor's own field, which is where a caller that sets it puts
    // it.
    float neuronA = d.neuronParameterA, neuronB = d.neuronParameterB, neuronC = [d charon_mps_neuronParameterC];
    for (NSUInteger oc = 0; oc < outChannels; oc++) {
        float bias = _biases ? (float)CharonMPSLoad((const char *)[_biases contents] + _biasesOffset + oc * sizeof(float), MPSDataTypeFloat32, 0) : 0.0f;
        for (NSUInteger oy = 0; oy < destHeight; oy++) {
            for (NSUInteger ox = 0; ox < destWidth; ox++) {
                float sum = bias;
                for (NSUInteger ic = 0; ic < inChannels; ic++) {
                    for (NSUInteger k = 0; k < tapCount; k++) {
                        NSUInteger sx, sy;
                        if (!CharonMPSCnnSourceFor(ox, oy, taps[k].x, taps[k].y, strideX, strideY,
                                                    dilationX, dilationY, sourceWidth, sourceHeight,
                                                    leftPad, topPad, &sx, &sy))
                            continue;   // a tap outside the image contributes nothing
                        float value = (float)CharonMPSLoad(CharonMPSCnnPixel(&from, sx, sy, ic), MPSDataTypeFloat32, 0);
                        // The weights are laid out OHWI: output, height, width, input.
                        size_t weightIndex = ((oc * kernelHeight + taps[k].y) * kernelWidth + taps[k].x) * inChannels + ic;
                        float weight = (float)CharonMPSLoad((const char *)[_weights contents] + _weightsOffset,
                                                              MPSDataTypeFloat32, weightIndex);
                        sum += value * weight;
                    }
                }
                float y = (float)CharonMPSApplyNeuron(neuronType, sum, neuronA, neuronB, neuronC, neuronA);
                CharonMPSStore(CharonMPSCnnPixelMutable(&to, ox, oy, oc), MPSDataTypeFloat32, 0, y);
            }
        }
    }
    free(taps);
    [destinationImage writeBytes:destination
                      dataLayout:MPSDataLayoutHeightxWidthxFeatureChannels
                      bytesPerRow:destWidth * element
                           region:MTLRegionMake3D(0, 0, 0, destWidth, destHeight, outChannels)
              featureChannelInfo:(MPSImageReadWriteParams){0, 0}
                      imageIndex:0];
    free(source);
    free(destination);
    CharonMPSConsumeReadCount(sourceImage);
}

@end
