// MPSCNNLossDataDescriptor, from the header of MPSCNNLoss.h in the SDK of iOS 16.4: the layout and the size of
// a loss's per-element data, and the two byte counts a dense array of that data has. A plain shape object. The
// release keeps the NSData it is given for the labels object, which this port does not carry, and the header
// offers no accessor for it, so the data is not kept here.

#import "CharonMPS.h"

@implementation MPSCNNLossDataDescriptor {
    MPSDataLayout _layout;
    MTLSize _size;
    NSUInteger _bytesPerRow;
    NSUInteger _bytesPerImage;
}

// -init is NS_UNAVAILABLE in the header. This class does not override NSObject's -init, so a caller that reaches it
// gets a zeroed object, which is what the release answers too (measured on the host).
+ (nullable MPSCNNLossDataDescriptor *)cnnLossDataDescriptorWithData:(NSData *__nonnull)data
                                                              layout:(MPSDataLayout)layout
                                                                size:(MTLSize)size
{
    (void)data;
    // The release asserts on a layout outside MPSDataLayout (measured: layouts 2 and 7 abort). An API in this port
    // never crashes its caller, so it refuses by name and returns nil. The layout is an NSUInteger, so a negative
    // value arrives as a large one and is refused by the same test.
    if (layout > MPSDataLayoutFeatureChannelsxHeightxWidth) {
        CharonMPSRefuse(@"MPSCNNLossDataDescriptor: layout %lu is not an MPSDataLayout, so no descriptor is made",
                        (unsigned long)layout);
        return nil;
    }
    MPSCNNLossDataDescriptor *descriptor = [[self alloc] init];
    descriptor->_layout = layout;
    descriptor->_size = size;
    // The data is single precision, and a dense array has no padding. The interleaved layout's row is the width
    // times the feature channels (size.depth), the planar layout's row is the width alone, and a slice is the
    // rows of the image. These are the counts the release returns for the sizes measured on the host.
    NSUInteger rowElements = layout == MPSDataLayoutHeightxWidthxFeatureChannels ? size.depth : 1;
    descriptor->_bytesPerRow = size.width * rowElements * (NSUInteger)sizeof(float);
    descriptor->_bytesPerImage = descriptor->_bytesPerRow * size.height;
    return descriptor;
}

- (MPSDataLayout)layout
{
    return _layout;
}

- (MTLSize)size
{
    return _size;
}

- (NSUInteger)bytesPerRow
{
    return _bytesPerRow;
}

- (void)setBytesPerRow:(NSUInteger)bytesPerRow
{
    _bytesPerRow = bytesPerRow;
}

- (NSUInteger)bytesPerImage
{
    return _bytesPerImage;
}

- (void)setBytesPerImage:(NSUInteger)bytesPerImage
{
    _bytesPerImage = bytesPerImage;
}

- (id)copyWithZone:(NSZone *)zone
{
    MPSCNNLossDataDescriptor *copy = [[[self class] allocWithZone:zone] init];
    copy->_layout = _layout;
    copy->_size = _size;
    copy->_bytesPerRow = _bytesPerRow;
    copy->_bytesPerImage = _bytesPerImage;
    return copy;
}

@end
