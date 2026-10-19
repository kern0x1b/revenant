// MPSImageWalk13.m - the walking layer CharonMPSImage.h declares.
//
// One place that knows how an MPSImage's bytes are addressed: the layout from the image's own data type,
// shape and feature channel count, and the read and write of one channel of one pixel through the
// image's own readBytes:/writeBytes:. Every kernel in this family is a callback over that, and none of
// them repeats the addressing.
//
// The addressing is interleaved, because that is what the 16.4 surface has: MPSImageFeatureChannelFormat
// names an element width, `featureChannels` names how many of them a pixel holds, and a pixel's
// channels sit together at `pixel * bytesPerPixel` with a row `bytesPerRow` from the next. The planar
// layouts of the 26.2 surface are not in this surface and are not invented here: an image whose channel
// format is one of those four is walked interleaved, and MPSImage13.m refuses the shapes it cannot hold.

#import "CharonMPS.h"
#import "CharonMPSImage.h"

// The data type the eight element types name that a channel format's elements have. The 16.4 MPSImage
// carries no `dataType` of its own: it carries a pixel format and a feature channel format, and the
// channel format is what says how wide one element is and whether it is signed.
MPSDataType CharonMPSImageDataTypeOf(MPSImageFeatureChannelFormat format)
{
    switch (format) {
    case MPSImageFeatureChannelFormatUnorm8: return MPSDataTypeUInt8;
    case MPSImageFeatureChannelFormatUnorm16: return MPSDataTypeUInt16;
    case MPSImageFeatureChannelFormatFloat16: return MPSDataTypeFloat16;
    case MPSImageFeatureChannelFormatFloat32: return MPSDataTypeFloat32;
    default: return MPSDataTypeInvalid;
    }
}

size_t CharonMPSImageFeatureChannelSize(MPSImageFeatureChannelFormat format)
{
    switch (format) {
    case MPSImageFeatureChannelFormatUnorm8: return 1;
    case MPSImageFeatureChannelFormatUnorm16: return 2;
    case MPSImageFeatureChannelFormatFloat16: return 2;
    case MPSImageFeatureChannelFormatFloat32: return 4;
    default: return 0;
    }
}

CharonMPSImageLayout CharonMPSImageLayoutOf(MPSImage *image)
{
    CharonMPSImageLayout layout;
    memset(&layout, 0, sizeof(layout));
    if (!image)
        return layout;
    layout.width = image.width;
    layout.height = image.height;
    layout.channels = image.featureChannels ? image.featureChannels : 1;
    layout.dataType = CharonMPSImageDataTypeOf(image.featureChannelFormat);
    layout.elementSize = CharonMPSImageFeatureChannelSize(image.featureChannelFormat);
    // count is the WHOLE image's, and it is set per region where a region's buffer is allocated: the
    // kernels pass self.clipRect, so for any clip smaller than the image a count that stays the image's
    // would let an index past the region's buffer and inside the image's count through the guard.
    layout.pixelFormat = (int)image.pixelFormat;
    // The stride and the pixel's own width are the texture's, which is what the release's readBytes:
    // and writeBytes: are given: MPSImage has no bytesPerRow of its own in this surface, and its
    // pixelSize is the channel count times the element, which the texture's bytesPerPixel agrees with.
    // The 16.4 MTLTexture has no bytesPerRow or bytesPerPixel property: MPSImage is told its own shape
    // and a walk is given the stride it wants, so the row of a region is the region's own width in
    // pixels times the pixel's width, which is what the release's own getBytes: is given for a tightly
    // packed read of a region. There is no padding to honour, because there is no row stride in this
    // surface to honour it from.
    layout.bytesPerPixel = layout.channels * layout.elementSize;
    layout.bytesPerRow = layout.bytesPerPixel * layout.width;
    return layout;
}

BOOL CharonMPSImageUsable(MPSImage *image, NSString *what)
{
    if (!image) {
        CharonMPSRefuse(@"%@: no image, so nothing was written", what);
        return NO;
    }
    if (!image.texture) {
        CharonMPSRefuse(@"%@: the image holds no texture, so nothing was written", what);
        return NO;
    }
    MPSDataType dataType = CharonMPSImageDataTypeOf(image.featureChannelFormat);
    if (!CharonMPSDataTypeIsElement(dataType) || !MPSSizeofMPSDataType(dataType)) {
        CharonMPSRefuse(@"%@: the image's channel format %lu is not one of the four the 16.4 surface names, so nothing was written",
                        what, (unsigned long)image.featureChannelFormat);
        return NO;
    }
    if (!image.width || !image.height) {
        CharonMPSRefuse(@"%@: the image's shape is %lux%lu, so nothing was written",
                        what, (unsigned long)image.width, (unsigned long)image.height);
        return NO;
    }
    return YES;
}

// The index of one channel of one pixel WITHIN A REGION'S BUFFER, which the region's read is one
// row-major run of `width * channels` elements per row, so pixel is counted in pixels from the region's
// own origin and not from the image's. The `rowWidth` this took is gone: the body never read it, and a
// caller that passed a (row, column) pair got a wrong answer with no diagnostic - which is what the
// review measured.
NSUInteger CharonMPSImageIndex(const CharonMPSImageLayout *layout, NSUInteger pixel, NSUInteger channel)
{
    if (channel >= layout->channels)
        return (NSUInteger)-1;
    return pixel * layout->channels + channel;
}

double CharonMPSImageLoad(const void *buffer, const CharonMPSImageLayout *layout, NSUInteger index)
{
    // The buffer is a region's, w*h*channels elements of layout->elementSize, and the index is an
    // ELEMENT index - one scaling, as MPSImageWalk13.m:107-117 and the load agree. Anything outside that
    // is a bug in the walk, and it is refused here with the numbers rather than read: a read one byte
    // past a one-byte buffer is the harness's overrun, and the numbers are how it is found.
    NSUInteger count = layout->count;
    // There is no tracing on this path and the refusal below is the diagnostic: it names
    // the index, the count, the shape and the element size, and that is how the overrun was found.
    if (index >= count) {
        CharonMPSRefuse(@"MPSImage: the walk asked for element %lu of a region of %lu element(s) "
                        "(%lux%lu pixels, %lu channel(s), elementSize %lu, dataType %d, pixelFormat %d), "
                        "so the value is 0 and nothing was read",
                        (unsigned long)index, (unsigned long)count,
                        (unsigned long)layout->width, (unsigned long)layout->height,
                        (unsigned long)layout->channels, (unsigned long)layout->elementSize,
                        (int)layout->dataType, (int)layout->pixelFormat);
        return 0.0;
    }
    return CharonMPSLoad((const unsigned char *)buffer, layout->dataType, index);
}

void CharonMPSImageStore(void *buffer, const CharonMPSImageLayout *layout, NSUInteger index, double value)
{
    CharonMPSStore((unsigned char *)buffer, layout->dataType, index, value);
}

// The region a kernel's clipRect means, resolved against the image it clips.
//
// MPSKernel's clipRect is MPSRectNoClip - size {-1, -1, 0} - when the caller set none, and that is a
// SENTINEL, not a region: handed to a texture it is xoffset + width = -2, which no level width
// satisfies, and the framework asserts. Apple's contract is that it means the whole destination. So a
// negative size, and a size that runs past the image, both become what is left of the image, and the
// origin is clamped into it. A region that ends up empty does nothing at all - no allocation, no read, no
// write, no assertion - which is what "clipped away" means.
MTLRegion CharonMPSImageResolvedRegion(MPSImage *image, MTLRegion clip)
{
    NSUInteger width = image.width, height = image.height;
    NSInteger ox = (NSInteger)clip.origin.x, oy = (NSInteger)clip.origin.y;
    NSInteger sw = (NSInteger)clip.size.width, sh = (NSInteger)clip.size.height;
    if (ox < 0) ox = 0;
    if (oy < 0) oy = 0;
    if ((NSUInteger)ox > width) ox = (NSInteger)width;
    if ((NSUInteger)oy > height) oy = (NSInteger)height;
    NSUInteger right = width, bottom = height;
    if (sw > 0) {
        NSInteger end = ox + sw;
        if (end < (NSInteger)right) right = (NSUInteger)end;
    }
    if (sh > 0) {
        NSInteger end = oy + sh;
        if (end < (NSInteger)bottom) bottom = (NSUInteger)end;
    }
    if (right < (NSUInteger)ox) right = (NSUInteger)ox;
    if (bottom < (NSUInteger)oy) bottom = (NSUInteger)oy;
    return MTLRegionMake2D((NSUInteger)ox, (NSUInteger)oy, right - (NSUInteger)ox, bottom - (NSUInteger)oy);
}

// YES when the region has no pixels, and the walk does nothing at all for it.
BOOL CharonMPSImageRegionIsEmpty(MTLRegion region)
{
    return region.size.width == 0 || region.size.height == 0;
}

// A region of one image as a row-major run of its elements, in the image's own element width. A
// region that names no pixel is an empty run and nothing was read.
//
// NULL is a real answer here and there are three of them - an empty region, a channel format with no
// element width, and a failed allocation - and CharonMPSImage.h:95-124 says so where the declaration is
// and names the twelve callers that already handle it. The declaration is `_Nullable`; this definition
// says so too, so that the two cannot drift apart without clang saying which one is wrong.
//
// Not static: `MPSImageTranspose` reads a source region and writes a destination one itself, because the
// permutation it performs is in the index - destination(row, column) is source(column, row) - which the
// walk's unary map cannot express. The declarations are in CharonMPSImage.h.
void *_Nullable CharonMPSImageReadRegion(MPSImage *image, const CharonMPSImageLayout *layout,
                                        MTLRegion region, NSString *what)
{
    NSUInteger w = region.size.width, h = region.size.height;
    // An empty region: there is no element to return. A caller tells this apart from a failure by the
    // count it put on its own layout copy, which is why the tests below are guarded on the width and the
    // ones at the two refusals below are not - those two are failures whatever the region says.
    if (!w || !h)
        return NULL;
    NSUInteger perRow = w * layout->channels;
    size_t bytes = (size_t)perRow * h * layout->elementSize;
    if (!layout->elementSize) {
        CharonMPSRefuse(@"MPSImage: the channel format names data type %d, which has no element size, so a "
                        "%lux%lu read has no buffer and nothing was read", (int)layout->dataType,
                        (unsigned long)w, (unsigned long)h);
        return NULL;
    }
    // the element count THIS region holds, for the guard in CharonMPSImageLoad
    CharonMPSImageLayout here = *layout;
    here.count = (NSUInteger)w * (NSUInteger)h * layout->channels;
    unsigned char *buffer = calloc(bytes, 1);
    if (!buffer) {
        CharonMPSRefuse(@"%@: no memory for a %lux%lu walk of %lu channel(s), so nothing was written",
                        what, (unsigned long)w, (unsigned long)h, (unsigned long)layout->channels);
        return NULL;
    }
    [image readBytes:buffer
          dataLayout:MPSDataLayoutHeightxWidthxFeatureChannels
         bytesPerRow:perRow * layout->elementSize
              region:region
   featureChannelInfo:(MPSImageReadWriteParams){0}
           imageIndex:0];
    return buffer;
}

// Not static, for the same reason as the read: a kernel that reads a source region writes a
// destination one itself.
BOOL CharonMPSImageWriteRegion(MPSImage *image, const CharonMPSImageLayout *layout,
                               MTLRegion region, const void *buffer, NSString *what)
{
    NSUInteger w = region.size.width, h = region.size.height;
    if (!w || !h)
        return YES;
    NSUInteger perRow = w * layout->channels;
#if defined(CHARON_PLANT)
    // THE RED CONTROL, the other half. A kernel that hands a finished buffer to -writeBytes: - the walk
    // the whole family goes through, and therefore MPSImageTranspose - never reaches CharonMPSStore, so
    // planting only there would leave exactly that kernel untested by the control. The buffer is
    // perturbed here, on its way out of the walk, which is the last point every one of them passes.
    // Compiled only into the harness's planted builds; the library never sees it.
    if (layout->dataType == MPSDataTypeFloat32 && layout->elementSize == 4) {
        float *out = (float *)buffer;
        size_t elements = (size_t)perRow * h;
        for (size_t i = 0; i < elements; i++) {
#if CHARON_PLANT == 1
            out[i] = out[i] + 1.0f;
#elif CHARON_PLANT == 2
            if (i == 0)
                out[i] = out[i] + 1.0f;
#endif
        }
    }
#endif
    [image writeBytes:buffer
           dataLayout:MPSDataLayoutHeightxWidthxFeatureChannels
          bytesPerRow:perRow * layout->elementSize
               region:region
   featureChannelInfo:(MPSImageReadWriteParams){0}
            imageIndex:0];
    return YES;
}

// Two images walked together must be the same shape and the same data type: a walk reads one element of
// each, so a caller that gave a kernel two different shapes gets NO and the numbers, not a walk of one
// against the other.
static BOOL CharonMPSImageWalkable(MPSImage *a, MPSImage *b, NSString *what)
{
    if (!a || !b)
        return NO;
    if (a.width != b.width || a.height != b.height) {
        CharonMPSRefuse(@"%@: the two images are %lux%lu and %lux%lu, and a walk reads one pixel of each, so nothing was written",
                        what, (unsigned long)a.width, (unsigned long)a.height,
                        (unsigned long)b.width, (unsigned long)b.height);
        return NO;
    }
    MPSDataType da = CharonMPSImageDataTypeOf(a.featureChannelFormat);
    MPSDataType db = CharonMPSImageDataTypeOf(b.featureChannelFormat);
    if (da != db) {
        CharonMPSRefuse(@"%@: the two images hold channel formats %lu and %lu, and a walk reads one element of each, so nothing was written",
                        what, (unsigned long)a.featureChannelFormat, (unsigned long)b.featureChannelFormat);
        return NO;
    }
    if (a.featureChannels != b.featureChannels) {
        CharonMPSRefuse(@"%@: the two images hold %lu and %lu feature channels, so nothing was written",
                        what, (unsigned long)a.featureChannels, (unsigned long)b.featureChannels);
        return NO;
    }
    return YES;
}

BOOL CharonMPSImageMapUnary(MPSImage *source, MPSImage *destination, MTLRegion region,
                            CharonMPSImageUnary fn, NSString *what)
{
    if (!CharonMPSImageUsable(source, what) || !CharonMPSImageUsable(destination, what))
        return NO;
    // the kernel's clipRect, resolved against the destination. A NoClip sentinel arrives as -1 and a
    // region of -1 to a texture is an assertion; this is the line that stops it.
    region = CharonMPSImageResolvedRegion(destination, region);
    if (CharonMPSImageRegionIsEmpty(region)) {
        CharonMPSRefuse(@"%@: the clip rectangle leaves no pixel of a %lux%lu image, so nothing was written",
                        what, (unsigned long)destination.width, (unsigned long)destination.height);
        return YES;
    }
    if (!CharonMPSImageWalkable(source, destination, what))
        return NO;
    CharonMPSImageLayout in = CharonMPSImageLayoutOf(source);
    CharonMPSImageLayout out = CharonMPSImageLayoutOf(destination);
    // count is the RESOLVED region's element count, on both layouts the load below is handed. The
    // binary map sets it on its three; the unary map did not, so the guard read the zero the
    // layout's memset leaves and refused every load - 60 refusals and 9 zero-filled cases.
    NSUInteger regionCount = region.size.width * region.size.height;
    in.count = regionCount * in.channels;
    out.count = regionCount * out.channels;
    // The counts are set here, for the RESOLVED region, on both layouts the load is handed
    // below. The guard in CharonMPSImageLoad refuses anything outside them by name, and that
    // refusal names the count, so a wrong one here is reported once and is findable.
    unsigned char *primary = CharonMPSImageReadRegion(source, &in, region, what);
    if (region.size.width && !primary)
        return NO;
    size_t bytes = (size_t)region.size.width * out.channels * region.size.height * out.elementSize;
    unsigned char *result = calloc(bytes ? bytes : 1, 1);
    if (!result) {
        free(primary);
        CharonMPSRefuse(@"%@: no memory for a %lux%lu answer, so nothing was written", what,
                        (unsigned long)region.size.width, (unsigned long)region.size.height);

        return NO;
    }
    // `w` and `h` are the REGION's, and the index into the source is into the SOURCE's own run, so the
    // pixel loop is bounded by the region's own loops and the index by the source's extent. Indexing
    // the source by the region's w is what asked a 12-element source for elements 12, 13 and 14.
    NSUInteger w = region.size.width, h = region.size.height;
    for (NSUInteger y = 0; y < h; y++) {
        for (NSUInteger x = 0; x < w; x++) {
            for (NSUInteger c = 0; c < out.channels; c++) {
                NSUInteger pixel = y * w + x;
                if (pixel >= in.width * in.height)
                    continue;
                NSUInteger at = CharonMPSImageIndex(&in, pixel, c);
                double value = at == (NSUInteger)-1 ? 0.0
                    : CharonMPSImageLoad(primary, &in, at);
                NSUInteger to = CharonMPSImageIndex(&out, pixel, c);
                if (to != (NSUInteger)-1)
                    CharonMPSImageStore(result, &out, to, fn(pixel, c, value));
            }
        }
    }
    free(primary);
    BOOL ok = CharonMPSImageWriteRegion(destination, &out, region, result, what);
    free(result);
    return ok;
}

BOOL CharonMPSImageMapBinary(MPSImage *primaryImage, MPSImage *secondaryImage, MPSImage *destination,
                             MTLRegion region, CharonMPSImageBinary fn, NSString *what)
{
    if (!CharonMPSImageUsable(primaryImage, what) || !CharonMPSImageUsable(secondaryImage, what) ||
        !CharonMPSImageUsable(destination, what))
        return NO;
    if (!CharonMPSImageWalkable(primaryImage, secondaryImage, what) ||
        !CharonMPSImageWalkable(primaryImage, destination, what))
        return NO;
    region = CharonMPSImageResolvedRegion(destination, region);
    if (CharonMPSImageRegionIsEmpty(region)) {
        CharonMPSRefuse(@"%@: the clip rectangle leaves no pixel of a %lux%lu image, so nothing was written",
                        what, (unsigned long)destination.width, (unsigned long)destination.height);
        return YES;
    }
    CharonMPSImageLayout a = CharonMPSImageLayoutOf(primaryImage);
    CharonMPSImageLayout b = CharonMPSImageLayoutOf(secondaryImage);
    CharonMPSImageLayout out = CharonMPSImageLayoutOf(destination);
    NSUInteger regionCount = region.size.width * region.size.height;
    a.count = regionCount * a.channels;
    b.count = regionCount * b.channels;
    out.count = regionCount * out.channels;
    unsigned char *first = CharonMPSImageReadRegion(primaryImage, &a, region, what);
    unsigned char *second = CharonMPSImageReadRegion(secondaryImage, &b, region, what);
    if (region.size.width && (!first || !second)) {
        free(first); free(second);
        return NO;
    }
    NSUInteger w = region.size.width, h = region.size.height;
    size_t bytes = (size_t)w * out.channels * h * out.elementSize;
    unsigned char *result = calloc(bytes ? bytes : 1, 1);
    if (!result) {
        free(first); free(second);
        CharonMPSRefuse(@"%@: no memory for a %lux%lu answer, so nothing was written", what,
                        (unsigned long)w, (unsigned long)h);
        return NO;
    }
    for (NSUInteger y = 0; y < h; y++) {
        for (NSUInteger x = 0; x < w; x++) {
            for (NSUInteger c = 0; c < out.channels; c++) {
                NSUInteger pixel = y * w + x;
                NSUInteger at = CharonMPSImageIndex(&a, pixel, c);
                NSUInteger at2 = CharonMPSImageIndex(&b, pixel, c);
                double primary = at == (NSUInteger)-1 ? 0.0 : CharonMPSImageLoad(first, &a, at);
                double secondary = at2 == (NSUInteger)-1 ? 0.0 : CharonMPSImageLoad(second, &b, at2);
                NSUInteger to = CharonMPSImageIndex(&out, pixel, c);
                if (to != (NSUInteger)-1)
                    CharonMPSImageStore(result, &out, to, fn(pixel, c, primary, secondary));
            }
        }
    }
    free(first); free(second);
    BOOL ok = CharonMPSImageWriteRegion(destination, &out, region, result, what);
    free(result);
    return ok;
}

// Lay one image's channels into another's at a feature channel offset, the two sides in SEPARATE
// buffers. MPSNNGraphNodes.h:2443-2446 is the rule: every image is padded up to whole groups of four feature channels, so the sizes M, N and O
// here come out as multiples of four too, even if the MPSImage objects themselves do not, and the
// channels of one source land in one block of the destination. So this reads a source row of
// `source->channels` elements and writes them at `offset .. offset + source->channels` of a destination
// row of `destination->channels` elements, at each side's own element width.
//
// The header's declaration of this and its refusal cases are at CharonMPSImage.h:98-121; the reason the
// two sides are separate buffers rather than one is in the comment there, and it is a measured SIGSEGV.
BOOL CharonMPSImageConcatRows(const CharonMPSImageLayout *source, const CharonMPSImageLayout *destination,
                              NSUInteger offset, const void *sourceBytes, void *destinationBytes)
{
    if (!source || !destination || !sourceBytes || !destinationBytes)
        return NO;
    if (source->width != destination->width || source->height != destination->height)
        return NO;
    if (!source->elementSize || !destination->elementSize)
        return NO;
    if (offset + source->channels > destination->channels)
        return NO;
    size_t sourceRow = (size_t)source->width * source->channels;
    size_t destinationRow = (size_t)destination->width * destination->channels;
    for (NSUInteger y = 0; y < source->height; y++) {
        const char *from = (const char *)sourceBytes + (size_t)y * sourceRow * source->elementSize;
        char *to = (char *)destinationBytes + (size_t)y * destinationRow * destination->elementSize;
        for (NSUInteger x = 0; x < source->width; x++) {
            const char *pixel = from + (size_t)x * source->channels * source->elementSize;
            char *out = to + ((size_t)x * destination->channels + offset) * destination->elementSize;
            for (NSUInteger c = 0; c < source->channels; c++)
                memcpy(out + (size_t)c * destination->elementSize,
                       pixel + (size_t)c * source->elementSize, source->elementSize);
        }
    }
    return YES;
}
