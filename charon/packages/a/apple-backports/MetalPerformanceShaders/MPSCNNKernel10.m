// MPSCNNKernel, from the header of MPSCNNKernel.h in the SDK of iOS 16.4: what every convolutional
// kernel carries, whether it convolves, pools or normalises - the edge mode, the offsets into the
// feature channels, the clip rectangle, and the window it walks.

#import "CharonMPSCnn.h"

#pragma clang diagnostic ignored "-Wprotocol"
#pragma clang diagnostic ignored "-Wincomplete-implementation"

@implementation MPSCNNKernel {
    MPSOffset _offset;
    MTLRegion _clipRect;
    NSUInteger _destinationFeatureChannelOffset, _sourceFeatureChannelOffset, _sourceFeatureChannelMaxCount;
    MPSImageEdgeMode _edgeMode;
    NSUInteger _kernelWidth, _kernelHeight, _strideInPixelsX, _strideInPixelsY, _dilationRateX, _dilationRateY;
    BOOL _isBackwards;
    id<MPSNNPadding> _padding;
    id<MPSImageAllocator> _destinationImageAllocator;
}

- (instancetype)initWithDevice:(id<MTLDevice>)device
{
    if ((self = [super initWithDevice:device])) {
        // The window a kernel walks is one pixel wide and one pixel high unless its own initialiser
        // says otherwise, and the edges clamp, which is what the header's defaults are.
        _kernelWidth = 1;
        _kernelHeight = 1;
        _strideInPixelsX = 1;
        _strideInPixelsY = 1;
        _dilationRateX = 1;
        _dilationRateY = 1;
        _edgeMode = MPSImageEdgeModeClamp;
        _clipRect = MTLRegionMake3D(0, 0, 0, 0, 0, 0);
        _sourceFeatureChannelMaxCount = 0;
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder device:(id<MTLDevice>)device
{
    if ((self = [super initWithCoder:aDecoder device:device])) {
        _kernelWidth = 1;
        _kernelHeight = 1;
        _strideInPixelsX = 1;
        _strideInPixelsY = 1;
        _dilationRateX = 1;
        _dilationRateY = 1;
        _edgeMode = MPSImageEdgeModeClamp;
    }
    return self;
}

- (MPSOffset)offset { return _offset; }
- (void)setOffset:(MPSOffset)value { _offset = value; }

- (MTLRegion)clipRect { return _clipRect; }
- (void)setClipRect:(MTLRegion)value { _clipRect = value; }

- (NSUInteger)destinationFeatureChannelOffset { return _destinationFeatureChannelOffset; }
- (void)setDestinationFeatureChannelOffset:(NSUInteger)value { _destinationFeatureChannelOffset = value; }

- (NSUInteger)sourceFeatureChannelOffset { return _sourceFeatureChannelOffset; }
- (void)setSourceFeatureChannelOffset:(NSUInteger)value { _sourceFeatureChannelOffset = value; }

- (NSUInteger)sourceFeatureChannelMaxCount { return _sourceFeatureChannelMaxCount; }
- (void)setSourceFeatureChannelMaxCount:(NSUInteger)value { _sourceFeatureChannelMaxCount = value; }

- (MPSImageEdgeMode)edgeMode { return _edgeMode; }
- (void)setEdgeMode:(MPSImageEdgeMode)value { _edgeMode = value; }

- (NSUInteger)kernelWidth { return _kernelWidth; }
- (NSUInteger)kernelHeight { return _kernelHeight; }
- (NSUInteger)strideInPixelsX { return _strideInPixelsX; }
- (NSUInteger)strideInPixelsY { return _strideInPixelsY; }
- (NSUInteger)dilationRateX { return _dilationRateX; }
- (NSUInteger)dilationRateY { return _dilationRateY; }

- (BOOL)isBackwards { return _isBackwards; }
- (void)setIsBackwards:(BOOL)value { _isBackwards = value; }

- (id<MPSNNPadding>)padding { return _padding; }
- (void)setPadding:(id<MPSNNPadding>)value { _padding = value; }

- (id<MPSImageAllocator>)destinationImageAllocator { return _destinationImageAllocator; }
- (void)setDestinationImageAllocator:(id<MPSImageAllocator>)value { _destinationImageAllocator = value; }

- (BOOL)isStateModified { return NO; }

// The window the kernel walks, which a subclass's initialiser sets and every kernel here reads rather
// than keeping its own copy of.
- (void)charon_mps_setWindowWidth:(NSUInteger)width
                           height:(NSUInteger)height
                    strideInPixelsX:(NSUInteger)strideX
                    strideInPixelsY:(NSUInteger)strideY
                     dilationRateX:(NSUInteger)dilationX
                     dilationRateY:(NSUInteger)dilationY
{
    _kernelWidth = width;
    _kernelHeight = height;
    _strideInPixelsX = strideX ? strideX : 1;
    _strideInPixelsY = strideY ? strideY : 1;
    _dilationRateX = dilationX ? dilationX : 1;
    _dilationRateY = dilationY ? dilationY : 1;
}

- (id)copyWithZone:(NSZone *)zone
{
    return self;
}

@end
