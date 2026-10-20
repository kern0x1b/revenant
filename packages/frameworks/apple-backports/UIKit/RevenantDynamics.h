#import <UIKit/UIKit.h>
#include <Box2D/Box2D.h>

#define REVENANT_DYNAMICS_PTM 100.0f
#define REVENANT_DYNAMICS_INVERSE_PTM 0.01f

static inline b2Vec2 revenant_metres(CGPoint point)
{
    return b2Vec2((float)((double)REVENANT_DYNAMICS_INVERSE_PTM * point.x), (float)((double)REVENANT_DYNAMICS_INVERSE_PTM * point.y));
}

static inline CGPoint revenant_points(b2Vec2 vector)
{
    return CGPointMake((double)(REVENANT_DYNAMICS_PTM * vector.x), (double)(REVENANT_DYNAMICS_PTM * vector.y));
}

typedef NS_ENUM(NSInteger, RevenantDynamicsShape) {
    RevenantDynamicsShapeNone,
    RevenantDynamicsShapeBox,
    RevenantDynamicsShapeCircle,
    RevenantDynamicsShapeEdge,
    RevenantDynamicsShapeLoop,
};

@interface RevenantDynamicsBody : NSObject
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

@interface RevenantDynamicsContact : NSObject
@property (nonatomic, readonly) RevenantDynamicsBody *bodyA;
@property (nonatomic, readonly) RevenantDynamicsBody *bodyB;
@property (nonatomic, readonly) CGPoint contactPoint;
@end

@interface UIDynamicAnimator (RevenantDynamics)
- (b2World *)revenant_world;
- (RevenantDynamicsBody *)revenant_registerBodyForItem:(id<UIDynamicItem>)item shape:(RevenantDynamicsShape)shape;
- (void)revenant_unregisterBodyForItem:(id<UIDynamicItem>)item action:(void (^)(RevenantDynamicsBody *body))action;
- (RevenantDynamicsBody *)revenant_bodyForItem:(id<UIDynamicItem>)item;
- (RevenantDynamicsBody *)revenant_anchorBodyAtPoint:(CGPoint)point;
- (RevenantDynamicsBody *)revenant_boundaryBodyFromPoint:(CGPoint)first toPoint:(CGPoint)second;
- (RevenantDynamicsBody *)revenant_boundaryBodyWithLoop:(const b2Vec2 *)vertices count:(int32)count;
- (void)revenant_addBody:(RevenantDynamicsBody *)body;
- (void)revenant_removeBody:(RevenantDynamicsBody *)body;
- (void)revenant_tickle;
- (void)revenant_checkBehavior:(UIDynamicBehavior *)behavior;
- (void)revenant_registerBehavior:(UIDynamicBehavior *)behavior;
- (void)revenant_unregisterBehavior:(UIDynamicBehavior *)behavior;
- (void)revenant_runBlockPostSolverIfNeeded:(dispatch_block_t)block;
- (void)revenant_shouldReevaluateLocalBehaviors;
- (void)revenant_traverseBehaviorHierarchy:(void (^)(UIDynamicBehavior *behavior))block;
- (int)revenant_registerCollisionGroup;
- (void)revenant_unregisterCollisionGroup;
- (void)revenant_registerImplicitBounds;
- (void)revenant_unregisterImplicitBounds;
- (CGRect)revenant_referenceSystemBounds;
- (void)revenant_setWorldGravity:(CGVector)gravity;
@end

@interface UIDynamicBehavior (RevenantDynamics)
- (instancetype)revenant_initPrimitive:(BOOL)primitive __attribute__((objc_method_family(init)));
- (NSMutableArray *)revenant_items;
- (UIDynamicAnimator *)revenant_context;
- (BOOL)revenant_isAssociated;
- (void)revenant_setContext:(UIDynamicAnimator *)animator;
- (void)revenant_associate;
- (void)revenant_dissociate;
- (void)revenant_step;
- (void)revenant_reevaluate:(NSInteger)mode;
- (BOOL)revenant_allowsAnimatorToStop;
- (void)revenant_changedParameterForBody:(RevenantDynamicsBody *)body;
@end

@interface UIDynamicItemBehavior (RevenantDynamics)
- (void)revenant_configureBody:(RevenantDynamicsBody *)body;
@end

@interface UICollisionBehavior (RevenantDynamics)
- (void)revenant_didBeginContact:(RevenantDynamicsContact *)contact;
- (void)revenant_didEndContact:(RevenantDynamicsContact *)contact;
- (void)revenant_reevaluateImplicitBounds;
- (BOOL)revenant_usesImplicitBounds;
@end
