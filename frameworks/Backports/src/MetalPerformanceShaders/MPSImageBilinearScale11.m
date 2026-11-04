#import "RevenantMPSImage.h"
#import "RevenantMPSBilinear.h"
#import "../revenant_alias.h"

REVENANT_ALIAS_OF(MPSImageBilinearScale, MPSImageScale)

static BOOL RevenantMPSBilinearPlanOf(MPSImageScale *kernel, NSUInteger sourceWidth, NSUInteger sourceHeight,
                                      NSUInteger destinationWidth, NSUInteger destinationHeight,
                                      RevenantMPSBilinearTransform *transform, NSString *what)
{
    MPSImageEdgeMode edgeMode = kernel.edgeMode;
    if (edgeMode != MPSImageEdgeModeZero && edgeMode != MPSImageEdgeModeClamp) {
        RevenantMPSRefuse(@"%@: edge mode %lu is not one this filter defines (MPS documents zero and clamp for it),"
                        @" so nothing was written", what, (unsigned long)edgeMode);
        return NO;
    }
    const MPSScaleTransform *given = kernel.scaleTransform;
    if (given) {
        *transform = (RevenantMPSBilinearTransform){ given->scaleX, given->scaleY, given->translateX, given->translateY };
    } else {
        *transform = (RevenantMPSBilinearTransform){ (double)destinationWidth / (double)sourceWidth,
                                                     (double)destinationHeight / (double)sourceHeight, 0.0, 0.0 };
    }
    if (!(isfinite(transform->scaleX) && transform->scaleX > 0.0 && isfinite(transform->scaleY) &&
          transform->scaleY > 0.0 && isfinite(transform->translateX) && isfinite(transform->translateY))) {
        RevenantMPSRefuse(@"%@: the scale transform (%g, %g) with translate (%g, %g) is not a positive finite mapping,"
                        @" so nothing was written", what, transform->scaleX, transform->scaleY,
                        transform->translateX, transform->translateY);
        return NO;
    }
    return YES;
}

static float *RevenantMPSBilinearScaled(const float *input, NSUInteger width, NSUInteger height, NSUInteger channels,
                                        RevenantMPSBilinearTransform transform, MPSImageEdgeMode edgeMode, MTLRegion clip)
{
    size_t count = (size_t)clip.size.width * clip.size.height * channels;
    float *output = malloc(count * sizeof(float));
    if (!output)
        return NULL;
    if (!RevenantMPSBilinearResample(input, width, height, channels, (int)edgeMode, transform, output,
                                     clip.origin.x, clip.origin.y, clip.size.width, clip.size.height)) {
        free(output);
        return NULL;
    }
    return output;
}

@implementation REVENANT_ALIAS_CLASS(MPSImageBilinearScale) (RevenantMPSBilinearScale)

- (void)encodeToCommandBuffer:(id<MTLCommandBuffer>)commandBuffer
                sourceTexture:(id<MTLTexture>)sourceTexture
           destinationTexture:(id<MTLTexture>)destinationTexture
{
    NSString *what = @"MPSImageBilinearScale";
    if (!RevenantMPSCommandBufferPermits(commandBuffer))
        return;
    if (!sourceTexture || !destinationTexture) {
        RevenantMPSRefuse(@"%@: a source and a destination texture are both required, so nothing was written", what);
        return;
    }
    if (sourceTexture.textureType != MTLTextureType2D || destinationTexture.textureType != MTLTextureType2D) {
        RevenantMPSRefuse(@"%@: only single 2D textures are carried and texture arrays are refused, so nothing was written", what);
        return;
    }
    NSUInteger channels = 0, destinationChannels = 0;
    RevenantMPSTextureElement sourceElement, destinationElement;
    if (!RevenantMPSTextureFormat(sourceTexture.pixelFormat, &channels, &sourceElement) ||
        !RevenantMPSTextureFormat(destinationTexture.pixelFormat, &destinationChannels, &destinationElement)) {
        RevenantMPSRefuse(@"%@: pixel format %lu to %lu is not carried, so nothing was written", what,
                        (unsigned long)sourceTexture.pixelFormat, (unsigned long)destinationTexture.pixelFormat);
        return;
    }
    if (channels != destinationChannels) {
        RevenantMPSRefuse(@"%@: the source has %lu channel(s) and the destination %lu, so nothing was written", what,
                        (unsigned long)channels, (unsigned long)destinationChannels);
        return;
    }
    RevenantMPSBilinearTransform transform;
    if (!RevenantMPSBilinearPlanOf(self, sourceTexture.width, sourceTexture.height, destinationTexture.width,
                                   destinationTexture.height, &transform, what))
        return;
    MTLRegion clip = RevenantMPSResolvedRegion(destinationTexture.width, destinationTexture.height, self.clipRect);
    if (RevenantMPSImageRegionIsEmpty(clip))
        return;

    NSUInteger width = sourceTexture.width, height = sourceTexture.height;
    size_t sourceElementSize = RevenantMPSTextureElementSize(sourceElement);
    size_t destinationElementSize = RevenantMPSTextureElementSize(destinationElement);
    size_t inputCount = width * height * channels;
    unsigned char *sourceBytes = malloc(inputCount * sourceElementSize);
    float *input = malloc(inputCount * sizeof(float));
    if (!sourceBytes || !input) {
        free(sourceBytes);
        free(input);
        RevenantMPSRefuse(@"%@: no memory for a %lux%lu source, so nothing was written", what,
                        (unsigned long)width, (unsigned long)height);
        return;
    }
    if (!RevenantMPSTextureRead(sourceTexture, 0, width, height, channels, sourceElementSize, sourceBytes)) {
        free(sourceBytes);
        free(input);
        RevenantMPSRefuse(@"%@: the source could not be read, so nothing was written", what);
        return;
    }
    for (size_t i = 0; i < inputCount; i++)
        input[i] = (float)RevenantMPSTextureLoad(sourceBytes, sourceElement, i);
    free(sourceBytes);
    float *output = RevenantMPSBilinearScaled(input, width, height, channels, transform, self.edgeMode, clip);
    free(input);
    if (!output) {
        RevenantMPSRefuse(@"%@: no memory for the %lux%lu result, so nothing was written", what,
                        (unsigned long)clip.size.width, (unsigned long)clip.size.height);
        return;
    }
    size_t outputCount = clip.size.width * clip.size.height * channels;
    unsigned char *destinationBytes = malloc(outputCount * destinationElementSize);
    if (!destinationBytes) {
        free(output);
        RevenantMPSRefuse(@"%@: no memory for the %lux%lu result, so nothing was written", what,
                        (unsigned long)clip.size.width, (unsigned long)clip.size.height);
        return;
    }
    for (size_t i = 0; i < outputCount; i++)
        RevenantMPSTextureStore(destinationBytes, destinationElement, i, output[i]);
    free(output);
    [destinationTexture replaceRegion:clip mipmapLevel:0 withBytes:destinationBytes
                          bytesPerRow:clip.size.width * channels * destinationElementSize];
    free(destinationBytes);
}

- (void)encodeToCommandBuffer:(id<MTLCommandBuffer>)commandBuffer
                  sourceImage:(MPSImage *)sourceImage
             destinationImage:(MPSImage *)destinationImage
{
    NSString *what = @"MPSImageBilinearScale";
    if (!RevenantMPSCommandBufferPermits(commandBuffer))
        return;
    if (!RevenantMPSImageUsable(sourceImage, what) || !RevenantMPSImageUsable(destinationImage, what))
        return;
    if (sourceImage.numberOfImages != 1 || destinationImage.numberOfImages != 1) {
        RevenantMPSRefuse(@"%@: image arrays are refused, only single-slice images are carried, so nothing was written", what);
        return;
    }
    RevenantMPSImageLayout from = RevenantMPSImageLayoutOf(sourceImage);
    RevenantMPSImageLayout to = RevenantMPSImageLayoutOf(destinationImage);
    if (from.channels != to.channels) {
        RevenantMPSRefuse(@"%@: the source has %lu feature channel(s) and the destination %lu, so nothing was written", what,
                        (unsigned long)from.channels, (unsigned long)to.channels);
        return;
    }
    RevenantMPSBilinearTransform transform;
    if (!RevenantMPSBilinearPlanOf(self, from.width, from.height, to.width, to.height, &transform, what))
        return;
    MTLRegion clip = RevenantMPSImageResolvedRegion(destinationImage, self.clipRect);
    if (RevenantMPSImageRegionIsEmpty(clip))
        return;

    from.count = from.width * from.height * from.channels;
    void *sourceBytes = RevenantMPSImageReadRegion(sourceImage, &from,
                                                   MTLRegionMake2D(0, 0, from.width, from.height), what);
    if (!sourceBytes)
        return;
    float *input = malloc(from.count * sizeof(float));
    if (!input) {
        free(sourceBytes);
        RevenantMPSRefuse(@"%@: no memory for the source, so nothing was written", what);
        return;
    }
    for (NSUInteger i = 0; i < from.count; i++)
        input[i] = (float)RevenantMPSImageLoad(sourceBytes, &from, i);
    free(sourceBytes);
    float *output = RevenantMPSBilinearScaled(input, from.width, from.height, from.channels, transform, self.edgeMode, clip);
    free(input);
    if (!output) {
        RevenantMPSRefuse(@"%@: no memory for the result, so nothing was written", what);
        return;
    }
    RevenantMPSImageLayout region = to;
    region.width = clip.size.width;
    region.height = clip.size.height;
    region.count = region.width * region.height * region.channels;
    unsigned char *destinationBytes = calloc(region.count * region.elementSize, 1);
    if (!destinationBytes) {
        free(output);
        RevenantMPSRefuse(@"%@: no memory for the result, so nothing was written", what);
        return;
    }
    for (NSUInteger i = 0; i < region.count; i++)
        RevenantMPSImageStore(destinationBytes, &region, i, output[i]);
    free(output);
    RevenantMPSImageWriteRegion(destinationImage, &region, clip, destinationBytes, what);
    free(destinationBytes);
}

@end
