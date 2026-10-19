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
    MTLRegion window = CharonMPSImageResolvedRegion(sourceImage, self.clipRectSource);
    if (CharonMPSImageRegionIsEmpty(window)) {
        CharonMPSConsumeReadCount(sourceImage);
        return;
    }
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
