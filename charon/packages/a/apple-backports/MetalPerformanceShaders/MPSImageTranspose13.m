// MPSImageTranspose13.m - MPSImageTranspose, the index permutation the walk already serves.
//
// MPSImage.h declares one method on it, and the header's own words for what it does are that the
// destination is written "transposed relative to the source": a pixel at (row, column) of the source
// lands at (column, row) of the destination, and nothing else about the value changes. There is no
// arithmetic here, which is why it is the second kernel this series carries - the first, and the only
// other one the walk serves as it stands, is a copy of each pixel's value.
//
// MPSImageTranspose is MPSUnaryImageKernel's, so the encode is the shape MPSImageKernel.h declares:
// a source image, a destination image, and the clip rectangle. The destination may be a different shape
// from the source - a transposed image of width x height is height x width - so the walk is given the
// SOURCE's shape for the read and the DESTINATION's for the write, and the two are indexed with the
// destination's own (row, column) so the permutation happens in the index rather than in a copy.
//
// `copyWithTexture:`, which the header also declares, is not implemented here: it copies a texture into
// an image of the texture's shape with no permutation, which is a different row and is owed.

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

    // The transpose: destination(row, column) is source(column, row). The clip rectangle is the
    // destination's extent, because that is the image being written, and the source is read at the
    // transposed index. A region of the source is never read outside its own extent, so a clip
    // rectangle larger than the source contributes nothing rather than reading past it.
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
            // destination(row, column) <- source(column, row)
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
