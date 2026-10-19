// CharonMPSCnn.h — what the convolutional kernels share: a feature channel's slice of an image, the
// offset table a convolution walks, and the padding rule.
//
// The layout is the release's own: an MPSImage is a width by height rectangle of feature channels, and
// a feature channel is a width by height rectangle of one value, stored plane by plane. The offset walk
// and the padding are ncnn's, read from c6b351b56fbe32e0381ae00331e3df649b20d7b7 (BSD 3-Clause):
// `Convolution::convolution` builds a space_ofs table of kernel_tap byte offsets for the stride and the
// dilation once, and `Pooling` divides by the window rather than by the count of values inside it
// unless countIncludePad says otherwise.

#import "CharonMPS.h"
#import "CharonMPS26.h"

@interface MPSCNNKernel (CharonMPSCnn)
// The window a kernel walks, set by its own initialiser and read by the walk, so a subclass does not
// keep a second copy of what its superclass already answers.
- (void)charon_mps_setWindowWidth:(NSUInteger)width
                           height:(NSUInteger)height
                    strideInPixelsX:(NSUInteger)strideX
                    strideInPixelsY:(NSUInteger)strideY
                     dilationRateX:(NSUInteger)dilationX
                     dilationRateY:(NSUInteger)dilationY;
@end

@interface MPSCNNPooling (CharonMPSCnn)
- (void)charon_mps_setMaximum:(BOOL)maximum;
- (NSUInteger)charon_mps_zeroPadSizeX;
- (NSUInteger)charon_mps_zeroPadSizeY;
@end


// The bytes one pixel of an image occupies, and the address of one feature channel's pixel, in the
// plane-per-channel layout. A value is at (x, y, channel).
typedef struct {
    const void *base;
    size_t width, height, channels;
    size_t stride;          // bytes from one pixel to the next along a row
    size_t element;         // bytes in one value
} CharonMPSCnnPlane;

static inline const void *CharonMPSCnnPixel(const CharonMPSCnnPlane *plane, size_t x, size_t y, size_t channel)
{
    // The stride is a number of bytes and x is a number of pixels, so the pixel's own offset inside
    // its row is x times the element size, not x.
    return (const char *)plane->base + (channel * plane->height + y) * plane->stride + x * plane->element;
}

static inline void *CharonMPSCnnPixelMutable(CharonMPSCnnPlane *plane, size_t x, size_t y, size_t channel)
{
    return (char *)plane->base + (channel * plane->height + y) * plane->stride + x * plane->element;
}

// The values of one image, as a plane per feature channel, copied in and out through the image's
// texture - which is where the release keeps them and where a kernel writes.
static inline BOOL CharonMPSCnnTake(MPSImage *image, CharonMPSCnnPlane *plane, size_t *width, size_t *height, size_t *channels)
{
    size_t element = MPSSizeofMPSDataType(MPSDataTypeFloat32);
    *width = image.width;
    *height = image.height;
    *channels = image.featureChannels;
    size_t stride = *width * element;
    size_t bytes = stride * (*height * *channels);
    void *storage = calloc(bytes ? bytes : 1, 1);
    [[image texture] getBytes:storage bytesPerRow:stride fromRegion:MTLRegionMake2D(0, 0, *width, *height) mipmapLevel:0];
    plane->base = storage;
    plane->width = *width;
    plane->height = *height;
    plane->channels = *channels;
    plane->stride = stride;
    plane->element = element;
    return YES;
}

static inline void CharonMPSCnnGive(MPSImage *image, CharonMPSCnnPlane *plane)
{
    [[image texture] replaceRegion:MTLRegionMake2D(0, 0, plane->width, plane->height)
                      mipmapLevel:0 withBytes:plane->base bytesPerRow:plane->stride];
    free((void *)plane->base);
    plane->base = NULL;
}


// The kernel-tap offsets for a stride and a dilation, ncnn's space_ofs: the byte distance from a
// window's top-left pixel to each of the kernel's taps, walking right along a row and then down.
typedef struct {
    size_t tap;
    NSUInteger y, x;
} CharonMPSCnnTap;

static inline NSUInteger CharonMPSCnnTaps(NSUInteger kernelWidth, NSUInteger kernelHeight, NSUInteger strideX, NSUInteger strideY, CharonMPSCnnTap *out)
{
    NSUInteger count = 0;
    for (NSUInteger ky = 0; ky < kernelHeight; ky++)
        for (NSUInteger kx = 0; kx < kernelWidth; kx++) {
            out[count].y = ky;
            out[count].x = kx;
            out[count].tap = count;
            count++;
        }
    (void)strideX;
    (void)strideY;
    return count;
}

// The source offset of a tap for a given output position, or NO when the tap falls outside the image.
static inline BOOL CharonMPSCnnSourceFor(NSUInteger outX, NSUInteger outY,
                                          NSUInteger tapX, NSUInteger tapY,
                                          NSUInteger strideX, NSUInteger strideY,
                                          NSUInteger dilationX, NSUInteger dilationY,
                                          NSUInteger width, NSUInteger height,
                                          NSUInteger leftPad, NSUInteger topPad,
                                          NSUInteger *sourceX, NSUInteger *sourceY)
{
    long x = (long)outX * (long)strideX + (long)tapX * (long)dilationX - (long)leftPad;
    long y = (long)outY * (long)strideY + (long)tapY * (long)dilationY - (long)topPad;
    if (x < 0 || y < 0 || (NSUInteger)x >= width || (NSUInteger)y >= height)
        return NO;
    *sourceX = (NSUInteger)x;
    *sourceY = (NSUInteger)y;
    return YES;
}
