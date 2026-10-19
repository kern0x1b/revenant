// MPSImageGaussianPyramid, the one pyramid kernel the header calls "currently supported" under
// MPSImagePyramid (MPSImageConvolution.h:497-498), from the iPhoneOS 16.4 surface of
// MPSImageConvolution.h.
//
// One object for one release. MPSImageConvolution.h:612 annotates this class ios(10.0) and the release
// exports _OBJC_CLASS_$_MPSImageGaussianPyramid from 10.0.1, which tools/release-split.lua measures
// over the held ladder and agrees with, so 10.0 is what this object implements. Its superclass
// MPSImagePyramid is exported only from 16.0 and is MPSImagePyramid16.m's class; MPSImageConvolution.h
// annotates that one ios(10.0) too and the releases do not agree, which is written down where it is
// implemented. The three Laplacian pyramid classes annotate ios(10.0) as well and the ladder exports
// them from 12.0, so they are MPSImageLaplacianPyramid12.m's work. What the three objects share is in
// CharonMPSPyramid.h.
//
// THE FILTER is MPSImagePyramid's own and is reached through charon_mps_filter, which MPSImagePyramid16.m
// implements and every band that keeps this object also keeps, because the release exports this class
// from 10.0.1 and the base only from 16.0: a band keeps an object when the release does not export it, so
// a band that keeps this one is below 10.0.1 and therefore below 16.0.
//
// THE LEVEL SHAPE is the header's own (:508-514):
//     w_n = max(1, floor(w_0 / 2^n)),  h_n = max(1, floor(h_0 / 2^n))
//
// THE WALK (:519-537 and :576-596) fills every mipmap level after level 0, in place:
//     mip[n+1] = Downsample( filter( mip[n] ) )
// where Downsample "removes odd rows and columns from the input image" (:582-583) - which is to say
// level n+1's pixel (x, y) is the filtered level n at (2x, 2y). The header says the pyramid "ignores
// clipRect and offset and fills the entire mipmap levels" (:506-508), so nothing here reads either.
//
// WHAT IS NOT CLAIMED. No number in this file is a measurement of Apple's code - the release's own MPS
// crashes on this encode, which facts/MetalPerformanceShaders/Elements10.md records with its
// transcript. What is written here is transcribed from the header above; what has been checked is the
// armv7 link, that this object defines the class it says.

#import "CharonMPSPyramid.h"

// The value of the kernel's own filter at (x, y) of a level: the taps read the source, clamped at the
// border, which is the ordinary edge rule for a blur. The kernel is stored row major over
// kernelWidth * kernelHeight, so the tap at (kx, ky) weighs kernel[ky * kernelWidth + kx].
static double CharonMPSPyramidFiltered(const float *source, NSUInteger width, NSUInteger height,
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

// The class itself first, and it is needed: MPSImageConvolution.h:613 ends at @end, so this class has
// nothing of its own to write, and a CATEGORY cannot create the class it is written on - which this
// object said outright before the empty @implementation was added, _OBJC_CLASS_$_MPSImageGaussianPyramid
// left undefined by the file alone, so NSClassFromString answered nil and an alloc on it died in the
// loader. An empty @implementation is the arrangement MPSImageThreshold13.m and MPSImageArithmetic13.m
// already use in this package.
@implementation MPSImageGaussianPyramid
@end

// The encode is a CATEGORY on this class and not on MPSImagePyramid, and that is the arrangement the
// header requires and not a preference: "the user must run the operation in-place using
// MPSUnaryImageKernel::encodeToCommandBuffer:inPlaceTexture:fallbackCopyAllocator:"
// (MPSImageConvolution.h:592-594), and MPSUnaryImageKernel9.m answers that selector by refusing,
// because the in-place form needs MPSCopyAllocator semantics. A subclass's own implementation is found
// before its superclass's, so the pyramid's in-place walk is this category's and the refusal above it
// is what every other MPSUnaryImageKernel still gets.
@interface MPSImageGaussianPyramid (CharonMPSGaussianPyramid)
- (BOOL)encodeToCommandBuffer:(id<MTLCommandBuffer>)commandBuffer
                  inPlaceTexture:(id<MTLTexture>)texture
       fallbackCopyAllocator:(MPSCopyAllocator)copyAllocator;
@end

@implementation MPSImageGaussianPyramid (CharonMPSGaussianPyramid)

- (BOOL)encodeToCommandBuffer:(id<MTLCommandBuffer>)commandBuffer
                 inPlaceTexture:(id<MTLTexture>)texture
       fallbackCopyAllocator:(MPSCopyAllocator)copyAllocator
{
    // "The fallbackCopyAllocator parameter is not used" (MPSImageConvolution.h:595), because the work
    // is in place: every level of the texture is both read and written, which is what makes this the
    // form the header insists on.
    (void)copyAllocator;
    NSString *what = @"MPSImageGaussianPyramid";
    if (!commandBuffer) {
        CharonMPSRefuse(@"%@: no command buffer, so no level was written", what);
        return NO;
    }
    if (!CharonMPSCommandBufferPermits(commandBuffer))
        return NO;
    if (!texture) {
        CharonMPSRefuse(@"%@: no texture, so no level was written", what);
        return NO;
    }
    NSUInteger channels = 0;
    size_t elementSize = 0;
    if (!CharonMPSPyramidPixelShape(texture.pixelFormat, &channels, &elementSize) || !channels || !elementSize) {
        CharonMPSRefuse(@"%@: a texture of pixel format %d names no element width this port carries, so no"
                        @" level was written", what, (int)texture.pixelFormat);
        return NO;
    }
    const float *kernel = [self charon_mps_filter];
    NSUInteger kernelWidth = [self charon_mps_filterWidth];
    NSUInteger kernelHeight = [self charon_mps_filterHeight];
    NSUInteger levels = texture.mipmapLevelCount;
    if (levels < 2) {
        CharonMPSRefuse(@"%@: the texture has %lu mip level(s) and a pyramid writes every level after the"
                        @" first, so there was nothing to do", what, (unsigned long)levels);
        return NO;
    }
    NSUInteger baseWidth = texture.width, baseHeight = texture.height;
    for (NSUInteger level = 1; level < levels; level++) {
        NSUInteger sourceWidth = CharonMPSPyramidExtent(baseWidth, level - 1);
        NSUInteger sourceHeight = CharonMPSPyramidExtent(baseHeight, level - 1);
        NSUInteger width = CharonMPSPyramidExtent(baseWidth, level);
        NSUInteger height = CharonMPSPyramidExtent(baseHeight, level);
        size_t sourceBytes = (size_t)sourceWidth * sourceHeight * channels * elementSize;
        size_t bytes = (size_t)width * height * channels * elementSize;
        float *source = (float *)calloc(sourceBytes ? sourceBytes : 1, 1);
        float *answer = (float *)calloc(bytes ? bytes : 1, 1);
        if (!source || !answer) {
            free(source);
            free(answer);
            CharonMPSRefuse(@"%@: no memory for level %lu, so no level was written", what, (unsigned long)level);
            return NO;
        }
        if (!CharonMPSPyramidRead(texture, level - 1, sourceWidth, sourceHeight, channels, elementSize, source)) {
            free(source);
            free(answer);
            CharonMPSRefuse(@"%@: level %lu could not be read, so the pyramid stopped there", what,
                            (unsigned long)(level - 1));
            return NO;
        }
        // Downsample: this level's pixel (x, y) is the filtered level above at (2x, 2y), which is the header's Downsample() dropping the odd rows and columns of its input (MPSImageConvolution.h:582-583).
        for (NSUInteger y = 0; y < height; y++) {
            for (NSUInteger x = 0; x < width; x++) {
                NSUInteger at = 2 * x, over = 2 * y;
                if (at >= sourceWidth)
                    at = sourceWidth ? sourceWidth - 1 : 0;
                if (over >= sourceHeight)
                    over = sourceHeight ? sourceHeight - 1 : 0;
                for (NSUInteger channel = 0; channel < channels; channel++) {
                    double value = CharonMPSPyramidFiltered(source, sourceWidth, sourceHeight, channel, channels,
                                                            at, over, kernel, kernelWidth, kernelHeight);
                    answer[(y * width + x) * channels + channel] = (float)value;
                }
            }
        }
        BOOL written = CharonMPSPyramidWrite(texture, level, width, height, channels, elementSize, answer);
        free(source);
        free(answer);
        if (!written) {
            CharonMPSRefuse(@"%@: level %lu could not be written, so the pyramid stopped there", what,
                            (unsigned long)level);
            return NO;
        }
    }
    return YES;
}

@end
