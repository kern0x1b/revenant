#import "CharonMPSReduce.h"


@implementation MPSImageReduceUnary {
    MTLRegion _clipRectSource;
    BOOL _byColumn;
    CharonMPSReduceOperation _operation;
}

@synthesize clipRectSource = _clipRectSource;

- (instancetype)charon_initWithDevice:(id<MTLDevice>)device
                            byColumn:(BOOL)byColumn
                            operation:(CharonMPSReduceOperation)operation
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
    CharonMPSRefuse(@"MPSImageReduceUnary: -initWithDevice: is unavailable on the abstract base - use MPSImageReduceRowMin,"
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
        _operation = CharonMPSReduceSum;
    }
    return self;
}

- (void)encodeToCommandBuffer:(id<MTLCommandBuffer>)commandBuffer
                   sourceImage:(MPSImage *)sourceImage
             destinationImage:(MPSImage *)destinationImage
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
    if (!destinationImage) {
        CharonMPSRefuse(@"%@: no destination image, so nothing was written", what);
        return;
    }

    MTLRegion write = CharonMPSImageResolvedRegion(destinationImage, self.clipRect);
    if (!CharonMPSImageRegionIsEmpty(self.clipRect)) {
        if (self.clipRect.size.width < 2 || self.clipRect.size.height < 1) {
            CharonMPSRefuse(@"%@: the destination clip rectangle is %lux%lu and its width must be >=2"
                            @" and its height must be >=1, so nothing was written",
                            what, (unsigned long)self.clipRect.size.width,
                            (unsigned long)self.clipRect.size.height);
            return;
        }
    }

    CharonMPSImageLayout in = CharonMPSImageLayoutOf(sourceImage);
    CharonMPSImageLayout out = CharonMPSImageLayoutOf(destinationImage);

    NSUInteger winX, winY, winCols, winRows;
    CharonMPSImageRegionIsEmpty(_clipRectSource)
        ? (winX = 0, winY = 0, winCols = in.width, winRows = in.height)
        : (winX = (NSUInteger)self.clipRectSource.origin.x, winY = (NSUInteger)self.clipRectSource.origin.y,
           winCols = (NSUInteger)self.clipRectSource.size.width,
           winRows = (NSUInteger)self.clipRectSource.size.height);
    if (winX + winCols > in.width) winCols = in.width - (winX < in.width ? winX : in.width);
    if (winY + winRows > in.height) winRows = in.height - (winY < in.height ? winY : in.height);
    NSUInteger span = _byColumn ? winRows : winCols;
    NSUInteger runs = _byColumn ? winCols : winRows;
    if (!winCols || !winRows) {
        CharonMPSRefuse(@"%@: clipRectSource intersects the %lux%lu source to nothing, so nothing was"
                        @" written", what, (unsigned long)in.width, (unsigned long)in.height);
        return;
    }
    if (_byColumn && winRows < 1) {
        CharonMPSRefuse(@"%@: a column reduction needs at least one row to reduce", what);
        return;
    }

    if ((_byColumn && out.width < runs) || (!_byColumn && out.height < runs)) {
        CharonMPSRefuse(@"%@: %s reduction over a %lux%lu window answers %lu values and the destination is"
                        @" %lux%lu, so nothing was written", what, _byColumn ? "a column" : "a row",
                        (unsigned long)winCols, (unsigned long)winRows, (unsigned long)runs,
                        (unsigned long)out.width, (unsigned long)out.height);
        return;
    }

    CharonMPSImageLayout slice = in;
    slice.count = winCols * winRows * in.channels;
    void *from = CharonMPSImageReadRegion(sourceImage, &slice,
                                          MTLRegionMake2D(winX, winY, winCols, winRows), what);
    if (slice.count && !from)
        return;

    double *result = calloc(runs, sizeof(double));
    if (!result) {
        CharonMPSRefuse(@"%@: no memory for %lu reduced values, so nothing was written", what,
                        (unsigned long)runs);
        return;
    }

    for (NSUInteger r = 0; r < runs; r++) {
        double total = 0.0;
        double smallest = 0.0, largest = 0.0;
        for (NSUInteger s = 0; s < span; s++) {
            NSUInteger y = _byColumn ? (winY + s) : (winY + r);
            NSUInteger x = _byColumn ? (winX + r) : (winX + s);
            double value = CharonMPSImageLoad(from, &slice, CharonMPSImageIndex(&slice,
                                                                                y * winCols + x, 0));
            if (s == 0 || value < smallest) smallest = value;
            if (s == 0 || value > largest) largest = value;
            total += value;
        }
        switch (_operation) {
            case CharonMPSReduceMin: result[r] = smallest; break;
            case CharonMPSReduceMax: result[r] = largest; break;
            case CharonMPSReduceMean: result[r] = total / (double)span; break;
            case CharonMPSReduceSum: result[r] = total; break;
        }
    }

    MTLRegion writeRegion = _byColumn
        ? MTLRegionMake2D(write.origin.x, write.origin.y, runs, 1)
        : MTLRegionMake2D(write.origin.x, write.origin.y, 1, runs);
    for (NSUInteger r = 0; r < runs; r++) {
        NSUInteger dx = _byColumn ? (write.origin.x + r) : write.origin.x;
        NSUInteger dy = _byColumn ? write.origin.y : (write.origin.y + r);
        if (dx >= out.width || dy >= out.height) {
            CharonMPSRefuse(@"%@: value %lu would land at %lux%lu of a %lux%lu destination, so nothing"
                            @" was written", what, (unsigned long)r, (unsigned long)dx,
                            (unsigned long)dy, (unsigned long)out.width, (unsigned long)out.height);
            free(result);
            return;
        }
    }

    CharonMPSImageLayout staged = out;
    staged.count = (writeRegion.size.width) * (writeRegion.size.height) * out.channels;
    void *bytes = calloc(staged.count ? staged.count : 1, staged.elementSize);
    if (!bytes) {
        CharonMPSRefuse(@"%@: no memory for a %lux%lu result, so nothing was written", what,
                        (unsigned long)writeRegion.size.width, (unsigned long)writeRegion.size.height);
        free(result);
        return;
    }
    for (NSUInteger r = 0; r < runs; r++) {
        NSUInteger column = _byColumn ? r : 0;
        NSUInteger row = _byColumn ? 0 : r;
        CharonMPSImageStore((unsigned char *)bytes + (row * writeRegion.size.width + column) *
                                                out.channels * out.elementSize,
                            &staged, 0, result[r]);
    }
    CharonMPSImageWriteRegion(destinationImage, &staged, writeRegion, bytes, what);
    free(bytes);
    free(result);
    CharonMPSConsumeReadCount(sourceImage);
}

@end
