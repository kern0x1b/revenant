#import <SceneKit/SceneKit.h>
#import <UIKit/UIKit.h>
#import "RevenantSCNAudio.h"

@interface SCNPhysicsRadialGravityField : SCNPhysicsField <NSSecureCoding>
@end

@interface SCNMaterialProperty (RevenantSCNCoding)
@property (nonatomic, readonly) BOOL revenantColorNotRead;
+ (instancetype)revenantDefaultWithContents:(id)contents;
@property (nonatomic, readonly) BOOL revenantHoldsDefault;
- (void)revenantKeepDefaultOf:(SCNMaterialProperty *)fallback;
@end

@interface RevenantSCNCoding : NSObject
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

@interface SCNScene (RevenantSCNSource)
- (NSURL *)revenantSourceURL;
@end

@class EAGLContext;

SCNMatrix4 RevenantSCNProjectionMatrix(SCNNode *pointOfView, int width, int height);

SCNVector3 RevenantSCNProjectPoint(SCNNode *pointOfView, int width, int height, SCNVector3 point);
SCNVector3 RevenantSCNUnprojectPoint(SCNNode *pointOfView, int width, int height, SCNVector3 point);

@interface RevenantSCNRenderEngine : NSObject
- (instancetype)initWithContext:(EAGLContext *)context;
@property (nonatomic, strong) SCNNode *lastRenderPointOfView;
@property (nonatomic, assign) int lastRenderWidth;
@property (nonatomic, assign) int lastRenderHeight;
- (void)renderScene:(SCNScene *)scene pointOfView:(SCNNode *)pointOfView width:(int)width height:(int)height;
+ (SCNNode *)defaultPointOfViewInScene:(SCNScene *)scene;
@end

@protocol RevenantSCNAnimatable <NSObject>
- (NSValue *)revenantModelValueForKeyPath:(NSString *)keyPath;
@end

@interface RevenantSCNAnimations : NSObject
- (void)addAnimation:(id)animation forKey:(NSString *)key;
- (void)removeAnimationForKey:(NSString *)key;
- (void)removeAllAnimations;
- (NSArray<NSString *> *)animationKeys;
- (CAAnimation *)animationForKey:(NSString *)key;
- (void)pauseAnimationForKey:(NSString *)key;
- (void)resumeAnimationForKey:(NSString *)key;
- (BOOL)isAnimationForKeyPaused:(NSString *)key;
- (NSDictionary<NSString *, NSValue *> *)presented;
- (RevenantSCNAnimations *)revenantCopy;
- (void)evaluateAtTime:(CFTimeInterval)now model:(id<RevenantSCNAnimatable>)model;
+ (void)evaluateScene:(SCNScene *)scene atTime:(CFTimeInterval)now listener:(SCNNode *)listener;
@end

@interface SCNNode (RevenantSCNAnimation) <RevenantSCNAnimatable>
- (RevenantSCNAnimations *)revenantAnimations;
- (SCNMatrix4)revenantPresentedTransform;
- (SCNMatrix4)revenantPresentedWorldTransform;
- (CGFloat)revenantPresentedOpacity;
@end

@interface SCNMaterialProperty (RevenantSCNAnimation) <RevenantSCNAnimatable>
- (RevenantSCNAnimations *)revenantAnimations;
- (SCNMatrix4)revenantPresentedContentsTransform;
@end

@interface SCNGeometry (RevenantReplace)
- (void)revenant_replaceSources:(NSArray<SCNGeometrySource *> *)sources
                     elements:(NSArray<SCNGeometryElement *> *)elements;
@end
