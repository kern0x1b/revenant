#import "RevenantMPSPyramid.h"

static double RevenantMPSPyramidInterpolated(const float *source, NSUInteger width, NSUInteger height,
                                           NSUInteger channel, NSUInteger channels,
                                           NSUInteger x, NSUInteger y,
                                           const float *kernel, NSUInteger kernelWidth, NSUInteger kernelHeight)
{
    NSUInteger halfWidth = kernelWidth / 2, halfHeight = kernelHeight / 2;
    double total = 0.0;
    for (NSUInteger ky = 0; ky < kernelHeight; ky++) {
        long py = (long)y + (long)ky - (long)halfHeight;
        for (NSUInteger kx = 0; kx < kernelWidth; kx++) {
            long px = (long)x + (long)kx - (long)halfWidth;
            if ((py & 1) || (px & 1))
                continue;
            long sx = px / 2, sy = py / 2;
            if (sx < 0 || sy < 0 || (NSUInteger)sx >= width || (NSUInteger)sy >= height)
                continue;
            double sample = (double)source[((NSUInteger)sy * width + (NSUInteger)sx) * channels + channel];
            total += (double)kernel[ky * kernelWidth + kx] * sample;
        }
    }
    return total;
}

@implementation MPSImageLaplacianPyramid {
    float _laplacianBias, _laplacianScale;
}

- (float)getLaplacianBias { return _laplacianBias; }

- (void)setLaplacianBias:(float)laplacianBias { _laplacianBias = laplacianBias; }
- (float)getLaplacianScale { return _laplacianScale; }
- (void)setLaplacianScale:(float)laplacianScale { _laplacianScale = laplacianScale; }

@end

@implementation MPSImageLaplacianPyramidSubtract
@end

@interface MPSImageLaplacianPyramidSubtract (RevenantMPSLaplacianPyramid)
- (void)encodeToCommandBuffer:(id<MTLCommandBuffer>)commandBuffer
                sourceTexture:(id<MTLTexture>)sourceTexture
           destinationTexture:(id<MTLTexture>)destinationTexture;
@end

@implementation MPSImageLaplacianPyramidSubtract (RevenantMPSLaplacianPyramid)

- (void)encodeToCommandBuffer:(id<MTLCommandBuffer>)commandBuffer
                sourceTexture:(id<MTLTexture>)sourceTexture
           destinationTexture:(id<MTLTexture>)destinationTexture
{
    NSString *what = @"MPSImageLaplacianPyramid";
    if (!commandBuffer) {
        RevenantMPSRefuse(@"%@: no command buffer, so no level was written", what);
        return;
    }
    if (!RevenantMPSCommandBufferPermits(commandBuffer))
        return;
    if (!sourceTexture || !destinationTexture) {
        RevenantMPSRefuse(@"%@: no source or no destination texture, so no level was written", what);
        return;
    }
    NSUInteger channels = 0, destinationChannels = 0;
    size_t elementSize = 0, destinationElementSize = 0;
    if (!RevenantMPSPyramidPixelShape(sourceTexture.pixelFormat, &channels, &elementSize) ||
        !RevenantMPSPyramidPixelShape(destinationTexture.pixelFormat, &destinationChannels, &destinationElementSize) ||
        channels != destinationChannels || elementSize != destinationElementSize) {
        RevenantMPSRefuse(@"%@: the source is pixel format %d and the destination %d; their channels, bit depth"
                        @" and resolution have to match, so no level was written",
                        what, (int)sourceTexture.pixelFormat, (int)destinationTexture.pixelFormat);
        return;
    }
    NSUInteger levels = sourceTexture.mipmapLevelCount;
    if (destinationTexture.mipmapLevelCount < levels) {
        RevenantMPSRefuse(@"%@: the destination has %lu mip level(s) and the source %lu; the destination needs at"
                        @" least one fewer than the source, so no level was written",
                        what, (unsigned long)destinationTexture.mipmapLevelCount, (unsigned long)levels);
        return;
    }
    const float *kernel = [self revenant_mps_filter];
    NSUInteger kernelWidth = [self revenant_mps_filterWidth];
    NSUInteger kernelHeight = [self revenant_mps_filterHeight];
    if (!kernel || !kernelWidth || !kernelHeight) {
        RevenantMPSRefuse(@"%@: the MPSImagePyramid of this iOS is the release's own class, and its filter's"
                        @" weights are in storage no header declares, so no level was written", what);
        return;
    }
    double laplacianBias = [self getLaplacianBias];
    double laplacianScale = [self getLaplacianScale];
    for (NSUInteger level = 0; level + 1 < levels; level++) {
        NSUInteger width = RevenantMPSPyramidExtent(sourceTexture.width, level);
        NSUInteger height = RevenantMPSPyramidExtent(sourceTexture.height, level);
        NSUInteger aboveWidth = RevenantMPSPyramidExtent(sourceTexture.width, level + 1);
        NSUInteger aboveHeight = RevenantMPSPyramidExtent(sourceTexture.height, level + 1);
        size_t bytes = (size_t)width * height * channels * elementSize;
        size_t aboveBytes = (size_t)aboveWidth * aboveHeight * channels * elementSize;
        float *here = (float *)calloc(bytes ? bytes : 1, 1);
        float *above = (float *)calloc(aboveBytes ? aboveBytes : 1, 1);
        if (!here || !above) {
            free(here);
            free(above);
            RevenantMPSRefuse(@"%@: no memory for level %lu, so no level was written", what, (unsigned long)level);
            return;
        }
        BOOL read = RevenantMPSPyramidRead(sourceTexture, level, width, height, channels, elementSize, here) &&
                    RevenantMPSPyramidRead(sourceTexture, level + 1, aboveWidth, aboveHeight, channels, elementSize, above);
        if (!read) {
            free(here);
            free(above);
            RevenantMPSRefuse(@"%@: level %lu of the source could not be read, so no level was written", what,
                            (unsigned long)level);
            return;
        }
        for (NSUInteger y = 0; y < height; y++) {
            for (NSUInteger x = 0; x < width; x++) {
                for (NSUInteger channel = 0; channel < channels; channel++) {
                    double raw = (double)here[(y * width + x) * channels + channel] -
                                 RevenantMPSPyramidInterpolated(above, aboveWidth, aboveHeight, channel, channels,
                                                             x, y, kernel, kernelWidth, kernelHeight);
                    double value = laplacianBias + raw * laplacianScale;
                    here[(y * width + x) * channels + channel] = (float)value;
                }
            }
        }
        RevenantMPSPyramidWrite(destinationTexture, level, width, height, channels, elementSize, here);
        free(here);
        free(above);
    }
}

@end

@implementation MPSImageLaplacianPyramidAdd
@end

@implementation MPSImageLaplacianPyramidAdd (RevenantMPSLaplacianPyramid)

- (void)encodeToCommandBuffer:(id<MTLCommandBuffer>)commandBuffer
                sourceTexture:(id<MTLTexture>)sourceTexture
           destinationTexture:(id<MTLTexture>)destinationTexture
{
    NSString *what = @"MPSImageLaplacianPyramidAdd";
    if (!commandBuffer) {
        RevenantMPSRefuse(@"%@: no command buffer, so no level was written", what);
        return;
    }
    if (!RevenantMPSCommandBufferPermits(commandBuffer))
        return;
    if (!sourceTexture || !destinationTexture) {
        RevenantMPSRefuse(@"%@: no source or no destination texture, so no level was written", what);
        return;
    }
    NSUInteger channels = 0, destinationChannels = 0;
    size_t elementSize = 0, destinationElementSize = 0;
    if (!RevenantMPSPyramidPixelShape(sourceTexture.pixelFormat, &channels, &elementSize) ||
        !RevenantMPSPyramidPixelShape(destinationTexture.pixelFormat, &destinationChannels, &destinationElementSize) ||
        channels != destinationChannels || elementSize != destinationElementSize) {
        RevenantMPSRefuse(@"%@: the source is pixel format %d and the destination %d; their channels, bit depth"
                        @" and resolution have to match, so no level was written",
                        what, (int)sourceTexture.pixelFormat, (int)destinationTexture.pixelFormat);
        return;
    }
    NSUInteger levels = sourceTexture.mipmapLevelCount;
    if (destinationTexture.mipmapLevelCount < levels) {
        RevenantMPSRefuse(@"%@: the destination has %lu mip level(s) and the source %lu; the destination needs at"
                        @" least one fewer than the source, so no level was written",
                        what, (unsigned long)destinationTexture.mipmapLevelCount, (unsigned long)levels);
        return;
    }
    const float *kernel = [self revenant_mps_filter];
    NSUInteger kernelWidth = [self revenant_mps_filterWidth];
    NSUInteger kernelHeight = [self revenant_mps_filterHeight];
    if (!kernel || !kernelWidth || !kernelHeight) {
        RevenantMPSRefuse(@"%@: the MPSImagePyramid of this iOS is the release's own class, and its filter's"
                        @" weights are in storage no header declares, so no level was written", what);
        return;
    }
    double laplacianBias = [self getLaplacianBias];
    double laplacianScale = [self getLaplacianScale];
    NSUInteger topWidth = RevenantMPSPyramidExtent(sourceTexture.width, levels - 1);
    NSUInteger topHeight = RevenantMPSPyramidExtent(sourceTexture.height, levels - 1);
    size_t topBytes = (size_t)topWidth * topHeight * channels * elementSize;
    float *top = (float *)calloc(topBytes ? topBytes : 1, 1);
    if (!top) {
        RevenantMPSRefuse(@"%@: no memory for the top level, so no level was written", what);
        return;
    }
    if (!RevenantMPSPyramidRead(sourceTexture, levels - 1, topWidth, topHeight, channels, elementSize, top)) {
        free(top);
        RevenantMPSRefuse(@"%@: the top level of the source could not be read, so no level was written", what);
        return;
    }
    for (long step = (long)levels - 2; step >= 0; step--) {
        NSUInteger level = (NSUInteger)step;
        NSUInteger width = RevenantMPSPyramidExtent(sourceTexture.width, level);
        NSUInteger height = RevenantMPSPyramidExtent(sourceTexture.height, level);
        size_t bytes = (size_t)width * height * channels * elementSize;
        float *here = (float *)calloc(bytes ? bytes : 1, 1);
        if (!here) {
            free(top);
            RevenantMPSRefuse(@"%@: no memory for level %lu, so no level was written", what, (unsigned long)level);
            return;
        }
        if (!RevenantMPSPyramidRead(sourceTexture, level, width, height, channels, elementSize, here)) {
            free(here);
            free(top);
            RevenantMPSRefuse(@"%@: level %lu of the source could not be read, so no level was written", what,
                            (unsigned long)level);
            return;
        }
        BOOL destinationHasAbove = destinationTexture.mipmapLevelCount > level + 1;
        NSUInteger aboveWidth = RevenantMPSPyramidExtent(sourceTexture.width, level + 1);
        NSUInteger aboveHeight = RevenantMPSPyramidExtent(sourceTexture.height, level + 1);
        size_t aboveBytes = (size_t)aboveWidth * aboveHeight * channels * elementSize;
        float *above = (float *)calloc(aboveBytes ? aboveBytes : 1, 1);
        if (!above || !(level + 1 == levels - 1
                        ? YES
                        : (destinationHasAbove
                           ? RevenantMPSPyramidRead(destinationTexture, level + 1, aboveWidth, aboveHeight,
                                                    channels, elementSize, above)
                           : NO))) {
            free(here);
            free(above);
            free(top);
            RevenantMPSRefuse(@"%@: level %lu above could not be read, so no level was written", what,
                            (unsigned long)(level + 1));
            return;
        }
        const float *aboveValues = (level + 1 == levels - 1) ? top : above;
        for (NSUInteger y = 0; y < height; y++) {
            for (NSUInteger x = 0; x < width; x++) {
                for (NSUInteger channel = 0; channel < channels; channel++) {
                    double stored = (double)here[(y * width + x) * channels + channel];
                    double raw = laplacianScale != 0.0 ? (stored - laplacianBias) / laplacianScale : stored;
                    double value = raw + RevenantMPSPyramidInterpolated(aboveValues, aboveWidth, aboveHeight,
                                                                       channel, channels, x, y,
                                                                       kernel, kernelWidth, kernelHeight);
                    here[(y * width + x) * channels + channel] = (float)value;
                }
            }
        }
        RevenantMPSPyramidWrite(destinationTexture, level, width, height, channels, elementSize, here);
        free(here);
        free(above);
    }
    free(top);
}

@end
