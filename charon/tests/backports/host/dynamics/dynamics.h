// dynamics.h — what the Dynamics host tests share: a plain dynamic item, the two sides of each comparison
// (the host's UIKit, the oracle, and our renamed classes), and the oracle driver.
//
// The oracle driver. A command-line Catalyst process has no display link that ticks
// (facts/UIKit/UIDynamicAnimator.md §1.6: w_app1, elapsed 0 after 0.5 s of run loop), so the host's animator is
// stepped through its private -_animatorStep:(double)dt, the method its own tick calls with the frame's dt
// (facts/UIKit/UIDynamicAnimator.md §1.5; present on the host, type B24@0:8d16), and ours through its counterpart
// -charon_animatorStep:. Both run the whole step: pre-solver, world, write-back, post-solver.
// The host's bodies, world and joints are read through its private accessors (-_bodyForItem:, -_world, the
// PKPhysicsBody getters): test code only, to see what the oracle's engine holds.
#import <UIKit/UIKit.h>
#import "check.h"
#import "engine.h"

@interface Item : NSObject <UIDynamicItem>
@property (nonatomic) CGPoint center;
@property (nonatomic) CGRect bounds;
@property (nonatomic) CGAffineTransform transform;
+ (instancetype)itemAt:(CGPoint)center size:(CGSize)size;
@end

typedef NS_ENUM(int, Side) { Oracle, Ours };
extern const char *const side_names[2];

// The class `name` on a side: the host's own, or ours under its CharonHost name. A missing class is a failure.
Class side_class(Side side, NSString *name);
#define MAKE(side, cls) ((cls *)[side_class(side, @#cls) alloc])

UIDynamicAnimator *make_animator(Side side, UIView *reference);
BOOL animator_step(UIDynamicAnimator *animator, double dt);
void landing_scene(Side side, double y[4]);
id animator_body(UIDynamicAnimator *animator, id item);
// World gravity in m/s^2.
CGVector animator_gravity(UIDynamicAnimator *animator);
// Our world, for engine.h (NULL before the first behavior); the oracle has none to give.
void *our_world(UIDynamicAnimator *animator);
void *our_b2body(id body);
BOOL body_dynamic(id body);
BOOL body_resting(id body);
CGPoint body_position(id body);

// One turn of the main run loop: what runs the main-queue blocks both implementations schedule.
void turn_run_loop(void);

// A description or exception text with our renaming and the object addresses taken out.
NSString *normalized(NSString *text);

void check_near(double actual, double expected, double tolerance, const char *name, NSString *context);
void check_equal_double(double actual, double expected, const char *name, NSString *context);
int finish(void);

@interface NSObject (DynamicsPrivate)
// both: 7.0's own switch that keeps an animator from starting a display link (facts/UIKit/UIDynamicAnimator.md §1.6)
- (void)_setAlwaysDisableDisplayLink:(BOOL)disable;
// host UIKit (oracle driver)
- (BOOL)_animatorStep:(double)dt;
- (id)_bodyForItem:(id)item;
- (id)_world;
- (CGVector)gravity;
- (BOOL)isDynamic;
- (BOOL)isResting;
// ours
- (BOOL)charon_animatorStep:(double)dt;
- (id)charon_bodyForItem:(id)item;
- (void *)charon_world;
- (void *)b2Body;
- (BOOL)dynamic;
- (BOOL)resting;
// both bodies
- (uint32_t)categoryBitMask;
- (uint32_t)collisionBitMask;
- (uint32_t)contactTestBitMask;
- (CGFloat)restitution;
- (CGFloat)friction;
- (CGFloat)normalizedDensity;
- (CGFloat)linearDamping;
- (CGFloat)angularDamping;
- (BOOL)allowsRotation;
- (CGFloat)charge;
- (CGVector)velocity;
- (CGFloat)angularVelocity;
- (CGPoint)position;
- (CGFloat)rotation;
- (BOOL)affectedByGravity;
- (BOOL)usesPreciseCollisionDetection;
@end
