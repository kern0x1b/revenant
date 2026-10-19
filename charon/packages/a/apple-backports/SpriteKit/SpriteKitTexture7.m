// SpriteKitTexture7.m - SKTexture of iOS 7, carried for the releases that have no SpriteKit at all.
//
// A texture is a rectangle of an image, in the unit square of that image, and its size is the rectangle's size in the
// image's pixels. A texture cut from another texture takes its rectangle in the unit square of the image both were made
// from, not in the texture it was cut from, and its size is that rectangle times the image's size (measured: a rectangle
// cut from a quarter of a 4 by 4 image, then cut again, keeps the rectangle it was given and has a size of 2 by 2). A
// copy keeps the rectangle, the size and the filtering, and not the mipmaps (measured, facts/SpriteKit/SKTexture.md).
//
// The pixels are held for the renderer, which is owed; nothing here draws. The texture of an image named by a file is
// owed to the image loader (SpriteKit's textureWithImageNamed: answers a placeholder on the host, and the iOS answer is
// not measured).
#import "CharonSpriteKit.h"

@implementation SKTexture {
    CGRect _textureRect;
    CGSize _imageSize;
    CGSize _size;
    SKTextureFilteringMode _filteringMode;
    BOOL _usesMipmaps;
    NSData *_pixelData;
}

@synthesize textureRect = _textureRect;
@synthesize size = _size;
@synthesize filteringMode = _filteringMode;
@synthesize usesMipmaps = _usesMipmaps;

// A texture of the whole of its image, linear filtered: the defaults the host gives a texture made from pixels.
- (instancetype)init
{
    self = [super init];
    if (self) {
        _textureRect = CGRectMake(0, 0, 1, 1);
        _filteringMode = SKTextureFilteringLinear;
    }
    return self;
}

// The size of the new texture is read from the texture it is cut from, with no check for nil: the host does the same and
// dies on a read through nil (SIGSEGV, measured in facts/SpriteKit/SKTexture.md), and the port dies the same way.
+ (instancetype)textureWithRect:(CGRect)rect inTexture:(SKTexture *)texture
{
    SKTexture *result = [[self alloc] init];
    result->_imageSize = texture->_imageSize;
    result->_textureRect = rect;
    result->_size = CGSizeMake(rect.size.width * texture->_imageSize.width, rect.size.height * texture->_imageSize.height);
    return result;
}

// The host gives nil for nil pixels (measured). Short pixels are not checked: the size is the one given.
+ (instancetype)textureWithData:(NSData *)pixelData size:(CGSize)size
{
    if (pixelData == nil) {
        return nil;
    }
    SKTexture *result = [[self alloc] init];
    result->_imageSize = size;
    result->_size = size;
    result->_pixelData = [pixelData copy];
    return result;
}

- (id)copyWithZone:(NSZone *)zone
{
    SKTexture *copy = [[[self class] allocWithZone:zone] init];
    copy->_imageSize = _imageSize;
    copy->_textureRect = _textureRect;
    copy->_size = _size;
    copy->_filteringMode = _filteringMode;
    copy->_pixelData = _pixelData;
    return copy;
}

@end
