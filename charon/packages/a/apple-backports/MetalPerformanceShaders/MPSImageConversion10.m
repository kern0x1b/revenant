// MPSImageConversion, from MPSImageConversion.h of the iPhoneOS 16.4 surface: the filter that "performs
// a conversion from source to destination" (:19) - the colour channels' premultiplication and the
// destination's own shape.
//
// One object for one release: the class's own annotation above its @interface is ios(10.0)
// (MPSImageConversion.h:22) and nothing else is in this file.
//
// WHAT A CONVERSION IS, and it is written out in full rather than described. MPSImageTypes.h:32-41
// gives all nine cells of source against destination, each with the operation it performs:
//     NonPremultiplied -> NonPremultiplied    <none>
//     NonPremultiplied -> AlphaIsOne          composite with opaque background color
//     NonPremultiplied -> Premultiplied       multiply color channels by alpha
//     AlphaIsOne       -> NonPremultiplied    set alpha to 1
//     AlphaIsOne       -> AlphaIsOne          set alpha to 1
//     AlphaIsOne       -> Premultiplied       set alpha to 1
//     Premultiplied    -> NonPremultiplied    divide color channels by alpha
//     Premultiplied    -> AlphaIsOne          composite with opaque background color
//     Premultiplied    -> Premultiplied       <none>
// and MPSImageTypes.h:22 defines the terms: the colour channels of a premultiplied image "are stored
// instead as color * alpha", so multiplying is the way into that and dividing the way out of it. The
// nine cells are the switch below, because that is the table the header prints.
//
// The background colour is the other half of the composite cell. MPSImageConversion.h:49-53 describes it
// as an array of CGFloats, in the source colour space, with one entry per colour channel of that space.
// When the array is NULL the header's default applies: black. So a flattening cell with no colour is a
// composite over black, which is what that default means.
//
// OWED, refused by name rather than answered wrongly: the COLOUR SPACE conversion. The header's
// The header's conversionInfo argument may be NULL, meaning no colour-space conversion is needed
// (MPSImageConversion.h:56-57), and a non-NULL CGColorConversionInfoRef is opaque - CoreGraphics
// declares no accessor that reads the two spaces back out of one - so a converter built from it alone
// has no source space and no destination space to convert between, and CGColorConvert needs both. The
// NULL case, which is every conversion that does not change colour space, is the one carried here, and
// a conversionInfo this port cannot act on is refused by name at initialization rather than ignored.
//
// WHAT IS NOT CLAIMED. No number in this file is a measurement of Apple's code - the release's own MPS
// cannot run on this host, which facts/MetalPerformanceShaders/Image9.md records. What is written here
// is transcribed from the header above; what has been checked is the armv7 link, that this object
// defines the class it says.

#import "CharonMPSImage.h"


@implementation MPSImageConversion {
    MPSAlphaType _sourceAlpha;
    MPSAlphaType _destinationAlpha;
    BOOL _flattens;            // the destination is opaque, so the composite cells apply
    BOOL _setsAlphaOne;        // one of the three cells that writes alpha as 1
    BOOL _multiplies;          // colour channels by alpha
    BOOL _divides;             // colour channels by alpha
    double _background[4];
}

- (instancetype)initWithDevice:(id<MTLDevice>)device
                        srcAlpha:(MPSAlphaType)srcAlpha
                       destAlpha:(MPSAlphaType)destAlpha
                 backgroundColor:(CGFloat *)backgroundColor
                  conversionInfo:(CGColorConversionInfoRef)conversionInfo
{
    if (conversionInfo) {
        CharonMPSRefuse(@"MPSImageConversion: a colour space conversion was asked for and this port cannot"
                        @" perform it - CoreGraphics declares no accessor that reads the source and the"
                        @" destination space back out of a CGColorConversionInfoRef, so there is nothing"
                        @" to convert between. Pass NULL, which means no colour"
                        @" space conversion is needed, and the alpha conversion is carried");
        return nil;
    }
    if (!(self = [super initWithDevice:device]))
        return nil;
    _sourceAlpha = srcAlpha;
    _destinationAlpha = destAlpha;
    // MPSImageConversion.h:49-53: the array holds one CGFloat per colour channel of the source
    // colourspace, and a NULL array means {0}. Four is the widest a colour space this port carries can
    // be, and a channel the array does not reach is black rather than the source's value.
    for (NSUInteger channel = 0; channel < 4; channel++)
        _background[channel] = 0.0;
    if (backgroundColor)
        for (NSUInteger channel = 0; channel < 4; channel++)
            _background[channel] = (double)backgroundColor[channel];
    // The four questions the nine cells reduce to, read off the table above. The alpha is written as 1
    // in the five cells whose operation says so, which are the three whose SOURCE is AlphaIsOne (the
    // table prints "set alpha to 1" for those, and a source that guarantees an alpha of one has one to
    // copy) together with the composite cells, whose destination is opaque by definition.
    _flattens = destAlpha == MPSAlphaTypeAlphaIsOne && srcAlpha != destAlpha;
    _setsAlphaOne = destAlpha == MPSAlphaTypeAlphaIsOne || srcAlpha == MPSAlphaTypeAlphaIsOne;
    _multiplies = destAlpha == MPSAlphaTypePremultiplied && srcAlpha == MPSAlphaTypeNonPremultiplied;
    _divides = destAlpha == MPSAlphaTypeNonPremultiplied && srcAlpha == MPSAlphaTypePremultiplied;
    return self;
}

- (MPSAlphaType)sourceAlpha { return _sourceAlpha; }
- (MPSAlphaType)destinationAlpha { return _destinationAlpha; }

- (void)encodeToCommandBuffer:(id<MTLCommandBuffer>)commandBuffer
                  sourceImage:(MPSImage *)sourceImage
             destinationImage:(MPSImage *)destinationImage
{
    NSString *what = @"MPSImageConversion";
    if (!CharonMPSCommandBufferPermits(commandBuffer))
        return;
    CharonMPSImageLayout from = CharonMPSImageLayoutOf(sourceImage);
    CharonMPSImageLayout to = CharonMPSImageLayoutOf(destinationImage);
    if (!CharonMPSImageUsable(sourceImage, @"MPSImageConversion source") ||
        !CharonMPSImageUsable(destinationImage, @"MPSImageConversion destination")) {
        CharonMPSRefuse(@"%@: an image with no walkable shape was given, so nothing was written", what);
        return;
    }
    // The header's own compare-with-no-tolerance rule does not apply here: a conversion moves a value,
    // and the two images may hold different element widths, so each is read and written in its own.
    MTLRegion region = MTLRegionMake2D(0, 0, from.width, from.height);
    if (to.width < from.width || to.height < from.height) {
        CharonMPSRefuse(@"%@: the destination is %lux%lu and the source %lux%lu, and a conversion does not"
                        @" enlarge or move pixels, so nothing was written", what,
                        (unsigned long)to.width, (unsigned long)to.height,
                        (unsigned long)from.width, (unsigned long)from.height);
        return;
    }
    // The element count of the region this reads, which is what CharonMPSImageLoad's guard is against and
    // which every other caller of the read sets on its own layout before reading: MPSImage9.m:132,
    // MPSImageConvolution13.m:68, MPSImageMorphology13.m:62, MPSImageReduceUnary16.m:191,
    // MPSImageTranspose13.m:54, MPSImageStatistics11.m:108 and the walk's own three at
    // MPSImageWalk13.m:296-305. CharonMPSImageLayoutOf leaves it at the zero its memset writes, because a
    // count that stayed the whole image's would let an index past this region's buffer through the guard,
    // so a caller that does not set it gets every element refused.
    // Measured, macOS 27.0 build 26A428 over the 2x2 float32 image of
    // tests/backports/host/mpsimage10/cases.m with a NULL conversionInfo and
    // srcAlpha == destAlpha == AlphaIsOne: without it the read succeeded and loaded zeros - the log carried
    // "the walk asked for element 0 of a region of 0 element(s) (2x2 pixels, 1 channel(s), elementSize 4)"
    // four times - so the conversion wrote four zeros where the release copies the source's four values.
    from.count = (NSUInteger)region.size.width * (NSUInteger)region.size.height * from.channels;
    void *source = CharonMPSImageReadRegion(sourceImage, &from, region, what);
    if (!source)
        return;
    size_t bytes = (size_t)to.width * to.channels * to.height * to.elementSize;
    unsigned char *destination = bytes ? (unsigned char *)calloc(bytes, 1) : NULL;
    if (!destination) {
        free(source);
        CharonMPSRefuse(@"%@: no memory for a %lux%lu destination, so nothing was written", what,
                        (unsigned long)to.width, (unsigned long)to.height);
        return;
    }

    // An alpha channel is the LAST channel of the image, which is what MPSImageTypes.h:21 means by
    // "color * alpha" for the colour channels of the image. An image of one channel has no alpha at all,
    // so the multiply, divide and composite cells have nothing to act on and the value passes through -
    // the same answer as the table's own "<none>" rows, reached by the shape rather than by a guess.
    NSUInteger fromAlpha = from.channels > 1 ? from.channels - 1 : (NSUInteger)-1;
    NSUInteger toAlpha = to.channels > 1 ? to.channels - 1 : (NSUInteger)-1;
    NSUInteger pixels = from.width * from.height;
    for (NSUInteger pixel = 0; pixel < pixels; pixel++) {
        NSUInteger at = pixel * from.channels;
        NSUInteger into = pixel * to.channels;
        double alpha = _flattens || _multiplies || _divides
            ? (fromAlpha != (NSUInteger)-1 ? CharonMPSImageLoad(source, &from, at + fromAlpha) : 1.0)
            : 1.0;
        for (NSUInteger channel = 0; channel < to.channels; channel++) {
            double value = channel < from.channels ? CharonMPSImageLoad(source, &from, at + channel) : 0.0;
            if (toAlpha != (NSUInteger)-1 && channel == toAlpha) {
                // The alpha channel itself is written as the table says: 1 for the three cells that say
                // "set alpha to 1", the source's own value otherwise, since dividing or multiplying the
                // colour channels does not change it.
                value = _setsAlphaOne ? 1.0 : (fromAlpha != (NSUInteger)-1 ? alpha : 1.0);
            } else if (_divides) {
                value = alpha != 0.0 ? value / alpha : 0.0;
            } else if (_multiplies) {
                value = value * alpha;
            } else if (_flattens) {
                // "composite with opaque background color" (MPSImageTypes.h:34 and :40): the colour over
                // the background by the source's own alpha, which is the compositing operator those two
                // cells mean. The background is black unless the caller gave one.
                value = value * alpha + _background[channel < 4 ? channel : 3] * (1.0 - alpha);
            }
            CharonMPSImageStore(destination, &to, into + channel, value);
        }
    }
    CharonMPSImageWriteRegion(destinationImage, &to,
                              MTLRegionMake2D(0, 0, to.width, to.height), destination, what);
    free(source);
    free(destination);
}

@end