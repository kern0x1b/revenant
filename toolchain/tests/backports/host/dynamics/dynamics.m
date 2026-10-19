#import "dynamics.h"
#include <math.h>
#include <objc/message.h>
#include <stdlib.h>

@implementation Item
@synthesize center = _center, bounds = _bounds, transform = _transform;

+ (instancetype)itemAt:(CGPoint)center size:(CGSize)size
{
    Item *item = [self new];
    item.center = center;
    item.bounds = CGRectMake(0, 0, size.width, size.height);
    item.transform = CGAffineTransformIdentity;
    return item;
}

- (NSString *)description
{
    return @"<Item>";
}

@end

const char *const side_names[2] = {"oracle", "ours"};

Class side_class(Side side, NSString *name)
{
    NSString *full = side == Ours ? [@"RevenantHost" stringByAppendingString:name] : name;
    Class found = NSClassFromString(full);
    if (!found) {
        printf("FAIL no class %s\n", full.UTF8String);
        exit(2);
    }
    return found;
}

UIDynamicAnimator *make_animator(Side side, UIView *reference)
{
    UIDynamicAnimator *animator = [side_class(side, @"UIDynamicAnimator") alloc];
    animator = reference ? [animator initWithReferenceView:reference] : [animator init];
    [animator _setAlwaysDisableDisplayLink:YES];
    return animator;
}

static BOOL is_oracle(id object)
{
    return ![NSStringFromClass([object class]) hasPrefix:@"RevenantHost"];
}

BOOL animator_step(UIDynamicAnimator *animator, double dt)
{
    return is_oracle(animator) ? [animator _animatorStep:dt] : [animator revenant_animatorStep:dt];
}

void landing_scene(Side side, double y[4])
{
    UIDynamicAnimator *animator = make_animator(side, nil);
    Item *item = [Item itemAt:CGPointMake(100, 100) size:CGSizeMake(100, 100)];
    UIDynamicItemBehavior *material = [MAKE(side, UIDynamicItemBehavior) initWithItems:@[item]];
    material.elasticity = 0;
    material.resistance = 0;
    [animator addBehavior:material];
    [animator addBehavior:[MAKE(side, UIGravityBehavior) initWithItems:@[item]]];
    UICollisionBehavior *collision = [MAKE(side, UICollisionBehavior) initWithItems:@[item]];
    [collision addBoundaryWithIdentifier:@"floor" fromPoint:CGPointMake(0, 300) toPoint:CGPointMake(1000, 300)];
    [animator addBehavior:collision];
    for (int index = 1; index <= 300; index++) {
        animator_step(animator, 1.0 / 60.0);
        if (index >= 26 && index <= 28)
            y[index - 26] = item.center.y;
    }
    y[3] = item.center.y;
}

id animator_body(UIDynamicAnimator *animator, id item)
{
    return is_oracle(animator) ? [animator _bodyForItem:item] : [animator revenant_bodyForItem:item];
}

CGVector animator_gravity(UIDynamicAnimator *animator)
{
    if (is_oracle(animator))
        return [[animator _world] gravity];
    void *world = [animator revenant_world];
    if (!world)
        return CGVectorMake(NAN, NAN);
    EngineVector gravity = engine_world_gravity(world);
    return CGVectorMake(gravity.x, gravity.y);
}

void *our_world(UIDynamicAnimator *animator)
{
    return is_oracle(animator) ? NULL : [animator revenant_world];
}

void *our_b2body(id body)
{
    return [body b2Body];
}

BOOL body_dynamic(id body)
{
    return is_oracle(body) ? [body isDynamic] : [body dynamic];
}

BOOL body_resting(id body)
{
    return is_oracle(body) ? [body isResting] : [body resting];
}

CGPoint body_position(id body)
{
    return ((CGPoint(*)(id, SEL))objc_msgSend)(body, @selector(position));
}

void turn_run_loop(void)
{
    CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.05, false);
}

NSString *normalized(NSString *text)
{
    NSString *plain = [text stringByReplacingOccurrencesOfString:@"RevenantHost" withString:@""];
    NSRegularExpression *address = [NSRegularExpression regularExpressionWithPattern:@"0x[0-9a-f]+" options:0 error:NULL];
    return [address stringByReplacingMatchesInString:plain options:0 range:NSMakeRange(0, plain.length) withTemplate:@"0x"];
}

void check_near(double actual, double expected, double tolerance, const char *name, NSString *context)
{
    revenant_check(actual == expected || fabs(actual - expected) <= tolerance, name,
                 [NSString stringWithFormat:@"%@: %.9g vs %.9g (difference %.3g, tolerance %.3g)", context, actual, expected, actual - expected, tolerance]);
}

void check_equal_double(double actual, double expected, const char *name, NSString *context)
{
    revenant_check(actual == expected || (isnan(actual) && isnan(expected)), name,
                 [NSString stringWithFormat:@"%@: %.17g vs %.17g", context, actual, expected]);
}

int finish(void)
{
    printf("checks=%d failures=%d\n", revenant_checks, revenant_failures);
    return revenant_failures ? 1 : 0;
}
