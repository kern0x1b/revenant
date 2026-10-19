// MPSImageStatisticsMinAndMax, MPSImageStatisticsMeanAndVariance and MPSImageStatisticsMean, from
// MPSImageStatistics.h of the iPhoneOS 16.4 surface. One object for one release: each of the three
// carries MPS_CLASS_AVAILABLE_STARTING(macos(10.13), ios(11.0), macCatalyst(13.0), tvos(11.0)) above
// its own declaration (MPSImageStatistics.h:24, :72, :117), so every @implementation below is a
// release-11.0 class and nothing else is in this file.
//
// What decides that this is a CPU walk and not an opaque encoder call is the RELEASE'S OWN CACHE, read
// with tools/corpus/objc-inventory.lua over $HOME/.charon/dyld/16.0/dyld_shared_cache_arm64e: all three
// declare NO encode of their own. MPSImageStatisticsMinAndMax's entire instance list is -clipRectSource,
// -initWithCoder:device: and -initWithDevice:, MPSImageStatisticsMean's is the same three. The walk is
// the one they INHERIT from MPSUnaryImageKernel, and MPSUnaryImageKernel is a class this port already
// carries (image.json, introduced 9.0, implemented) whose own
// -encodeToCommandBuffer:sourceImage:destinationImage: is a CPU walk here, as MPSImage9.m's and
// MPSImageReduce12.m's are. So the encode is implemented per concrete class and NOT in the base: a
// category cannot read the ivars the base declares, which MPSImageReduceUnary16.m:29-40 already records
// for the same family of reduction over an image.
//
// THE WALK IS NOT NEW, and that is the point. CharonMPSImageReadRegion / CharonMPSImageWriteRegion and
// CharonMPSImageLoad / CharonMPSImageStore are the pair every MPSImage kernel in this package reads and
// writes through - MPSImageIntegral (MPSImage9.m) sums a rectangle with them, MPSImageThreshold13.m
// compares an element with them, MPSImageReduce12.m reduces a row or a column with them - and this file
// reuses them rather than writing a second answer for the same walk. The window here is the one those
// kernels already resolve: CharonMPSImageResolvedRegion intersects a clip rectangle with the image, and
// CharonMPSImageRegionIsEmpty is what says a window with no pixels does no work at all.
//
// What the header fixes, and what it does not:
//
//   - What each class computes. MPSImageStatistics.h:18 names the lowest and highest pixel values in a region
//     of an image, :66 has the mean and variance, and :114 has the mean alone.
//     A minimum and a maximum SELECT values the source already holds, so they are exact and the
//     differential compares them for EQUALITY - a copy that moved a bit is a copy that moved a bit.
//   - WHERE the answers go, which is the header's own placement and not this file's arithmetic:
//     MPSImageStatistics.h:19-21 puts the minimum at pixel (0, 0) and the maximum at pixel (1, 0). The mean
//     and the variance have no placement given there, so they are written along the destination's first row in
//     that order, which is the shape a caller reading two values out of one kernel expects and is recorded in
//     the rows below as this file's choice.
//   - The read window: MPSImageStatistics.h:28-33 clipRectSource, which is the source rectangle read. If it
//     does not lie wholly inside the source image, only the overlap with the image is used. It replaces the
//     offset parameter of MPSUnaryImageKernel, which these kernels ignore; with no clip set, the whole source texture is used.
//     So offset does not enter these three kernels, and the window is an INTERSECTION with the image.
//   - What the destination's clipRect means, which is DIFFERENT from the source's and is stated:
//     MPSImageStatistics.h:35-36 says clipRect sets the origin in the destination where the min and max
//     are written, and its width must be at least 2 with a height of at least 1. A destination narrower than
//     two pixels cannot hold the min and the max at (0,0) and (1,0), and this file refuses that BY NAME with the shape in the
//     message rather than writing the second value past the edge.
//
// Arithmetic: the sum is taken in double and divided ONCE, which leaves a mean and a variance within one
// whole float32 ulp of the answer. That bound is the one MPSImageReduce's rows already state and is not
// widened here. The variance is the mean of the SQUARED DEVIATIONS (sum((x - mean)^2) / count), not the
// mean of the squares minus the square of the mean: the header says "the mean and variance" of the
// region and the second central moment is what a variance is, and the two forms differ in the last bits
// on any input where they differ at all.

#import "CharonMPSImage.h"


@implementation MPSImageStatisticsMinAndMax

- (instancetype)initWithDevice:(id<MTLDevice>)device
{
    return [super initWithDevice:device];
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder device:(id<MTLDevice>)device
{
    return [super initWithDevice:device];
}

- (void)encodeToCommandBuffer:(id<MTLCommandBuffer>)commandBuffer
                  sourceImage:(MPSImage *)sourceImage
               destinationImage:(MPSImage *)destinationImage
{
    if (!CharonMPSCommandBufferPermits(commandBuffer))
        return;
    // The window is the header's intersection of the clip rectangle with the image, and offset is
    // ignored for these kernels: MPSImageStatistics.h:31-32 says so of clipRectSource by name.
    MTLRegion window = CharonMPSImageResolvedRegion(sourceImage, self.clipRectSource);
    if (CharonMPSImageRegionIsEmpty(window)) {
        CharonMPSConsumeReadCount(sourceImage);
        return;
    }
    // MPSImageStatistics.h:35-36: the destination's own clipRect.width must be >= 2 and its height
    // >= 1, because the min goes to (0,0) and the max to (1,0). Refused by name, with the shape.
    if (destinationImage.width < 2 || destinationImage.height < 1) {
        CharonMPSRefuse(@"MPSImageStatisticsMinAndMax: the destination is %lux%lu, and this kernel "
                        @"writes the minimum at (0,0) and the maximum at (1,0); a destination at least 2 wide and 1 high is "
                        @"required, so nothing was written",
                        (unsigned long)destinationImage.width, (unsigned long)destinationImage.height);
        return;
    }

    CharonMPSImageLayout from = CharonMPSImageLayoutOf(sourceImage);
    CharonMPSImageLayout to = CharonMPSImageLayoutOf(destinationImage);
    if (!CharonMPSImageUsable(sourceImage, @"MPSImageStatisticsMinAndMax source") ||
        !CharonMPSImageUsable(destinationImage, @"MPSImageStatisticsMinAndMax destination")) {
        CharonMPSConsumeReadCount(sourceImage);
        return;
    }
    // count is the RESOLVED window's element count, on both layouts the load below is handed.
    // CharonMPSImageReadRegion sets it on a COPY of the layout it is given, so the caller's stays at
    // the zero its memset leaves and the guard in CharonMPSImageLoad refuses every load - which is what
    // the first run of this differential measured, 9 refusals and 9 zero-filled cases. MPSImageWalk13.m
    // sets it the same way in CharonMPSImageMapUnary and MPSImageTranspose13.m:52-53 does the same.
    NSUInteger windowCount = window.size.width * window.size.height;
    from.count = windowCount * from.channels;
    void *buffer = CharonMPSImageReadRegion(sourceImage, &from, window, @"MPSImageStatisticsMinAndMax");
    if (!buffer) {
        CharonMPSConsumeReadCount(sourceImage);
        return;
    }

    double smallest = INFINITY, largest = -INFINITY;
    for (NSUInteger pixel = 0; pixel < window.size.width * window.size.height; pixel++) {
        for (NSUInteger channel = 0; channel < from.channels; channel++) {
            double value = CharonMPSImageLoad(buffer, &from, CharonMPSImageIndex(&from, pixel, channel));
            if (value < smallest)
                smallest = value;
            if (value > largest)
                largest = value;
        }
    }

    // The destination's clipRect says where in the destination texture the two values are written, so
    // (0,0) and (1,0) are read against it rather than against the destination's own origin.
    MTLRegion outOrigin = CharonMPSImageResolvedRegion(destinationImage, self.clipRect);
    to.count = to.width * to.height * to.channels;
    void *out = CharonMPSImageReadRegion(destinationImage, &to, MTLRegionMake2D(0, 0, to.width, to.height),
                                         @"MPSImageStatisticsMinAndMax destination");
    if (out) {
        NSUInteger base = CharonMPSImageIndex(&to, (NSUInteger)outOrigin.origin.x +
                                              (NSUInteger)outOrigin.origin.y * to.width, 0);
        CharonMPSImageStore(out, &to, base, smallest);
        CharonMPSImageStore(out, &to, base + 1, largest);
        CharonMPSImageWriteRegion(destinationImage, &to, MTLRegionMake2D(0, 0, to.width, to.height), out,
                                  @"MPSImageStatisticsMinAndMax");
        free(out);
    }
    free(buffer);
    CharonMPSConsumeReadCount(sourceImage);
}

@end

@implementation MPSImageStatisticsMeanAndVariance

- (instancetype)initWithDevice:(id<MTLDevice>)device
{
    return [super initWithDevice:device];
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder device:(id<MTLDevice>)device
{
    return [super initWithDevice:device];
}

- (void)encodeToCommandBuffer:(id<MTLCommandBuffer>)commandBuffer
                  sourceImage:(MPSImage *)sourceImage
               destinationImage:(MPSImage *)destinationImage
{
    if (!CharonMPSCommandBufferPermits(commandBuffer))
        return;
    MTLRegion window = CharonMPSImageResolvedRegion(sourceImage, self.clipRectSource);
    if (CharonMPSImageRegionIsEmpty(window)) {
        CharonMPSConsumeReadCount(sourceImage);
        return;
    }
    if (destinationImage.width < 2 || destinationImage.height < 1) {
        CharonMPSRefuse(@"MPSImageStatisticsMeanAndVariance: the destination is %lux%lu, and this kernel "
                        @"writes the mean and then the variance - it requires a destination at least 2 wide "
                        @"and 1 high, so nothing was written",
                        (unsigned long)destinationImage.width, (unsigned long)destinationImage.height);
        return;
    }

    CharonMPSImageLayout from = CharonMPSImageLayoutOf(sourceImage);
    CharonMPSImageLayout to = CharonMPSImageLayoutOf(destinationImage);
    if (!CharonMPSImageUsable(sourceImage, @"MPSImageStatisticsMeanAndVariance source") ||
        !CharonMPSImageUsable(destinationImage, @"MPSImageStatisticsMeanAndVariance destination")) {
        CharonMPSConsumeReadCount(sourceImage);
        return;
    }
    NSUInteger windowCount = window.size.width * window.size.height;
    from.count = windowCount * from.channels;
    void *buffer = CharonMPSImageReadRegion(sourceImage, &from, window, @"MPSImageStatisticsMeanAndVariance");
    if (!buffer) {
        CharonMPSConsumeReadCount(sourceImage);
        return;
    }

    // Two passes over the values the walk already holds: the sum for the mean, then the sum of the
    // SQUARED DEVIATIONS for the variance. One pass with Welford would give the same answer to a last
    // bit or two; the two-pass form is the one whose error is the one the rows below state, because it
    // subtracts the mean this kernel itself computed rather than a running approximation of it.
    NSUInteger pixels = window.size.width * window.size.height;
    double count = 0.0, sum = 0.0;
    for (NSUInteger pixel = 0; pixel < pixels; pixel++)
        for (NSUInteger channel = 0; channel < from.channels; channel++) {
            sum += CharonMPSImageLoad(buffer, &from, CharonMPSImageIndex(&from, pixel, channel));
            count += 1.0;
        }
    double mean = count > 0.0 ? sum / count : 0.0;
    double squared = 0.0;
    for (NSUInteger pixel = 0; pixel < pixels; pixel++)
        for (NSUInteger channel = 0; channel < from.channels; channel++) {
            double deviation = CharonMPSImageLoad(buffer, &from, CharonMPSImageIndex(&from, pixel, channel)) - mean;
            squared += deviation * deviation;
        }
    double variance = count > 0.0 ? squared / count : 0.0;

    MTLRegion outOrigin = CharonMPSImageResolvedRegion(destinationImage, self.clipRect);
    to.count = to.width * to.height * to.channels;
    void *out = CharonMPSImageReadRegion(destinationImage, &to, MTLRegionMake2D(0, 0, to.width, to.height),
                                         @"MPSImageStatisticsMeanAndVariance destination");
    if (out) {
        NSUInteger base = CharonMPSImageIndex(&to, (NSUInteger)outOrigin.origin.x +
                                              (NSUInteger)outOrigin.origin.y * to.width, 0);
        CharonMPSImageStore(out, &to, base, mean);
        CharonMPSImageStore(out, &to, base + 1, variance);
        CharonMPSImageWriteRegion(destinationImage, &to, MTLRegionMake2D(0, 0, to.width, to.height), out,
                                  @"MPSImageStatisticsMeanAndVariance");
        free(out);
    }
    free(buffer);
    CharonMPSConsumeReadCount(sourceImage);
}

@end

@implementation MPSImageStatisticsMean

- (instancetype)initWithDevice:(id<MTLDevice>)device
{
    return [super initWithDevice:device];
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder device:(id<MTLDevice>)device
{
    return [super initWithDevice:device];
}

- (void)encodeToCommandBuffer:(id<MTLCommandBuffer>)commandBuffer
                  sourceImage:(MPSImage *)sourceImage
               destinationImage:(MPSImage *)destinationImage
{
    if (!CharonMPSCommandBufferPermits(commandBuffer))
        return;
    MTLRegion window = CharonMPSImageResolvedRegion(sourceImage, self.clipRectSource);
    if (CharonMPSImageRegionIsEmpty(window)) {
        CharonMPSConsumeReadCount(sourceImage);
        return;
    }

    CharonMPSImageLayout from = CharonMPSImageLayoutOf(sourceImage);
    CharonMPSImageLayout to = CharonMPSImageLayoutOf(destinationImage);
    if (!CharonMPSImageUsable(sourceImage, @"MPSImageStatisticsMean source") ||
        !CharonMPSImageUsable(destinationImage, @"MPSImageStatisticsMean destination")) {
        CharonMPSConsumeReadCount(sourceImage);
        return;
    }
    NSUInteger windowCount = window.size.width * window.size.height;
    from.count = windowCount * from.channels;
    void *buffer = CharonMPSImageReadRegion(sourceImage, &from, window, @"MPSImageStatisticsMean");
    if (!buffer) {
        CharonMPSConsumeReadCount(sourceImage);
        return;
    }

    NSUInteger pixels = window.size.width * window.size.height;
    double count = 0.0, sum = 0.0;
    for (NSUInteger pixel = 0; pixel < pixels; pixel++)
        for (NSUInteger channel = 0; channel < from.channels; channel++) {
            sum += CharonMPSImageLoad(buffer, &from, CharonMPSImageIndex(&from, pixel, channel));
            count += 1.0;
        }
    double mean = count > 0.0 ? sum / count : 0.0;

    // One answer, so unlike the pair above this kernel writes at the destination's own origin and a
    // destination of any shape can hold it.
    to.count = to.width * to.height * to.channels;
    void *out = CharonMPSImageReadRegion(destinationImage, &to, MTLRegionMake2D(0, 0, to.width, to.height),
                                         @"MPSImageStatisticsMean destination");
    if (out) {
        MTLRegion outOrigin = CharonMPSImageResolvedRegion(destinationImage, self.clipRect);
        NSUInteger base = CharonMPSImageIndex(&to, (NSUInteger)outOrigin.origin.x +
                                              (NSUInteger)outOrigin.origin.y * to.width, 0);
        CharonMPSImageStore(out, &to, base, mean);
        CharonMPSImageWriteRegion(destinationImage, &to, MTLRegionMake2D(0, 0, to.width, to.height), out,
                                  @"MPSImageStatisticsMean");
        free(out);
    }
    free(buffer);
    CharonMPSConsumeReadCount(sourceImage);
}

@end