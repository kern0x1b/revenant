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

Class side_class(Side side, NSString *name);
#define MAKE(side, cls) ((cls *)[side_class(side, @#cls) alloc])

UIDynamicAnimator *make_animator(Side side, UIView *reference);
BOOL animator_step(UIDynamicAnimator *animator, double dt);
void landing_scene(Side side, double y[4]);
id animator_body(UIDynamicAnimator *animator, id item);
CGVector animator_gravity(UIDynamicAnimator *animator);
void *our_world(UIDynamicAnimator *animator);
void *our_b2body(id body);
BOOL body_dynamic(id body);
BOOL body_resting(id body);
CGPoint body_position(id body);

void turn_run_loop(void);

NSString *normalized(NSString *text);

void check_near(double actual, double expected, double tolerance, const char *name, NSString *context);
void check_equal_double(double actual, double expected, const char *name, NSString *context);
int finish(void);

@interface NSObject (DynamicsPrivate)
- (void)_setAlwaysDisableDisplayLink:(BOOL)disable;
- (BOOL)_animatorStep:(double)dt;
- (id)_bodyForItem:(id)item;
- (id)_world;
- (CGVector)gravity;
- (BOOL)isDynamic;
- (BOOL)isResting;
- (BOOL)revenant_animatorStep:(double)dt;
- (id)revenant_bodyForItem:(id)item;
- (void *)revenant_world;
- (void *)b2Body;
- (BOOL)dynamic;
- (BOOL)resting;
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
