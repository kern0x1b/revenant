#import "CharonMPS.h"
#import "CharonMPSImage.h"

#pragma clang diagnostic ignored "-Wincomplete-implementation"
#pragma clang diagnostic ignored "-Wobjc-designated-initializers"

typedef NS_ENUM(NSInteger, CharonMPSMorphologyPick) {
    CharonMPSMorphologyMax = 0,
    CharonMPSMorphologyMin,
};

static void CharonMPSMorphologyRegion(MPSImage *source, MPSImage *destination, MTLRegion read,
                                      NSUInteger kernelWidth, NSUInteger kernelHeight,
                                      const float *probe, CharonMPSMorphologyPick pick, NSString *what)
{
    CharonMPSImageLayout in = CharonMPSImageLayoutOf(source);
    CharonMPSImageLayout out = CharonMPSImageLayoutOf(destination);
    if (!kernelWidth || !kernelHeight) {
        CharonMPSRefuse(@"%@: a %lux%lu window has no centre, so nothing was written", what,
                        (unsigned long)kernelWidth, (unsigned long)kernelHeight);
        return;
    }
    CharonMPSImageLayout slice = in;
    slice.count = read.size.width * read.size.height * in.channels;
    void *from = CharonMPSImageReadRegion(source, &slice, read, what);
    if (slice.count && !from)
        return;

    NSUInteger halfW = kernelWidth / 2, halfH = kernelHeight / 2;
    float *answer = calloc(slice.count ? slice.count : 1, sizeof(float));
    if (!answer) {
        CharonMPSRefuse(@"%@: no memory for a %lux%lu result, so nothing was written", what,
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
                        double value = CharonMPSImageLoad(from, &slice,
                                                         CharonMPSImageIndex(&slice, index, channel));
                        double candidate = probe ? (value + (double)probe[ky * kernelWidth + kx]) : value;
                        if (kx == 0 && ky == 0)
                            best = candidate;
                        else if (pick == CharonMPSMorphologyMax ? candidate > best : candidate < best)
                            best = candidate;
                    }
                }
                answer[(y * read.size.width + x) * in.channels + channel] = (float)best;
            }
        }
    }
    CharonMPSImageWriteRegion(destination, &out, read, answer, what);
    free(answer);
    CharonMPSConsumeReadCount(source);
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
            CharonMPSRefuse(@"MPSImageAreaMax: a %lux%lu window is refused - it must be odd so the window"
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
    CharonMPSRefuse(@"MPSImageAreaMax: -initWithDevice: is NS_UNAVAILABLE - the"
                    @" window is what makes the filter, so no object was made");
    return nil;
}

- (CharonMPSMorphologyPick)charon_pick
{
    return CharonMPSMorphologyMax;
}

- (void)encodeToCommandBuffer:(id<MTLCommandBuffer>)commandBuffer
                   sourceImage:(MPSImage *)sourceImage
             destinationImage:(MPSImage *)destinationImage
{
    NSString *what = NSStringFromClass([self class]);
    if (!CharonMPSImageUsable(sourceImage, what)) {
        CharonMPSRefuse(@"%@: the source image cannot be walked", what);
        return;
    }
    if (!destinationImage) {
        CharonMPSRefuse(@"%@: no destination image, so nothing was written", what);
        return;
    }
    CharonMPSMorphologyRegion(sourceImage, destinationImage,
                              CharonMPSImageResolvedRegion(destinationImage, self.clipRect),
                              _kernelWidth, _kernelHeight, NULL, [self charon_pick], what);
}

@end

@implementation MPSImageAreaMin
- (CharonMPSMorphologyPick)charon_pick
{
    return CharonMPSMorphologyMin;
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
            CharonMPSRefuse(@"MPSImageDilate: a %lux%lu window is refused - the width and the height have to be odd,"
                            @" so no object was made", (unsigned long)kernelWidth,
                            (unsigned long)kernelHeight);
            return nil;
        }
        if (!values) {
            CharonMPSRefuse(@"MPSImageDilate: no probe was given and a dilate probe IS the filter, so no"
                            @" object was made");
            return nil;
        }
        _kernelWidth = kernelWidth;
        _kernelHeight = kernelHeight;
        _probe = [NSMutableData dataWithLength:kernelWidth * kernelHeight * sizeof(float)];
        if (!_probe) {
            CharonMPSRefuse(@"MPSImageDilate: no memory for a %lux%lu probe, so no object was made",
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
    CharonMPSRefuse(@"MPSImageDilate: -initWithDevice: is NS_UNAVAILABLE - the"
                    @" window and the probe are what make the filter, so no object was made");
    return nil;
}

- (CharonMPSMorphologyPick)charon_pick
{
    return CharonMPSMorphologyMax;
}

- (void)encodeToCommandBuffer:(id<MTLCommandBuffer>)commandBuffer
                   sourceImage:(MPSImage *)sourceImage
             destinationImage:(MPSImage *)destinationImage
{
    NSString *what = NSStringFromClass([self class]);
    if (!CharonMPSImageUsable(sourceImage, what)) {
        CharonMPSRefuse(@"%@: the source image cannot be walked", what);
        return;
    }
    if (!destinationImage) {
        CharonMPSRefuse(@"%@: no destination image, so nothing was written", what);
        return;
    }
    CharonMPSMorphologyRegion(sourceImage, destinationImage,
                              CharonMPSImageResolvedRegion(destinationImage, self.clipRect),
                              _kernelWidth, _kernelHeight, (const float *)_probe.bytes,
                              [self charon_pick], what);
}

@end

@implementation MPSImageErode
- (CharonMPSMorphologyPick)charon_pick
{
    return CharonMPSMorphologyMin;
}
@end
