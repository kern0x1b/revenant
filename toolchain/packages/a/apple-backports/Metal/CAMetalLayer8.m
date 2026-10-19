#import <QuartzCore/CAMetalLayer.h>
#import "CharonMetal.h"

#pragma clang diagnostic ignored "-Wincomplete-implementation"
#pragma clang diagnostic ignored "-Wobjc-property-implementation"

@implementation CAMetalLayer {
    id<MTLDevice> _device;
    MTLPixelFormat _pixelFormat;
    BOOL _framebufferOnly;
    CGSize _drawableSize;
    BOOL _drawableSizeSet;
    BOOL _presentsWithTransaction;
    CGColorSpaceRef _colorspace;
}

@dynamic allowsNextDrawableTimeout, maximumDrawableCount, preferredDevice, wantsExtendedDynamicRangeContent, EDRMetadata, developerHUDProperties;

- (instancetype)init
{
    if ((self = [super init])) {
        _pixelFormat = (MTLPixelFormat)80;
        _framebufferOnly = YES;
    }
    return self;
}

- (void)dealloc
{
    CGColorSpaceRelease(_colorspace);
}

- (id<MTLDevice>)device
{
    return _device;
}

- (void)setDevice:(id<MTLDevice>)device
{
    _device = device;
}

- (MTLPixelFormat)pixelFormat
{
    return _pixelFormat;
}

- (void)setPixelFormat:(MTLPixelFormat)pixelFormat
{
    _pixelFormat = pixelFormat;
}

- (BOOL)framebufferOnly
{
    return _framebufferOnly;
}

- (void)setFramebufferOnly:(BOOL)framebufferOnly
{
    _framebufferOnly = framebufferOnly;
}

- (CGSize)drawableSize
{
    if (_drawableSizeSet)
        return _drawableSize;
    CGSize size = self.bounds.size;
    CGFloat scale = self.contentsScale;
    return CGSizeMake(size.width * scale, size.height * scale);
}

- (void)setDrawableSize:(CGSize)drawableSize
{
    _drawableSize = drawableSize;
    _drawableSizeSet = YES;
}

- (BOOL)presentsWithTransaction
{
    return _presentsWithTransaction;
}

- (void)setPresentsWithTransaction:(BOOL)presentsWithTransaction
{
    _presentsWithTransaction = presentsWithTransaction;
}

- (CGColorSpaceRef)colorspace
{
    return _colorspace;
}

- (void)setColorspace:(CGColorSpaceRef)colorspace
{
    CGColorSpaceRetain(colorspace);
    CGColorSpaceRelease(_colorspace);
    _colorspace = colorspace;
}

- (id<CAMetalDrawable>)nextDrawable
{
    return CharonMetalNextDrawable(self);
}

@end
