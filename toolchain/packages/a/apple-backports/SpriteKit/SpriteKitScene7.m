#import "CharonSpriteKit.h"
#if !TARGET_OS_IPHONE
#import <AppKit/AppKit.h>
#endif

static CharonSKColor *CharonSKDefaultBackground(void)
{
#if TARGET_OS_IPHONE
    return [UIColor colorWithRed:0.15 green:0.15 blue:0.15 alpha:1];
#else
    return [NSColor colorWithDeviceRed:0.15 green:0.15 blue:0.15 alpha:1];
#endif
}

@implementation SKScene {
    CGSize _size;
    SKSceneScaleMode _scaleMode;
    CGPoint _anchorPoint;
    CharonSKColor *_backgroundColor;
#if TARGET_OS_IPHONE
    __weak SKView *_view;
#endif
}

+ (instancetype)sceneWithSize:(CGSize)size
{
    return [[self alloc] initWithSize:size];
}

- (instancetype)init
{
    return [self initWithSize:CGSizeMake(1, 1)];
}

- (instancetype)initWithSize:(CGSize)size
{
    self = [super init];
    if (self) {
        _size = size;
        _scaleMode = SKSceneScaleModeFill;
        _anchorPoint = CGPointZero;
        _backgroundColor = CharonSKDefaultBackground();
        [self didChangeSize:size];
    }
    return self;
}

- (CGSize)size
{
    return _size;
}

- (void)setSize:(CGSize)size
{
    CGSize oldSize = _size;
    _size = size;
    [self didChangeSize:oldSize];
}

- (SKSceneScaleMode)scaleMode
{
    return _scaleMode;
}

- (void)setScaleMode:(SKSceneScaleMode)scaleMode
{
    _scaleMode = scaleMode;
}

- (CGPoint)anchorPoint
{
    return _anchorPoint;
}

- (void)setAnchorPoint:(CGPoint)anchorPoint
{
    _anchorPoint = anchorPoint;
}

- (CharonSKColor *)backgroundColor
{
    return _backgroundColor;
}

- (void)setBackgroundColor:(CharonSKColor *)backgroundColor
{
    _backgroundColor = backgroundColor;
}

- (CGRect)frame
{
    return CGRectMake(-_anchorPoint.x * _size.width, -_anchorPoint.y * _size.height, _size.width, _size.height);
}

- (void)setPosition:(CGPoint)position
{
    (void)position;
    NSLog(@"SKScene: Setting the position of a SKScene has no effect.");
}

- (void)setXScale:(CGFloat)xScale
{
    (void)xScale;
    NSLog(@"SKScene: Setting the scale of a SKScene has no effect.");
}

- (void)setYScale:(CGFloat)yScale
{
    (void)yScale;
    NSLog(@"SKScene: Setting the scale of a SKScene has no effect.");
}

- (void)setScale:(CGFloat)scale
{
    (void)scale;
    NSLog(@"SKScene: Setting the scale of a SKScene has no effect.");
}

- (void)setZRotation:(CGFloat)zRotation
{
    (void)zRotation;
    NSLog(@"SKScene: Setting the zRotation of a SKScene has no effect.");
}

- (void)setZPosition:(CGFloat)zPosition
{
    (void)zPosition;
    NSLog(@"SKScene: Setting the zPosition of a SKScene has no effect.");
}

#if TARGET_OS_IPHONE
- (SKView *)view
{
    return _view;
}

- (void)didMoveToView:(SKView *)view
{
    (void)view;
}

- (void)willMoveFromView:(SKView *)view
{
    (void)view;
}
#endif

- (void)update:(NSTimeInterval)currentTime
{
    (void)currentTime;
}

- (void)didEvaluateActions
{
}

- (void)didSimulatePhysics
{
}

- (void)didChangeSize:(CGSize)oldSize
{
    (void)oldSize;
}

@end

@implementation SKScene (CharonSpriteKitView)

- (void)charon_setView:(SKView *)view
{
#if TARGET_OS_IPHONE
    _view = view;
#endif
}

@end

@implementation SKNode (CharonSpriteKitScene)

- (SKScene *)scene
{
    for (SKNode *node = self; node != nil; node = node.parent) {
        if ([node isKindOfClass:[SKScene class]]) {
            return (SKScene *)node;
        }
    }
    return nil;
}

@end
