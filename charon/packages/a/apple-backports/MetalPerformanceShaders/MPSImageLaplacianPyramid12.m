// MPSImageLaplacianPyramid and the two kernels over it, from MPSImageConvolution.h of the iPhoneOS 16.4
// surface: the base with its two pointwise parameters, and the subtract and the add pyramid.
//
// One object for one release, and the release's own cache ladder is the judge rather than the header's
// annotation. All three annotate ios(10.0) - MPSImageConvolution.h:663 (:664 MPSImageLaplacianPyramid),
// :683 (:684 MPSImageLaplacianPyramidSubtract) and :706 (:707 MPSImageLaplacianPyramidAdd) - and
//     xmake l tools/cache-index/first-rung.lua _OBJC_CLASS_\$_MPSImageLaplacianPyramid
//         _OBJC_CLASS_\$_MPSImageLaplacianPyramidAdd _OBJC_CLASS_\$_MPSImageLaplacianPyramidSubtract
// answers 12.0 for all three, where the same command answers 10.0.1 for MPSImagePyramid and
// MPSImageGaussianPyramid, which are MPSImagePyramid10.m's classes. So 12.0 is what this object
// implements, and it is why these three are not in that file: one object carries one release. What the two
// files share - the level shape, the level read and write, and the filter's own accessors - is in
// CharonMPSPyramid.h.
//
// THE LAPLACIAN PYRAMID (:612-660) is the difference against an interpolated half-resolution level:
//     Laplacian level l is the Gaussian level l less the interpolated Gaussian level l+1
// where Interpolate is the usual twofold upsampling (:619-620), which the header spells out
// as exactly two steps (:622-633): zero-stuffing, which keeps the source value at each position where x
// and y are both even and puts zero at the rest, and then filtering with this class's inherited kernel.
// So the interpolation here is a five-by-five filter over the zero-stuffed source, and a tap that lands
// on an odd position reads the zero of the zero-stuffing - which is also what settles the border, and it
// is why no edge mode is read here and none is asked for.
//
// The result is then mapped pointwise (:645-649): LaplacianRangeScale(pixel, bias, scale) =
// bias + pixel * scale, defaults bias 0.0 and scale 1.0. The subtract kernel (:683-704) writes it into
// every destination level from the bottom up, one fewer level than the source has; the add kernel
// (:706-729) inverts that mapping and adds the interpolated level back, walking down from the top and
// taking the level above the first iteration from the source, which the header calls "the
// LaplacianMipLevel[#top] level" (:722-725).
//
// WHAT IS NOT CLAIMED. No number in this file is a measurement of Apple's code - the release's own MPS
// crashes on this family's substrate, which facts/MetalPerformanceShaders/Elements10.md records with its
// transcript. What is written here is transcribed from the header above; what has been checked is the
// armv7 link, that this object defines the three classes it says.

#import "CharonMPSPyramid.h"

// The interpolation, which is the same filter over the ZERO-STUFFED source: at (x, y) the sample a tap
// reads is the source's own at (p / 2, q / 2) when the tap's own position (p, q) is even in both
// directions, and zero otherwise. That is MPSImageConvolution.h:625-626 verbatim, and it is what makes
// the border answer without an edge rule of any kind.
static double CharonMPSPyramidInterpolated(const float *source, NSUInteger width, NSUInteger height,
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

// The base with its two pointwise parameters. It carries no encode - MPSImageConvolution.h:664 declares
// none - and the two kernels over it declare none either (:684, :707), so each walk is a category on its
// own class: a category on this one would be inherited by every subclass, and the subtract and the add
// walks are different functions of the same selector.
@implementation MPSImageLaplacianPyramid {
    float _laplacianBias, _laplacianScale;
}

- (float)getLaplacianBias { return _laplacianBias; }

// The header spells this property's accessors out (:667): "setter = setLaplacianBias:, getter =
// getLaplacianBias", so the two are written by name and not the ones @synthesize would make.
- (void)setLaplacianBias:(float)laplacianBias { _laplacianBias = laplacianBias; }
- (float)getLaplacianScale { return _laplacianScale; }
- (void)setLaplacianScale:(float)laplacianScale { _laplacianScale = laplacianScale; }

@end

// The class itself first: MPSImageConvolution.h:684 declares no member on it, so it has nothing of its own
// to write, and a category cannot create the class it is written on - which is the same arrangement
// MPSImageThreshold13.m and MPSImageArithmetic13.m already use in this package.
@implementation MPSImageLaplacianPyramidSubtract
@end

@interface MPSImageLaplacianPyramidSubtract (CharonMPSLaplacianPyramid)
- (void)encodeToCommandBuffer:(id<MTLCommandBuffer>)commandBuffer
                sourceTexture:(id<MTLTexture>)sourceTexture
           destinationTexture:(id<MTLTexture>)destinationTexture;
@end

@implementation MPSImageLaplacianPyramidSubtract (CharonMPSLaplacianPyramid)

- (void)encodeToCommandBuffer:(id<MTLCommandBuffer>)commandBuffer
                sourceTexture:(id<MTLTexture>)sourceTexture
           destinationTexture:(id<MTLTexture>)destinationTexture
{
    NSString *what = @"MPSImageLaplacianPyramid";
    if (!commandBuffer) {
        CharonMPSRefuse(@"%@: no command buffer, so no level was written", what);
        return;
    }
    if (!CharonMPSCommandBufferPermits(commandBuffer))
        return;
    if (!sourceTexture || !destinationTexture) {
        CharonMPSRefuse(@"%@: no source or no destination texture, so no level was written", what);
        return;
    }
    // Limitation 2 of :655-658: source and destination must agree in channel count, bit depth and resolution.
    NSUInteger channels = 0, destinationChannels = 0;
    size_t elementSize = 0, destinationElementSize = 0;
    if (!CharonMPSPyramidPixelShape(sourceTexture.pixelFormat, &channels, &elementSize) ||
        !CharonMPSPyramidPixelShape(destinationTexture.pixelFormat, &destinationChannels, &destinationElementSize) ||
        channels != destinationChannels || elementSize != destinationElementSize) {
        CharonMPSRefuse(@"%@: the source is pixel format %d and the destination %d; their channels, bit depth"
                        @" and resolution have to match, so no level was written",
                        what, (int)sourceTexture.pixelFormat, (int)destinationTexture.pixelFormat);
        return;
    }
    // The subtract kernel writes one level fewer than the source has (:695-699), and limitation 1 of
    // :654-655 is that in-place is not supported, which is the plain two-texture form used here.
    NSUInteger levels = sourceTexture.mipmapLevelCount;
    if (destinationTexture.mipmapLevelCount < levels) {
        CharonMPSRefuse(@"%@: the destination has %lu mip level(s) and the source %lu; the destination needs at"
                        @" least one fewer than the source, so no level was written",
                        what, (unsigned long)destinationTexture.mipmapLevelCount, (unsigned long)levels);
        return;
    }
    const float *kernel = [self charon_mps_filter];
    NSUInteger kernelWidth = [self charon_mps_filterWidth];
    NSUInteger kernelHeight = [self charon_mps_filterHeight];
    // The weights are the release's own storage on the bands of 10.0.1 to 10.3.4, and are this port's
    // below 10.0.1 and from 12.0 - measured, and written out beside MPSImagePyramid16.m: the release
    // carries MPSImagePyramid from 10.0.1 without exporting it, the name is therefore an alias, and
    // attach.c hands the release's class the five members it already has, so a pyramid built here
    // inherits the RELEASE's initializers and this port never wrote these weights. MPSImageConvolution.h
    // keeps the weights private, so there is no way to read them and no filter to interpolate with:
    // the walk is refused by name rather than made with a kernel this port did not build.
    if (!kernel || !kernelWidth || !kernelHeight) {
        CharonMPSRefuse(@"%@: the MPSImagePyramid of this iOS is the release's own class, and its filter's"
                        @" weights are in storage no header declares, so no level was written", what);
        return;
    }
    // The two pointwise parameters through the getters the header spells out at MPSImageConvolution.h:667 -
    // getLaplacianBias and getLaplacianScale - which are public and so visible from a category, where
    // the ivars behind them are not.
    double laplacianBias = [self getLaplacianBias];
    double laplacianScale = [self getLaplacianScale];
    for (NSUInteger level = 0; level + 1 < levels; level++) {
        NSUInteger width = CharonMPSPyramidExtent(sourceTexture.width, level);
        NSUInteger height = CharonMPSPyramidExtent(sourceTexture.height, level);
        NSUInteger aboveWidth = CharonMPSPyramidExtent(sourceTexture.width, level + 1);
        NSUInteger aboveHeight = CharonMPSPyramidExtent(sourceTexture.height, level + 1);
        size_t bytes = (size_t)width * height * channels * elementSize;
        size_t aboveBytes = (size_t)aboveWidth * aboveHeight * channels * elementSize;
        float *here = (float *)calloc(bytes ? bytes : 1, 1);
        float *above = (float *)calloc(aboveBytes ? aboveBytes : 1, 1);
        if (!here || !above) {
            free(here);
            free(above);
            CharonMPSRefuse(@"%@: no memory for level %lu, so no level was written", what, (unsigned long)level);
            return;
        }
        BOOL read = CharonMPSPyramidRead(sourceTexture, level, width, height, channels, elementSize, here) &&
                    CharonMPSPyramidRead(sourceTexture, level + 1, aboveWidth, aboveHeight, channels, elementSize, above);
        if (!read) {
            free(here);
            free(above);
            CharonMPSRefuse(@"%@: level %lu of the source could not be read, so no level was written", what,
                            (unsigned long)level);
            return;
        }
        for (NSUInteger y = 0; y < height; y++) {
            for (NSUInteger x = 0; x < width; x++) {
                for (NSUInteger channel = 0; channel < channels; channel++) {
                    double raw = (double)here[(y * width + x) * channels + channel] -
                                 CharonMPSPyramidInterpolated(above, aboveWidth, aboveHeight, channel, channels,
                                                             x, y, kernel, kernelWidth, kernelHeight);
                    // LaplacianRangeScale(pixel, bias, scale) := bias + pixel * scale (:647-648).
                    double value = laplacianBias + raw * laplacianScale;
                    here[(y * width + x) * channels + channel] = (float)value;
                }
            }
        }
        CharonMPSPyramidWrite(destinationTexture, level, width, height, channels, elementSize, here);
        free(here);
        free(above);
    }
}

@end

// The add kernel is the inverse of the above and is a second category on the other class, because it is
// a different class with its own encode and the release keeps them as two (:684 and :707).
// The add kernel's class, for the same reason as the subtract one above: MPSImageConvolution.h:707
// declares no member on it either.
@implementation MPSImageLaplacianPyramidAdd
@end

@implementation MPSImageLaplacianPyramidAdd (CharonMPSLaplacianPyramid)

- (void)encodeToCommandBuffer:(id<MTLCommandBuffer>)commandBuffer
                sourceTexture:(id<MTLTexture>)sourceTexture
           destinationTexture:(id<MTLTexture>)destinationTexture
{
    NSString *what = @"MPSImageLaplacianPyramidAdd";
    if (!commandBuffer) {
        CharonMPSRefuse(@"%@: no command buffer, so no level was written", what);
        return;
    }
    if (!CharonMPSCommandBufferPermits(commandBuffer))
        return;
    if (!sourceTexture || !destinationTexture) {
        CharonMPSRefuse(@"%@: no source or no destination texture, so no level was written", what);
        return;
    }
    NSUInteger channels = 0, destinationChannels = 0;
    size_t elementSize = 0, destinationElementSize = 0;
    if (!CharonMPSPyramidPixelShape(sourceTexture.pixelFormat, &channels, &elementSize) ||
        !CharonMPSPyramidPixelShape(destinationTexture.pixelFormat, &destinationChannels, &destinationElementSize) ||
        channels != destinationChannels || elementSize != destinationElementSize) {
        CharonMPSRefuse(@"%@: the source is pixel format %d and the destination %d; their channels, bit depth"
                        @" and resolution have to match, so no level was written",
                        what, (int)sourceTexture.pixelFormat, (int)destinationTexture.pixelFormat);
        return;
    }
    NSUInteger levels = sourceTexture.mipmapLevelCount;
    if (destinationTexture.mipmapLevelCount < levels) {
        CharonMPSRefuse(@"%@: the destination has %lu mip level(s) and the source %lu; the destination needs at"
                        @" least one fewer than the source, so no level was written",
                        what, (unsigned long)destinationTexture.mipmapLevelCount, (unsigned long)levels);
        return;
    }
    const float *kernel = [self charon_mps_filter];
    NSUInteger kernelWidth = [self charon_mps_filterWidth];
    NSUInteger kernelHeight = [self charon_mps_filterHeight];
    // The weights are the release's own storage on the bands of 10.0.1 to 10.3.4, and are this port's
    // below 10.0.1 and from 12.0 - measured, and written out beside MPSImagePyramid16.m: the release
    // carries MPSImagePyramid from 10.0.1 without exporting it, the name is therefore an alias, and
    // attach.c hands the release's class the five members it already has, so a pyramid built here
    // inherits the RELEASE's initializers and this port never wrote these weights. MPSImageConvolution.h
    // keeps the weights private, so there is no way to read them and no filter to interpolate with:
    // the walk is refused by name rather than made with a kernel this port did not build.
    if (!kernel || !kernelWidth || !kernelHeight) {
        CharonMPSRefuse(@"%@: the MPSImagePyramid of this iOS is the release's own class, and its filter's"
                        @" weights are in storage no header declares, so no level was written", what);
        return;
    }
    double laplacianBias = [self getLaplacianBias];
    double laplacianScale = [self getLaplacianScale];
    // One level of the answer at a time, from the top down (:713-719). The level ABOVE the first one is
    // not the destination's own - it has not been reconstructed yet - and comes from the source's top
    // level instead, which the header names "the LaplacianMipLevel[#top] level" (:722-725). It is read
    // once, before the walk, and it is the only level read from the source above.
    NSUInteger topWidth = CharonMPSPyramidExtent(sourceTexture.width, levels - 1);
    NSUInteger topHeight = CharonMPSPyramidExtent(sourceTexture.height, levels - 1);
    size_t topBytes = (size_t)topWidth * topHeight * channels * elementSize;
    float *top = (float *)calloc(topBytes ? topBytes : 1, 1);
    if (!top) {
        CharonMPSRefuse(@"%@: no memory for the top level, so no level was written", what);
        return;
    }
    if (!CharonMPSPyramidRead(sourceTexture, levels - 1, topWidth, topHeight, channels, elementSize, top)) {
        free(top);
        CharonMPSRefuse(@"%@: the top level of the source could not be read, so no level was written", what);
        return;
    }
    for (long step = (long)levels - 2; step >= 0; step--) {
        NSUInteger level = (NSUInteger)step;
        NSUInteger width = CharonMPSPyramidExtent(sourceTexture.width, level);
        NSUInteger height = CharonMPSPyramidExtent(sourceTexture.height, level);
        size_t bytes = (size_t)width * height * channels * elementSize;
        float *here = (float *)calloc(bytes ? bytes : 1, 1);
        if (!here) {
            free(top);
            CharonMPSRefuse(@"%@: no memory for level %lu, so no level was written", what, (unsigned long)level);
            return;
        }
        if (!CharonMPSPyramidRead(sourceTexture, level, width, height, channels, elementSize, here)) {
            free(here);
            free(top);
            CharonMPSRefuse(@"%@: level %lu of the source could not be read, so no level was written", what,
                            (unsigned long)level);
            return;
        }
        // The level above: the destination's own, already reconstructed, except at the top where it is
        // the source's own - the one read above.
        BOOL destinationHasAbove = destinationTexture.mipmapLevelCount > level + 1;
        NSUInteger aboveWidth = CharonMPSPyramidExtent(sourceTexture.width, level + 1);
        NSUInteger aboveHeight = CharonMPSPyramidExtent(sourceTexture.height, level + 1);
        size_t aboveBytes = (size_t)aboveWidth * aboveHeight * channels * elementSize;
        float *above = (float *)calloc(aboveBytes ? aboveBytes : 1, 1);
        if (!above || !(level + 1 == levels - 1
                        ? YES
                        : (destinationHasAbove
                           ? CharonMPSPyramidRead(destinationTexture, level + 1, aboveWidth, aboveHeight,
                                                    channels, elementSize, above)
                           : NO))) {
            free(here);
            free(above);
            free(top);
            CharonMPSRefuse(@"%@: level %lu above could not be read, so no level was written", what,
                            (unsigned long)(level + 1));
            return;
        }
        // AboveBytes is topBytes for the one iteration that uses `top`, and the two hold the same level's
        // values; the copy is what keeps one loop below.
        const float *aboveValues = (level + 1 == levels - 1) ? top : above;
        for (NSUInteger y = 0; y < height; y++) {
            for (NSUInteger x = 0; x < width; x++) {
                for (NSUInteger channel = 0; channel < channels; channel++) {
                    // LaplacianRangeScale^-1(stored, bias, scale) = (stored - bias) / scale, then the
                    // interpolated level above is added (:719). A scale of zero has no inverse; the value
                    // is then left as the stored one rather than divided by nothing.
                    double stored = (double)here[(y * width + x) * channels + channel];
                    double raw = laplacianScale != 0.0 ? (stored - laplacianBias) / laplacianScale : stored;
                    double value = raw + CharonMPSPyramidInterpolated(aboveValues, aboveWidth, aboveHeight,
                                                                       channel, channels, x, y,
                                                                       kernel, kernelWidth, kernelHeight);
                    here[(y * width + x) * channels + channel] = (float)value;
                }
            }
        }
        CharonMPSPyramidWrite(destinationTexture, level, width, height, channels, elementSize, here);
        free(here);
        free(above);
    }
    free(top);
}

@end
