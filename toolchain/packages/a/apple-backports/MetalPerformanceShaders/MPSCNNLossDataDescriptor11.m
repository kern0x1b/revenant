#import "CharonMPS.h"

@implementation MPSCNNLossDataDescriptor {
    MPSDataLayout _layout;
    MTLSize _size;
    NSUInteger _bytesPerRow;
    NSUInteger _bytesPerImage;
}

+ (nullable MPSCNNLossDataDescriptor *)cnnLossDataDescriptorWithData:(NSData *__nonnull)data
                                                              layout:(MPSDataLayout)layout
                                                                size:(MTLSize)size
{
    (void)data;
    if (layout > MPSDataLayoutFeatureChannelsxHeightxWidth) {
        CharonMPSRefuse(@"MPSCNNLossDataDescriptor: layout %lu is not an MPSDataLayout, so no descriptor is made",
                        (unsigned long)layout);
        return nil;
    }
    MPSCNNLossDataDescriptor *descriptor = [[self alloc] init];
    descriptor->_layout = layout;
    descriptor->_size = size;
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
