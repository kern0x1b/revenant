#ifndef CharonSpriteKit_h
#define CharonSpriteKit_h

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <TargetConditionals.h>
#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#else
#import <AppKit/AppKit.h>
#endif

@class SKTexture;
@class SKScene;
@class SKView;

#if TARGET_OS_IPHONE
@class UIColor;
typedef UIColor CharonSKColor;
#else
@class NSColor;
typedef NSColor CharonSKColor;
#endif

typedef NS_ENUM(NSInteger, SKUniformType) {
    SKUniformTypeNone = 0,
    SKUniformTypeFloat = 1,
    SKUniformTypeFloatVector2 = 2,
    SKUniformTypeFloatVector3 = 3,
    SKUniformTypeFloatVector4 = 4,
    SKUniformTypeFloatMatrix2 = 5,
    SKUniformTypeFloatMatrix3 = 6,
    SKUniformTypeFloatMatrix4 = 7,
    SKUniformTypeTexture = 8,
};

typedef NS_ENUM(NSInteger, SKSceneScaleMode) {
    SKSceneScaleModeFill = 0,
    SKSceneScaleModeAspectFill = 1,
    SKSceneScaleModeAspectFit = 2,
    SKSceneScaleModeResizeFill = 3,
};

typedef NS_ENUM(NSInteger, SKTextureFilteringMode) {
    SKTextureFilteringNearest = 0,
    SKTextureFilteringLinear = 1,
};

typedef NS_ENUM(NSInteger, SKBlendMode) {
    SKBlendModeAlpha = 0,
    SKBlendModeAdd = 1,
    SKBlendModeSubtract = 2,
    SKBlendModeMultiply = 3,
    SKBlendModeMultiplyX2 = 4,
    SKBlendModeScreen = 5,
    SKBlendModeReplace = 6,
    SKBlendModeMultiplyAlpha = 7,
};

@interface SKTexture : NSObject <NSCopying>

+ (instancetype)textureWithRect:(CGRect)rect inTexture:(SKTexture *)texture;
+ (instancetype)textureWithData:(NSData *)pixelData size:(CGSize)size;

@property (nonatomic, readonly) CGRect textureRect;
@property (nonatomic, readonly) CGSize size;
@property (nonatomic) SKTextureFilteringMode filteringMode;
@property (nonatomic) BOOL usesMipmaps;

@end

@interface SKUniform : NSObject <NSCopying, NSSecureCoding>

+ (instancetype)uniformWithName:(NSString *)name;
+ (instancetype)uniformWithName:(NSString *)name texture:(SKTexture *)texture;
+ (instancetype)uniformWithName:(NSString *)name float:(float)value;

- (instancetype)initWithName:(NSString *)name;
- (instancetype)initWithName:(NSString *)name texture:(SKTexture *)texture;
- (instancetype)initWithName:(NSString *)name float:(float)value;

@property (nonatomic, readonly, copy) NSString *name;
@property (nonatomic, readonly) SKUniformType uniformType;
@property (nonatomic, retain) SKTexture *textureValue;
@property (nonatomic) float floatValue;

@end

@interface SKNode : NSObject

+ (instancetype)node;
- (instancetype)init;

@property (nonatomic, copy) NSString *name;
@property (nonatomic) CGPoint position;
@property (nonatomic) CGFloat zPosition;
@property (nonatomic) CGFloat zRotation;
@property (nonatomic) CGFloat xScale;
@property (nonatomic) CGFloat yScale;
@property (nonatomic) CGFloat alpha;
@property (nonatomic) CGFloat speed;
@property (nonatomic, getter=isPaused) BOOL paused;
@property (nonatomic, getter=isHidden) BOOL hidden;
@property (nonatomic, getter=isUserInteractionEnabled) BOOL userInteractionEnabled;
@property (nonatomic, retain) NSMutableDictionary *userData;

@property (nonatomic, readonly) SKNode *parent;
@property (nonatomic, readonly) NSArray *children;
@property (nonatomic, readonly) CGRect frame;

- (CGRect)calculateAccumulatedFrame;
- (void)setScale:(CGFloat)scale;

- (void)addChild:(SKNode *)node;
- (void)insertChild:(SKNode *)node atIndex:(NSUInteger)index;
- (void)removeChildrenInArray:(NSArray *)nodes;
- (void)removeAllChildren;
- (void)removeFromParent;

- (SKNode *)childNodeWithName:(NSString *)name;
- (void)enumerateChildNodesWithName:(NSString *)name usingBlock:(void (^)(SKNode *node, BOOL *stop))block;

- (BOOL)inParentHierarchy:(SKNode *)parent;
- (BOOL)containsPoint:(CGPoint)point;
- (SKNode *)nodeAtPoint:(CGPoint)point;
- (NSArray *)nodesAtPoint:(CGPoint)point;
- (CGPoint)convertPoint:(CGPoint)point fromNode:(SKNode *)node;
- (CGPoint)convertPoint:(CGPoint)point toNode:(SKNode *)node;
- (BOOL)intersectsNode:(SKNode *)node;
- (BOOL)isEqualToNode:(SKNode *)node;

@end

@interface SKNode (CharonSpriteKitMatching)
- (NSArray *)charon_nodesMatchingPath:(NSString *)path;
@end

@interface SKNode (CharonSpriteKit8)
- (NSArray *)objectForKeyedSubscript:(NSString *)path;
@end

@interface SKNode (CharonSpriteKit9)
- (void)moveToParent:(SKNode *)parent;
@end

@interface SKSpriteNode : SKNode

+ (instancetype)spriteNodeWithColor:(CharonSKColor *)color size:(CGSize)size;
+ (instancetype)spriteNodeWithTexture:(SKTexture *)texture;
+ (instancetype)spriteNodeWithTexture:(SKTexture *)texture size:(CGSize)size;

- (instancetype)initWithColor:(CharonSKColor *)color size:(CGSize)size;
- (instancetype)initWithTexture:(SKTexture *)texture;
- (instancetype)initWithTexture:(SKTexture *)texture color:(CharonSKColor *)color size:(CGSize)size;

@property (nonatomic, retain) SKTexture *texture;
@property (nonatomic, retain) CharonSKColor *color;
@property (nonatomic) CGFloat colorBlendFactor;
@property (nonatomic) SKBlendMode blendMode;
@property (nonatomic) CGPoint anchorPoint;
@property (nonatomic) CGSize size;
@property (nonatomic) CGRect centerRect;

@end

@interface SKShapeNode : SKNode

+ (instancetype)shapeNodeWithPath:(CGPathRef)path;
+ (instancetype)shapeNodeWithPath:(CGPathRef)path centered:(BOOL)centered;
+ (instancetype)shapeNodeWithRect:(CGRect)rect;
+ (instancetype)shapeNodeWithRectOfSize:(CGSize)size;
+ (instancetype)shapeNodeWithRect:(CGRect)rect cornerRadius:(CGFloat)cornerRadius;
+ (instancetype)shapeNodeWithRectOfSize:(CGSize)size cornerRadius:(CGFloat)cornerRadius;
+ (instancetype)shapeNodeWithCircleOfRadius:(CGFloat)radius;
+ (instancetype)shapeNodeWithEllipseInRect:(CGRect)rect;
+ (instancetype)shapeNodeWithEllipseOfSize:(CGSize)size;

@property (nonatomic) CGPathRef path;
@property (nonatomic, retain) CharonSKColor *strokeColor;
@property (nonatomic, retain) CharonSKColor *fillColor;
@property (nonatomic) SKBlendMode blendMode;
@property (nonatomic, getter=isAntialiased) BOOL antialiased;
@property (nonatomic) CGFloat lineWidth;
@property (nonatomic) CGFloat glowWidth;
@property (nonatomic) CGLineCap lineCap;
@property (nonatomic) CGLineJoin lineJoin;
@property (nonatomic) CGFloat miterLimit;

@end

@interface SKShapeNode (CharonSpriteKitShape8)

+ (instancetype)shapeNodeWithPoints:(CGPoint *)points count:(size_t)numPoints;
+ (instancetype)shapeNodeWithSplinePoints:(CGPoint *)points count:(size_t)numPoints;

@property (nonatomic, retain) SKTexture *fillTexture;
@property (nonatomic, retain) SKTexture *strokeTexture;

@end

typedef NS_ENUM(NSInteger, SKLabelHorizontalAlignmentMode) {
    SKLabelHorizontalAlignmentModeCenter = 0,
    SKLabelHorizontalAlignmentModeLeft = 1,
    SKLabelHorizontalAlignmentModeRight = 2,
};

typedef NS_ENUM(NSInteger, SKLabelVerticalAlignmentMode) {
    SKLabelVerticalAlignmentModeBaseline = 0,
    SKLabelVerticalAlignmentModeCenter = 1,
    SKLabelVerticalAlignmentModeTop = 2,
    SKLabelVerticalAlignmentModeBottom = 3,
};

@interface SKLabelNode : SKNode

+ (instancetype)labelNodeWithText:(NSString *)text;
+ (instancetype)labelNodeWithFontNamed:(NSString *)fontName;
- (instancetype)initWithFontNamed:(NSString *)fontName;

@property (nonatomic, copy) NSString *text;
@property (nonatomic, copy) NSString *fontName;
@property (nonatomic) CGFloat fontSize;
@property (nonatomic, retain) CharonSKColor *fontColor;
@property (nonatomic, retain) CharonSKColor *color;
@property (nonatomic) CGFloat colorBlendFactor;
@property (nonatomic) SKBlendMode blendMode;
@property (nonatomic) SKLabelHorizontalAlignmentMode horizontalAlignmentMode;
@property (nonatomic) SKLabelVerticalAlignmentMode verticalAlignmentMode;
@property (nonatomic) NSInteger numberOfLines;
@property (nonatomic) NSLineBreakMode lineBreakMode;
@property (nonatomic) CGFloat preferredMaxLayoutWidth;

@end

@interface SKCropNode : SKNode

@property (nonatomic, retain) SKNode *maskNode;

@end

@class CIFilter;

@interface SKEffectNode : SKNode

@property (nonatomic, retain) CIFilter *filter;
@property (nonatomic) BOOL shouldCenterFilter;
@property (nonatomic) BOOL shouldEnableEffects;
@property (nonatomic) BOOL shouldRasterize;
@property (nonatomic) SKBlendMode blendMode;

@end

@interface SKScene : SKEffectNode

+ (instancetype)sceneWithSize:(CGSize)size;
- (instancetype)initWithSize:(CGSize)size;

@property (nonatomic) CGSize size;
@property (nonatomic) SKSceneScaleMode scaleMode;
@property (nonatomic) CGPoint anchorPoint;
@property (nonatomic, retain) CharonSKColor *backgroundColor;

#if TARGET_OS_IPHONE
@property (nonatomic, weak, readonly) SKView *view;
- (void)didMoveToView:(SKView *)view;
- (void)willMoveFromView:(SKView *)view;
#endif

- (void)update:(NSTimeInterval)currentTime;
- (void)didEvaluateActions;
- (void)didSimulatePhysics;
- (void)didChangeSize:(CGSize)oldSize;

@end

@interface SKScene (CharonSpriteKitView)
- (void)charon_setView:(SKView *)view;
@end

@interface SKNode (CharonSpriteKitScene)
@property (nonatomic, readonly) SKScene *scene;
@end

@protocol SKSceneDelegate;

@interface SKScene (CharonSpriteKitScene8)
@property (nonatomic, weak) id<SKSceneDelegate> delegate;
- (void)didApplyConstraints;
- (void)didFinishUpdate;
@end

#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>

@interface SKView : UIView

@property (nonatomic, getter=isPaused) BOOL paused;
@property (nonatomic) BOOL showsFPS;
@property (nonatomic) BOOL showsDrawCount;
@property (nonatomic) BOOL showsNodeCount;
@property (nonatomic, getter=isAsynchronous) BOOL asynchronous;
@property (nonatomic) BOOL ignoresSiblingOrder;
@property (nonatomic) NSInteger frameInterval;
@property (nonatomic, readonly) SKScene *scene;

- (void)presentScene:(SKScene *)scene;

@end
#endif

#endif
