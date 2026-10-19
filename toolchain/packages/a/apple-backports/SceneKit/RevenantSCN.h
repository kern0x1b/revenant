#import <SceneKit/SceneKit.h>
#import <UIKit/UIKit.h>

@interface SCNPhysicsRadialGravityField : SCNPhysicsField <NSSecureCoding>
@end

@interface SCNMaterialProperty (CharonSCNCoding)
@property (nonatomic, readonly) BOOL charonColorNotRead;
+ (instancetype)charonDefaultWithContents:(id)contents;
@property (nonatomic, readonly) BOOL charonHoldsDefault;
- (void)charonKeepDefaultOf:(SCNMaterialProperty *)fallback;
@end

@interface CharonSCNCoding : NSObject
+ (SCNVector3)decodeVector3:(NSCoder *)coder forKey:(NSString *)key;
+ (void)encodeVector3:(SCNVector3)vector coder:(NSCoder *)coder forKey:(NSString *)key;
+ (SCNVector4)decodeVector4:(NSCoder *)coder forKey:(NSString *)key;
+ (void)encodeVector4:(SCNVector4)vector coder:(NSCoder *)coder forKey:(NSString *)key;

+ (SCNMatrix4)decodeMatrix4:(NSCoder *)coder forKey:(NSString *)key;
+ (void)encodeMatrix4:(SCNMatrix4)matrix coder:(NSCoder *)coder forKey:(NSString *)key;

+ (NSArray *)decodeArrayOfClass:(Class)cls coder:(NSCoder *)coder forKey:(NSString *)key;
+ (UIColor *)decodeColor:(NSCoder *)coder forKey:(NSString *)key;
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
- (NSURL *)charonSourceURL;
@end

@class EAGLContext;

SCNMatrix4 CharonSCNProjectionMatrix(SCNNode *pointOfView, int width, int height);

SCNVector3 CharonSCNProjectPoint(SCNNode *pointOfView, int width, int height, SCNVector3 point);
SCNVector3 CharonSCNUnprojectPoint(SCNNode *pointOfView, int width, int height, SCNVector3 point);

@interface CharonSCNRenderer : NSObject
- (instancetype)initWithContext:(EAGLContext *)context;
@property (nonatomic, strong) SCNNode *lastRenderPointOfView;
@property (nonatomic, assign) int lastRenderWidth;
@property (nonatomic, assign) int lastRenderHeight;
- (void)renderScene:(SCNScene *)scene pointOfView:(SCNNode *)pointOfView width:(int)width height:(int)height;
+ (SCNNode *)defaultPointOfViewInScene:(SCNScene *)scene;
@end

@protocol CharonSCNAnimatable <NSObject>
- (NSValue *)charonModelValueForKeyPath:(NSString *)keyPath;
@end

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
+ (void)evaluateScene:(SCNScene *)scene atTime:(CFTimeInterval)now;
@end

@interface SCNNode (CharonSCNAnimation) <CharonSCNAnimatable>
- (CharonSCNAnimations *)charonAnimations;
- (SCNMatrix4)charonPresentedTransform;
- (SCNMatrix4)charonPresentedWorldTransform;
- (CGFloat)charonPresentedOpacity;
@end

@interface SCNMaterialProperty (CharonSCNAnimation) <CharonSCNAnimatable>
- (CharonSCNAnimations *)charonAnimations;
- (SCNMatrix4)charonPresentedContentsTransform;
@end

@interface SCNGeometry (CharonReplace)
- (void)charon_replaceSources:(NSArray<SCNGeometrySource *> *)sources
                     elements:(NSArray<SCNGeometryElement *> *)elements;
@end
