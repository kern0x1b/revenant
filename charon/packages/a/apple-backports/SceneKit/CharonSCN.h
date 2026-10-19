#import <SceneKit/SceneKit.h>
#import <UIKit/UIKit.h>

@interface SCNPhysicsRadialGravityField : SCNPhysicsField <NSSecureCoding>
@end

@interface SCNMaterialProperty (CharonSCNCoding)
// YES when the archive this property was decoded from held a colour this port could not read: its contents are then
// nil, and a material puts its own default for the slot in their place.
@property (nonatomic, readonly) BOOL charonColorNotRead;
// A slot of a new material: nearest mipmap filtering, and a value SceneKit keeps as a colour in linear light and answers through `contents`
// sRGB-encoded (roughness: linear grey 0.2, answered as 0.484529). Drawn from that linear value until contents are set:
// assigning the very colour `contents` answered draws it as that colour (measured, facts/SceneKit/SCNView.md).
+ (instancetype)charonDefaultWithContents:(id)contents;
@property (nonatomic, readonly) BOOL charonHoldsDefault;
// Takes another property's contents and whether they are its slot's default, keeping this one's other values.
- (void)charonKeepDefaultOf:(SCNMaterialProperty *)fallback;
@end

@interface CharonSCNCoding : NSObject
+ (SCNVector3)decodeVector3:(NSCoder *)coder forKey:(NSString *)key;
+ (void)encodeVector3:(SCNVector3)vector coder:(NSCoder *)coder forKey:(NSString *)key;
+ (SCNVector4)decodeVector4:(NSCoder *)coder forKey:(NSString *)key;
+ (void)encodeVector4:(SCNVector4)vector coder:(NSCoder *)coder forKey:(NSString *)key;

+ (SCNMatrix4)decodeMatrix4:(NSCoder *)coder forKey:(NSString *)key;
+ (void)encodeMatrix4:(SCNMatrix4)matrix coder:(NSCoder *)coder forKey:(NSString *)key;

// The objects of one class a key holds: an archive may store a single object where it usually stores an array of
// them, and both pass a decode that allows the class and NSArray; an absent key is an empty array.
+ (NSArray *)decodeArrayOfClass:(Class)cls coder:(NSCoder *)coder forKey:(NSString *)key;
+ (UIColor *)decodeColor:(NSCoder *)coder forKey:(NSString *)key;
// A grey given in linear light, as SceneKit states its defaults, in the sRGB a UIColor means on this platform.
+ (UIColor *)colorWithLinearWhite:(double)white;
+ (NSString *)decodeFileReferenceName:(NSCoder *)coder forKey:(NSString *)key;
+ (BOOL)decodeBool:(NSCoder *)coder forKey:(NSString *)key default:(BOOL)fallback;

+ (void)pushSourceURL:(NSURL *)url;
+ (void)popSourceURL;
+ (NSURL *)currentSourceURL;

+ (void)markFound:(BOOL)found forKey:(NSString *)key onObject:(id)object;
+ (BOOL)wasFound:(NSString *)key onObject:(id)object;
@end

@interface SCNScene (CharonSCNSource)
// The file the scene was read from: images an archive names by file name are looked up beside it first.
- (NSURL *)charonSourceURL;
@end

@class EAGLContext;

// The OpenGL ES 2.0 renderer behind SCNView: it draws a scene from a point of view into the framebuffer bound when
// it is called. One renderer belongs to one context and keeps that context's buffers, textures and programs.
/// The projection a camera draws through, for a point of view and a viewport, shared by the frame
/// that is drawn and the points a hit test projects.
SCNMatrix4 CharonSCNProjectionMatrix(SCNNode *pointOfView, int width, int height);

/// A point from the world to the viewport, and back. Implemented once, over the point of view and
/// the viewport, and both SCNView and SCNRenderer answer with them - the view with its own point of
/// view and bounds, the renderer with its own and the viewport of its last render.
SCNVector3 CharonSCNProjectPoint(SCNNode *pointOfView, int width, int height, SCNVector3 point);
SCNVector3 CharonSCNUnprojectPoint(SCNNode *pointOfView, int width, int height, SCNVector3 point);

@interface CharonSCNRenderer : NSObject
- (instancetype)initWithContext:(EAGLContext *)context;
/// The point of view and the viewport of the last render, which is what projectPoint: and
/// unprojectPoint: answer with: before the first render there is none, and the port answers a point
/// unchanged, which is what macOS SceneKit's own renderer does (measured 2026-09-28).
@property (nonatomic, strong) SCNNode *lastRenderPointOfView;
@property (nonatomic, assign) int lastRenderWidth;
@property (nonatomic, assign) int lastRenderHeight;
- (void)renderScene:(SCNScene *)scene pointOfView:(SCNNode *)pointOfView width:(int)width height:(int)height;
+ (SCNNode *)defaultPointOfViewInScene:(SCNScene *)scene;
@end

// What an animated object answers for a key path before its animations: its model value, or nil for a key path the
// port does not animate.
@protocol CharonSCNAnimatable <NSObject>
- (NSValue *)charonModelValueForKeyPath:(NSString *)keyPath;
@end

// The Core Animation objects added to one node or material property, and the values they gave at the last frame.
@interface CharonSCNAnimations : NSObject
- (void)addAnimation:(id)animation forKey:(NSString *)key;
- (void)removeAnimationForKey:(NSString *)key;
- (void)removeAllAnimations;
- (NSArray<NSString *> *)animationKeys;
- (CAAnimation *)animationForKey:(NSString *)key;
- (void)pauseAnimationForKey:(NSString *)key;
- (void)resumeAnimationForKey:(NSString *)key;
- (BOOL)isAnimationForKeyPaused:(NSString *)key;
- (NSDictionary<NSString *, NSValue *> *)presented;
- (CharonSCNAnimations *)charonCopy;
- (void)evaluateAtTime:(CFTimeInterval)now model:(id<CharonSCNAnimatable>)model;
// every node's and material property's animations in the scene, at one time: called once a frame before the
// delegate hears renderer:didApplyAnimationsAtTime:
+ (void)evaluateScene:(SCNScene *)scene atTime:(CFTimeInterval)now;
@end

@interface SCNNode (CharonSCNAnimation) <CharonSCNAnimatable>
- (CharonSCNAnimations *)charonAnimations;
// the transform and opacity the last frame drew, with the animations applied
- (SCNMatrix4)charonPresentedTransform;
// the presented transform composed with those of the parents, which is where the last frame drew the node
- (SCNMatrix4)charonPresentedWorldTransform;
- (CGFloat)charonPresentedOpacity;
@end

@interface SCNMaterialProperty (CharonSCNAnimation) <CharonSCNAnimatable>
- (CharonSCNAnimations *)charonAnimations;
- (SCNMatrix4)charonPresentedContentsTransform;
@end

/// Replacing what a geometry is made of, in place.
///
/// `SCNGeometry`'s `geometrySources` and `geometryElements` are readonly - `SCNGeometry.h:121` and
/// `:135` - and the only public way to put data into a geometry is
/// `+geometryWithSources:elements:`, which returns a *new* object. So an ARKit class that subclasses
/// `SCNGeometry` and is handed new geometry to show has no public way to repopulate its receiver, which
/// is what `-updateFromPlaneGeometry:` is for.
///
/// This is that way, and it is package-internal on purpose. It is declared here and in no public
/// header, and it is not in the registry: it is not API, it adds nothing a caller can reach, and it
/// exists because the storage is *this file's* - the port implements the class, so the values behind
/// those two readonly properties are its own and nothing outside can see them. That is the difference
/// between this and a private ivar: nothing private is being reached, the class is simply implemented
/// here.
@interface SCNGeometry (CharonReplace)
- (void)charon_replaceSources:(NSArray<SCNGeometrySource *> *)sources
                     elements:(NSArray<SCNGeometryElement *> *)elements;
@end
