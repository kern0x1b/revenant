#import "RevenantMPSImage.h"


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
    if (!RevenantMPSCommandBufferPermits(commandBuffer))
        return;
    MTLRegion window = RevenantMPSImageResolvedRegion(sourceImage, self.clipRectSource);
    if (RevenantMPSImageRegionIsEmpty(window)) {
        RevenantMPSConsumeReadCount(sourceImage);
        return;
    }
    if (destinationImage.width < 2 || destinationImage.height < 1) {
        RevenantMPSRefuse(@"MPSImageStatisticsMinAndMax: the destination is %lux%lu, and this kernel "
                        @"writes the minimum at (0,0) and the maximum at (1,0); a destination at least 2 wide and 1 high is "
                        @"required, so nothing was written",
                        (unsigned long)destinationImage.width, (unsigned long)destinationImage.height);
        return;
    }

    RevenantMPSImageLayout from = RevenantMPSImageLayoutOf(sourceImage);
    RevenantMPSImageLayout to = RevenantMPSImageLayoutOf(destinationImage);
    if (!RevenantMPSImageUsable(sourceImage, @"MPSImageStatisticsMinAndMax source") ||
        !RevenantMPSImageUsable(destinationImage, @"MPSImageStatisticsMinAndMax destination")) {
        RevenantMPSConsumeReadCount(sourceImage);
        return;
    }
    NSUInteger windowCount = window.size.width * window.size.height;
    from.count = windowCount * from.channels;
    void *buffer = RevenantMPSImageReadRegion(sourceImage, &from, window, @"MPSImageStatisticsMinAndMax");
    if (!buffer) {
        RevenantMPSConsumeReadCount(sourceImage);
        return;
    }

    double smallest = INFINITY, largest = -INFINITY;
    for (NSUInteger pixel = 0; pixel < window.size.width * window.size.height; pixel++) {
        for (NSUInteger channel = 0; channel < from.channels; channel++) {
            double value = RevenantMPSImageLoad(buffer, &from, RevenantMPSImageIndex(&from, pixel, channel));
            if (value < smallest)
                smallest = value;
            if (value > largest)
                largest = value;
        }
    }

    MTLRegion outOrigin = RevenantMPSImageResolvedRegion(destinationImage, self.clipRect);
    to.count = to.width * to.height * to.channels;
    void *out = RevenantMPSImageReadRegion(destinationImage, &to, MTLRegionMake2D(0, 0, to.width, to.height),
                                         @"MPSImageStatisticsMinAndMax destination");
    if (out) {
        NSUInteger base = RevenantMPSImageIndex(&to, (NSUInteger)outOrigin.origin.x +
                                              (NSUInteger)outOrigin.origin.y * to.width, 0);
        RevenantMPSImageStore(out, &to, base, smallest);
        RevenantMPSImageStore(out, &to, base + 1, largest);
        RevenantMPSImageWriteRegion(destinationImage, &to, MTLRegionMake2D(0, 0, to.width, to.height), out,
                                  @"MPSImageStatisticsMinAndMax");
        free(out);
    }
    free(buffer);
    RevenantMPSConsumeReadCount(sourceImage);
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
    if (!RevenantMPSCommandBufferPermits(commandBuffer))
        return;
    MTLRegion window = RevenantMPSImageResolvedRegion(sourceImage, self.clipRectSource);
    if (RevenantMPSImageRegionIsEmpty(window)) {
        RevenantMPSConsumeReadCount(sourceImage);
        return;
    }
    if (destinationImage.width < 2 || destinationImage.height < 1) {
        RevenantMPSRefuse(@"MPSImageStatisticsMeanAndVariance: the destination is %lux%lu, and this kernel "
                        @"writes the mean and then the variance - it requires a destination at least 2 wide "
                        @"and 1 high, so nothing was written",
                        (unsigned long)destinationImage.width, (unsigned long)destinationImage.height);
        return;
    }

    RevenantMPSImageLayout from = RevenantMPSImageLayoutOf(sourceImage);
    RevenantMPSImageLayout to = RevenantMPSImageLayoutOf(destinationImage);
    if (!RevenantMPSImageUsable(sourceImage, @"MPSImageStatisticsMeanAndVariance source") ||
        !RevenantMPSImageUsable(destinationImage, @"MPSImageStatisticsMeanAndVariance destination")) {
        RevenantMPSConsumeReadCount(sourceImage);
        return;
    }
    NSUInteger windowCount = window.size.width * window.size.height;
    from.count = windowCount * from.channels;
    void *buffer = RevenantMPSImageReadRegion(sourceImage, &from, window, @"MPSImageStatisticsMeanAndVariance");
    if (!buffer) {
        RevenantMPSConsumeReadCount(sourceImage);
        return;
    }

    NSUInteger pixels = window.size.width * window.size.height;
    double count = 0.0, sum = 0.0;
    for (NSUInteger pixel = 0; pixel < pixels; pixel++)
        for (NSUInteger channel = 0; channel < from.channels; channel++) {
            sum += RevenantMPSImageLoad(buffer, &from, RevenantMPSImageIndex(&from, pixel, channel));
            count += 1.0;
        }
    double mean = count > 0.0 ? sum / count : 0.0;
    double squared = 0.0;
    for (NSUInteger pixel = 0; pixel < pixels; pixel++)
        for (NSUInteger channel = 0; channel < from.channels; channel++) {
            double deviation = RevenantMPSImageLoad(buffer, &from, RevenantMPSImageIndex(&from, pixel, channel)) - mean;
            squared += deviation * deviation;
        }
    double variance = count > 0.0 ? squared / count : 0.0;

    MTLRegion outOrigin = RevenantMPSImageResolvedRegion(destinationImage, self.clipRect);
    to.count = to.width * to.height * to.channels;
    void *out = RevenantMPSImageReadRegion(destinationImage, &to, MTLRegionMake2D(0, 0, to.width, to.height),
                                         @"MPSImageStatisticsMeanAndVariance destination");
    if (out) {
        NSUInteger base = RevenantMPSImageIndex(&to, (NSUInteger)outOrigin.origin.x +
                                              (NSUInteger)outOrigin.origin.y * to.width, 0);
        RevenantMPSImageStore(out, &to, base, mean);
        RevenantMPSImageStore(out, &to, base + 1, variance);
        RevenantMPSImageWriteRegion(destinationImage, &to, MTLRegionMake2D(0, 0, to.width, to.height), out,
                                  @"MPSImageStatisticsMeanAndVariance");
        free(out);
    }
    free(buffer);
    RevenantMPSConsumeReadCount(sourceImage);
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
    if (!RevenantMPSCommandBufferPermits(commandBuffer))
        return;
    MTLRegion window = RevenantMPSImageResolvedRegion(sourceImage, self.clipRectSource);
    if (RevenantMPSImageRegionIsEmpty(window)) {
        RevenantMPSConsumeReadCount(sourceImage);
        return;
    }

    RevenantMPSImageLayout from = RevenantMPSImageLayoutOf(sourceImage);
    RevenantMPSImageLayout to = RevenantMPSImageLayoutOf(destinationImage);
    if (!RevenantMPSImageUsable(sourceImage, @"MPSImageStatisticsMean source") ||
        !RevenantMPSImageUsable(destinationImage, @"MPSImageStatisticsMean destination")) {
        RevenantMPSConsumeReadCount(sourceImage);
        return;
    }
    NSUInteger windowCount = window.size.width * window.size.height;
    from.count = windowCount * from.channels;
    void *buffer = RevenantMPSImageReadRegion(sourceImage, &from, window, @"MPSImageStatisticsMean");
    if (!buffer) {
        RevenantMPSConsumeReadCount(sourceImage);
        return;
    }

    NSUInteger pixels = window.size.width * window.size.height;
    double count = 0.0, sum = 0.0;
    for (NSUInteger pixel = 0; pixel < pixels; pixel++)
        for (NSUInteger channel = 0; channel < from.channels; channel++) {
            sum += RevenantMPSImageLoad(buffer, &from, RevenantMPSImageIndex(&from, pixel, channel));
            count += 1.0;
        }
    double mean = count > 0.0 ? sum / count : 0.0;

    to.count = to.width * to.height * to.channels;
    void *out = RevenantMPSImageReadRegion(destinationImage, &to, MTLRegionMake2D(0, 0, to.width, to.height),
                                         @"MPSImageStatisticsMean destination");
    if (out) {
        MTLRegion outOrigin = RevenantMPSImageResolvedRegion(destinationImage, self.clipRect);
        NSUInteger base = RevenantMPSImageIndex(&to, (NSUInteger)outOrigin.origin.x +
                                              (NSUInteger)outOrigin.origin.y * to.width, 0);
        RevenantMPSImageStore(out, &to, base, mean);
        RevenantMPSImageWriteRegion(destinationImage, &to, MTLRegionMake2D(0, 0, to.width, to.height), out,
                                  @"MPSImageStatisticsMean");
        free(out);
    }
    free(buffer);
    RevenantMPSConsumeReadCount(sourceImage);
}

@end
