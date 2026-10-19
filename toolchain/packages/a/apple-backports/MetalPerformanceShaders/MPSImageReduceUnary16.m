#import "RevenantMPSReduce.h"


@implementation MPSImageReduceUnary {
    MTLRegion _clipRectSource;
    BOOL _byColumn;
    RevenantMPSReduceOperation _operation;
}

@synthesize clipRectSource = _clipRectSource;

- (instancetype)revenant_initWithDevice:(id<MTLDevice>)device
                            byColumn:(BOOL)byColumn
                            operation:(RevenantMPSReduceOperation)operation
{
    MPSImageReduceUnary *made = [super initWithDevice:device];
    if (made) {
        made->_clipRectSource = MPSRectNoClip;
        made->_byColumn = byColumn;
        made->_operation = operation;
    }
    return made;
}

- (instancetype)initWithDevice:(id<MTLDevice>)device
{
    RevenantMPSRefuse(@"MPSImageReduceUnary: -initWithDevice: is unavailable on the abstract base - use MPSImageReduceRowMin,"
                    @" MPSImageReduceColumnMin, MPSImageReduceRowMax, MPSImageReduceColumnMax,"
                    @" MPSImageReduceRowMean, MPSImageReduceColumnMean, MPSImageReduceRowSum or"
                    @" MPSImageReduceColumnSum");
    return nil;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder device:(id<MTLDevice>)device
{
    if ((self = [super initWithCoder:aDecoder device:device])) {
        _clipRectSource = MPSRectNoClip;
        _byColumn = NO;
        _operation = RevenantMPSReduceSum;
    }
    return self;
}

- (void)encodeToCommandBuffer:(id<MTLCommandBuffer>)commandBuffer
                   sourceImage:(MPSImage *)sourceImage
             destinationImage:(MPSImage *)destinationImage
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
    if (!destinationImage) {
        RevenantMPSRefuse(@"%@: no destination image, so nothing was written", what);
        return;
    }

    MTLRegion write = RevenantMPSImageResolvedRegion(destinationImage, self.clipRect);
    if (!RevenantMPSImageRegionIsEmpty(self.clipRect)) {
        if (self.clipRect.size.width < 2 || self.clipRect.size.height < 1) {
            RevenantMPSRefuse(@"%@: the destination clip rectangle is %lux%lu and its width must be >=2"
                            @" and its height must be >=1, so nothing was written",
                            what, (unsigned long)self.clipRect.size.width,
                            (unsigned long)self.clipRect.size.height);
            return;
        }
    }

    RevenantMPSImageLayout in = RevenantMPSImageLayoutOf(sourceImage);
    RevenantMPSImageLayout out = RevenantMPSImageLayoutOf(destinationImage);

    NSUInteger winX, winY, winCols, winRows;
    RevenantMPSImageRegionIsEmpty(_clipRectSource)
        ? (winX = 0, winY = 0, winCols = in.width, winRows = in.height)
        : (winX = (NSUInteger)self.clipRectSource.origin.x, winY = (NSUInteger)self.clipRectSource.origin.y,
           winCols = (NSUInteger)self.clipRectSource.size.width,
           winRows = (NSUInteger)self.clipRectSource.size.height);
    if (winX + winCols > in.width) winCols = in.width - (winX < in.width ? winX : in.width);
    if (winY + winRows > in.height) winRows = in.height - (winY < in.height ? winY : in.height);
    NSUInteger span = _byColumn ? winRows : winCols;
    NSUInteger runs = _byColumn ? winCols : winRows;
    if (!winCols || !winRows) {
        RevenantMPSRefuse(@"%@: clipRectSource intersects the %lux%lu source to nothing, so nothing was"
                        @" written", what, (unsigned long)in.width, (unsigned long)in.height);
        return;
    }
    if (_byColumn && winRows < 1) {
        RevenantMPSRefuse(@"%@: a column reduction needs at least one row to reduce", what);
        return;
    }

    if ((_byColumn && out.width < runs) || (!_byColumn && out.height < runs)) {
        RevenantMPSRefuse(@"%@: %s reduction over a %lux%lu window answers %lu values and the destination is"
                        @" %lux%lu, so nothing was written", what, _byColumn ? "a column" : "a row",
                        (unsigned long)winCols, (unsigned long)winRows, (unsigned long)runs,
                        (unsigned long)out.width, (unsigned long)out.height);
        return;
    }

    RevenantMPSImageLayout slice = in;
    slice.count = winCols * winRows * in.channels;
    void *from = RevenantMPSImageReadRegion(sourceImage, &slice,
                                          MTLRegionMake2D(winX, winY, winCols, winRows), what);
    if (slice.count && !from)
        return;

    double *result = calloc(runs, sizeof(double));
    if (!result) {
        RevenantMPSRefuse(@"%@: no memory for %lu reduced values, so nothing was written", what,
                        (unsigned long)runs);
        return;
    }

    for (NSUInteger r = 0; r < runs; r++) {
        double total = 0.0;
        double smallest = 0.0, largest = 0.0;
        for (NSUInteger s = 0; s < span; s++) {
            NSUInteger y = _byColumn ? (winY + s) : (winY + r);
            NSUInteger x = _byColumn ? (winX + r) : (winX + s);
            double value = RevenantMPSImageLoad(from, &slice, RevenantMPSImageIndex(&slice,
                                                                                y * winCols + x, 0));
            if (s == 0 || value < smallest) smallest = value;
            if (s == 0 || value > largest) largest = value;
            total += value;
        }
        switch (_operation) {
            case RevenantMPSReduceMin: result[r] = smallest; break;
            case RevenantMPSReduceMax: result[r] = largest; break;
            case RevenantMPSReduceMean: result[r] = total / (double)span; break;
            case RevenantMPSReduceSum: result[r] = total; break;
        }
    }

    MTLRegion writeRegion = _byColumn
        ? MTLRegionMake2D(write.origin.x, write.origin.y, runs, 1)
        : MTLRegionMake2D(write.origin.x, write.origin.y, 1, runs);
    for (NSUInteger r = 0; r < runs; r++) {
        NSUInteger dx = _byColumn ? (write.origin.x + r) : write.origin.x;
        NSUInteger dy = _byColumn ? write.origin.y : (write.origin.y + r);
        if (dx >= out.width || dy >= out.height) {
            RevenantMPSRefuse(@"%@: value %lu would land at %lux%lu of a %lux%lu destination, so nothing"
                            @" was written", what, (unsigned long)r, (unsigned long)dx,
                            (unsigned long)dy, (unsigned long)out.width, (unsigned long)out.height);
            free(result);
            return;
        }
    }

    RevenantMPSImageLayout staged = out;
    staged.count = (writeRegion.size.width) * (writeRegion.size.height) * out.channels;
    void *bytes = calloc(staged.count ? staged.count : 1, staged.elementSize);
    if (!bytes) {
        RevenantMPSRefuse(@"%@: no memory for a %lux%lu result, so nothing was written", what,
                        (unsigned long)writeRegion.size.width, (unsigned long)writeRegion.size.height);
        free(result);
        return;
    }
    for (NSUInteger r = 0; r < runs; r++) {
        NSUInteger column = _byColumn ? r : 0;
        NSUInteger row = _byColumn ? 0 : r;
        RevenantMPSImageStore((unsigned char *)bytes + (row * writeRegion.size.width + column) *
                                                out.channels * out.elementSize,
                            &staged, 0, result[r]);
    }
    RevenantMPSImageWriteRegion(destinationImage, &staged, writeRegion, bytes, what);
    free(bytes);
    free(result);
    RevenantMPSConsumeReadCount(sourceImage);
}

@end
