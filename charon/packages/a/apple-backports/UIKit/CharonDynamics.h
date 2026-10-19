#import <UIKit/UIKit.h>
#include <Box2D/Box2D.h>

#define CHARON_DYNAMICS_PTM 100.0f
#define CHARON_DYNAMICS_INVERSE_PTM 0.01f

static inline b2Vec2 charon_metres(CGPoint point)
{
    return b2Vec2((float)((double)CHARON_DYNAMICS_INVERSE_PTM * point.x), (float)((double)CHARON_DYNAMICS_INVERSE_PTM * point.y));
}

static inline CGPoint charon_points(b2Vec2 vector)
{
    return CGPointMake((double)(CHARON_DYNAMICS_PTM * vector.x), (double)(CHARON_DYNAMICS_PTM * vector.y));
}

typedef NS_ENUM(NSInteger, CharonDynamicsShape) {
    CharonDynamicsShapeNone,
    CharonDynamicsShapeBox,
    CharonDynamicsShapeCircle,
    CharonDynamicsShapeEdge,
    CharonDynamicsShapeLoop,
};

@interface CharonDynamicsBody : NSObject
@property (nonatomic, readonly) b2Body *b2Body;
@property (nonatomic, strong) id representedObject;
@property (nonatomic) NSInteger associations;
@property (nonatomic) uint32_t categoryBitMask;
@property (nonatomic) uint32_t collisionBitMask;
@property (nonatomic) uint32_t contactTestBitMask;
@property (nonatomic) BOOL affectedByGravity;
@property (nonatomic) BOOL usesPreciseCollisionDetection;
@property (nonatomic) BOOL dynamic;
@property (nonatomic) BOOL resting;
@property (nonatomic) CGPoint position;
@property (nonatomic) CGFloat rotation;
@property (nonatomic) CGPoint velocity;
@property (nonatomic) CGFloat angularVelocity;
@property (nonatomic) CGFloat restitution;
@property (nonatomic) CGFloat friction;
@property (nonatomic) CGFloat normalizedDensity;
@property (nonatomic) CGFloat linearDamping;
@property (nonatomic) CGFloat angularDamping;
@property (nonatomic) BOOL allowsRotation;
@property (nonatomic) CGFloat charge;
- (void)applyForce:(CGVector)force;
- (void)applyForce:(CGVector)force atPoint:(CGPoint)point;
- (void)applyImpulse:(CGVector)impulse;
- (void)applyImpulse:(CGVector)impulse atPoint:(CGPoint)point;
@end

@interface CharonDynamicsContact : NSObject
@property (nonatomic, readonly) CharonDynamicsBody *bodyA;
@property (nonatomic, readonly) CharonDynamicsBody *bodyB;
@property (nonatomic, readonly) CGPoint contactPoint;
@end

@interface UIDynamicAnimator (CharonDynamics)
- (b2World *)charon_world;
- (CharonDynamicsBody *)charon_registerBodyForItem:(id<UIDynamicItem>)item shape:(CharonDynamicsShape)shape;
- (void)charon_unregisterBodyForItem:(id<UIDynamicItem>)item action:(void (^)(CharonDynamicsBody *body))action;
- (CharonDynamicsBody *)charon_bodyForItem:(id<UIDynamicItem>)item;
- (CharonDynamicsBody *)charon_anchorBodyAtPoint:(CGPoint)point;
- (CharonDynamicsBody *)charon_boundaryBodyFromPoint:(CGPoint)first toPoint:(CGPoint)second;
- (CharonDynamicsBody *)charon_boundaryBodyWithLoop:(const b2Vec2 *)vertices count:(int32)count;
- (void)charon_addBody:(CharonDynamicsBody *)body;
- (void)charon_removeBody:(CharonDynamicsBody *)body;
- (void)charon_tickle;
- (void)charon_checkBehavior:(UIDynamicBehavior *)behavior;
- (void)charon_registerBehavior:(UIDynamicBehavior *)behavior;
- (void)charon_unregisterBehavior:(UIDynamicBehavior *)behavior;
- (void)charon_runBlockPostSolverIfNeeded:(dispatch_block_t)block;
- (void)charon_shouldReevaluateLocalBehaviors;
- (void)charon_traverseBehaviorHierarchy:(void (^)(UIDynamicBehavior *behavior))block;
- (int)charon_registerCollisionGroup;
- (void)charon_unregisterCollisionGroup;
- (void)charon_registerImplicitBounds;
- (void)charon_unregisterImplicitBounds;
- (CGRect)charon_referenceSystemBounds;
- (void)charon_setWorldGravity:(CGVector)gravity;
@end

@interface UIDynamicBehavior (CharonDynamics)
- (instancetype)charon_initPrimitive:(BOOL)primitive __attribute__((objc_method_family(init)));
- (NSMutableArray *)charon_items;
- (UIDynamicAnimator *)charon_context;
- (BOOL)charon_isAssociated;
- (void)charon_setContext:(UIDynamicAnimator *)animator;
- (void)charon_associate;
- (void)charon_dissociate;
- (void)charon_step;
- (void)charon_reevaluate:(NSInteger)mode;
- (BOOL)charon_allowsAnimatorToStop;
- (void)charon_changedParameterForBody:(CharonDynamicsBody *)body;
@end

@interface UIDynamicItemBehavior (CharonDynamics)
- (void)charon_configureBody:(CharonDynamicsBody *)body;
@end

@interface UICollisionBehavior (CharonDynamics)
- (void)charon_didBeginContact:(CharonDynamicsContact *)contact;
- (void)charon_didEndContact:(CharonDynamicsContact *)contact;
- (void)charon_reevaluateImplicitBounds;
- (BOOL)charon_usesImplicitBounds;
@end
