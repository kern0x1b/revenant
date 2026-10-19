#import "RevenantMPSCnn.h"
#import "RevenantMPS.h"
#import "RevenantMPS26.h"

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

- (void)encodeToCommandBuffer:(id<MTLCommandBuffer>)commandBuffer
                  sourceImage:(MPSImage *)sourceImage
               destinationImage:(MPSImage *)destinationImage
{
    if (!RevenantMPSCommandBufferPermits(commandBuffer))
        return;
    MPSCNNConvolutionDescriptor *d = _descriptor;
    if (!d || !_weights) {
        RevenantMPSRefuse(@"MPSCNNConvolution: the kernel has no descriptor or no weights, so nothing was written");
        return;
    }
    NSUInteger kernelWidth = d.kernelWidth, kernelHeight = d.kernelHeight;
    NSUInteger inChannels = d.inputFeatureChannels, outChannels = d.outputFeatureChannels;
    NSUInteger strideX = d.strideInPixelsX ? d.strideInPixelsX : 1;
    NSUInteger strideY = d.strideInPixelsY ? d.strideInPixelsY : 1;
    NSUInteger dilationX = d.dilationRateX ? d.dilationRateX : 1;
    NSUInteger dilationY = d.dilationRateY ? d.dilationRateY : 1;
    if (d.groups != 1) {
        RevenantMPSRefuse(@"MPSCNNConvolution: %lu groups is not carried yet, so nothing was written", (unsigned long)d.groups);
        return;
    }
    NSUInteger leftPad = (kernelWidth - 1) * dilationX / 2;
    NSUInteger topPad = (kernelHeight - 1) * dilationY / 2;
    size_t element = MPSSizeofMPSDataType(destinationImage.featureChannelFormat == MPSImageFeatureChannelFormatFloat32
                                         ? MPSDataTypeFloat32 : MPSDataTypeFloat32);

    size_t sourceWidth = sourceImage.width, sourceHeight = sourceImage.height;
    size_t destWidth = destinationImage.width, destHeight = destinationImage.height;
    if (sourceImage.featureChannels != inChannels) {
        RevenantMPSRefuse(@"MPSCNNConvolution: the source has %lu feature channels and the descriptor names %lu",
                        (unsigned long)sourceImage.featureChannels, (unsigned long)inChannels);
        return;
    }
    if (destinationImage.featureChannels != outChannels) {
        RevenantMPSRefuse(@"MPSCNNConvolution: the destination has %lu feature channels and the descriptor names %lu",
                        (unsigned long)destinationImage.featureChannels, (unsigned long)outChannels);
        return;
    }
    size_t sourceBytes = sourceWidth * sourceHeight * inChannels * element;
    size_t destBytes = destWidth * destHeight * outChannels * element;
    void *source = calloc(sourceBytes ? sourceBytes : 1, 1);
    void *destination = calloc(destBytes ? destBytes : 1, 1);
    if (sourceImage.featureChannelFormat != MPSImageFeatureChannelFormatFloat32 ||
        destinationImage.featureChannelFormat != MPSImageFeatureChannelFormatFloat32) {
        RevenantMPSRefuse(@"MPSCNNConvolution: only single precision images are carried, so nothing was written");
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
    RevenantMPSCnnPlane from = {source, sourceWidth, sourceHeight, inChannels, sourceWidth * element};
    RevenantMPSCnnPlane to = {destination, destWidth, destHeight, outChannels, destWidth * element};

    NSUInteger tapCount = kernelWidth * kernelHeight;
    RevenantMPSCnnTap *taps = (RevenantMPSCnnTap *)calloc(tapCount ? tapCount : 1, sizeof(RevenantMPSCnnTap));
    RevenantMPSCnnTaps(kernelWidth, kernelHeight, strideX, strideY, taps);

    MPSCNNNeuronType neuronType = d.neuronType;
    float neuronA = d.neuronParameterA, neuronB = d.neuronParameterB, neuronC = [d revenant_mps_neuronParameterC];
    for (NSUInteger oc = 0; oc < outChannels; oc++) {
        float bias = _biases ? (float)RevenantMPSLoad((const char *)[_biases contents] + _biasesOffset + oc * sizeof(float), MPSDataTypeFloat32, 0) : 0.0f;
        for (NSUInteger oy = 0; oy < destHeight; oy++) {
            for (NSUInteger ox = 0; ox < destWidth; ox++) {
                float sum = bias;
                for (NSUInteger ic = 0; ic < inChannels; ic++) {
                    for (NSUInteger k = 0; k < tapCount; k++) {
                        NSUInteger sx, sy;
                        if (!RevenantMPSCnnSourceFor(ox, oy, taps[k].x, taps[k].y, strideX, strideY,
                                                    dilationX, dilationY, sourceWidth, sourceHeight,
                                                    leftPad, topPad, &sx, &sy))
                            continue;
                        float value = (float)RevenantMPSLoad(RevenantMPSCnnPixel(&from, sx, sy, ic), MPSDataTypeFloat32, 0);
                        size_t weightIndex = ((oc * kernelHeight + taps[k].y) * kernelWidth + taps[k].x) * inChannels + ic;
                        float weight = (float)RevenantMPSLoad((const char *)[_weights contents] + _weightsOffset,
                                                              MPSDataTypeFloat32, weightIndex);
                        sum += value * weight;
                    }
                }
                float y = (float)RevenantMPSApplyNeuron(neuronType, sum, neuronA, neuronB, neuronC, neuronA);
                RevenantMPSStore(RevenantMPSCnnPixelMutable(&to, ox, oy, oc), MPSDataTypeFloat32, 0, y);
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
    RevenantMPSConsumeReadCount(sourceImage);
}

@end
