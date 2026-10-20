#import "RevenantMPS.h"
#import "RevenantMPSImage.h"


static inline long RevenantMPSResizeSampleInHalfPixels(long destination, long destinationSize,
                                                      long size, BOOL alignCorners)
{
    if (destinationSize < 1)
        destinationSize = 1;
    if (size < 1)
        size = 1;
    long doubled;
    if (alignCorners) {
        if (destinationSize > 1)
            doubled = (2 * (size - 1) * destination) / (destinationSize - 1);
        else
            doubled = 0;
    } else {
        doubled = ((2 * destination + 1) * size) / destinationSize - 1;
    }
    if (doubled < 0)
        doubled = 0;
    long last = 2 * (size - 1);
    if (doubled > last)
        doubled = last;
    return doubled;
}

static inline void RevenantMPSResizeCorners(const void *bytes, const RevenantMPSImageLayout *in,
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
        NSUInteger index = RevenantMPSImageIndex(in, pixel, channel);
        if (index != (NSUInteger)-1)
            corners[corner] = RevenantMPSImageLoad(bytes, in, index);
    }
}

static inline double RevenantMPSResizeBlend(const double corners[4], long atX, long atY)
{
    double alongX = (atX - 2 * (atX / 2)) * 0.5;
    double acrossX = 1.0 - alongX;
    double alongY = (atY - 2 * (atY / 2)) * 0.5;
    double acrossY = 1.0 - alongY;
    double top = corners[0] * acrossX + corners[1] * alongX;
    double bottom = corners[2] * acrossX + corners[3] * alongX;
    return top * acrossY + bottom * alongY;
}

static BOOL RevenantMPSResizePrepare(MPSImage *sourceImage, MPSImage *destinationImage,
                                   NSUInteger resizeWidth, NSUInteger resizeHeight,
                                   NSString *what, BOOL checkDestinationSize)
{
    if (!RevenantMPSImageUsable(sourceImage, what) || !RevenantMPSImageUsable(destinationImage, what))
        return NO;
    if (checkDestinationSize &&
        (destinationImage.width != resizeWidth || destinationImage.height != resizeHeight)) {
        RevenantMPSRefuse(@"%@: the destination is %lux%lu and the kernel was asked for %lux%lu, so nothing "
                        @"was written", what, (unsigned long)destinationImage.width,
                        (unsigned long)destinationImage.height,
                        (unsigned long)resizeWidth, (unsigned long)resizeHeight);
        return NO;
    }
    if (sourceImage.featureChannels != destinationImage.featureChannels) {
        RevenantMPSRefuse(@"%@: the source holds %lu feature channel(s) and the destination %lu, and this "
                        @"resize keeps the number of them, so nothing was written", what,
                        (unsigned long)sourceImage.featureChannels,
                        (unsigned long)destinationImage.featureChannels);
        return NO;
    }
    return YES;
}

static BOOL RevenantMPSResizeBuffers(MPSImage *sourceImage, MPSImage *destinationImage,
                                   RevenantMPSImageLayout *in, RevenantMPSImageLayout *out,
                                   void **from, unsigned char **to, NSString *what)
{
    *in = RevenantMPSImageLayoutOf(sourceImage);
    *out = RevenantMPSImageLayoutOf(destinationImage);
    in->count = sourceImage.width * sourceImage.height * in->channels;
    out->count = destinationImage.width * destinationImage.height * out->channels;
    *from = RevenantMPSImageReadRegion(sourceImage, in,
                                     MTLRegionMake2D(0, 0, sourceImage.width, sourceImage.height), what);
    if (!*from)
        return NO;
    size_t bytes = (size_t)destinationImage.width * out->channels * destinationImage.height * out->elementSize;
    *to = calloc(bytes ? bytes : 1, 1);
    if (!*to) {
        free(*from);
        *from = NULL;
        RevenantMPSRefuse(@"%@: no memory for a %lux%lu result, so nothing was written", what,
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
        RevenantMPSRefuse(@"%@: no command buffer, so nothing was written", what);
        return;
    }
    if (!RevenantMPSResizePrepare(sourceImage, destinationImage, _resizeWidth, _resizeHeight, what, YES))
        return;
    if (!destinationImage.width || !destinationImage.height)
        return;

    RevenantMPSImageLayout in, out;
    void *from;
    unsigned char *to;
    if (!RevenantMPSResizeBuffers(sourceImage, destinationImage, &in, &out, &from, &to, what))
        return;

    long sourceWidth = (long)sourceImage.width, sourceHeight = (long)sourceImage.height;
    long destinationWidth = (long)destinationImage.width, destinationHeight = (long)destinationImage.height;
    for (long y = 0; y < destinationHeight; y++) {
        long atY = RevenantMPSResizeSampleInHalfPixels(y, destinationHeight, sourceHeight, _alignCorners);
        for (long x = 0; x < destinationWidth; x++) {
            long atX = RevenantMPSResizeSampleInHalfPixels(x, destinationWidth, sourceWidth, _alignCorners);
            for (NSUInteger c = 0; c < destinationImage.featureChannels; c++) {
                double corners[4];
                RevenantMPSResizeCorners(from, &in, 0, 0, sourceWidth, sourceHeight, sourceWidth,
                                       c, atX / 2, atX / 2 + 1, atY / 2, atY / 2 + 1, corners);
                double blend = RevenantMPSResizeBlend(corners, atX, atY);
                NSUInteger pixel = (NSUInteger)(y * destinationWidth + x);
                NSUInteger into = RevenantMPSImageIndex(&out, pixel, c);
                if (into != (NSUInteger)-1)
                    RevenantMPSImageStore(to, &out, into, blend);
            }
        }
    }
    free(from);
    (void)RevenantMPSImageWriteRegion(destinationImage, &out,
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

static void RevenantMPSCropWindow(MPSRegion region, NSUInteger sourceWidth, NSUInteger sourceHeight,
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
        RevenantMPSRefuse(@"%@: no command buffer, so nothing was written", what);
        return;
    }
    NSUInteger needed = _resizeHeight * _numberOfRegions;
    if (!RevenantMPSResizePrepare(sourceImage, destinationImage, _resizeWidth, needed, what, YES))
        return;
    if (!_numberOfRegions || !_regions) {
        RevenantMPSRefuse(@"%@: no region was given, so nothing was written", what);
        return;
    }
    if (!destinationImage.width || !needed)
        return;

    RevenantMPSImageLayout in, out;
    void *from;
    unsigned char *to;
    if (!RevenantMPSResizeBuffers(sourceImage, destinationImage, &in, &out, &from, &to, what))
        return;

    for (NSUInteger region = 0; region < _numberOfRegions; region++) {
        long originX = 0, originY = 0, windowWidth = 0, windowHeight = 0;
        RevenantMPSCropWindow(_regions[region], sourceImage.width, sourceImage.height,
                            &originX, &originY, &windowWidth, &windowHeight);
        if (windowWidth < 1 || windowHeight < 1) {
            RevenantMPSRefuse(@"%@: region %lu does not meet the %lux%lu source, so it was not resized",
                            what, (unsigned long)region,
                            (unsigned long)sourceImage.width, (unsigned long)sourceImage.height);
            continue;
        }
        for (NSUInteger y = 0; y < _resizeHeight; y++) {
            long atY = RevenantMPSResizeSampleInHalfPixels((long)y, (long)_resizeHeight, windowHeight, NO);
            for (NSUInteger x = 0; x < _resizeWidth; x++) {
                long atX = RevenantMPSResizeSampleInHalfPixels((long)x, (long)_resizeWidth, windowWidth, NO);
                for (NSUInteger c = 0; c < destinationImage.featureChannels; c++) {
                    double corners[4];
                    RevenantMPSResizeCorners(from, &in, originX, originY, windowWidth, windowHeight,
                                           (long)sourceImage.width, c,
                                           atX / 2, atX / 2 + 1, atY / 2, atY / 2 + 1, corners);
                    double blend = RevenantMPSResizeBlend(corners, atX, atY);
                    NSUInteger pixel = (NSUInteger)((y + region * _resizeHeight) * destinationImage.width + x);
                    NSUInteger into = RevenantMPSImageIndex(&out, pixel, c);
                    if (into != (NSUInteger)-1)
                        RevenantMPSImageStore(to, &out, into, blend);
                }
            }
        }
    }
    free(from);
    (void)RevenantMPSImageWriteRegion(destinationImage, &out,
                                    MTLRegionMake2D(0, 0, destinationImage.width, needed),
                                    to, what);
    free(to);
}

@end
