#import "RevenantMPS.h"
#import "RevenantMPSImage.h"


@implementation MPSMatrixCopyToImage {
    MPSDataLayout _dataLayout;
    MTLOrigin _sourceMatrixOrigin;
    NSUInteger _sourceMatrixBatchIndex;
    id<MTLDevice> _device;
}

static inline BOOL RevenantMPSMatrixToImageIsRowMajor(MPSDataLayout layout)
{
    return layout == MPSDataLayoutHeightxWidthxFeatureChannels;
}

- (instancetype)initWithDevice:(id<MTLDevice>)device dataLayout:(MPSDataLayout)dataLayout
{
    if ((self = [super initWithDevice:device])) {
        _dataLayout = dataLayout;
        _sourceMatrixOrigin = MTLOriginMake(0, 0, 0);
        _sourceMatrixBatchIndex = 0;
        _device = device;
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder device:(id<MTLDevice>)device
{
    NSNumber *layout = [aDecoder decodeObjectForKey:@"dataLayout"];
    if (!layout) {
        RevenantMPSRefuse(@"MPSMatrixCopyToImage: the coder carries no dataLayout, and the layout is what says "
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
        RevenantMPSRefuse(@"%@: no command buffer, so nothing was written", what);
        return;
    }
    if (!RevenantMPSImageUsable(destinationImage, what))
        return;
    if (!sourceMatrix) {
        RevenantMPSRefuse(@"%@: no source matrix, so nothing was written", what);
        return;
    }

    RevenantMPSMatrixView matrix = RevenantMPSMatrixViewOf(sourceMatrix);
    if (!matrix.elementSize) {
        RevenantMPSRefuse(@"%@: the matrix's data type names no element size, so nothing was written", what);
        return;
    }

    BOOL rowMajor = RevenantMPSMatrixToImageIsRowMajor(_dataLayout);
    NSUInteger matrixRows = rowMajor ? destinationImage.height : destinationImage.featureChannels;
    NSUInteger matrixColumns = rowMajor ? destinationImage.featureChannels : destinationImage.width;

    double originRowValue = _sourceMatrixOrigin.x;
    double originColumnValue = _sourceMatrixOrigin.y;
    if (originRowValue != floor(originRowValue) || originColumnValue != floor(originColumnValue)) {
        RevenantMPSRefuse(@"%@: the source origin is (%g, %g) and a copy starts at a whole row and column, "
                        @"so nothing was written", what, originRowValue, originColumnValue);
        return;
    }
    NSInteger originRow = (NSInteger)originRowValue;
    NSInteger originColumn = (NSInteger)originColumnValue;
    if (originRow < 0 || originColumn < 0 ||
        !RevenantMPSMatrixHolds(&matrix, _sourceMatrixBatchIndex, (NSUInteger)originRow, (NSUInteger)originColumn,
                              matrixRows, matrixColumns)) {
        RevenantMPSRefuse(@"%@: a %lux%lu copy from (%ld, %ld) of matrix %lu of %lux%lux%lu falls outside it, "
                        @"so nothing was written", what,
                        (unsigned long)matrixRows, (unsigned long)matrixColumns,
                        (long)originRow, (long)originColumn,
                        (unsigned long)_sourceMatrixBatchIndex,
                        (unsigned long)matrix.matrices, (unsigned long)matrix.rows, (unsigned long)matrix.columns);
        return;
    }

    RevenantMPSImageLayout out = RevenantMPSImageLayoutOf(destinationImage);
    out.count = destinationImage.width * destinationImage.height * out.channels;
    size_t bytes = (size_t)destinationImage.width * out.channels * destinationImage.height * out.elementSize;
    unsigned char *to = calloc(bytes ? bytes : 1, 1);
    if (!to) {
        RevenantMPSRefuse(@"%@: no memory for a %lux%lu image, so nothing was written", what,
                        (unsigned long)destinationImage.width, (unsigned long)destinationImage.height);
        return;
    }

    for (NSUInteger channel = 0; channel < destinationImage.featureChannels; channel++) {
        for (NSUInteger row = 0; row < destinationImage.height; row++) {
            for (NSUInteger column = 0; column < destinationImage.width; column++) {
                NSUInteger matrixRow = (NSUInteger)originRow + (rowMajor ? row : channel);
                NSUInteger matrixColumn = (NSUInteger)originColumn + (rowMajor ? channel : column);
                const void *element = RevenantMPSMatrixElement(&matrix, _sourceMatrixBatchIndex, matrixRow, matrixColumn);
                double value = RevenantMPSLoad(element, matrix.dataType, 0);
                NSUInteger pixel = row * destinationImage.width + column;
                NSUInteger into = RevenantMPSImageIndex(&out, pixel, channel);
                if (into != (NSUInteger)-1)
                    RevenantMPSImageStore(to, &out, into, value);
            }
        }
    }
    (void)RevenantMPSImageWriteRegion(destinationImage, &out,
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
        RevenantMPSRefuse(@"%@: no command buffer, so nothing was written", what);
        return;
    }
    NSUInteger count = destinationImages.count;
    if (count > 1 && sourceMatrix) {
        RevenantMPSMatrixView matrix = RevenantMPSMatrixViewOf(sourceMatrix);
        if (count > matrix.matrices) {
            RevenantMPSRefuse(@"%@: %lu image(s) were given and the matrix holds %lu, so only the first %lu "
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
