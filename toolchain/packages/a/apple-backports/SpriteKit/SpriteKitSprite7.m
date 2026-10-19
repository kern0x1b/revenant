#import "RevenantSpriteKit.h"
#if !TARGET_OS_IPHONE
#import <AppKit/AppKit.h>
#endif

static NSString *RevenantSKSizeString(CGSize size)
{
    return [NSString stringWithFormat:@"{%g, %g}", size.width, size.height];
}

static RevenantSKColor *RevenantSKTextureDefaultColor(void)
{
#if TARGET_OS_IPHONE
    return [UIColor colorWithWhite:1 alpha:0];
#else
    return [NSColor colorWithDeviceRed:1 green:1 blue:1 alpha:0];
#endif
}

@implementation SKSpriteNode {
    SKTexture *_texture;
    RevenantSKColor *_color;
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

+ (instancetype)spriteNodeWithColor:(RevenantSKColor *)color size:(CGSize)size
{
    return [[self alloc] initWithColor:color size:size];
}

+ (instancetype)spriteNodeWithTexture:(SKTexture *)texture
{
    return [[self alloc] initWithTexture:texture];
}

+ (instancetype)spriteNodeWithTexture:(SKTexture *)texture size:(CGSize)size
{
    if (size.width < 0 || size.height < 0) {
        [NSException raise:NSInvalidArgumentException format:@"Invalid bounds specified: %@", RevenantSKSizeString(size)];
    }
    return [[self alloc] initWithTexture:texture color:RevenantSKTextureDefaultColor() size:size];
}

- (instancetype)initWithColor:(RevenantSKColor *)color size:(CGSize)size
{
    if (size.width < 0 || size.height < 0) {
        [NSException raise:NSInvalidArgumentException format:@"Invalid size specified: %@", RevenantSKSizeString(size)];
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

- (instancetype)initWithTexture:(SKTexture *)texture
{
    return [self initWithTexture:texture color:RevenantSKTextureDefaultColor() size:texture.size];
}

- (instancetype)initWithTexture:(SKTexture *)texture color:(RevenantSKColor *)color size:(CGSize)size
{
    if (size.width < 0 || size.height < 0) {
        [NSException raise:NSInvalidArgumentException format:@"Invalid size specified: %@", RevenantSKSizeString(size)];
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
