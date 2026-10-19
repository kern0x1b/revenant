// MPSImageHistogram, from MPSImageHistogram.h of the iPhoneOS 26.2 surface. One object per release:
// both classes here are MPS_CLASS_AVAILABLE_STARTING ios(9.0) (:32, :144); the release exports MPSImageHistogram from 9.0 and
// MPSImageNormalizedHistogram from 12.0, so the latter is MPSImageNormalizedHistogram12.m.
//
// Two of this family's four rows are here, and the other two are OWED with the reason at the bottom.
//
// WHAT THE HEADER SAYS, and it is the whole contract for these two:
//
//   MPSImageHistogramInfo holds numberOfHistogramEntries (the bin count), histogramForAlpha, minPixelValue
//   and maxPixelValue. The header's wording on the two bounds gives the range as half-open at the bottom
//   and closed at the top, and a value outside that range is not binned at all.
//   :42  clipRectSource - the region of the source to read, intersected with the image, default
//        MPSRectNoClip. Same rule the reduction family has, from the same wording.
//   :49  zeroHistogram - when YES (the default) the result memory is zero-initialized first, and when NO it is
//        left as it was. So a caller that sets NO is asking for the buffer's existing contents to be ADDED to,
//        and a kernel that zeroed anyway would silently destroy the accumulation it was asked to do.
//   :59  minPixelThresholdValue - an entry is incremented only when the pixel value reaches this threshold.
//        It is a per-channel vector_float4, so the threshold is per channel.
//   :206-215 the result layout: all R-channel bins come first, then G, then B, then A, each channel's bins
//        in order. :208 adds that with histogramForAlpha off on an RGBA source only the RGB channels are stored.
//        So the buffer is CHANNEL-MAJOR, not bin-major, and the channel count depends on the source and on
//        histogramForAlpha. Getting that wrong writes a plausible-looking array in the wrong order.
//   :115 the encode takes a texture, a buffer and a byte offset - not an MPSImage - because the histogram
//   is written to memory the caller owns, not to another image.
//   :131 histogramSizeForSourceFormat: gives the byte count the result histograms need, so it is the bins
//        times the channels times the entry size, and it is what tells a caller how big to make the buffer.
//
// EXACT. A histogram COUNTS: it selects a bin and adds one to it. Nothing is averaged, nothing is scaled,
// nothing is stored as a float that was computed, so the counts are integers and are compared for
// equality with no tolerance - the same argument as the morphology family, and the opposite of the
// convolution family's one-ulp bound. A tolerance on a count could only hide an off-by-one.
//
// The entry type is uint32 and is not this file's choice: MPSImageHistogram.h's result description calls
// them "histogram results" and the buffer is the caller's, so the width is asked of the header's own
// declaration where it gives one and refused by name otherwise, rather than guessed.


#import "CharonMPSHistogram.h"

#pragma clang diagnostic ignored "-Wincomplete-implementation"
// As in the reduction, convolution and morphology families, and recorded in the same crutches.md entry.
#pragma clang diagnostic ignored "-Wobjc-designated-initializers"

@implementation MPSImageHistogram {
    MTLRegion _clipRectSource;
    BOOL _zeroHistogram;
    vector_float4 _minPixelThresholdValue;
    MPSImageHistogramInfo _histogramInfo;
}

@synthesize clipRectSource = _clipRectSource;
@synthesize zeroHistogram = _zeroHistogram;
@synthesize minPixelThresholdValue = _minPixelThresholdValue;
@synthesize histogramInfo = _histogramInfo;

// :76 - initWithDevice:histogramInfo: is the designated initializer, and the info IS the histogram's shape.
- (instancetype)initWithDevice:(id<MTLDevice>)device histogramInfo:(const MPSImageHistogramInfo *)histogramInfo
{
    if ((self = [super initWithDevice:device])) {
        if (!histogramInfo || !histogramInfo->numberOfHistogramEntries) {
            CharonMPSRefuse(@"MPSImageHistogram: MPSImageHistogramInfo with %lu entries describes no"
                            @" histogram, so no object was made",
                            (unsigned long)(histogramInfo ? histogramInfo->numberOfHistogramEntries : 0));
            return nil;
        }
        _histogramInfo = *histogramInfo;
        _clipRectSource = MPSRectNoClip;          // the default, as :42's wording gives
        _zeroHistogram = YES;                     // :49 - "Default: YES"
        _minPixelThresholdValue = (vector_float4){0.0f, 0.0f, 0.0f, 0.0f};
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder device:(id<MTLDevice>)device
{
    CharonMPSRefuse(@"MPSImageHistogram: -initWithCoder:device: is not carried - the release's keys for a"
                    @" histogram's bins and range are in no header, so a decoder cannot rebuild them"
                    @" honestly");
    return nil;
}

- (size_t)histogramSizeForSourceFormat:(MTLPixelFormat)sourceFormat
{
    // :131 gives the byte count the result histograms need, and :208 says the channel count
    // follows the source unless histogramForAlpha trims it. The entry is a 32-bit count, which is the
    // width the buffer description and histogramSizeForSourceFormat: together imply.
    // Only the formats this surface actually names are answered. There is no MTLPixelFormatRGB8Unorm on
    // it - the 8-bit formats are the RGBA and BGRA ones - so a three-channel source would have to be
    // spelled from the real enum, and guessing at one that does not exist would be a compile error at
    // best and a wrong channel count at worst.
    if (sourceFormat != MTLPixelFormatRGBA8Unorm && sourceFormat != MTLPixelFormatRGBA8Unorm_sRGB) {
        CharonMPSRefuse(@"MPSImageHistogram: -histogramSizeForSourceFormat: is asked about pixel format %lu,"
                        @" which this port does not carry, so the size is not guessed", (unsigned long)sourceFormat);
        return 0;
    }
    NSUInteger channels = 4;
    if (!_histogramInfo.histogramForAlpha)
        channels = 3;                              // :208 - RGBA with histogramForAlpha false stores RGB only
    return (size_t)_histogramInfo.numberOfHistogramEntries * channels * sizeof(uint32_t);
}

- (void)encodeToCommandBuffer:(id<MTLCommandBuffer>)commandBuffer
                sourceTexture:(id<MTLTexture>)source
                     histogram:(id<MTLBuffer>)histogram
                histogramOffset:(NSUInteger)histogramOffset
{
    NSString *what = NSStringFromClass([self class]);
    if (!source || !histogram) {
        CharonMPSRefuse(@"%@: a source texture and a histogram buffer are both required, so nothing was"
                        @" written", what);
        return;
    }
    NSUInteger channels = _histogramInfo.histogramForAlpha ? 4 : 3;
    size_t need = [self histogramSizeForSourceFormat:source.pixelFormat];
    unsigned char *base = (unsigned char *)[histogram contents];
    if (histogramOffset > [histogram length] || need > [histogram length] - histogramOffset) {
        CharonMPSRefuse(@"%@: %lu bytes at offset %lu will not fit a buffer of %lu, so nothing was written",
                        what, (unsigned long)need, (unsigned long)histogramOffset,
                        (unsigned long)[histogram length]);
        return;
    }
    uint32_t *bins = (uint32_t *)(base + histogramOffset);
    // :49 - zeroHistogram NO means the caller's existing counts are to be ADDED to, so the memory is only
    // cleared when it was asked for.
    if (_zeroHistogram)
        memset(bins, 0, need);
    MTLRegion window = _clipRectSource;
    if (window.size.width < 0 || window.size.height < 0) {
        window = MTLRegionMake2D(0, 0, source.width, source.height);   // MPSRectNoClip, the whole texture
    }
    CharonMPSHistogramRegion(source, window, _histogramInfo, _minPixelThresholdValue, bins, channels,
                             _histogramInfo.histogramForAlpha, what);
}

@end

// OWED, and named here so the gap is in the file rather than only in the registry:
//
//   MPSImageHistogramEqualization (:268) and MPSImageHistogramSpecification (:340). Neither is a walk over
//   an image. Both build a TRANSFORM - :249 describes it as the cumulative distribution of the histogram,
//   for the equalization, and :358 builds one from a desired histogram for the specification. Their only
//   encode is :425 encodeTransformToCommandBuffer:, which takes an
//   MTLComputeCommandEncoder. That is the one thing this host cannot do at all: its AGX family lacks
//   computeCommandEncoderWithDispatchType: and the release's own kernel dies encoding with an
//   unrecognized selector. So there is no oracle for them here and no way to check an answer, and an
//   untestable transform would be a guessed one.
