#import "RevenantMPS.h"
#import "RevenantMPSImage.h"

#pragma clang diagnostic ignored "-Wincomplete-implementation"
#pragma clang diagnostic ignored "-Wobjc-designated-initializers"

typedef NS_ENUM(NSInteger, RevenantMPSMorphologyPick) {
    RevenantMPSMorphologyMax = 0,
    RevenantMPSMorphologyMin,
};

static void RevenantMPSMorphologyRegion(MPSImage *source, MPSImage *destination, MTLRegion read,
                                      NSUInteger kernelWidth, NSUInteger kernelHeight,
                                      const float *probe, RevenantMPSMorphologyPick pick, NSString *what)
{
    RevenantMPSImageLayout in = RevenantMPSImageLayoutOf(source);
    RevenantMPSImageLayout out = RevenantMPSImageLayoutOf(destination);
    if (!kernelWidth || !kernelHeight) {
        RevenantMPSRefuse(@"%@: a %lux%lu window has no centre, so nothing was written", what,
                        (unsigned long)kernelWidth, (unsigned long)kernelHeight);
        return;
    }
    RevenantMPSImageLayout slice = in;
    slice.count = read.size.width * read.size.height * in.channels;
    void *from = RevenantMPSImageReadRegion(source, &slice, read, what);
    if (slice.count && !from)
        return;

    NSUInteger halfW = kernelWidth / 2, halfH = kernelHeight / 2;
    float *answer = calloc(slice.count ? slice.count : 1, sizeof(float));
    if (!answer) {
        RevenantMPSRefuse(@"%@: no memory for a %lux%lu result, so nothing was written", what,
                        (unsigned long)read.size.width, (unsigned long)read.size.height);
        return;
    }
    for (NSUInteger channel = 0; channel < in.channels; channel++) {
        for (NSUInteger y = 0; y < read.size.height; y++) {
            for (NSUInteger x = 0; x < read.size.width; x++) {
                double best = 0.0;
                for (NSUInteger ky = 0; ky < kernelHeight; ky++) {
                    for (NSUInteger kx = 0; kx < kernelWidth; kx++) {
                        long sy = (long)(read.origin.y + y + ky) - (long)halfH;
                        long sx = (long)(read.origin.x + x + kx) - (long)halfW;
                        if (sy < 0) sy = 0;
                        if (sx < 0) sx = 0;
                        if (sy >= (long)in.height) sy = (long)in.height - 1;
                        if (sx >= (long)in.width) sx = (long)in.width - 1;
                        NSUInteger index = (NSUInteger)sy * in.width + (NSUInteger)sx;
                        double value = RevenantMPSImageLoad(from, &slice,
                                                         RevenantMPSImageIndex(&slice, index, channel));
                        double candidate = probe ? (value + (double)probe[ky * kernelWidth + kx]) : value;
                        if (kx == 0 && ky == 0)
                            best = candidate;
                        else if (pick == RevenantMPSMorphologyMax ? candidate > best : candidate < best)
                            best = candidate;
                    }
                }
                answer[(y * read.size.width + x) * in.channels + channel] = (float)best;
            }
        }
    }
    RevenantMPSImageWriteRegion(destination, &out, read, answer, what);
    free(answer);
    RevenantMPSConsumeReadCount(source);
}

@implementation MPSImageAreaMax {
    NSUInteger _kernelWidth, _kernelHeight;
}

@synthesize kernelWidth = _kernelWidth;
@synthesize kernelHeight = _kernelHeight;

- (instancetype)initWithDevice:(id<MTLDevice>)device
                  kernelHeight:(NSUInteger)kernelHeight
                   kernelWidth:(NSUInteger)kernelWidth
{
    if ((self = [super initWithDevice:device])) {
        if (!kernelWidth || !kernelHeight || !(kernelWidth % 2) || !(kernelHeight % 2)) {
            RevenantMPSRefuse(@"MPSImageAreaMax: a %lux%lu window is refused - it must be odd so the window"
                            @" has a centre, so no object was made", (unsigned long)kernelWidth,
                            (unsigned long)kernelHeight);
            return nil;
        }
        _kernelWidth = kernelWidth;
        _kernelHeight = kernelHeight;
    }
    return self;
}

- (instancetype)initWithDevice:(id<MTLDevice>)device
{
    RevenantMPSRefuse(@"MPSImageAreaMax: -initWithDevice: is NS_UNAVAILABLE - the"
                    @" window is what makes the filter, so no object was made");
    return nil;
}

- (RevenantMPSMorphologyPick)revenant_pick
{
    return RevenantMPSMorphologyMax;
}

- (void)encodeToCommandBuffer:(id<MTLCommandBuffer>)commandBuffer
                   sourceImage:(MPSImage *)sourceImage
             destinationImage:(MPSImage *)destinationImage
{
    NSString *what = NSStringFromClass([self class]);
    if (!RevenantMPSImageUsable(sourceImage, what)) {
        RevenantMPSRefuse(@"%@: the source image cannot be walked", what);
        return;
    }
    if (!destinationImage) {
        RevenantMPSRefuse(@"%@: no destination image, so nothing was written", what);
        return;
    }
    RevenantMPSMorphologyRegion(sourceImage, destinationImage,
                              RevenantMPSImageResolvedRegion(destinationImage, self.clipRect),
                              _kernelWidth, _kernelHeight, NULL, [self revenant_pick], what);
}

@end

@implementation MPSImageAreaMin
- (RevenantMPSMorphologyPick)revenant_pick
{
    return RevenantMPSMorphologyMin;
}
@end

@implementation MPSImageDilate {
    NSUInteger _kernelWidth, _kernelHeight;
    NSMutableData *_probe;
}

@synthesize kernelWidth = _kernelWidth;
@synthesize kernelHeight = _kernelHeight;

- (instancetype)initWithDevice:(id<MTLDevice>)device
                  kernelHeight:(NSUInteger)kernelHeight
                   kernelWidth:(NSUInteger)kernelWidth
                       values:(const float *)values
{
    if ((self = [super initWithDevice:device])) {
        if (!kernelWidth || !kernelHeight || !(kernelWidth % 2) || !(kernelHeight % 2)) {
            RevenantMPSRefuse(@"MPSImageDilate: a %lux%lu window is refused - the width and the height have to be odd,"
                            @" so no object was made", (unsigned long)kernelWidth,
                            (unsigned long)kernelHeight);
            return nil;
        }
        if (!values) {
            RevenantMPSRefuse(@"MPSImageDilate: no probe was given and a dilate probe IS the filter, so no"
                            @" object was made");
            return nil;
        }
        _kernelWidth = kernelWidth;
        _kernelHeight = kernelHeight;
        _probe = [NSMutableData dataWithLength:kernelWidth * kernelHeight * sizeof(float)];
        if (!_probe) {
            RevenantMPSRefuse(@"MPSImageDilate: no memory for a %lux%lu probe, so no object was made",
                            (unsigned long)kernelWidth, (unsigned long)kernelHeight);
            return nil;
        }
        [_probe replaceBytesInRange:NSMakeRange(0, kernelWidth * kernelHeight * sizeof(float))
                         withBytes:values];
    }
    return self;
}

- (instancetype)initWithDevice:(id<MTLDevice>)device
{
    RevenantMPSRefuse(@"MPSImageDilate: -initWithDevice: is NS_UNAVAILABLE - the"
                    @" window and the probe are what make the filter, so no object was made");
    return nil;
}

- (RevenantMPSMorphologyPick)revenant_pick
{
    return RevenantMPSMorphologyMax;
}

- (void)encodeToCommandBuffer:(id<MTLCommandBuffer>)commandBuffer
                   sourceImage:(MPSImage *)sourceImage
             destinationImage:(MPSImage *)destinationImage
{
    NSString *what = NSStringFromClass([self class]);
    if (!RevenantMPSImageUsable(sourceImage, what)) {
        RevenantMPSRefuse(@"%@: the source image cannot be walked", what);
        return;
    }
    if (!destinationImage) {
        RevenantMPSRefuse(@"%@: no destination image, so nothing was written", what);
        return;
    }
    RevenantMPSMorphologyRegion(sourceImage, destinationImage,
                              RevenantMPSImageResolvedRegion(destinationImage, self.clipRect),
                              _kernelWidth, _kernelHeight, (const float *)_probe.bytes,
                              [self revenant_pick], what);
}

@end

@implementation MPSImageErode
- (RevenantMPSMorphologyPick)revenant_pick
{
    return RevenantMPSMorphologyMin;
}
@end
