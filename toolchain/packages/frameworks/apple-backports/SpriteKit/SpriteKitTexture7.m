#import "RevenantSpriteKit.h"

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

- (instancetype)init
{
    self = [super init];
    if (self) {
        _textureRect = CGRectMake(0, 0, 1, 1);
        _filteringMode = SKTextureFilteringLinear;
    }
    return self;
}

+ (instancetype)textureWithRect:(CGRect)rect inTexture:(SKTexture *)texture
{
    SKTexture *result = [[self alloc] init];
    result->_imageSize = texture->_imageSize;
    result->_textureRect = rect;
    result->_size = CGSizeMake(rect.size.width * texture->_imageSize.width, rect.size.height * texture->_imageSize.height);
    return result;
}

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
