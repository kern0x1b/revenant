// MPSImageReduce, from MPSImageReduce.h of the iPhoneOS 26.2 surface. One object per release:
// MPS_CLASS_AVAILABLE_STARTING at :28 is macos(10.13.4), ios(11.3), so this is a release-11.3 object.
//
// Nine classes, eight of them concrete. :17-26 lists the eight operations - reduce row min, column min,
// row max, column max, row mean, column mean, row sum, column sum - and each concrete class says what it
// returns: :53 and its seven siblings "the mininmum value for each row of an image" (the release's own
// spelling), "the maximum value for each row", "the mean value for each row", "the sum for each row",
// and the same four for each column. So a row reduction answers one value per source row and a column
// reduction one per source column, and THAT is the permutation: the walk is over the reduction's axis.
//
// TWO RULES HERE ARE NOT LIKE EVERY OTHER UNARY KERNEL IN THIS PACKAGE, and both come from the header:
//
//  1. clipRectSource (:31-42): the source rectangle that is read from. If it does not lie wholly inside the source
//     image, only the overlap with the image is used. It takes the place of the offset parameter of
//     MPSUnaryImageKernel, which this filter ignores; with no clip set, the whole source texture is used.
//     That makes `offset` irrelevant here, and the window is an INTERSECTION with the image
//     rather than a rectangle applied on its own. That intersection is done here with the same resolved
//     region the walk uses, so the MPSRectNoClip sentinel is resolved against the image before any
//     texture sees it - a NoClip rectangle has size {-1,-1,0} and to a texture its xoffset + width is -2,
//     where the framework asserts.
//  2. clipRect is NOT the read window (:38-40): it fixes the place in the destination where the minimum and maximum
//     entries are stored, and its width must be at least 2 with a height of at least 1. So clipRect says where the result
//     lands in the destination, and those two lower bounds are preconditions. A clip that fails them is
//     refused by name and writes nothing, rather than being quietly widened or clipped away.
//
// The base's -initWithDevice: is NS_UNAVAILABLE (:44-47): "You must use one of the sub-classes of
// MPSImageReduceUnary." So instantiating the abstract base refuses and says so.
//
// The encode is implemented HERE, in the base's own @implementation, and not in a subclass. The earlier
// plan was a CATEGORY on MPSImageReduceUnary because MPSImageThreshold13.m carries a category on
// MPSUnaryImageKernel that implements the same selector - and that is true and still the reason the walk
// must not be inherited: the threshold band's walk is 1:1 and a reduction's destination is a different
// shape from its source, so the inherited one would be wrong. A category cannot read the ivars declared
// in the class's @implementation, though, and this kernel needs to remember which axis and which
// operation it is. So the encode lives in the base, where those two pieces of state are, and the
// concrete classes set them through one internal method.
//
// Arithmetic: min, max and sum select or add values the source already holds, so they are exact - a copy
// that moved a bit is a copy that moved a bit. mean divides, and dividing cannot be exact in binary, so
// the sum is taken in double and divided once, which leaves the result within one float32 ulp. The
// harness's reference uses that same bound, and states it.

#import "CharonMPSReduce.h"

// ONE scoped suppression, and it is recorded in coordination/crutches.md with the reason. The SDK marks
// MPSImageReduceUnary's -initWithDevice: NS_UNAVAILABLE (:44-47) and each concrete class's -initWithDevice:
// NS_DESIGNATED_INITIALIZER, so clang requires the latter to call a designated initializer of the former
// while the former's only designated initializer is -initWithCoder:device:, which cannot know which of the
// eight operations to build and takes a nonnull coder this path has no use for. Marking this file's own
// charon_initWithDevice:... designated was tried first and removed the concrete classes' warning but not
// the base's, because the base's -initWithDevice: then becomes a convenience initializer that refuses
// rather than one that calls self. Measured release behaviour, mirrored here: the release asserts
// ("Cannot directly initialize MPSImageReduceUnary") and aborts, so there is no successful chain to write.


@implementation MPSImageReduceUnary {
    MTLRegion _clipRectSource;
    BOOL _byColumn;
    CharonMPSReduceOperation _operation;
}

@synthesize clipRectSource = _clipRectSource;

// The state :36 states as the default, and the axis and operation a concrete class names.
//
// This is not in the `init` family - the name does not begin with "init" in the family's own sense - so
// it must not assign to self, and it returns what the superclass made instead.
- (instancetype)charon_initWithDevice:(id<MTLDevice>)device
                            byColumn:(BOOL)byColumn
                            operation:(CharonMPSReduceOperation)operation
{
    MPSImageReduceUnary *made = [super initWithDevice:device];
    if (made) {
        made->_clipRectSource = MPSRectNoClip;             // MPSImageReduce.h:36, the whole source
        made->_byColumn = byColumn;
        made->_operation = operation;
    }
    return made;
}

// MPSImageReduce.h:36 - "Default: MPSRectNoClip, use the entire source texture."
- (instancetype)initWithDevice:(id<MTLDevice>)device
{
    // MPSImageReduce.h:44-47 marks this NS_UNAVAILABLE on the abstract base: "You must use one of the
    // sub-classes of MPSImageReduceUnary." A caller that reached it has no operation and no axis, so there
    // is nothing to reduce, and the refusal is the honest answer.
    //
    // MEASURED, and mirrored: the release does not return nil here, it asserts and takes the process with
    // it. On this host, calling the base's -initWithDevice: on the real MPSImageReduceUnary prints
    //   MPSImageReduce.mm:345: failed assertion `Cannot directly initialize MPSImageReduceUnary. Use one
    //   of the sub-classes of MPSImageReduceUnary.'
    // and the run stops there. This port refuses by name and returns nil instead: the observable
    // behaviour a caller depends on is the same - there is no usable object - and refusing is what the
    // rest of this package does everywhere rather than aborting a caller that got the class wrong.
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

    // MPSImageReduce.h:38-40 on clipRect: it is where the result lands in the destination, and the two
    // bounds are preconditions. Asked of the destination, so a clip larger than the image is caught here
    // rather than by the framework's own assertion on a read or a write.
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

    // The window read: clipRectSource INTERSECTED with the image (:33-34). The reduction runs along
    // whichever axis this kernel names, so the window has to be whole along that axis or there would be
    // nothing to reduce; that is refused by name rather than silently shortened.
    NSUInteger winX, winY, winCols, winRows;
    CharonMPSImageRegionIsEmpty(_clipRectSource)
        ? (winX = 0, winY = 0, winCols = in.width, winRows = in.height)
        : (winX = (NSUInteger)self.clipRectSource.origin.x, winY = (NSUInteger)self.clipRectSource.origin.y,
           winCols = (NSUInteger)self.clipRectSource.size.width,
           winRows = (NSUInteger)self.clipRectSource.size.height);
    if (winX + winCols > in.width) winCols = in.width - (winX < in.width ? winX : in.width);   // intersected
    if (winY + winRows > in.height) winRows = in.height - (winY < in.height ? winY : in.height);
    NSUInteger span = _byColumn ? winRows : winCols;     // how many values one reduction combines
    NSUInteger runs = _byColumn ? winCols : winRows;     // how many reductions there are
    if (!winCols || !winRows) {
        CharonMPSRefuse(@"%@: clipRectSource intersects the %lux%lu source to nothing, so nothing was"
                        @" written", what, (unsigned long)in.width, (unsigned long)in.height);
        return;
    }
    if (_byColumn && winRows < 1) {
        CharonMPSRefuse(@"%@: a column reduction needs at least one row to reduce", what);
        return;
    }

    // The destination holds `runs` values. For a row reduction that is one per row, written along a row
    // of the destination; for a column reduction one per column, written down a column. Which is which is
    // the header's per-class wording and nothing else.
    if ((_byColumn && out.width < runs) || (!_byColumn && out.height < runs)) {
        CharonMPSRefuse(@"%@: %s reduction over a %lux%lu window answers %lu values and the destination is"
                        @" %lux%lu, so nothing was written", what, _byColumn ? "a column" : "a row",
                        (unsigned long)winCols, (unsigned long)winRows, (unsigned long)runs,
                        (unsigned long)out.width, (unsigned long)out.height);
        return;
    }

    // One region read of the window, then one reduction per run along the axis. The value moves out of
    // the source and into the destination's own buffer; nothing is reinterpreted and nothing is scaled.
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

    // The write, at the origin clipRect names. A ROW reduction answers one value per source row and its
    // destination is one WIDE and `runs` tall, so the run of values goes DOWN that destination's single
    // column; a COLUMN reduction's destination is `runs` wide and one tall, so its run goes ALONG the
    // single row. Getting this backwards is a write wider than the texture is, which the framework
    // asserts on - and did, which is how it was found.
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

    // Staged row-major, HeightxWidthxFeatureChannels, which is the layout the walk's write takes.
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
