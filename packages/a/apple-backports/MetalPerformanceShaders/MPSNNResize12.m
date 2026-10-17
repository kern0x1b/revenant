// MPSNNResizeBilinear and MPSNNCropAndResizeBilinear, from MPSNNResize.h of the iPhoneOS 16.4 SDK.
// One object for one release: `xmake l tools/cache-index/first-rung.lua MPSNNResizeBilinear
// MPSNNCropAndResizeBilinear` answers 12.0 for both, and every other name this file defines is a
// member both headers declare at ios(12.0), so this file carries 12.0 API only.
//
// WHAT THE HEADERS ASK FOR. Both classes derive from MPSCNNKernel, and both produce a bilinear-interpolated copy
// of the source at the size set by resizeWidth and resizeHeight, with the feature channel count left as it was.
// MPSNNResizeBilinear adds one flag, alignCorners: when YES, the outer pixel centres of the input and output
// are lined up, so the corner values are kept. It defaults to NO (the header's own default).
//
// So there are exactly two sampling conventions and they are both implemented here, each in one
// place, from the two properties' own wording:
//
//   alignCorners == YES   a corner pixel is preserved, so destination x maps onto source x as
//                         x * (sourceWidth - 1) / (destinationWidth - 1): the first and last
//                         destination pixels read the first and last source pixels with no blend.
//   alignCorners == NO    the CENTRES align, so the sampling point is the destination pixel's centre
//                         mapped by the ratio of the extents, less half a source pixel to get from a
//                         centre to an edge: (x + 0.5) * source / destination - 0.5. A destination of
//                         one pixel on an axis has its centre on the source's centre.
//
// Both then clamp: a sampling point before the first source pixel reads that pixel, and one past the
// last reads the last. That is what makes every sample fall inside the image, and it is the same rule
// MPSNNCropAndResizeBilinear's own doc gives for a region outside [0, 1] - except that this kernel
// extrapolates, which is below.
//
// MPSNNCropAndResizeBilinear takes its regions as `const MPSRegion *`, a pointer to a run of as many records
// as there are regions, each giving a crop box in the source image with normalized coordinates. MPSRegion is
// { MPSOrigin origin; MPSSize size; } and
// both are doubles (MPSCoreTypes.h:321-338 and :355-359), so a region is read as the array of
// structs the header declares - not as an NSArray of boxes, and not through a coordinate convention
// of this file's own. The destination is resizeWidth by (resizeHeight * numberOfRegions), the crops
// stacked along its height, which is what a batch of crops of one image is in this framework.
//
// WHY THE WALK IS THIS FILE'S. The helpers in CharonMPSImage.h read a region into a buffer and write
// one back, and index a region's buffer row-major over width * channels per row. Both classes walk
// the DESTINATION and pick their source pixels, so the arithmetic here is one bilinear blend per
// channel per destination pixel and the four-neighbour index arithmetic is this file's alone.

#import "CharonMPS.h"
#import "CharonMPSImage.h"


// The source position a destination position samples, in HALF source pixels, so the bilinear weights
// stay exact and the fraction is either 0 or a half. `alignCorners` picks the convention; the result
// is clamped into [0, 2 * (size - 1)], which is what puts a sample at or past an edge onto that edge
// instead of off the image.
static inline long CharonMPSResizeSampleInHalfPixels(long destination, long destinationSize,
                                                      long size, BOOL alignCorners)
{
    if (destinationSize < 1)
        destinationSize = 1;
    if (size < 1)
        size = 1;
    long doubled;
    if (alignCorners) {
        // The corner pixels are preserved, so the source extent that is spread is size - 1. A
        // destinationSize of one has no other pixel to divide between and reads the source's start.
        if (destinationSize > 1)
            doubled = (2 * (size - 1) * destination) / (destinationSize - 1);
        else
            doubled = 0;
    } else {
        // Centres: (destination + 0.5) * size / destinationSize - 0.5, in half units, which is
        // (2 * destination + 1) * size / destinationSize - 1.
        doubled = ((2 * destination + 1) * size) / destinationSize - 1;
    }
    if (doubled < 0)
        doubled = 0;
    long last = 2 * (size - 1);
    if (doubled > last)
        doubled = last;
    return doubled;
}

// The four neighbours of a sample, in the corners' order: top-left, top-right, bottom-left,
// bottom-right. A neighbour outside the window reads zero, which happens only for a window of one
// pixel on an axis, and the weights then put all of the value on that one pixel.
//
// `originX`/`originY` are where the window begins in the source and `strideWidth` is how many pixels
// one row of the buffer holds, which is the source's own width: the whole source is read once, and a
// crop's window is a rectangle inside it rather than a second read.
static inline void CharonMPSResizeCorners(const void *bytes, const CharonMPSImageLayout *in,
                                          long originX, long originY,
                                          long windowWidth, long windowHeight, long strideWidth,
                                          NSUInteger channel, long lowX, long highX,
                                          long lowY, long highY, double corners[4])
{
    long xs[4] = {originX + lowX, originX + highX, originX + lowX, originX + highX};
    long ys[4] = {originY + lowY, originY + lowY, originY + highY, originY + highY};
    for (int corner = 0; corner < 4; corner++) {
        corners[corner] = 0.0;
        if (xs[corner] < originX || ys[corner] < originY)
            continue;
        if (xs[corner] >= originX + windowWidth || ys[corner] >= originY + windowHeight)
            continue;
        NSUInteger pixel = (NSUInteger)ys[corner] * (NSUInteger)strideWidth + (NSUInteger)xs[corner];
        NSUInteger index = CharonMPSImageIndex(in, pixel, channel);
        if (index != (NSUInteger)-1)
            corners[corner] = CharonMPSImageLoad(bytes, in, index);
    }
}

// The blend itself, in both axes at once: the four corners of the destination pixel's cell, weighted
// by how far the sample sits along each axis. The weight away from the low pixel is half the
// half-pixel offset - so either 0 or one half, and a sample exactly on a pixel takes that pixel whole,
// which is what makes alignCorners == NO exact for a scale of one. Along x first, then along y.
static inline double CharonMPSResizeBlend(const double corners[4], long atX, long atY)
{
    double alongX = (atX - 2 * (atX / 2)) * 0.5;
    double acrossX = 1.0 - alongX;
    double alongY = (atY - 2 * (atY / 2)) * 0.5;
    double acrossY = 1.0 - alongY;
    double top = corners[0] * acrossX + corners[1] * alongX;
    double bottom = corners[2] * acrossX + corners[3] * alongX;
    return top * acrossY + bottom * alongY;
}

// The four shapes a destination must have before anything is written: the two images usable, the
// destination the size the kernel was asked for, and the number of feature channels they share.
// Returns NO and says which of them failed, so the two classes report the same refusals.
static BOOL CharonMPSResizePrepare(MPSImage *sourceImage, MPSImage *destinationImage,
                                   NSUInteger resizeWidth, NSUInteger resizeHeight,
                                   NSString *what, BOOL checkDestinationSize)
{
    if (!CharonMPSImageUsable(sourceImage, what) || !CharonMPSImageUsable(destinationImage, what))
        return NO;
    if (checkDestinationSize &&
        (destinationImage.width != resizeWidth || destinationImage.height != resizeHeight)) {
        CharonMPSRefuse(@"%@: the destination is %lux%lu and the kernel was asked for %lux%lu, so nothing "
                        @"was written", what, (unsigned long)destinationImage.width,
                        (unsigned long)destinationImage.height,
                        (unsigned long)resizeWidth, (unsigned long)resizeHeight);
        return NO;
    }
    if (sourceImage.featureChannels != destinationImage.featureChannels) {
        CharonMPSRefuse(@"%@: the source holds %lu feature channel(s) and the destination %lu, and this "
                        @"resize keeps the number of them, so nothing was written", what,
                        (unsigned long)sourceImage.featureChannels,
                        (unsigned long)destinationImage.featureChannels);
        return NO;
    }
    return YES;
}

// Read the whole source once and allocate the whole destination, which is the pair of allocations
// every resize in this file makes. The layouts come back with `in` sized over the source's own extent
// and `out` over the destination's, which is what makes an index into either buffer mean that
// buffer's pixel.
static BOOL CharonMPSResizeBuffers(MPSImage *sourceImage, MPSImage *destinationImage,
                                   CharonMPSImageLayout *in, CharonMPSImageLayout *out,
                                   void **from, unsigned char **to, NSString *what)
{
    *in = CharonMPSImageLayoutOf(sourceImage);
    *out = CharonMPSImageLayoutOf(destinationImage);
    in->count = sourceImage.width * sourceImage.height * in->channels;
    out->count = destinationImage.width * destinationImage.height * out->channels;
    *from = CharonMPSImageReadRegion(sourceImage, in,
                                     MTLRegionMake2D(0, 0, sourceImage.width, sourceImage.height), what);
    if (!*from)
        return NO;
    size_t bytes = (size_t)destinationImage.width * out->channels * destinationImage.height * out->elementSize;
    *to = calloc(bytes ? bytes : 1, 1);
    if (!*to) {
        free(*from);
        *from = NULL;
        CharonMPSRefuse(@"%@: no memory for a %lux%lu result, so nothing was written", what,
                        (unsigned long)destinationImage.width, (unsigned long)destinationImage.height);
        return NO;
    }
    return YES;
}


@implementation MPSNNResizeBilinear {
    NSUInteger _resizeWidth;
    NSUInteger _resizeHeight;
    BOOL _alignCorners;
}

// -initWithDevice: is NS_UNAVAILABLE in MPSNNResize.h, so this class is not built by name: the two
// initialisers below are the only ways to make one, and each of them sets the size the encode needs.
- (instancetype)initWithDevice:(id<MTLDevice>)device
                  resizeWidth:(NSUInteger)resizeWidth
                 resizeHeight:(NSUInteger)resizeHeight
                  alignCorners:(BOOL)alignCorners
{
    if ((self = [super initWithDevice:device])) {
        _resizeWidth = resizeWidth;
        _resizeHeight = resizeHeight;
        _alignCorners = alignCorners;
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder device:(id<MTLDevice>)device
{
    // The three values are the kernel's whole state and the coder is where MPSKernel's own
    // initialisers put them, so they are read by the names the properties carry.
    if ((self = [super initWithDevice:device])) {
        _resizeWidth = (NSUInteger)[aDecoder decodeDoubleForKey:@"resizeWidth"];
        _resizeHeight = (NSUInteger)[aDecoder decodeDoubleForKey:@"resizeHeight"];
        _alignCorners = [aDecoder decodeBoolForKey:@"alignCorners"];
    }
    return self;
}

- (NSUInteger)resizeWidth { return _resizeWidth; }
- (NSUInteger)resizeHeight { return _resizeHeight; }
- (BOOL)alignCorners { return _alignCorners; }

- (void)encodeToCommandBuffer:(id<MTLCommandBuffer>)commandBuffer
                  sourceImage:(MPSImage *)sourceImage
             destinationImage:(MPSImage *)destinationImage
{
    NSString *what = NSStringFromClass([self class]);
    if (!commandBuffer) {
        CharonMPSRefuse(@"%@: no command buffer, so nothing was written", what);
        return;
    }
    if (!CharonMPSResizePrepare(sourceImage, destinationImage, _resizeWidth, _resizeHeight, what, YES))
        return;
    if (!destinationImage.width || !destinationImage.height)
        return;

    CharonMPSImageLayout in, out;
    void *from;
    unsigned char *to;
    if (!CharonMPSResizeBuffers(sourceImage, destinationImage, &in, &out, &from, &to, what))
        return;

    // The whole source is the window: this kernel resizes the image it was given, so the window is
    // the source's own extent and the two half-pixel positions are the resize's. Every channel of a
    // pixel uses the same two positions, so only the channel index differs inside the loops.
    long sourceWidth = (long)sourceImage.width, sourceHeight = (long)sourceImage.height;
    long destinationWidth = (long)destinationImage.width, destinationHeight = (long)destinationImage.height;
    for (long y = 0; y < destinationHeight; y++) {
        long atY = CharonMPSResizeSampleInHalfPixels(y, destinationHeight, sourceHeight, _alignCorners);
        for (long x = 0; x < destinationWidth; x++) {
            long atX = CharonMPSResizeSampleInHalfPixels(x, destinationWidth, sourceWidth, _alignCorners);
            for (NSUInteger c = 0; c < destinationImage.featureChannels; c++) {
                double corners[4];
                CharonMPSResizeCorners(from, &in, 0, 0, sourceWidth, sourceHeight, sourceWidth,
                                       c, atX / 2, atX / 2 + 1, atY / 2, atY / 2 + 1, corners);
                double blend = CharonMPSResizeBlend(corners, atX, atY);
                NSUInteger pixel = (NSUInteger)(y * destinationWidth + x);
                NSUInteger into = CharonMPSImageIndex(&out, pixel, c);
                if (into != (NSUInteger)-1)
                    CharonMPSImageStore(to, &out, into, blend);
            }
        }
    }
    free(from);
    (void)CharonMPSImageWriteRegion(destinationImage, &out,
                                    MTLRegionMake2D(0, 0, destinationImage.width, destinationImage.height),
                                    to, what);
    free(to);
}

@end


@implementation MPSNNCropAndResizeBilinear {
    NSUInteger _resizeWidth;
    NSUInteger _resizeHeight;
    NSUInteger _numberOfRegions;
    const MPSRegion *_regions;
}

- (instancetype)initWithDevice:(id<MTLDevice>)device
                  resizeWidth:(NSUInteger)resizeWidth
                 resizeHeight:(NSUInteger)resizeHeight
                numberOfRegions:(NSUInteger)numberOfRegions
                       regions:(const MPSRegion *)regions
{
    if ((self = [super initWithDevice:device])) {
        _resizeWidth = resizeWidth;
        _resizeHeight = resizeHeight;
        _numberOfRegions = numberOfRegions;
        _regions = regions;
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder device:(id<MTLDevice>)device
{
    // The regions are a pointer to C structs and an NSCoder holds objects, so what a coder can carry
    // is the count and the two sizes. A decoded kernel with no region behind its count has no source
    // window to sample, and the encode below says so rather than reading a pointer nothing set.
    if ((self = [super initWithDevice:device])) {
        _resizeWidth = (NSUInteger)[aDecoder decodeDoubleForKey:@"resizeWidth"];
        _resizeHeight = (NSUInteger)[aDecoder decodeDoubleForKey:@"resizeHeight"];
        _numberOfRegions = (NSUInteger)[aDecoder decodeDoubleForKey:@"numberOfRegions"];
        _regions = NULL;
    }
    return self;
}

- (NSUInteger)resizeWidth { return _resizeWidth; }
- (NSUInteger)resizeHeight { return _resizeHeight; }
- (NSUInteger)numberOfRegions { return _numberOfRegions; }
- (const MPSRegion *)regions { return _regions; }

// One region, in whole source pixels, intersected with the source. The coordinates are normalised, so
// the window is a fraction of the source and a region that runs off an edge contributes only what the
// image has - the same rule the clip rectangle is resolved by elsewhere in this package, and the
// reason a normalised box needs no clamping before it reaches the sampler.
static void CharonMPSCropWindow(MPSRegion region, NSUInteger sourceWidth, NSUInteger sourceHeight,
                                long *originX, long *originY, long *windowWidth, long *windowHeight)
{
    double left = region.origin.x * (double)sourceWidth;
    double top = region.origin.y * (double)sourceHeight;
    double right = (region.origin.x + region.size.width) * (double)sourceWidth;
    double bottom = (region.origin.y + region.size.height) * (double)sourceHeight;

    long firstColumn = (long)ceil(left);
    long firstRow = (long)ceil(top);
    long lastColumn = (long)floor(right);
    long lastRow = (long)floor(bottom);
    if (firstColumn < 0) firstColumn = 0;
    if (firstRow < 0) firstRow = 0;
    if (lastColumn > (long)sourceWidth) lastColumn = (long)sourceWidth;
    if (lastRow > (long)sourceHeight) lastRow = (long)sourceHeight;
    *originX = firstColumn;
    *originY = firstRow;
    *windowWidth = lastColumn - firstColumn;
    *windowHeight = lastRow - firstRow;
    if (*windowWidth < 0) *windowWidth = 0;
    if (*windowHeight < 0) *windowHeight = 0;
}

- (void)encodeToCommandBuffer:(id<MTLCommandBuffer>)commandBuffer
                  sourceImage:(MPSImage *)sourceImage
             destinationImage:(MPSImage *)destinationImage
{
    NSString *what = NSStringFromClass([self class]);
    if (!commandBuffer) {
        CharonMPSRefuse(@"%@: no command buffer, so nothing was written", what);
        return;
    }
    // The destination of N crops is resizeWidth by (resizeHeight * N): one crop stacked under the
    // next, which is how a batch of crops of a single source is laid out in this framework. So the
    // destination's height is checked against the regions, not against resizeHeight alone.
    NSUInteger needed = _resizeHeight * _numberOfRegions;
    if (!CharonMPSResizePrepare(sourceImage, destinationImage, _resizeWidth, needed, what, YES))
        return;
    if (!_numberOfRegions || !_regions) {
        CharonMPSRefuse(@"%@: no region was given, so nothing was written", what);
        return;
    }
    if (!destinationImage.width || !needed)
        return;

    CharonMPSImageLayout in, out;
    void *from;
    unsigned char *to;
    if (!CharonMPSResizeBuffers(sourceImage, destinationImage, &in, &out, &from, &to, what))
        return;

    for (NSUInteger region = 0; region < _numberOfRegions; region++) {
        long originX = 0, originY = 0, windowWidth = 0, windowHeight = 0;
        CharonMPSCropWindow(_regions[region], sourceImage.width, sourceImage.height,
                            &originX, &originY, &windowWidth, &windowHeight);
        if (windowWidth < 1 || windowHeight < 1) {
            CharonMPSRefuse(@"%@: region %lu does not meet the %lux%lu source, so it was not resized",
                            what, (unsigned long)region,
                            (unsigned long)sourceImage.width, (unsigned long)sourceImage.height);
            continue;
        }
        // The resize is over the CROP: a box a third of the source wide is sampled across that third
        // and resized to resizeWidth, not sampled across the whole image.
        for (NSUInteger y = 0; y < _resizeHeight; y++) {
            long atY = CharonMPSResizeSampleInHalfPixels((long)y, (long)_resizeHeight, windowHeight, NO);
            for (NSUInteger x = 0; x < _resizeWidth; x++) {
                long atX = CharonMPSResizeSampleInHalfPixels((long)x, (long)_resizeWidth, windowWidth, NO);
                for (NSUInteger c = 0; c < destinationImage.featureChannels; c++) {
                    double corners[4];
                    CharonMPSResizeCorners(from, &in, originX, originY, windowWidth, windowHeight,
                                           (long)sourceImage.width, c,
                                           atX / 2, atX / 2 + 1, atY / 2, atY / 2 + 1, corners);
                    double blend = CharonMPSResizeBlend(corners, atX, atY);
                    NSUInteger pixel = (NSUInteger)((y + region * _resizeHeight) * destinationImage.width + x);
                    NSUInteger into = CharonMPSImageIndex(&out, pixel, c);
                    if (into != (NSUInteger)-1)
                        CharonMPSImageStore(to, &out, into, blend);
                }
            }
        }
    }
    free(from);
    (void)CharonMPSImageWriteRegion(destinationImage, &out,
                                    MTLRegionMake2D(0, 0, destinationImage.width, needed),
                                    to, what);
    free(to);
}

@end