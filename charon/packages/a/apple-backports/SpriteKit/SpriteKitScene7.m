// SpriteKitScene7.m - SKScene of iOS 7, carried for the releases that have no SpriteKit at all.
//
// A scene is the root of a tree of nodes, presented in a view (SpriteKitView7.m). Its size is the viewport, its anchor
// point places the origin of its coordinates in that viewport, and its frame is the viewport in those coordinates.
// Its position and scale are not its to take: the host logs a message and keeps the values it had. Those answers, and
// the frame formula, are measured against the host's own SpriteKit in facts/SpriteKit/SKScene.md.
//
// Nothing here draws. The view clears to the background colour; a node's content is the step that carries it.
#import "CharonSpriteKit.h"
#if !TARGET_OS_IPHONE
#import <AppKit/AppKit.h>
#endif

// The default background colour of a scene: the host's own (measured on macOS, facts/SpriteKit/SKScene.md). The iOS
// value is not measured on a device; the port uses the same components.
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

// The host calls didChangeSize: once from the initialiser, with the size as the old one (measured).
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

// The host calls didChangeSize: with the size the scene had, and does so even when the size does not change (measured).
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

// The frame is the viewport in the scene's own coordinates: the anchor point is the fraction of the size that sits at
// the origin (measured: anchor (0.5,0.25) on 320x480 gives (-160,-120,320,480)).
- (CGRect)frame
{
    return CGRectMake(-_anchorPoint.x * _size.width, -_anchorPoint.y * _size.height, _size.width, _size.height);
}

// The host logs and ignores a scene's position, scale, rotation and depth (measured for each, facts/SpriteKit/SKScene.md).
// The alpha, the hidden flag and the speed are stored as on any node.
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

// The scene of a node: the nearest scene among the node and its ancestors, which for a scene is the scene itself.
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
