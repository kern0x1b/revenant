#import "RevenantMPS.h"
#import "RevenantMPSImage.h"

MPSDataType RevenantMPSImageDataTypeOf(MPSImageFeatureChannelFormat format)
{
    switch (format) {
    case MPSImageFeatureChannelFormatUnorm8: return MPSDataTypeUInt8;
    case MPSImageFeatureChannelFormatUnorm16: return MPSDataTypeUInt16;
    case MPSImageFeatureChannelFormatFloat16: return MPSDataTypeFloat16;
    case MPSImageFeatureChannelFormatFloat32: return MPSDataTypeFloat32;
    default: return MPSDataTypeInvalid;
    }
}

size_t RevenantMPSImageFeatureChannelSize(MPSImageFeatureChannelFormat format)
{
    switch (format) {
    case MPSImageFeatureChannelFormatUnorm8: return 1;
    case MPSImageFeatureChannelFormatUnorm16: return 2;
    case MPSImageFeatureChannelFormatFloat16: return 2;
    case MPSImageFeatureChannelFormatFloat32: return 4;
    default: return 0;
    }
}

RevenantMPSImageLayout RevenantMPSImageLayoutOf(MPSImage *image)
{
    RevenantMPSImageLayout layout;
    memset(&layout, 0, sizeof(layout));
    if (!image)
        return layout;
    layout.width = image.width;
    layout.height = image.height;
    layout.channels = image.featureChannels ? image.featureChannels : 1;
    layout.dataType = RevenantMPSImageDataTypeOf(image.featureChannelFormat);
    layout.elementSize = RevenantMPSImageFeatureChannelSize(image.featureChannelFormat);
    layout.pixelFormat = (int)image.pixelFormat;
    layout.bytesPerPixel = layout.channels * layout.elementSize;
    layout.bytesPerRow = layout.bytesPerPixel * layout.width;
    return layout;
}

BOOL RevenantMPSImageUsable(MPSImage *image, NSString *what)
{
    if (!image) {
        RevenantMPSRefuse(@"%@: no image, so nothing was written", what);
        return NO;
    }
    if (!image.texture) {
        RevenantMPSRefuse(@"%@: the image holds no texture, so nothing was written", what);
        return NO;
    }
    MPSDataType dataType = RevenantMPSImageDataTypeOf(image.featureChannelFormat);
    if (!RevenantMPSDataTypeIsElement(dataType) || !MPSSizeofMPSDataType(dataType)) {
        RevenantMPSRefuse(@"%@: the image's channel format %lu is not one of the four the 16.4 surface names, so nothing was written",
                        what, (unsigned long)image.featureChannelFormat);
        return NO;
    }
    if (!image.width || !image.height) {
        RevenantMPSRefuse(@"%@: the image's shape is %lux%lu, so nothing was written",
                        what, (unsigned long)image.width, (unsigned long)image.height);
        return NO;
    }
    return YES;
}

NSUInteger RevenantMPSImageIndex(const RevenantMPSImageLayout *layout, NSUInteger pixel, NSUInteger channel)
{
    if (channel >= layout->channels)
        return (NSUInteger)-1;
    return pixel * layout->channels + channel;
}

double RevenantMPSImageLoad(const void *buffer, const RevenantMPSImageLayout *layout, NSUInteger index)
{
    NSUInteger count = layout->count;
    if (index >= count) {
        RevenantMPSRefuse(@"MPSImage: the walk asked for element %lu of a region of %lu element(s) "
                        "(%lux%lu pixels, %lu channel(s), elementSize %lu, dataType %d, pixelFormat %d), "
                        "so the value is 0 and nothing was read",
                        (unsigned long)index, (unsigned long)count,
                        (unsigned long)layout->width, (unsigned long)layout->height,
                        (unsigned long)layout->channels, (unsigned long)layout->elementSize,
                        (int)layout->dataType, (int)layout->pixelFormat);
        return 0.0;
    }
    return RevenantMPSLoad((const unsigned char *)buffer, layout->dataType, index);
}

void RevenantMPSImageStore(void *buffer, const RevenantMPSImageLayout *layout, NSUInteger index, double value)
{
    RevenantMPSStore((unsigned char *)buffer, layout->dataType, index, value);
}

MTLRegion RevenantMPSImageResolvedRegion(MPSImage *image, MTLRegion clip)
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

BOOL RevenantMPSImageRegionIsEmpty(MTLRegion region)
{
    return region.size.width == 0 || region.size.height == 0;
}

void *_Nullable RevenantMPSImageReadRegion(MPSImage *image, const RevenantMPSImageLayout *layout,
                                        MTLRegion region, NSString *what)
{
    NSUInteger w = region.size.width, h = region.size.height;
    if (!w || !h)
        return NULL;
    NSUInteger perRow = w * layout->channels;
    size_t bytes = (size_t)perRow * h * layout->elementSize;
    if (!layout->elementSize) {
        RevenantMPSRefuse(@"MPSImage: the channel format names data type %d, which has no element size, so a "
                        "%lux%lu read has no buffer and nothing was read", (int)layout->dataType,
                        (unsigned long)w, (unsigned long)h);
        return NULL;
    }
    RevenantMPSImageLayout here = *layout;
    here.count = (NSUInteger)w * (NSUInteger)h * layout->channels;
    unsigned char *buffer = calloc(bytes, 1);
    if (!buffer) {
        RevenantMPSRefuse(@"%@: no memory for a %lux%lu walk of %lu channel(s), so nothing was written",
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

BOOL RevenantMPSImageWriteRegion(MPSImage *image, const RevenantMPSImageLayout *layout,
                               MTLRegion region, const void *buffer, NSString *what)
{
    NSUInteger w = region.size.width, h = region.size.height;
    if (!w || !h)
        return YES;
    NSUInteger perRow = w * layout->channels;
#if defined(REVENANT_PLANT)
    if (layout->dataType == MPSDataTypeFloat32 && layout->elementSize == 4) {
        float *out = (float *)buffer;
        size_t elements = (size_t)perRow * h;
        for (size_t i = 0; i < elements; i++) {
#if REVENANT_PLANT == 1
            out[i] = out[i] + 1.0f;
#elif REVENANT_PLANT == 2
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

static BOOL RevenantMPSImageWalkable(MPSImage *a, MPSImage *b, NSString *what)
{
    if (!a || !b)
        return NO;
    if (a.width != b.width || a.height != b.height) {
        RevenantMPSRefuse(@"%@: the two images are %lux%lu and %lux%lu, and a walk reads one pixel of each, so nothing was written",
                        what, (unsigned long)a.width, (unsigned long)a.height,
                        (unsigned long)b.width, (unsigned long)b.height);
        return NO;
    }
    MPSDataType da = RevenantMPSImageDataTypeOf(a.featureChannelFormat);
    MPSDataType db = RevenantMPSImageDataTypeOf(b.featureChannelFormat);
    if (da != db) {
        RevenantMPSRefuse(@"%@: the two images hold channel formats %lu and %lu, and a walk reads one element of each, so nothing was written",
                        what, (unsigned long)a.featureChannelFormat, (unsigned long)b.featureChannelFormat);
        return NO;
    }
    if (a.featureChannels != b.featureChannels) {
        RevenantMPSRefuse(@"%@: the two images hold %lu and %lu feature channels, so nothing was written",
                        what, (unsigned long)a.featureChannels, (unsigned long)b.featureChannels);
        return NO;
    }
    return YES;
}

BOOL RevenantMPSImageMapUnary(MPSImage *source, MPSImage *destination, MTLRegion region,
                            RevenantMPSImageUnary fn, NSString *what)
{
    if (!RevenantMPSImageUsable(source, what) || !RevenantMPSImageUsable(destination, what))
        return NO;
    region = RevenantMPSImageResolvedRegion(destination, region);
    if (RevenantMPSImageRegionIsEmpty(region)) {
        RevenantMPSRefuse(@"%@: the clip rectangle leaves no pixel of a %lux%lu image, so nothing was written",
                        what, (unsigned long)destination.width, (unsigned long)destination.height);
        return YES;
    }
    if (!RevenantMPSImageWalkable(source, destination, what))
        return NO;
    RevenantMPSImageLayout in = RevenantMPSImageLayoutOf(source);
    RevenantMPSImageLayout out = RevenantMPSImageLayoutOf(destination);
    NSUInteger regionCount = region.size.width * region.size.height;
    in.count = regionCount * in.channels;
    out.count = regionCount * out.channels;
    unsigned char *primary = RevenantMPSImageReadRegion(source, &in, region, what);
    if (region.size.width && !primary)
        return NO;
    size_t bytes = (size_t)region.size.width * out.channels * region.size.height * out.elementSize;
    unsigned char *result = calloc(bytes ? bytes : 1, 1);
    if (!result) {
        free(primary);
        RevenantMPSRefuse(@"%@: no memory for a %lux%lu answer, so nothing was written", what,
                        (unsigned long)region.size.width, (unsigned long)region.size.height);

        return NO;
    }
    NSUInteger w = region.size.width, h = region.size.height;
    for (NSUInteger y = 0; y < h; y++) {
        for (NSUInteger x = 0; x < w; x++) {
            for (NSUInteger c = 0; c < out.channels; c++) {
                NSUInteger pixel = y * w + x;
                if (pixel >= in.width * in.height)
                    continue;
                NSUInteger at = RevenantMPSImageIndex(&in, pixel, c);
                double value = at == (NSUInteger)-1 ? 0.0
                    : RevenantMPSImageLoad(primary, &in, at);
                NSUInteger to = RevenantMPSImageIndex(&out, pixel, c);
                if (to != (NSUInteger)-1)
                    RevenantMPSImageStore(result, &out, to, fn(pixel, c, value));
            }
        }
    }
    free(primary);
    BOOL ok = RevenantMPSImageWriteRegion(destination, &out, region, result, what);
    free(result);
    return ok;
}

BOOL RevenantMPSImageMapBinary(MPSImage *primaryImage, MPSImage *secondaryImage, MPSImage *destination,
                             MTLRegion region, RevenantMPSImageBinary fn, NSString *what)
{
    if (!RevenantMPSImageUsable(primaryImage, what) || !RevenantMPSImageUsable(secondaryImage, what) ||
        !RevenantMPSImageUsable(destination, what))
        return NO;
    if (!RevenantMPSImageWalkable(primaryImage, secondaryImage, what) ||
        !RevenantMPSImageWalkable(primaryImage, destination, what))
        return NO;
    region = RevenantMPSImageResolvedRegion(destination, region);
    if (RevenantMPSImageRegionIsEmpty(region)) {
        RevenantMPSRefuse(@"%@: the clip rectangle leaves no pixel of a %lux%lu image, so nothing was written",
                        what, (unsigned long)destination.width, (unsigned long)destination.height);
        return YES;
    }
    RevenantMPSImageLayout a = RevenantMPSImageLayoutOf(primaryImage);
    RevenantMPSImageLayout b = RevenantMPSImageLayoutOf(secondaryImage);
    RevenantMPSImageLayout out = RevenantMPSImageLayoutOf(destination);
    NSUInteger regionCount = region.size.width * region.size.height;
    a.count = regionCount * a.channels;
    b.count = regionCount * b.channels;
    out.count = regionCount * out.channels;
    unsigned char *first = RevenantMPSImageReadRegion(primaryImage, &a, region, what);
    unsigned char *second = RevenantMPSImageReadRegion(secondaryImage, &b, region, what);
    if (region.size.width && (!first || !second)) {
        free(first); free(second);
        return NO;
    }
    NSUInteger w = region.size.width, h = region.size.height;
    size_t bytes = (size_t)w * out.channels * h * out.elementSize;
    unsigned char *result = calloc(bytes ? bytes : 1, 1);
    if (!result) {
        free(first); free(second);
        RevenantMPSRefuse(@"%@: no memory for a %lux%lu answer, so nothing was written", what,
                        (unsigned long)w, (unsigned long)h);
        return NO;
    }
    for (NSUInteger y = 0; y < h; y++) {
        for (NSUInteger x = 0; x < w; x++) {
            for (NSUInteger c = 0; c < out.channels; c++) {
                NSUInteger pixel = y * w + x;
                NSUInteger at = RevenantMPSImageIndex(&a, pixel, c);
                NSUInteger at2 = RevenantMPSImageIndex(&b, pixel, c);
                double primary = at == (NSUInteger)-1 ? 0.0 : RevenantMPSImageLoad(first, &a, at);
                double secondary = at2 == (NSUInteger)-1 ? 0.0 : RevenantMPSImageLoad(second, &b, at2);
                NSUInteger to = RevenantMPSImageIndex(&out, pixel, c);
                if (to != (NSUInteger)-1)
                    RevenantMPSImageStore(result, &out, to, fn(pixel, c, primary, secondary));
            }
        }
    }
    free(first); free(second);
    BOOL ok = RevenantMPSImageWriteRegion(destination, &out, region, result, what);
    free(result);
    return ok;
}

BOOL RevenantMPSImageConcatRows(const RevenantMPSImageLayout *source, const RevenantMPSImageLayout *destination,
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
