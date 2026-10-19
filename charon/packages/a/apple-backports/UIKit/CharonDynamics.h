// The interface between the files of the UIKit Dynamics backport: the animator, which owns the Box2D
// world (UIDynamicAnimator.mm), and the behaviors, each in its own file. Every file here defines a
// class iOS 7.0 exports, so a band whose release carries UIKit Dynamics drops them all together;
// they reach one another only through Objective-C messages, never through a C symbol or a class
// reference, so no file of a band needs a symbol another file of it lacks.
//
// No C++ library container is used: its templates would be instantiated, and exported, in every file
// that uses one. The C++ here is Box2D's own.
//
// Internal: nothing declared here is API. The behaviour it reproduces is iOS 7.0's, measured against
// the host's UIKit (Mac Catalyst) and read from the 7.0 armv7/arm64 listings; see
// facts/UIKit/UIDynamicAnimator.md.

#import <UIKit/UIKit.h>
#include <Box2D/Box2D.h>

// Points per metre (-[UIDynamicAnimator _ptmRatio] is 100 on 7.0 and on the host).
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

// The shape a body is built with. A box is an item's bounds; an edge or a loop is a boundary; none is
// the static anchor an attachment or a snap pulls towards.
typedef NS_ENUM(NSInteger, CharonDynamicsShape) {
    CharonDynamicsShapeNone,
    CharonDynamicsShapeBox,
    CharonDynamicsShapeCircle,
    CharonDynamicsShapeEdge,
    CharonDynamicsShapeLoop,
};

// One PhysicsKit body: the b2Body while the body is in a world, and everything that has to outlive it
// (a boundary exists before its behavior joins an animator). The three masks are UIKit's 32-bit ones,
// which b2Filter's 16 bits cannot hold: the world's contact filter reads them from here.
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

// A contact between two bodies, buffered while the world steps and delivered after it.
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
