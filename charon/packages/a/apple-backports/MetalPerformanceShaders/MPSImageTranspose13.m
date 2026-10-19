#import "CharonMPS.h"
#import "CharonMPSImage.h"


@implementation MPSImageTranspose

- (void)encodeToCommandBuffer:(id<MTLCommandBuffer>)commandBuffer
                 sourceImage:(MPSImage *)sourceImage
            destinationImage:(MPSImage *)destinationImage
{
    NSString *what = NSStringFromClass([self class]);
    if (!commandBuffer) {
        CharonMPSRefuse(@"%@: no command buffer, so nothing was written", what);
        return;
    }
    if (!CharonMPSImageUsable(sourceImage, what) || !CharonMPSImageUsable(destinationImage, what))
        return;

    NSUInteger width = destinationImage.width, height = destinationImage.height;
    if (sourceImage.height < width || sourceImage.width < height) {
        CharonMPSRefuse(@"%@: the destination is %lux%lu and the source %lux%lu, and a transpose of the "
                        @"destination needs a source at least that large, so nothing was written",
                        what, (unsigned long)width, (unsigned long)height,
                        (unsigned long)sourceImage.width, (unsigned long)sourceImage.height);
        return;
    }
    CharonMPSImageLayout in = CharonMPSImageLayoutOf(sourceImage);
    CharonMPSImageLayout out = CharonMPSImageLayoutOf(destinationImage);
    in.count = width * height * in.channels;
    out.count = width * height * out.channels;
    void *from = CharonMPSImageReadRegion(sourceImage, &in,
                                          MTLRegionMake2D(0, 0, sourceImage.width, sourceImage.height), what);
    if (width && !from)
        return;
    size_t bytes = (size_t)width * out.channels * height * out.elementSize;
    unsigned char *to = calloc(bytes ? bytes : 1, 1);
    if (!to) {
        free(from);
        CharonMPSRefuse(@"%@: no memory for a %lux%lu answer, so nothing was written", what,
                        (unsigned long)width, (unsigned long)height);
        return;
    }
    for (NSUInteger row = 0; row < height; row++) {
        for (NSUInteger column = 0; column < width; column++) {
            NSUInteger sourcePixel = column * sourceImage.width + row;
            for (NSUInteger c = 0; c < out.channels; c++) {
                NSUInteger at = CharonMPSImageIndex(&in, sourcePixel, c);
                double value = at == (NSUInteger)-1 ? 0.0 : CharonMPSImageLoad(from, &in, at);
                NSUInteger destPixel = row * width + column;
                NSUInteger into = CharonMPSImageIndex(&out, destPixel, c);
                if (into != (NSUInteger)-1)
                    CharonMPSImageStore(to, &out, into, value);
            }
        }
    }
    free(from);
    BOOL ok = CharonMPSImageWriteRegion(destinationImage, &out,
                                       MTLRegionMake2D(0, 0, width, height), to, what);
    free(to);
    (void)ok;
}

@end
