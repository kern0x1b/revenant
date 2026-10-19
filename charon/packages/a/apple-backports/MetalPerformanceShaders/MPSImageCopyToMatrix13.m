// MPSImageCopyToMatrix, from the header of the SDK of iOS 16.4, in
// MetalPerformanceShaders.framework/Frameworks/MPSImage.framework/Headers/MPSImageCopy.h:18-80. One
// object per release: the band machinery keeps an object whole or drops it whole, so a file here carries
// the API of exactly one release.
//
// The header, at :19-24, says the kernel copies image data into a matrix, one image's data per row. The
// data layout fixes how the feature channels are placed in the matrix, and a batch of images
// occupies several rows, one for each image.
//
// So one image becomes one row of the destination matrix, and dataLayout is what decides the order
// inside that row. MPSImage.h:300-303 gives the two orders, as the surface's own comments:
// MPSDataLayoutFeatureChannelsxHeightxWidth is [imageNum][featureChannels][imageHeight][imageWidth] and
// MPSDataLayoutHeightxWidthxFeatureChannels is [imageNum][imageHeight][imageWidth][featureChannels]. The
// header's default, at MPSImageCopy.h:37, is MPSDataLayoutFeatureChannelsxHeightxWidth, and that is what
// -initWithDevice: is given when the caller does not say.
//
// Two things bound the copy, and both come from the header:
//   - :23-24 the origin, measured from the zero corner of the destination matrix, is where writing starts; it
//     defaults to [0, 0], and its z must be 0. The origin's x is the row the first image goes into and its
//     y the column that row starts at, which is how :89 reads it for the batch form, where each image gets
//     its own row beginning at destinationMatrixOrigin.x.
//   - :26-29 a row of the matrix must hold at least image width times image height times the feature
//     channel count. That is a requirement on the caller, and a kernel in this port does not walk off the
//     end of a buffer to find out: CharonMPSMatrixHolds asks it first and the kernel says so in the log and writes nothing.
//
// The data type: MPSImageCopy.h:70 and :91 both say the destination matrix's dataType "must match the
// feature channel data type in sourceImage". A copy moves the bits, so a mismatch is refused rather than
// converted - there is no conversion in this kernel and a reinterpreting one would be a different
// kernel.

#import "CharonMPS.h"
#import "CharonMPSImage.h"

#pragma clang diagnostic ignored "-Wprotocol"
#pragma clang diagnostic ignored "-Wincomplete-implementation"

@implementation MPSImageCopyToMatrix {
    MPSDataLayout _dataLayout;
    MTLOrigin _destinationMatrixOrigin;
    NSUInteger _destinationMatrixBatchIndex;
}

// The header's default layout, at MPSImageCopy.h:37.
- (instancetype)initWithDevice:(id<MTLDevice>)device
{
    return [self initWithDevice:device dataLayout:MPSDataLayoutFeatureChannelsxHeightxWidth];
}

- (instancetype)initWithDevice:(id<MTLDevice>)device dataLayout:(MPSDataLayout)dataLayout
{
    if ((self = [super initWithDevice:device])) {
        _dataLayout = dataLayout;
        _destinationMatrixOrigin = MTLOriginMake(0, 0, 0);
        _destinationMatrixBatchIndex = 0;
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder device:(id<MTLDevice>)device
{
    // MPSImageCopy.h:50-61 says the standard coder initializers may guess the wrong device, since a file
    // cannot know where its data lives, and sends a caller to this one instead. The kernel's own state is not read back, for the reason MPSKernel's own
    // caller to this one instead. The kernel's own state is not read back, for the reason MPSKernel's own
    // -initWithCoder:device: gives and this family follows: the release's key for the layout is in no
    // header, and an invented key would read an archive the release never wrote. So the layout is the
    // header's default, MPSImageCopy.h:37, and this kernel is not recorded as round-tripping - the same
    // thing the two random generators are recorded as owed for in facts/MetalPerformanceShaders/Random.md.
    if ((self = [super initWithCoder:aDecoder device:device])) {
        _dataLayout = MPSDataLayoutFeatureChannelsxHeightxWidth;
        _destinationMatrixOrigin = MTLOriginMake(0, 0, 0);
        _destinationMatrixBatchIndex = 0;
    }
    return self;
}

- (MPSDataLayout)dataLayout
{
    return _dataLayout;
}

- (MTLOrigin)destinationMatrixOrigin
{
    return _destinationMatrixOrigin;
}

- (void)setDestinationMatrixOrigin:(MTLOrigin)origin
{
    _destinationMatrixOrigin = origin;
}

- (NSUInteger)destinationMatrixBatchIndex
{
    return _destinationMatrixBatchIndex;
}

- (void)setDestinationMatrixBatchIndex:(NSUInteger)index
{
    _destinationMatrixBatchIndex = index;
}

// The element inside one row of the destination, for the layout the caller chose. The two orders are the
// two comments at MPSImage.h:300-303, and they differ only in whether the channel count is the fastest
// or the slowest axis:
//   MPSDataLayoutFeatureChannelsxHeightxWidth   element = channel * height * width + row * width + column
//   MPSDataLayoutHeightxWidthxFeatureChannels   element = (row * width + column) * channels + channel
static inline NSUInteger CharonMPSImageCopyToMatrixElement(MPSDataLayout layout, NSUInteger width,
                                                            NSUInteger height, NSUInteger channels,
                                                            NSUInteger row, NSUInteger column,
                                                            NSUInteger channel)
{
    if (layout == MPSDataLayoutHeightxWidthxFeatureChannels)
        return (row * width + column) * channels + channel;
    return channel * width * height + row * width + column;
}

- (void)encodeToCommandBuffer:(id<MTLCommandBuffer>)commandBuffer
                   sourceImage:(MPSImage *)sourceImage
             destinationMatrix:(MPSMatrix *)destinationMatrix
{
    NSString *what = NSStringFromClass([self class]);
    if (!commandBuffer) {
        CharonMPSRefuse(@"%@: no command buffer, so nothing was written", what);
        return;
    }
    if (!CharonMPSCommandBufferPermits(commandBuffer))
        return;
    if (!CharonMPSImageUsable(sourceImage, what)) {
        CharonMPSRefuse(@"%@: the source image cannot be walked", what);
        return;
    }
    if (!destinationMatrix) {
        CharonMPSRefuse(@"%@: no destination matrix, so nothing was written", what);
        return;
    }
    // MPSImageCopy.h:21 "The z value must be 0." The release asserts on it; this port says so and writes
    // nothing, because a z that is not 0 names a plane this kernel has no meaning for.
    if (_destinationMatrixOrigin.z != 0) {
        CharonMPSRefuse(@"%@: the destination matrix origin's z is %lu and the header says it must be 0,"
                        @" so nothing was written", what, (unsigned long)_destinationMatrixOrigin.z);
        return;
    }
    // The two layouts of MPSImage.h:300-303 are the whole of MPSDataLayout on this surface. An
    // out-of-range value is not one of them, so there is no order to copy in.
    if (_dataLayout != MPSDataLayoutHeightxWidthxFeatureChannels &&
        _dataLayout != MPSDataLayoutFeatureChannelsxHeightxWidth) {
        CharonMPSRefuse(@"%@: the data layout %lu is neither of the two the header names, so nothing was"
                        @" written", what, (unsigned long)_dataLayout);
        return;
    }

    CharonMPSMatrixView to = CharonMPSMatrixViewOf(destinationMatrix);
    if (!CharonMPSDataTypeIsElement(to.dataType)) {
        CharonMPSRefuse(@"%@: the destination matrix's data type is not one of the eight element types",
                        what);
        return;
    }

    CharonMPSImageLayout in = CharonMPSImageLayoutOf(sourceImage);
    // MPSImageCopy.h:70 and :91, on both encode methods: the matrix's data type must match the image's
    // feature channel data type. A copy moves the bits, so a mismatch is refused rather than converted.
    if (to.elementSize != in.elementSize) {
        CharonMPSRefuse(@"%@: the destination matrix holds %lu-byte elements and the image's channels are"
                        @" %lu-byte, and the header says they must match, so nothing was written", what,
                        (unsigned long)to.elementSize, (unsigned long)in.elementSize);
        return;
    }

    // MPSImageCopy.h:19-24: each image's data goes into one row of the matrix, and if the image holds a
    // batch, the images take one row each. The origin's x is that first row and its y the column the row
    // starts at, which is how :89 reads it.
    NSUInteger images = sourceImage.numberOfImages ? sourceImage.numberOfImages : 1;
    NSUInteger elements = in.width * in.height * in.channels;

    // The bound from MPSImageCopy.h:26-29, asked of the matrix rather than assumed: every image needs a
    // row of at least width * height * featureChannels elements from the origin's column, and one row per
    // image from the origin's row.
    if (!CharonMPSMatrixHolds(&to, _destinationMatrixBatchIndex, _destinationMatrixOrigin.x,
                              _destinationMatrixOrigin.y, images, elements)) {
        CharonMPSRefuse(@"%@: the destination matrix is %lux%lux%lu and this copy needs %lu images of"
                        @" %lux%lux%lu from row %lu column %lu of matrix %lu, so nothing was written", what,
                        (unsigned long)to.rows, (unsigned long)to.columns, (unsigned long)to.matrices,
                        (unsigned long)images, (unsigned long)in.width, (unsigned long)in.height,
                        (unsigned long)in.channels, (unsigned long)_destinationMatrixOrigin.x,
                        (unsigned long)_destinationMatrixOrigin.y,
                        (unsigned long)_destinationMatrixBatchIndex);
        return;
    }

    // The bound above is asked of the matrix's own shape, which is a description and not a promise: a
    // caller can hand a buffer shorter than the matrix it describes, and then the write below runs off
    // the end of it. So the buffer's own length is checked too - the last element this copy touches is at
    // matrix * matrixBytes + row * rowBytes + (origin.y + elements - 1) * elementSize - 1.
    NSUInteger lastRow = _destinationMatrixOrigin.x + images - 1;
    NSUInteger lastColumn = _destinationMatrixOrigin.y + elements - 1;
    size_t span = (size_t)to.matrixBytes * _destinationMatrixBatchIndex +
                  (size_t)to.rowBytes * lastRow +
                  (size_t)to.elementSize * lastColumn + to.elementSize;
    id<MTLBuffer> backing = destinationMatrix.data;
    if (!backing || backing.length < span) {
        CharonMPSRefuse(@"%@: the destination matrix's buffer holds %lu bytes and this copy writes %lu, so"
                        @" nothing was written", what, (unsigned long)(backing ? backing.length : 0),
                        (unsigned long)span);
        return;
    }

    // One region read of each image, then the row-major permutation into the matrix's own buffer. The
    // image is read whole - the header's copy has no clip rectangle of its own, and the origin is where
    // the matrix's write starts, not a window into the image. Each image of a batch is read at its own
    // index, because MPSImageCopy.h:22-23 says each image goes to its own row.
    for (NSUInteger image = 0; image < images; image++) {
        CharonMPSImageLayout one = in;
        one.count = elements;
        MTLRegion region = MTLRegionMake2D(0, 0, in.width, in.height);
        unsigned char *from = calloc(elements * in.elementSize, 1);
        if (!from) {
            CharonMPSRefuse(@"%@: no memory for a %lux%lux%lu image, so nothing was written", what,
                            (unsigned long)in.width, (unsigned long)in.height, (unsigned long)in.channels);
            return;
        }
        [sourceImage readBytes:from
                    dataLayout:MPSDataLayoutHeightxWidthxFeatureChannels
                   bytesPerRow:in.width * in.channels * in.elementSize
                        region:region
             featureChannelInfo:(MPSImageReadWriteParams){0}
                    imageIndex:image];
        NSUInteger row = _destinationMatrixOrigin.x + image;
        for (NSUInteger y = 0; y < in.height; y++) {
            for (NSUInteger x = 0; x < in.width; x++) {
                for (NSUInteger channel = 0; channel < in.channels; channel++) {
                    NSUInteger pixel = y * in.width + x;
                    double value = CharonMPSImageLoad(from, &one,
                                                      CharonMPSImageIndex(&one, pixel, channel));
                    NSUInteger element = CharonMPSImageCopyToMatrixElement(
                        _dataLayout, in.width, in.height, in.channels, y, x, channel);
                    CharonMPSStore(CharonMPSMatrixElement(&to, _destinationMatrixBatchIndex, row,
                                                         _destinationMatrixOrigin.y + element),
                                   to.dataType, 0, value);
                }
            }
        }
        free(from);
        CharonMPSConsumeReadCount(sourceImage);
    }
}

@end
