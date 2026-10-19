#ifndef CharonSpriteKit_h
#define CharonSpriteKit_h

// The SpriteKit declarations this library carries, as the port declares them. The declarations are the generator's
// (packages/a/apple-backports/spec/SpriteKit/declarations.tsv); the bodies are the port's own.
//
// This header declares only the surface the library carries. It does not import the SDK's <SpriteKit/SpriteKit.h>:
// the SDK declares members that arrived in later releases (SKUniform's iOS 10 vector and matrix uniforms, for one), and
// an implementation that includes it is incomplete for every release below the member's own - clang warns on each of
// them. A member joins this header in the object of the release it arrived in: the iOS 7 surface of SKNode and SKScene
// is in SpriteKit7.m and SpriteKitScene7.m, the iOS 8 members in SpriteKit8.m and SpriteKitScene8.m (in categories,
// below), the iOS 9 members in SpriteKit9.m.

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <TargetConditionals.h>
// The platform's colour and line-break types (NSLineBreakMode is in UIKit on the device and in AppKit on the host).
#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#else
#import <AppKit/AppKit.h>
#endif

@class SKTexture;
@class SKScene;
@class SKView;

// SKColor is the colour class of the platform, as the spec gives it (the colour type of the SpriteKit rows).
#if TARGET_OS_IPHONE
@class UIColor;
typedef UIColor CharonSKColor;
#else
@class NSColor;
typedef NSColor CharonSKColor;
#endif

// The uniform types, with the values the SDK gives them (spec/SpriteKit/declarations.tsv).
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

// The scale modes of a scene, with the values the SDK gives them.
typedef NS_ENUM(NSInteger, SKSceneScaleMode) {
    SKSceneScaleModeFill = 0,
    SKSceneScaleModeAspectFill = 1,
    SKSceneScaleModeAspectFit = 2,
    SKSceneScaleModeResizeFill = 3,
};

// The texture filtering modes and the blend modes of iOS 7, with the values the SDK gives them.
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

// SKTexture of iOS 7: a rectangle of an image, the image being the one the texture was made from (SpriteKitTexture7.m).
// Its own pixels are held for the renderer, which is owed; the textures of this release carry the rectangle and the size.
@interface SKTexture : NSObject <NSCopying>

+ (instancetype)textureWithRect:(CGRect)rect inTexture:(SKTexture *)texture;
+ (instancetype)textureWithData:(NSData *)pixelData size:(CGSize)size;

@property (nonatomic, readonly) CGRect textureRect;
@property (nonatomic, readonly) CGSize size;
@property (nonatomic) SKTextureFilteringMode filteringMode;
@property (nonatomic) BOOL usesMipmaps;

@end

// SKUniform of iOS 8: a name, a type and one payload.
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

// SKNode of iOS 7: the tree of named nodes that every SpriteKit node is. Its frame, hit tests and conversions are the
// zero-size, content-free ones of the base class; a node with content supplies its own frame.
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

// The seam between the iOS 7 object and the members of later releases that match names: the node's descendants and
// children that a path of names picks out, in the order the host gives them. Declared here because two objects use it.
@interface SKNode (CharonSpriteKitMatching)
- (NSArray *)charon_nodesMatchingPath:(NSString *)path;
@end

// SKNode's iOS 8 member (SpriteKit8.m): the nodes a path picks out, as an array.
@interface SKNode (CharonSpriteKit8)
- (NSArray *)objectForKeyedSubscript:(NSString *)path;
@end

// SKNode's iOS 9 member (SpriteKit9.m): the node moves to a new parent, and leaves its old one.
@interface SKNode (CharonSpriteKit9)
- (void)moveToParent:(SKNode *)parent;
@end

// SKSpriteNode of iOS 7: a rectangle of colour or of a texture, of a size and an anchor point (SpriteKitSprite7.m). The
// normal map, lighting, shader and attribute members are owed (registry/SpriteKit/ios8.json and ios10.json).
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

// SKShapeNode of iOS 7: a node that draws a path, with its stroke and fill colours and its line style (SpriteKitShape7.m).
// The textures are of iOS 8 and are in the category below; the shaders and attributes of the stroke and fill are owed
// (registry/SpriteKit/ios8.json, ios10.json), and the line length is owed to the renderer.
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

// The points and spline forms of SKShapeNode, and the textures of its stroke and fill, are of iOS 8, in SpriteKit8.m. A
// category has no storage, so the textures are held by associated objects there.
@interface SKShapeNode (CharonSpriteKitShape8)

+ (instancetype)shapeNodeWithPoints:(CGPoint *)points count:(size_t)numPoints;
+ (instancetype)shapeNodeWithSplinePoints:(CGPoint *)points count:(size_t)numPoints;

@property (nonatomic, retain) SKTexture *fillTexture;
@property (nonatomic, retain) SKTexture *strokeTexture;

@end

// SKLabelNode of iOS 7: a text label in a font, with its colour and alignment (SpriteKitLabel7.m). The text is stored and
// read back; nothing is rasterised yet. The attributed text is iOS 11 and owed (registry/SpriteKit/ios11.json).
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

// SKCropNode of iOS 7: a node whose children are shown where its mask node is (SpriteKitCrop7.m). The crop is not drawn
// yet; the mask is stored and read back.
@interface SKCropNode : SKNode

@property (nonatomic, retain) SKNode *maskNode;

@end

// SKEffectNode of iOS 7: a node whose children are drawn into an effect (its filter, its centring, its rasterisation),
// and the superclass of SKScene (SpriteKitEffect7.m). The filter is stored and read back; the effect is not run yet, and
// the shader and attributes are owed (registry/SpriteKit/ios8.json, ios10.json).
@class CIFilter;

@interface SKEffectNode : SKNode

@property (nonatomic, retain) CIFilter *filter;
@property (nonatomic) BOOL shouldCenterFilter;
@property (nonatomic) BOOL shouldEnableEffects;
@property (nonatomic) BOOL shouldRasterize;
@property (nonatomic) SKBlendMode blendMode;

@end

// SKScene of iOS 7: the root of a tree of nodes, presented in a view. Its size is the viewport and its anchor point
// places the origin of its coordinates in that viewport; it does not take a position or a scale (SpriteKitScene7.m).
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

// The seam between SKView and the scene's members: the view records itself as the scene's view, which the scene's
// view property reads. The view calls it; no application does.
@interface SKScene (CharonSpriteKitView)
- (void)charon_setView:(SKView *)view;
@end

// SKNode's scene of iOS 7 (SpriteKitScene7.m): the scene the node is in, the node itself for a scene, or nil.
@interface SKNode (CharonSpriteKitScene)
@property (nonatomic, readonly) SKScene *scene;
@end

// The delegate of iOS 8 (SpriteKitScene8.m): the scene's delegate property and members of that release. The protocol is
// written by the generator into CharonSpriteKitProtocols.h (spec/protocol-headers.tsv); the sources that call its methods
// import that header.
@protocol SKSceneDelegate;

@interface SKScene (CharonSpriteKitScene8)
@property (nonatomic, weak) id<SKSceneDelegate> delegate;
- (void)didApplyConstraints;
- (void)didFinishUpdate;
@end

#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>

// SKView of iOS 7 (SpriteKitView7.m): the view that presents a scene. The port draws the scene's background colour and
// steps the scene's update methods each frame; the nodes' content is drawn by the step that carries it. The members
// carried are the ones whose behaviour the port has; the rest of the SDK's SKView are owed (registry/SpriteKit/ios7.json).
// Device-unverified.
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

#endif /* CharonSpriteKit_h */
