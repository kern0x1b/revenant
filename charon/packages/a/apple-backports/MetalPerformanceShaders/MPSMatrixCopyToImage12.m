// MPSMatrixCopyToImage, from MPSMatrixToImage.h of the iPhoneOS 26.2 surface. One object for one
// release: `xmake l tools/cache-index/first-rung.lua` answers 12.0 for MPSMatrixCopyToImage and for
// every other name in this file, so this file carries 12.0 API only.
//
// WHAT IT IS. The copy between a matrix and an image, one direction of the two MPSMatrixToImage.h
// declares. A matrix is a rows x columns array with its own strides and its own batch count; an image
// is a width x height x featureChannels rectangle. The two shapes never agree on their own - a matrix
// of one row and eight columns is an eight-channel image of width one, not an image of width eight -
// so the mapping is a choice and the header makes it explicit, through four properties:
//
//   dataLayout            MPSDataLayoutHeightxWidthxFeatureChannels or ...xChannelsxHeightxWidth.
//                         The first says the matrix's OWN row and column count ARE an image's height
//                         and width, and its columns are the feature channels: the matrix must then be
//                         rows == height, columns == featureChannels, and every row is one row of the
//                         image. The second says the transpose of that: rows == featureChannels,
//                         columns == width.
//   sourceMatrixOrigin    the row and column the copy starts from, in the matrix's own coordinates.
//   sourceMatrixBatchIndex which matrix of a batched matrix this copies from.
//
// So the copy has no arithmetic at all: it moves elements, and what decides where an element lands is
// the layout, which is why both directions of the layout are one switch in one place below rather
// than two walks.

#import "CharonMPS.h"
#import "CharonMPSImage.h"


@implementation MPSMatrixCopyToImage {
    MPSDataLayout _dataLayout;
    MTLOrigin _sourceMatrixOrigin;
    NSUInteger _sourceMatrixBatchIndex;
    id<MTLDevice> _device;
}

// Which axis of the destination a matrix row and column run along, read off the layout. The two
// layouts are the header's own enumeration and nothing else: HeightxWidthxFeatureChannels puts a
// matrix's column on a feature channel, and ChannelsxHeightxWidth puts a matrix's ROW on one.
static inline BOOL CharonMPSMatrixToImageIsRowMajor(MPSDataLayout layout)
{
    return layout == MPSDataLayoutHeightxWidthxFeatureChannels;
}

- (instancetype)initWithDevice:(id<MTLDevice>)device dataLayout:(MPSDataLayout)dataLayout
{
    if ((self = [super initWithDevice:device])) {
        _dataLayout = dataLayout;
        // The header's own defaults, MPSImageCopy.h: the origin, measured from the zero corner of the source
        // matrix, starts at [0, 0] when the kernel is created, and the batch slot read from the source starts at zero.
        _sourceMatrixOrigin = MTLOriginMake(0, 0, 0);
        _sourceMatrixBatchIndex = 0;
        _device = device;
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder device:(id<MTLDevice>)device
{
    // The layout is the one thing this kernel cannot invent, so a coder that carries none has no
    // answer and no object: guessing a layout would produce an image of the right values in the
    // wrong order, which is the failure this kernel is easiest to get wrong in.
    NSNumber *layout = [aDecoder decodeObjectForKey:@"dataLayout"];
    if (!layout) {
        CharonMPSRefuse(@"MPSMatrixCopyToImage: the coder carries no dataLayout, and the layout is what says "
                        @"where a matrix element lands in the image, so no kernel was made");
        return nil;
    }
    if ((self = [super initWithDevice:device])) {
        _dataLayout = (MPSDataLayout)[layout unsignedIntValue];
        _sourceMatrixOrigin = MTLOriginMake(0, 0, 0);
        _sourceMatrixBatchIndex = 0;
        _device = device;
    }
    return self;
}

- (MPSDataLayout)dataLayout { return _dataLayout; }
- (MTLOrigin)sourceMatrixOrigin { return _sourceMatrixOrigin; }
- (void)setSourceMatrixOrigin:(MTLOrigin)origin { _sourceMatrixOrigin = origin; }
- (NSUInteger)sourceMatrixBatchIndex { return _sourceMatrixBatchIndex; }
- (void)setSourceMatrixBatchIndex:(NSUInteger)index { _sourceMatrixBatchIndex = index; }

- (void)encodeToCommandBuffer:(id<MTLCommandBuffer>)commandBuffer
                 sourceMatrix:(MPSMatrix *)sourceMatrix
             destinationImage:(MPSImage *)destinationImage
{
    NSString *what = NSStringFromClass([self class]);
    if (!commandBuffer) {
        CharonMPSRefuse(@"%@: no command buffer, so nothing was written", what);
        return;
    }
    if (!CharonMPSImageUsable(destinationImage, what))
        return;
    if (!sourceMatrix) {
        CharonMPSRefuse(@"%@: no source matrix, so nothing was written", what);
        return;
    }

    CharonMPSMatrixView matrix = CharonMPSMatrixViewOf(sourceMatrix);
    if (!matrix.elementSize) {
        CharonMPSRefuse(@"%@: the matrix's data type names no element size, so nothing was written", what);
        return;
    }

    // The layout decides which of the matrix's axes is the image's channels. Which axis that is also
    // decides how many matrix rows and columns the destination's shape asks for, and a destination
    // that does not match is refused: this kernel copies a whole matrix into an image, and there is
    // no partial copy in the header.
    BOOL rowMajor = CharonMPSMatrixToImageIsRowMajor(_dataLayout);
    NSUInteger matrixRows = rowMajor ? destinationImage.height : destinationImage.featureChannels;
    NSUInteger matrixColumns = rowMajor ? destinationImage.featureChannels : destinationImage.width;

    // The origin is an MTLOrigin, so its components are doubles and are the matrix's own row and
    // column. A non-integral origin names a position between two rows, which a copy cannot start at,
    // so it is refused rather than silently floored: the caller asked for a half row.
    double originRowValue = _sourceMatrixOrigin.x;
    double originColumnValue = _sourceMatrixOrigin.y;
    if (originRowValue != floor(originRowValue) || originColumnValue != floor(originColumnValue)) {
        CharonMPSRefuse(@"%@: the source origin is (%g, %g) and a copy starts at a whole row and column, "
                        @"so nothing was written", what, originRowValue, originColumnValue);
        return;
    }
    NSInteger originRow = (NSInteger)originRowValue;
    NSInteger originColumn = (NSInteger)originColumnValue;
    if (originRow < 0 || originColumn < 0 ||
        !CharonMPSMatrixHolds(&matrix, _sourceMatrixBatchIndex, (NSUInteger)originRow, (NSUInteger)originColumn,
                              matrixRows, matrixColumns)) {
        CharonMPSRefuse(@"%@: a %lux%lu copy from (%ld, %ld) of matrix %lu of %lux%lux%lu falls outside it, "
                        @"so nothing was written", what,
                        (unsigned long)matrixRows, (unsigned long)matrixColumns,
                        (long)originRow, (long)originColumn,
                        (unsigned long)_sourceMatrixBatchIndex,
                        (unsigned long)matrix.matrices, (unsigned long)matrix.rows, (unsigned long)matrix.columns);
        return;
    }

    CharonMPSImageLayout out = CharonMPSImageLayoutOf(destinationImage);
    out.count = destinationImage.width * destinationImage.height * out.channels;
    size_t bytes = (size_t)destinationImage.width * out.channels * destinationImage.height * out.elementSize;
    unsigned char *to = calloc(bytes ? bytes : 1, 1);
    if (!to) {
        CharonMPSRefuse(@"%@: no memory for a %lux%lu image, so nothing was written", what,
                        (unsigned long)destinationImage.width, (unsigned long)destinationImage.height);
        return;
    }

    // One walk over the DESTINATION, because the destination's shape is what fixes the matrix's: for
    // each channel, for each row, for each column of the image, the element is at the matrix's own
    // row and column for this layout, and is loaded and stored through the two helpers the rest of
    // this package uses so a Float16 image and a Float32 matrix meet in one place.
    for (NSUInteger channel = 0; channel < destinationImage.featureChannels; channel++) {
        for (NSUInteger row = 0; row < destinationImage.height; row++) {
            for (NSUInteger column = 0; column < destinationImage.width; column++) {
                NSUInteger matrixRow = (NSUInteger)originRow + (rowMajor ? row : channel);
                NSUInteger matrixColumn = (NSUInteger)originColumn + (rowMajor ? channel : column);
                const void *element = CharonMPSMatrixElement(&matrix, _sourceMatrixBatchIndex, matrixRow, matrixColumn);
                double value = CharonMPSLoad(element, matrix.dataType, 0);
                NSUInteger pixel = row * destinationImage.width + column;
                NSUInteger into = CharonMPSImageIndex(&out, pixel, channel);
                if (into != (NSUInteger)-1)
                    CharonMPSImageStore(to, &out, into, value);
            }
        }
    }
    (void)CharonMPSImageWriteRegion(destinationImage, &out,
                                    MTLRegionMake2D(0, 0, destinationImage.width, destinationImage.height),
                                    to, what);
    free(to);
}

- (void)encodeBatchToCommandBuffer:(id<MTLCommandBuffer>)commandBuffer
                       sourceMatrix:(MPSMatrix *)sourceMatrix
                 destinationImages:(NSArray<MPSImage *> *)destinationImages
{
    NSString *what = NSStringFromClass([self class]);
    if (!commandBuffer) {
        CharonMPSRefuse(@"%@: no command buffer, so nothing was written", what);
        return;
    }
    // One matrix per image, in the order the array gives them: the header's batch form runs the same
    // copy once per destination, and MPSMatrix's own batch axis is the one sourceMatrixBatchIndex
    // names for a single copy. An image short of the matrix's batch count is left as it was and said
    // so, rather than the count being padded or truncated to what the array happens to hold.
    NSUInteger count = destinationImages.count;
    if (count > 1 && sourceMatrix) {
        CharonMPSMatrixView matrix = CharonMPSMatrixViewOf(sourceMatrix);
        if (count > matrix.matrices) {
            CharonMPSRefuse(@"%@: %lu image(s) were given and the matrix holds %lu, so only the first %lu "
                            @"were written", what, (unsigned long)count, (unsigned long)matrix.matrices,
                            (unsigned long)matrix.matrices);
            count = matrix.matrices;
        }
    }
    for (NSUInteger index = 0; index < count; index++) {
        self.sourceMatrixBatchIndex = index;
        [self encodeToCommandBuffer:commandBuffer sourceMatrix:sourceMatrix destinationImage:destinationImages[index]];
    }
    self.sourceMatrixBatchIndex = 0;
}

@end