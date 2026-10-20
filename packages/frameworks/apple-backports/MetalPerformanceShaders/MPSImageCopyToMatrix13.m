#import "RevenantMPS.h"
#import "RevenantMPSImage.h"

#pragma clang diagnostic ignored "-Wprotocol"
#pragma clang diagnostic ignored "-Wincomplete-implementation"

@implementation MPSImageCopyToMatrix {
    MPSDataLayout _dataLayout;
    MTLOrigin _destinationMatrixOrigin;
    NSUInteger _destinationMatrixBatchIndex;
}

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

static inline NSUInteger RevenantMPSImageCopyToMatrixElement(MPSDataLayout layout, NSUInteger width,
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
        RevenantMPSRefuse(@"%@: no command buffer, so nothing was written", what);
        return;
    }
    if (!RevenantMPSCommandBufferPermits(commandBuffer))
        return;
    if (!RevenantMPSImageUsable(sourceImage, what)) {
        RevenantMPSRefuse(@"%@: the source image cannot be walked", what);
        return;
    }
    if (!destinationMatrix) {
        RevenantMPSRefuse(@"%@: no destination matrix, so nothing was written", what);
        return;
    }
    if (_destinationMatrixOrigin.z != 0) {
        RevenantMPSRefuse(@"%@: the destination matrix origin's z is %lu and the header says it must be 0,"
                        @" so nothing was written", what, (unsigned long)_destinationMatrixOrigin.z);
        return;
    }
    if (_dataLayout != MPSDataLayoutHeightxWidthxFeatureChannels &&
        _dataLayout != MPSDataLayoutFeatureChannelsxHeightxWidth) {
        RevenantMPSRefuse(@"%@: the data layout %lu is neither of the two the header names, so nothing was"
                        @" written", what, (unsigned long)_dataLayout);
        return;
    }

    RevenantMPSMatrixView to = RevenantMPSMatrixViewOf(destinationMatrix);
    if (!RevenantMPSDataTypeIsElement(to.dataType)) {
        RevenantMPSRefuse(@"%@: the destination matrix's data type is not one of the eight element types",
                        what);
        return;
    }

    RevenantMPSImageLayout in = RevenantMPSImageLayoutOf(sourceImage);
    if (to.elementSize != in.elementSize) {
        RevenantMPSRefuse(@"%@: the destination matrix holds %lu-byte elements and the image's channels are"
                        @" %lu-byte, and the header says they must match, so nothing was written", what,
                        (unsigned long)to.elementSize, (unsigned long)in.elementSize);
        return;
    }

    NSUInteger images = sourceImage.numberOfImages ? sourceImage.numberOfImages : 1;
    NSUInteger elements = in.width * in.height * in.channels;

    if (!RevenantMPSMatrixHolds(&to, _destinationMatrixBatchIndex, _destinationMatrixOrigin.x,
                              _destinationMatrixOrigin.y, images, elements)) {
        RevenantMPSRefuse(@"%@: the destination matrix is %lux%lux%lu and this copy needs %lu images of"
                        @" %lux%lux%lu from row %lu column %lu of matrix %lu, so nothing was written", what,
                        (unsigned long)to.rows, (unsigned long)to.columns, (unsigned long)to.matrices,
                        (unsigned long)images, (unsigned long)in.width, (unsigned long)in.height,
                        (unsigned long)in.channels, (unsigned long)_destinationMatrixOrigin.x,
                        (unsigned long)_destinationMatrixOrigin.y,
                        (unsigned long)_destinationMatrixBatchIndex);
        return;
    }

    NSUInteger lastRow = _destinationMatrixOrigin.x + images - 1;
    NSUInteger lastColumn = _destinationMatrixOrigin.y + elements - 1;
    size_t span = (size_t)to.matrixBytes * _destinationMatrixBatchIndex +
                  (size_t)to.rowBytes * lastRow +
                  (size_t)to.elementSize * lastColumn + to.elementSize;
    id<MTLBuffer> backing = destinationMatrix.data;
    if (!backing || backing.length < span) {
        RevenantMPSRefuse(@"%@: the destination matrix's buffer holds %lu bytes and this copy writes %lu, so"
                        @" nothing was written", what, (unsigned long)(backing ? backing.length : 0),
                        (unsigned long)span);
        return;
    }

    for (NSUInteger image = 0; image < images; image++) {
        RevenantMPSImageLayout one = in;
        one.count = elements;
        MTLRegion region = MTLRegionMake2D(0, 0, in.width, in.height);
        unsigned char *from = calloc(elements * in.elementSize, 1);
        if (!from) {
            RevenantMPSRefuse(@"%@: no memory for a %lux%lux%lu image, so nothing was written", what,
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
                    double value = RevenantMPSImageLoad(from, &one,
                                                      RevenantMPSImageIndex(&one, pixel, channel));
                    NSUInteger element = RevenantMPSImageCopyToMatrixElement(
                        _dataLayout, in.width, in.height, in.channels, y, x, channel);
                    RevenantMPSStore(RevenantMPSMatrixElement(&to, _destinationMatrixBatchIndex, row,
                                                         _destinationMatrixOrigin.y + element),
                                   to.dataType, 0, value);
                }
            }
        }
        free(from);
        RevenantMPSConsumeReadCount(sourceImage);
    }
}

@end
