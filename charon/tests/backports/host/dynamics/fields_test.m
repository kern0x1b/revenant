// fields_test.m - facts/UIKit/UIFieldBehavior.md §16 rows F1, F3, F4 and F5 (F2, the region truth table, is
// region_test.m), where a field acts (§10.1, §10.4), and UIFloatRange's exported symbols (UIDynamicAnimator.md §6.4).
// Each scene runs with the host's UIFieldBehavior (the oracle) and with ours; ours is compared with the oracle's
// answer, and the oracle with the numbers the facts file gives as measured, so a scene that is not the probe's shows
// up as such.
//
// Ours is written over the public 7.0 API and applies the field once per animator step, after the world step (§10.7),
// where the host evaluates it inside the solver once per 1/120 s sub-step: the trajectories (F4) are compared within
// the error §10.7 measured for that design, and the force itself (F5) through the emulation's own acceleration
// function, -charon_accelerationAt:velocity:mass:charge:time:, given the state the host's first sub-step starts from.
#import "dynamics.h"
#include <float.h>
#include <math.h>

static const double frame = 1.0 / 60.0;
// The host's sub-step, and the world time after the first one (§0).
static const double substep = (double)(float)(1.0 / 120.0);

@interface NSObject (FieldsPrivate)
// ours: the emulation's acceleration, pt/s^2, of an item at `center` (the region not asked)
- (CGVector)charon_accelerationAt:(CGPoint)center velocity:(CGPoint)velocity mass:(CGFloat)mass charge:(CGFloat)charge time:(NSTimeInterval)time;
@end

// Ours, under run.sh's renaming.
extern const UIFloatRange CharonHostUIFloatRangeZero;
extern const UIFloatRange CharonHostUIFloatRangeInfinite;
BOOL CharonHostUIFloatRangeIsInfinite(UIFloatRange range);

typedef UIFieldBehavior *(^FieldMaker)(Class kind);

static Class field_class(Side side)
{
    return side_class(side, @"UIFieldBehavior");
}

static NSString *outcome(void (^block)(void))
{
    @try {
        block();
    } @catch (NSException *exception) {
        return [NSString stringWithFormat:@"%@: %@", exception.name, normalized(exception.reason)];
    }
    return @"no exception";
}

#pragma mark F1: factories and properties

static NSDictionary<NSString *, FieldMaker> *factories(void)
{
    return @{
        @"drag": ^(Class k) { return [k dragField]; },
        @"vortex": ^(Class k) { return [k vortexField]; },
        @"radial (30,40)": ^(Class k) { return [k radialGravityFieldWithPosition:CGPointMake(30, 40)]; },
        @"linear (3,4)": ^(Class k) { return [k linearGravityFieldWithVector:CGVectorMake(3, 4)]; },
        @"velocity (0.1,-7)": ^(Class k) { return [k velocityFieldWithVector:CGVectorMake(0.1, -7)]; },
        @"noise 0.3 0.7": ^(Class k) { return [k noiseFieldWithSmoothness:0.3 animationSpeed:0.7]; },
        @"turbulence -1 2.5": ^(Class k) { return [k turbulenceFieldWithSmoothness:-1 animationSpeed:2.5]; },
        @"spring": ^(Class k) { return [k springField]; },
        @"electric": ^(Class k) { return [k electricField]; },
        @"magnetic": ^(Class k) { return [k magneticField]; },
        @"block": ^(Class k) {
            return [k fieldWithEvaluationBlock:^CGVector(UIFieldBehavior *f, CGPoint p, CGVector v, CGFloat m, CGFloat q, NSTimeInterval t) {
                return CGVectorMake(0, 0);
            }];
        },
    };
}

static NSArray *properties(UIFieldBehavior *field)
{
    return @[@(field.strength), @(field.falloff), @(field.minimumRadius), @(field.direction.dx), @(field.direction.dy),
             @(field.position.x), @(field.position.y), @(field.smoothness), @(field.animationSpeed)];
}

// Every property after the factory, then after a round of sets with values that do not survive float and metres.
static NSArray *answers(Side side, FieldMaker make)
{
    UIFieldBehavior *field = make(field_class(side));
    NSMutableArray *found = [NSMutableArray arrayWithObject:properties(field)];
    [found addObject:@[@(field.region == [side_class(side, @"UIRegion") infiniteRegion]), @(field.items.count), @(field.childBehaviors.count)]];
    field.strength = 0.1;
    field.falloff = -2.7;
    field.minimumRadius = 3;
    field.direction = CGVectorMake(0.1, 0.2);
    field.position = CGPointMake(30, 40);
    field.smoothness = 0.1;
    field.animationSpeed = 1.3;
    [found addObject:properties(field)];
    field.minimumRadius = 0.001;
    field.position = CGPointMake(-0.1234, 1e5);
    [found addObject:properties(field)];
    field.minimumRadius = 12345.678;
    [found addObject:properties(field)];
    return found;
}

static void test_properties(void)
{
    NSDictionary<NSString *, FieldMaker> *made = factories();
    for (NSString *name in [made.allKeys sortedArrayUsingSelector:@selector(compare:)]) {
        NSArray *oracle = answers(Oracle, made[name]), *ours = answers(Ours, made[name]);
        for (NSUInteger row = 0; row < oracle.count; row++) {
            for (NSUInteger column = 0; column < [oracle[row] count]; column++) {
                check_equal_double([ours[row][column] doubleValue], [oracle[row][column] doubleValue], "F1 field property as the oracle",
                                   [NSString stringWithFormat:@"%@ row %lu value %lu", name, (unsigned long)row, (unsigned long)column]);
            }
        }
    }
    // f_1 (§10.1): the default minimum radius 0.00305175781 (2^-15 m), (30, 40) read back as (29.9999982, 39.9999976).
    NSArray *oracle = answers(Oracle, made[@"drag"]);
    check_near([oracle[0][2] doubleValue], 0.00305175781, 5e-12, "oracle field is as f_1 measured", @"default minimumRadius");
    check_near([oracle[2][5] doubleValue], 29.9999982, 5e-8, "oracle field is as f_1 measured", @"position x");
    check_near([oracle[2][6] doubleValue], 39.9999976, 5e-8, "oracle field is as f_1 measured", @"position y");
    NSArray *radial = answers(Oracle, made[@"radial (30,40)"]), *spring = answers(Oracle, made[@"spring"]);
    CHECK([radial[0][1] doubleValue] == 2 && [spring[0][1] doubleValue] == -1, "oracle field is as f_1 measured");
}

static NSArray *object_answers(Side side)
{
    Class kind = field_class(side);
    UIFieldBehavior *field = [kind vortexField];
    NSString *made = outcome(^{
        (void)[[kind alloc] init];
    });
    [field addChildBehavior:[MAKE(side, UIGravityBehavior) initWithItems:@[]]];
    Item *item = [Item itemAt:CGPointMake(0, 0) size:CGSizeMake(10, 10)];
    [field addItem:item];
    [field addItem:item];
    NSUInteger added = field.items.count;
    [field removeItem:item];
    return @[made, normalized(field.description), @(field.childBehaviors.count), @(added), @(field.items.count),
             @([field conformsToProtocol:@protocol(NSCopying)]), @([field conformsToProtocol:@protocol(NSCoding)])];
}

static void test_object(void)
{
    NSArray *oracle = object_answers(Oracle), *ours = object_answers(Ours);
    const char *rows[] = {"-init", "description", "a child is not taken", "an item once", "removed", "NSCopying", "NSCoding"};
    for (NSUInteger index = 0; index < oracle.count; index++) {
        charon_check([ours[index] isEqual:oracle[index]], "F1 field object as the oracle",
                     [NSString stringWithFormat:@"%s: ours %@ oracle %@", rows[index], ours[index], oracle[index]]);
    }
    CHECK_EQUAL(oracle[0], @"Invalid initialization: Use one of the supplied convenience initializers", "oracle field is as measured (p1)");
}

#pragma mark UIFloatRange

static void test_float_range(void)
{
    CHECK(CharonHostUIFloatRangeZero.minimum == UIFloatRangeZero.minimum && CharonHostUIFloatRangeZero.maximum == UIFloatRangeZero.maximum,
          "UIFloatRangeZero is the oracle's");
    CHECK(CharonHostUIFloatRangeInfinite.minimum == UIFloatRangeInfinite.minimum && CharonHostUIFloatRangeInfinite.maximum == UIFloatRangeInfinite.maximum,
          "UIFloatRangeInfinite is the oracle's");
    const UIFloatRange ranges[] = {
        {-INFINITY, INFINITY}, {0, 0}, {-INFINITY, 0}, {0, INFINITY}, {INFINITY, -INFINITY}, {-FLT_MAX, FLT_MAX},
        {-1e39, 1e39}, {-3.4028234e38, 3.4028234e38}, {-INFINITY, NAN}, {NAN, INFINITY}, {NAN, NAN}, {-DBL_MAX, DBL_MAX},
        {nextafter(-(double)FLT_MAX, 0), FLT_MAX}, {-FLT_MAX, nextafter((double)FLT_MAX, 0)},
    };
    for (size_t index = 0; index < sizeof(ranges) / sizeof(ranges[0]); index++) {
        BOOL expected = UIFloatRangeIsInfinite(ranges[index]), actual = CharonHostUIFloatRangeIsInfinite(ranges[index]);
        charon_check(actual == expected, "UIFloatRangeIsInfinite answers as the oracle's",
                     [NSString stringWithFormat:@"{%g, %g}: ours %d oracle %d", ranges[index].minimum, ranges[index].maximum, actual, expected]);
    }
}

#pragma mark F3: the 33rd field

static NSArray *categories(Side side)
{
    Class kind = field_class(side);
    UIDynamicAnimator *animator = make_animator(side, nil);
    Item *item = [Item itemAt:CGPointMake(300, 300) size:CGSizeMake(10, 10)];
    UIDynamicItemBehavior *material = [MAKE(side, UIDynamicItemBehavior) initWithItems:@[item]];
    material.resistance = 0;
    [animator addBehavior:material];
    NSMutableArray *fields = [NSMutableArray array];
    for (int index = 0; index < 32; index++) {
        UIFieldBehavior *field = [kind linearGravityFieldWithVector:CGVectorMake(1, 0)];
        [field addItem:item];
        [animator addBehavior:field];
        [fields addObject:field];
    }
    UIFieldBehavior *extra = [kind linearGravityFieldWithVector:CGVectorMake(0, 1)];
    [extra addItem:item];
    NSString *refused = outcome(^{
        [animator addBehavior:extra];
    });
    animator_step(animator, frame);
    CGFloat refusedVelocity = [material linearVelocityForItem:item].y;
    NSUInteger listed = [animator.behaviors containsObject:extra];
    NSString *removed = outcome(^{
        [animator removeBehavior:extra];
    });
    [animator removeBehavior:fields[0]];
    NSString *again = outcome(^{
        [animator addBehavior:extra];
    });
    animator_step(animator, frame);
    CGFloat acceptedVelocity = [material linearVelocityForItem:item].y;
    return @[refused, @(refusedVelocity == 0), @(listed), removed, again, @(acceptedVelocity > 0)];
}

static void test_categories(void)
{
    NSArray *oracle = categories(Oracle), *ours = categories(Ours);
    const char *rows[] = {"the 33rd field", "the refused field exerts no force", "the refused field is in behaviors",
                          "removing the refused field", "adding it after one was removed", "the field acts once let in"};
    for (NSUInteger index = 0; index < oracle.count; index++) {
        charon_check([ours[index] isEqual:oracle[index]], "F3 the 33rd field as the oracle",
                     [NSString stringWithFormat:@"%s: ours %@ oracle %@", rows[index], ours[index], oracle[index]]);
    }
    // m_f33 (M5).
    CHECK_EQUAL(oracle[0], @"Invalid Association: UIDynamicAnimator supports a maximum of 32 distinct fields", "oracle fields are as m_f33 measured");
}

#pragma mark Where a field acts

// §10.1 and §10.4: a field acts on its own items only, inside its region (asked in the field's local space, points),
// never on an anchored item. Each case answers whether the item has a velocity after one step: ours gives it after the
// world step, so its position changes only in the next (§10.7), and a position also moves by the float round trip of
// the write-back, where a velocity does not.
static BOOL accelerated(UIDynamicItemBehavior *material, id<UIDynamicItem> item)
{
    CGPoint velocity = [material linearVelocityForItem:item];
    return velocity.x != 0 || velocity.y != 0;
}

static NSArray *where(Side side)
{
    Class kind = field_class(side);
    NSMutableArray *moved = [NSMutableArray array];
    const CGPoint places[] = {{300, 350}, {300, 350.001}, {335.355, 335.355}, {350, 300}, {250, 300}, {300, 249.999}};
    for (size_t index = 0; index < sizeof(places) / sizeof(places[0]); index++) {
        UIDynamicAnimator *animator = make_animator(side, nil);
        Item *item = [Item itemAt:places[index] size:CGSizeMake(10, 10)];
        UIDynamicItemBehavior *material = [MAKE(side, UIDynamicItemBehavior) initWithItems:@[item]];
        UIFieldBehavior *field = [kind linearGravityFieldWithVector:CGVectorMake(0, 1)];
        field.position = CGPointMake(300, 300);
        field.region = [MAKE(side, UIRegion) initWithRadius:50];
        [field addItem:item];
        [animator addBehavior:material];
        [animator addBehavior:field];
        animator_step(animator, frame);
        [moved addObject:@(accelerated(material, item))];
    }
    UIDynamicAnimator *animator = make_animator(side, nil);
    Item *inside = [Item itemAt:CGPointMake(100, 100) size:CGSizeMake(10, 10)];
    Item *outside = [Item itemAt:CGPointMake(200, 100) size:CGSizeMake(10, 10)];
    Item *anchored = [Item itemAt:CGPointMake(300, 100) size:CGSizeMake(10, 10)];
    UIFieldBehavior *field = [kind linearGravityFieldWithVector:CGVectorMake(0, 1)];
    [field addItem:inside];
    [field addItem:anchored];
    UIDynamicItemBehavior *material = [MAKE(side, UIDynamicItemBehavior) initWithItems:@[inside, outside, anchored]];
    UIDynamicItemBehavior *pinned = [MAKE(side, UIDynamicItemBehavior) initWithItems:@[anchored]];
    pinned.anchored = YES;
    [animator addBehavior:material];
    [animator addBehavior:pinned];
    [animator addBehavior:field];
    animator_step(animator, frame);
    [moved addObjectsFromArray:@[@(accelerated(material, inside)), @(accelerated(material, outside)), @(accelerated(material, anchored))]];
    return moved;
}

static void test_where(void)
{
    NSArray *oracle = where(Oracle), *ours = where(Ours);
    const char *rows[] = {"region edge 50", "beyond the edge 50.001", "inside on the diagonal", "on the edge in x", "on the edge in -x",
                          "beyond the edge in -y", "an item of the field", "an item of another behavior", "an anchored item"};
    for (NSUInteger index = 0; index < oracle.count; index++) {
        charon_check([ours[index] isEqual:oracle[index]], "a field acts where the oracle's does",
                     [NSString stringWithFormat:@"%s: ours %@ oracle %@", rows[index], ours[index], oracle[index]]);
    }
    // f_4 (§10.1): a radius-50 region at (300,300) acts at distance 50, not at 50.001.
    CHECK([oracle[0] boolValue] && ![oracle[1] boolValue], "oracle region is as f_4 measured");
}

#pragma mark F5: the force

typedef struct {
    const char *name;
    FieldMaker make;
    CGFloat density, charge;
    CGPoint velocity;
    CGVector measured; // §10.2's number, pt/s^2; NAN where the facts file gives none
    double tolerance;  // relative
} ForceCase;

// The host's acceleration over its first sub-step of a new world, from the velocity it adds: a 100x100 item at
// (300,400) with resistance 0, density and charge as given, starting at `velocity`. The body keeps its velocity as
// float m/s, so the acceleration read back from it is known to one float step of the final velocity over the
// sub-step: `resolution`, pt/s^2, per axis.
typedef struct {
    CGVector acceleration, resolution;
} OracleAcceleration;

static double float_step(double points)
{
    float metres = fabsf((float)(points / 100.0));
    return 100.0 * ((double)nextafterf(metres, INFINITY) - (double)metres);
}

static OracleAcceleration oracle_acceleration(ForceCase c)
{
    UIDynamicAnimator *animator = make_animator(Oracle, nil);
    Item *item = [Item itemAt:CGPointMake(300, 400) size:CGSizeMake(100, 100)];
    UIDynamicItemBehavior *material = [[UIDynamicItemBehavior alloc] initWithItems:@[item]];
    material.resistance = 0;
    material.density = c.density;
    material.charge = c.charge;
    if (c.velocity.x || c.velocity.y)
        [material addLinearVelocity:c.velocity forItem:item];
    UIFieldBehavior *field = c.make([UIFieldBehavior class]);
    [field addItem:item];
    [animator addBehavior:material];
    [animator addBehavior:field];
    animator_step(animator, frame);
    CGPoint velocity = [material linearVelocityForItem:item];
    OracleAcceleration found = {
        CGVectorMake((velocity.x - c.velocity.x) / substep, (velocity.y - c.velocity.y) / substep),
        CGVectorMake(float_step(velocity.x) / substep, float_step(velocity.y) / substep),
    };
    return found;
}

static void check_relative(double actual, double expected, double tolerance, double resolution, const char *name, NSString *context)
{
    check_near(actual, expected, tolerance * fabs(expected) + resolution, name, context);
}

static void test_forces(void)
{
    CGVector (^custom)(UIFieldBehavior *, CGPoint, CGVector, CGFloat, CGFloat, NSTimeInterval) =
        ^CGVector(UIFieldBehavior *f, CGPoint p, CGVector v, CGFloat m, CGFloat q, NSTimeInterval t) {
            return CGVectorMake(1, 0);
        };
    // 1e-3 relative (§16 F5); noise and turbulence 1e-5 (M7 measured that force bit-exact); each plus the resolution
    // of the oracle's reading.
    const ForceCase cases[] = {
        {"linear (3,4)", ^(Class k) { return [k linearGravityFieldWithVector:CGVectorMake(3, 4)]; }, 1, 0, {0, 0}, {300, 400}, 1e-3},
        {"linear (3,4) m 3", ^(Class k) { return [k linearGravityFieldWithVector:CGVectorMake(3, 4)]; }, 3, 0, {0, 0}, {300, 400}, 1e-3},
        {"linear S 2 k 1", ^(Class k) {
             UIFieldBehavior *f = [k linearGravityFieldWithVector:CGVectorMake(3, 4)];
             f.strength = 2;
             f.falloff = 1;
             return f;
         }, 1, 0, {0, 0}, {120, 160}, 1e-3},
        {"radial at 0", ^(Class k) { return [k radialGravityFieldWithPosition:CGPointZero]; }, 1, 0, {0, 0}, {-2.4, -3.2}, 1e-3},
        {"radial at 0 m 3", ^(Class k) { return [k radialGravityFieldWithPosition:CGPointZero]; }, 3, 0, {0, 0}, {-2.4, -3.2}, 1e-3},
        {"radial S 2 k 1 rmin 1000", ^(Class k) {
             UIFieldBehavior *f = [k radialGravityFieldWithPosition:CGPointZero];
             f.strength = 2;
             f.falloff = 1;
             f.minimumRadius = 1000;
             return f;
         }, 1, 0, {0, 0}, {-12, -16}, 1e-3},
        {"electric q 2", ^(Class k) { return [k electricField]; }, 1, 2, {0, 0}, {24, 32}, 1e-3},
        {"electric q 2 m 3", ^(Class k) { return [k electricField]; }, 3, 2, {0, 0}, {8, 10.667}, 1e-3},
        {"electric q 0", ^(Class k) { return [k electricField]; }, 1, 0, {0, 0}, {0, 0}, 1e-3},
        {"magnetic q 2", ^(Class k) { return [k magneticField]; }, 1, 2, {100, 0}, {0, -20}, 1e-3},
        {"magnetic q -1", ^(Class k) { return [k magneticField]; }, 1, -1, {100, 0}, {0, -20}, 1e-3},
        {"magnetic q 1 m 3", ^(Class k) { return [k magneticField]; }, 3, 1, {100, 0}, {0, -6.667}, 1e-3},
        {"spring", ^(Class k) { return [k springField]; }, 1, 0, {0, 0}, {-300, -400}, 1e-3},
        {"spring m 3", ^(Class k) { return [k springField]; }, 3, 0, {0, 0}, {-100, -133.3}, 1e-3},
        {"vortex", ^(Class k) { return [k vortexField]; }, 1, 0, {0, 0}, {-80, 60}, 1e-3},
        {"vortex m 3", ^(Class k) { return [k vortexField]; }, 3, 0, {0, 0}, {-8.889, 6.667}, 1e-3},
        {"vortex S 2 k 1 rmin 1000", ^(Class k) {
             UIFieldBehavior *f = [k vortexField];
             f.strength = 2;
             f.falloff = 1;
             f.minimumRadius = 1000;
             return f;
         }, 1, 0, {0, 0}, {-16, 12}, 1e-3},
        {"drag", ^(Class k) { return [k dragField]; }, 1, 0, {100, 0}, {-100, 0}, 1e-3},
        {"drag m 3 v 200", ^(Class k) { return [k dragField]; }, 3, 0, {200, 0}, {-133.333, 0}, 1e-3},
        {"drag with the medium", ^(Class k) {
             UIFieldBehavior *f = [k dragField];
             f.direction = CGVectorMake(1, 0);
             return f;
         }, 1, 0, {100, 0}, {0, 0}, 1e-3},
        {"block", ^(Class k) { return [k fieldWithEvaluationBlock:custom]; }, 1, 0, {0, 0}, {100, 0}, 1e-3},
        {"block S 2 m 3", ^(Class k) {
             UIFieldBehavior *f = [k fieldWithEvaluationBlock:custom];
             f.strength = 2;
             return f;
         }, 3, 0, {0, 0}, {33.3333, 0}, 1e-3},
        {"noise 0.3 0.7", ^(Class k) { return [k noiseFieldWithSmoothness:0.3 animationSpeed:0.7]; }, 1, 0, {0, 0}, {NAN, NAN}, 1e-5},
        {"noise 0 0 m 3 at (37,-12) k 1", ^(Class k) {
             UIFieldBehavior *f = [k noiseFieldWithSmoothness:0 animationSpeed:0];
             f.position = CGPointMake(37, -12);
             f.falloff = 1;
             return f;
         }, 3, 0, {0, 0}, {NAN, NAN}, 1e-5},
        {"noise 2 -3 S -4", ^(Class k) {
             UIFieldBehavior *f = [k noiseFieldWithSmoothness:2 animationSpeed:-3];
             f.strength = -4;
             return f;
         }, 1, 0, {0, 0}, {NAN, NAN}, 1e-5},
        {"turbulence 0.5 1", ^(Class k) { return [k turbulenceFieldWithSmoothness:0.5 animationSpeed:1]; }, 1, 0, {100, 50}, {NAN, NAN}, 1e-5},
        {"turbulence 0.1 0 m 2", ^(Class k) { return [k turbulenceFieldWithSmoothness:0.1 animationSpeed:0]; }, 2, 0, {-30, 80}, {NAN, NAN}, 1e-5},
    };
    for (size_t index = 0; index < sizeof(cases) / sizeof(cases[0]); index++) {
        ForceCase c = cases[index];
        NSString *name = @(c.name);
        OracleAcceleration measured = oracle_acceleration(c);
        CGVector oracle = measured.acceleration;
        UIFieldBehavior *field = c.make(field_class(Ours));
        CGVector ours = [field charon_accelerationAt:CGPointMake(300, 400) velocity:c.velocity mass:c.density charge:c.charge time:substep];
        check_relative(ours.dx, oracle.dx, c.tolerance, measured.resolution.dx, "F5 field acceleration as the oracle", [name stringByAppendingString:@" x"]);
        check_relative(ours.dy, oracle.dy, c.tolerance, measured.resolution.dy, "F5 field acceleration as the oracle", [name stringByAppendingString:@" y"]);
        if (!isnan(c.measured.dx)) {
            // f_2, f_3 (§10.2), printed to 4 or 5 digits.
            check_relative(oracle.dx, c.measured.dx, 1e-3, measured.resolution.dx, "oracle field acceleration is as f_2/f_3 measured", [name stringByAppendingString:@" x"]);
            check_relative(oracle.dy, c.measured.dy, 1e-3, measured.resolution.dy, "oracle field acceleration is as f_2/f_3 measured", [name stringByAppendingString:@" y"]);
        } else {
            printf("F5 %s: ours (%.9g, %.9g) oracle (%.9g, %.9g) pt/s^2\n", c.name, ours.dx, ours.dy, oracle.dx, oracle.dy);
            CHECK(hypot(oracle.dx, oracle.dy) > 0, "the oracle's noise scene has a force to compare");
        }
    }
}

#pragma mark F4: trajectories

typedef struct {
    const char *name;
    FieldMaker make;
    CGPoint velocity;
    int frames;
    double tolerance;  // pt
    CGPoint appleF60;  // §10.7's "Apple f60"; NAN where the scene stops earlier
    CGPoint emulationF60; // §10.7's "emulation f60": the same design over the host's own 7.0 API
} TrajectoryCase;

// §10.7's scene: a 100x100 item at (300,400), resistance 0, the field alone, steps of 1/60.
static void trajectory(Side side, TrajectoryCase c, CGPoint positions[])
{
    UIDynamicAnimator *animator = make_animator(side, nil);
    Item *item = [Item itemAt:CGPointMake(300, 400) size:CGSizeMake(100, 100)];
    UIDynamicItemBehavior *material = [MAKE(side, UIDynamicItemBehavior) initWithItems:@[item]];
    material.resistance = 0;
    if (c.velocity.x || c.velocity.y)
        [material addLinearVelocity:c.velocity forItem:item];
    UIFieldBehavior *field = c.make(field_class(side));
    [field addItem:item];
    [animator addBehavior:material];
    [animator addBehavior:field];
    for (int index = 0; index < c.frames; index++) {
        animator_step(animator, frame);
        positions[index] = item.center;
    }
}

static void test_trajectories(void)
{
    // Tolerance 1.2 x the maximum error §10.7 measured over the same frames (§16 F4); radial gravity over its first 10
    // frames only, before the path nears the centre where the lag makes the emulation miss the singularity (§10.7).
    const TrajectoryCase cases[] = {
        {"linear (3,4)", ^(Class k) { return [k linearGravityFieldWithVector:CGVectorMake(3, 4)]; }, {0, 0}, 60, 1.2 * 2.083, {448.7500, 598.3333}, {447.5000, 596.6667}},
        {"radial S 200 at 0", ^(Class k) {
             UIFieldBehavior *f = [k radialGravityFieldWithPosition:CGPointZero];
             f.strength = 200;
             return f;
         }, {0, 0}, 10, 1.2 * 0.5644, {NAN, NAN}, {NAN, NAN}},
        {"spring S 4 at (250,350)", ^(Class k) {
             UIFieldBehavior *f = [k springField];
             f.strength = 4;
             f.position = CGPointMake(250, 350);
             return f;
         }, {0, 0}, 60, 1.2 * 0.5855, {229.5706, 329.5706}, {229.9463, 329.9463}},
        {"vortex S 2 at (250,350)", ^(Class k) {
             UIFieldBehavior *f = [k vortexField];
             f.strength = 2;
             f.position = CGPointMake(250, 350);
             return f;
         }, {0, 0}, 60, 1.2 * 0.7867, {218.9498, 451.9500}, {219.6843, 451.6683}},
        {"drag S 0.5 v0 100", ^(Class k) {
             UIFieldBehavior *f = [k dragField];
             f.strength = 0.5;
             return f;
         }, {100, 0}, 60, 1.2 * 0.08682, {380.3465, 400}, {380.4333, 400}},
        {"velocity (1,-0.5)", ^(Class k) { return [k velocityFieldWithVector:CGVectorMake(1, -0.5)]; }, {0, 0}, 60, 1.2 * 0.9317, {399.1680, 350.4174}, {398.3347, 350.8341}},
    };
    for (size_t index = 0; index < sizeof(cases) / sizeof(cases[0]); index++) {
        TrajectoryCase c = cases[index];
        CGPoint oracle[60], ours[60];
        trajectory(Oracle, c, oracle);
        trajectory(Ours, c, ours);
        double worst = 0;
        int worstFrame = 0;
        for (int step = 0; step < c.frames; step++) {
            double error = hypot(ours[step].x - oracle[step].x, ours[step].y - oracle[step].y);
            if (!(error <= worst)) {
                worst = error;
                worstFrame = step + 1;
            }
        }
        charon_check(worst <= c.tolerance, "F4 emulated field trajectory within the error s_fld measured",
                     [NSString stringWithFormat:@"%s: worst %.6g pt at frame %d over %d frames (tolerance %.6g)", c.name, worst, worstFrame, c.frames, c.tolerance]);
        printf("F4 %s: worst %.6g pt at frame %d; f%d ours (%.4f, %.4f) oracle (%.4f, %.4f)\n", c.name, worst, worstFrame, c.frames,
               ours[c.frames - 1].x, ours[c.frames - 1].y, oracle[c.frames - 1].x, oracle[c.frames - 1].y);
        if (!isnan(c.appleF60.x)) {
            // s_fld.m (§10.7), printed to 4 decimals.
            check_near(oracle[59].x, c.appleF60.x, 5e-5, "oracle field trajectory is as s_fld measured", [@(c.name) stringByAppendingString:@" f60 x"]);
            check_near(oracle[59].y, c.appleF60.y, 5e-5, "oracle field trajectory is as s_fld measured", [@(c.name) stringByAppendingString:@" f60 y"]);
            // The emulation s_fld.m ran over the host's classes lands where ours does, to the 4 decimals printed.
            check_near(ours[59].x, c.emulationF60.x, 5e-5, "F4 ours at frame 60 as s_fld's emulation", [@(c.name) stringByAppendingString:@" f60 x"]);
            check_near(ours[59].y, c.emulationF60.y, 5e-5, "F4 ours at frame 60 as s_fld's emulation", [@(c.name) stringByAppendingString:@" f60 y"]);
        }
    }
}

int main(void)
{
    @autoreleasepool {
        // PhysicsKit's points-per-metre ratio is 150 until the process makes its first UIDynamicAnimator (region_test.m):
        // a field's position and minimum radius are converted with it, so the oracle is put in UIKit's state first.
        (void)make_animator(Oracle, nil);
        test_properties();
        test_object();
        test_float_range();
        test_categories();
        test_where();
        test_forces();
        test_trajectories();
        return finish();
    }
}
