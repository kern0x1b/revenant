#import "CharonMPSCnn.h"
#import "CharonMPSReduce.h"


@implementation MPSNNReduceUnary {
    MTLRegion _clipRectSource;
    BOOL _byColumn;
    BOOL _byFeatureChannel;
    CharonMPSReduceOperation _operation;
    float _charonWeight;
}

@synthesize clipRectSource = _clipRectSource;

- (instancetype)charon_nnReduceWithDevice:(id<MTLDevice>)device
                                 byColumn:(BOOL)byColumn
                         byFeatureChannel:(BOOL)byFeatureChannel
                               operation:(CharonMPSReduceOperation)operation
{
    MPSNNReduceUnary *made = [super initWithDevice:device];
    if (made) {
        made->_clipRectSource = MPSRectNoClip;
        made->_byColumn = byColumn;
        made->_byFeatureChannel = byFeatureChannel;
        made->_operation = operation;
        made->_charonWeight = 1.0f;
    }
    return made;
}

- (instancetype)initWithDevice:(id<MTLDevice>)device
{
    CharonMPSRefuse(@"MPSNNReduceUnary: -initWithDevice: is unavailable on the abstract base - use one of the twelve"
                    @" concrete classes");
    return nil;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder device:(id<MTLDevice>)device
{
    if ((self = [super initWithCoder:aDecoder device:device])) {
        _clipRectSource = MPSRectNoClip;
        _byColumn = NO;
        _byFeatureChannel = NO;
        _operation = CharonMPSReduceSum;
        _charonWeight = 1.0f;
    }
    return self;
}

- (float)charon_nnReduceWeight { return _charonWeight; }
- (void)charon_setNnReduceWeight:(float)weight { _charonWeight = weight; }

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

    CharonMPSImageLayout in = CharonMPSImageLayoutOf(sourceImage);
    CharonMPSImageLayout out = CharonMPSImageLayoutOf(destinationImage);

    NSUInteger winX, winY, winCols, winRows;
    CharonMPSImageRegionIsEmpty(_clipRectSource)
        ? (winX = 0, winY = 0, winCols = in.width, winRows = in.height)
        : (winX = (NSUInteger)self.clipRectSource.origin.x, winY = (NSUInteger)self.clipRectSource.origin.y,
           winCols = (NSUInteger)self.clipRectSource.size.width,
           winRows = (NSUInteger)self.clipRectSource.size.height);
    if (winX + winCols > in.width)
        winCols = in.width - (winX < in.width ? winX : in.width);
    if (winY + winRows > in.height)
        winRows = in.height - (winY < in.height ? winY : in.height);
    if (!winCols || !winRows) {
        CharonMPSRefuse(@"%@: clipRectSource intersects the %lux%lu source to nothing, so nothing was"
                        @" written", what, (unsigned long)in.width, (unsigned long)in.height);
        return;
    }

    NSUInteger channels = in.channels ? in.channels : 1;
    NSUInteger span, runs;
    if (_byFeatureChannel) {
        span = channels;
        runs = winCols * winRows;
    } else {
        span = _byColumn ? winRows : winCols;
        runs = (_byColumn ? winCols : winRows) * channels;
        if (!span) {
            CharonMPSRefuse(@"%@: the window is one pixel along the reduction's axis, so there is"
                            @" nothing to reduce and nothing was written", what);
            return;
        }
    }

    NSUInteger needCols, needRows, needChannels;
    if (_byFeatureChannel) {
        needCols = winCols;
        needRows = winRows;
        needChannels = 1;
    } else if (_byColumn) {
        needCols = winCols;
        needRows = 1;
        needChannels = channels;
    } else {
        needCols = 1;
        needRows = winRows;
        needChannels = channels;
    }
    if (out.width < needCols || out.height < needRows || out.channels < needChannels) {
        CharonMPSRefuse(@"%@: a %@ reduction over a %lux%lu window of %lu channels answers %lu values"
                        @" and needs a %lux%lux%lu destination, and this one is %lux%lux%lu, so nothing"
                        @" was written",
                        what, _byFeatureChannel ? @"feature channel" : (_byColumn ? @"column" : @"row"),
                        (unsigned long)winCols, (unsigned long)winRows, (unsigned long)channels,
                        (unsigned long)runs, (unsigned long)needCols, (unsigned long)needRows,
                        (unsigned long)needChannels, (unsigned long)out.width,
                        (unsigned long)out.height, (unsigned long)out.channels);
        return;
    }

    CharonMPSImageLayout slice = in;
    slice.count = winCols * winRows * in.channels;
    void *from = CharonMPSImageReadRegion(sourceImage, &slice,
                                          MTLRegionMake2D(winX, winY, winCols, winRows), what);
    if (slice.count && !from)
        return;

    double *result = calloc(runs ? runs : 1, sizeof(double));
    if (!result) {
        CharonMPSRefuse(@"%@: no memory for %lu reduced values, so nothing was written", what,
                        (unsigned long)runs);
        free(from);
        return;
    }

    for (NSUInteger r = 0; r < runs; r++) {
        double total = 0.0;
        double smallest = 0.0, largest = 0.0;
        NSUInteger pixel, step, channel;
        if (_byFeatureChannel) {
            pixel = r;
            step = 0;
            channel = 0;
        } else {
            NSUInteger along = _byColumn ? winCols : winRows;
            NSUInteger spatial = r % along;
            channel = r / along;
            pixel = _byColumn ? spatial : spatial * winCols;
            step = _byColumn ? winCols : 1;
        }
        for (NSUInteger s = 0; s < span; s++) {
            NSUInteger at = pixel + s * step;
            NSUInteger which = _byFeatureChannel ? s : channel;
            if (at >= winCols * winRows || which >= channels)
                continue;
            double value = CharonMPSImageLoad(from, &slice, CharonMPSImageIndex(&slice, at, which));
            if (_byFeatureChannel && (_operation == CharonMPSReduceSum || _operation == CharonMPSReduceMean))
                value *= (double)_charonWeight;
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
    free(from);

    MTLRegion writeRegion = _byFeatureChannel
        ? MTLRegionMake2D(0, 0, winCols, winRows)
        : (_byColumn ? MTLRegionMake2D(0, 0, winCols, 1) : MTLRegionMake2D(0, 0, 1, winRows));
    CharonMPSImageLayout staged = out;
    staged.channels = needChannels;
    staged.count = writeRegion.size.width * writeRegion.size.height * staged.channels;
    void *bytes = calloc(staged.count ? staged.count : 1, staged.elementSize);
    if (!bytes) {
        CharonMPSRefuse(@"%@: no memory for a %lux%lux%lu result, so nothing was written", what,
                        (unsigned long)writeRegion.size.width, (unsigned long)writeRegion.size.height,
                        (unsigned long)staged.channels);
        free(result);
        return;
    }
    for (NSUInteger r = 0; r < runs; r++) {
        NSUInteger x, y, c;
        if (_byFeatureChannel) {
            x = r % winCols;
            y = r / winCols;
            c = 0;
        } else {
            NSUInteger along = _byColumn ? winCols : winRows;
            NSUInteger spatial = r % along;
            c = r / along;
            x = _byColumn ? spatial : 0;
            y = _byColumn ? 0 : spatial;
        }
        CharonMPSImageStore(bytes, &staged, CharonMPSImageIndex(&staged, y * writeRegion.size.width + x, c),
                            result[r]);
    }
    CharonMPSImageWriteRegion(destinationImage, &staged, writeRegion, bytes, what);
    free(bytes);
    free(result);
    CharonMPSConsumeReadCount(sourceImage);
}

@end
