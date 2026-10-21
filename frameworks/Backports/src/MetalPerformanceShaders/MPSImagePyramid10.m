#import "RevenantMPSPyramid.h"

static double RevenantMPSPyramidFiltered(const float *source, NSUInteger width, NSUInteger height,
                                       NSUInteger channel, NSUInteger channels,
                                       NSUInteger x, NSUInteger y,
                                       const float *kernel, NSUInteger kernelWidth, NSUInteger kernelHeight)
{
    NSUInteger halfWidth = kernelWidth / 2, halfHeight = kernelHeight / 2;
    double total = 0.0;
    for (NSUInteger ky = 0; ky < kernelHeight; ky++) {
        long sy = (long)y + (long)ky - (long)halfHeight;
        sy = sy < 0 ? 0 : ((NSUInteger)sy >= height ? (long)height - 1 : sy);
        for (NSUInteger kx = 0; kx < kernelWidth; kx++) {
            long sx = (long)x + (long)kx - (long)halfWidth;
            sx = sx < 0 ? 0 : ((NSUInteger)sx >= width ? (long)width - 1 : sx);
            double sample = (double)source[((NSUInteger)sy * width + (NSUInteger)sx) * channels + channel];
            total += (double)kernel[ky * kernelWidth + kx] * sample;
        }
    }
    return total;
}

@implementation MPSImageGaussianPyramid
@end

@interface MPSImageGaussianPyramid (RevenantMPSGaussianPyramid)
- (BOOL)encodeToCommandBuffer:(id<MTLCommandBuffer>)commandBuffer
                  inPlaceTexture:(id<MTLTexture>)texture
       fallbackCopyAllocator:(MPSCopyAllocator)copyAllocator;
@end

@implementation MPSImageGaussianPyramid (RevenantMPSGaussianPyramid)

- (BOOL)encodeToCommandBuffer:(id<MTLCommandBuffer>)commandBuffer
                 inPlaceTexture:(id<MTLTexture>)texture
       fallbackCopyAllocator:(MPSCopyAllocator)copyAllocator
{
    (void)copyAllocator;
    NSString *what = @"MPSImageGaussianPyramid";
    if (!commandBuffer) {
        RevenantMPSRefuse(@"%@: no command buffer, so no level was written", what);
        return NO;
    }
    if (!RevenantMPSCommandBufferPermits(commandBuffer))
        return NO;
    if (!texture) {
        RevenantMPSRefuse(@"%@: no texture, so no level was written", what);
        return NO;
    }
    NSUInteger channels = 0;
    size_t elementSize = 0;
    if (!RevenantMPSPyramidPixelShape(texture.pixelFormat, &channels, &elementSize) || !channels || !elementSize) {
        RevenantMPSRefuse(@"%@: a texture of pixel format %d names no element width this port carries, so no"
                        @" level was written", what, (int)texture.pixelFormat);
        return NO;
    }
    const float *kernel = [self revenant_mps_filter];
    NSUInteger kernelWidth = [self revenant_mps_filterWidth];
    NSUInteger kernelHeight = [self revenant_mps_filterHeight];
    NSUInteger levels = texture.mipmapLevelCount;
    if (levels < 2) {
        RevenantMPSRefuse(@"%@: the texture has %lu mip level(s) and a pyramid writes every level after the"
                        @" first, so there was nothing to do", what, (unsigned long)levels);
        return NO;
    }
    NSUInteger baseWidth = texture.width, baseHeight = texture.height;
    for (NSUInteger level = 1; level < levels; level++) {
        NSUInteger sourceWidth = RevenantMPSPyramidExtent(baseWidth, level - 1);
        NSUInteger sourceHeight = RevenantMPSPyramidExtent(baseHeight, level - 1);
        NSUInteger width = RevenantMPSPyramidExtent(baseWidth, level);
        NSUInteger height = RevenantMPSPyramidExtent(baseHeight, level);
        size_t sourceBytes = (size_t)sourceWidth * sourceHeight * channels * elementSize;
        size_t bytes = (size_t)width * height * channels * elementSize;
        float *source = (float *)calloc(sourceBytes ? sourceBytes : 1, 1);
        float *answer = (float *)calloc(bytes ? bytes : 1, 1);
        if (!source || !answer) {
            free(source);
            free(answer);
            RevenantMPSRefuse(@"%@: no memory for level %lu, so no level was written", what, (unsigned long)level);
            return NO;
        }
        if (!RevenantMPSPyramidRead(texture, level - 1, sourceWidth, sourceHeight, channels, elementSize, source)) {
            free(source);
            free(answer);
            RevenantMPSRefuse(@"%@: level %lu could not be read, so the pyramid stopped there", what,
                            (unsigned long)(level - 1));
            return NO;
        }
        for (NSUInteger y = 0; y < height; y++) {
            for (NSUInteger x = 0; x < width; x++) {
                NSUInteger at = 2 * x, over = 2 * y;
                if (at >= sourceWidth)
                    at = sourceWidth ? sourceWidth - 1 : 0;
                if (over >= sourceHeight)
                    over = sourceHeight ? sourceHeight - 1 : 0;
                for (NSUInteger channel = 0; channel < channels; channel++) {
                    double value = RevenantMPSPyramidFiltered(source, sourceWidth, sourceHeight, channel, channels,
                                                            at, over, kernel, kernelWidth, kernelHeight);
                    answer[(y * width + x) * channels + channel] = (float)value;
                }
            }
        }
        BOOL written = RevenantMPSPyramidWrite(texture, level, width, height, channels, elementSize, answer);
        free(source);
        free(answer);
        if (!written) {
            RevenantMPSRefuse(@"%@: level %lu could not be written, so the pyramid stopped there", what,
                            (unsigned long)level);
            return NO;
        }
    }
    return YES;
}

@end
