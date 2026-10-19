#import "RevenantMPS.h"
#import "RevenantMPS26.h"

@interface MPSCNNKernel (RevenantMPSCnn)
- (void)revenant_mps_setWindowWidth:(NSUInteger)width
                           height:(NSUInteger)height
                    strideInPixelsX:(NSUInteger)strideX
                    strideInPixelsY:(NSUInteger)strideY
                     dilationRateX:(NSUInteger)dilationX
                     dilationRateY:(NSUInteger)dilationY;
@end

@interface MPSCNNPooling (RevenantMPSCnn)
- (void)revenant_mps_setMaximum:(BOOL)maximum;
- (NSUInteger)revenant_mps_zeroPadSizeX;
- (NSUInteger)revenant_mps_zeroPadSizeY;
@end


typedef struct {
    const void *base;
    size_t width, height, channels;
    size_t stride;
    size_t element;
} RevenantMPSCnnPlane;

static inline const void *RevenantMPSCnnPixel(const RevenantMPSCnnPlane *plane, size_t x, size_t y, size_t channel)
{
    return (const char *)plane->base + (channel * plane->height + y) * plane->stride + x * plane->element;
}

static inline void *RevenantMPSCnnPixelMutable(RevenantMPSCnnPlane *plane, size_t x, size_t y, size_t channel)
{
    return (char *)plane->base + (channel * plane->height + y) * plane->stride + x * plane->element;
}

static inline BOOL RevenantMPSCnnTake(MPSImage *image, RevenantMPSCnnPlane *plane, size_t *width, size_t *height, size_t *channels)
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

static inline void RevenantMPSCnnGive(MPSImage *image, RevenantMPSCnnPlane *plane)
{
    [[image texture] replaceRegion:MTLRegionMake2D(0, 0, plane->width, plane->height)
                      mipmapLevel:0 withBytes:plane->base bytesPerRow:plane->stride];
    free((void *)plane->base);
    plane->base = NULL;
}


typedef struct {
    size_t tap;
    NSUInteger y, x;
} RevenantMPSCnnTap;

static inline NSUInteger RevenantMPSCnnTaps(NSUInteger kernelWidth, NSUInteger kernelHeight, NSUInteger strideX, NSUInteger strideY, RevenantMPSCnnTap *out)
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

static inline BOOL RevenantMPSCnnSourceFor(NSUInteger outX, NSUInteger outY,
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
