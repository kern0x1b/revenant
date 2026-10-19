// SpriteKitSprite7.m - SKSpriteNode of iOS 7, carried for the releases that have no SpriteKit at all.
//
// A sprite is a node with a size, an anchor point, a colour and a texture. Its size is the one it is given, or the texture's
// size when it is made from a texture without one; the colour blends with the texture by the colour blend factor. The
// values are stored as the host stores them (measured against the host's own SpriteKit in facts/SpriteKit/SKSpriteNode.md),
// and a setter does not check them. The initialisers do: a negative size raises (measured, the reasons in that fact file).
//
// Nothing here draws. The sprite's texture and colour are the renderer's, which is owed.
#import "CharonSpriteKit.h"
#if !TARGET_OS_IPHONE
#import <AppKit/AppKit.h>
#endif

// The reason the host gives for a negative size, in the form of NSStringFromSize ({width, height} with %g).
static NSString *CharonSKSizeString(CGSize size)
{
    return [NSString stringWithFormat:@"{%g, %g}", size.width, size.height];
}

// The colour a sprite made from a texture has: white with no alpha (measured on the host, facts/SpriteKit/SKSpriteNode.md).
static CharonSKColor *CharonSKTextureDefaultColor(void)
{
#if TARGET_OS_IPHONE
    return [UIColor colorWithWhite:1 alpha:0];
#else
    return [NSColor colorWithDeviceRed:1 green:1 blue:1 alpha:0];
#endif
}

@implementation SKSpriteNode {
    SKTexture *_texture;
    CharonSKColor *_color;
    CGFloat _colorBlendFactor;
    SKBlendMode _blendMode;
    CGPoint _anchorPoint;
    CGSize _size;
    CGRect _centerRect;
}

@synthesize texture = _texture;
@synthesize color = _color;
@synthesize colorBlendFactor = _colorBlendFactor;
@synthesize blendMode = _blendMode;
@synthesize anchorPoint = _anchorPoint;
@synthesize size = _size;
@synthesize centerRect = _centerRect;

+ (instancetype)spriteNodeWithColor:(CharonSKColor *)color size:(CGSize)size
{
    return [[self alloc] initWithColor:color size:size];
}

+ (instancetype)spriteNodeWithTexture:(SKTexture *)texture
{
    return [[self alloc] initWithTexture:texture];
}

// The host's message for a negative size here is "Invalid bounds specified", not the initialisers' "Invalid size specified".
+ (instancetype)spriteNodeWithTexture:(SKTexture *)texture size:(CGSize)size
{
    if (size.width < 0 || size.height < 0) {
        [NSException raise:NSInvalidArgumentException format:@"Invalid bounds specified: %@", CharonSKSizeString(size)];
    }
    return [[self alloc] initWithTexture:texture color:CharonSKTextureDefaultColor() size:size];
}

- (instancetype)initWithColor:(CharonSKColor *)color size:(CGSize)size
{
    if (size.width < 0 || size.height < 0) {
        [NSException raise:NSInvalidArgumentException format:@"Invalid size specified: %@", CharonSKSizeString(size)];
    }
    self = [super init];
    if (self) {
        _color = color;
        _size = size;
        _anchorPoint = CGPointMake(0.5, 0.5);
        _centerRect = CGRectMake(0, 0, 1, 1);
    }
    return self;
}

// A sprite made from a texture takes the texture's size, and the default colour of a texture sprite.
- (instancetype)initWithTexture:(SKTexture *)texture
{
    return [self initWithTexture:texture color:CharonSKTextureDefaultColor() size:texture.size];
}

- (instancetype)initWithTexture:(SKTexture *)texture color:(CharonSKColor *)color size:(CGSize)size
{
    if (size.width < 0 || size.height < 0) {
        [NSException raise:NSInvalidArgumentException format:@"Invalid size specified: %@", CharonSKSizeString(size)];
    }
    self = [super init];
    if (self) {
        _texture = texture;
        _color = color;
        _size = size;
        _anchorPoint = CGPointMake(0.5, 0.5);
        _centerRect = CGRectMake(0, 0, 1, 1);
    }
    return self;
}

@end
