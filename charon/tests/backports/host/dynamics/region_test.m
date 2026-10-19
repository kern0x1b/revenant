// region_test.m - facts/UIKit/UIFieldBehavior.md §16 row F2 and UIRegion's own behaviour (§10.6): the same regions are
// built from the host's UIRegion (the oracle) and from ours, and every region is asked about the same points; ours must
// answer as the oracle does, point for point. The regions cover the primitive shapes with their edges, negative and
// zero sizes, the inverse, the three operations with plain and inverted operands, operations chained on a composite
// (the host keeps one second operand only), copies, archives, the shared infinite region and a region made by -init.
#import "dynamics.h"
#include <math.h>

typedef UIRegion *(^RegionMaker)(Side side);

static UIRegion *circle(Side side, CGFloat radius)
{
    return [MAKE(side, UIRegion) initWithRadius:radius];
}

static UIRegion *rectangle(Side side, CGFloat width, CGFloat height)
{
    return [MAKE(side, UIRegion) initWithSize:CGSizeMake(width, height)];
}

static UIRegion *infinite(Side side)
{
    return [side_class(side, @"UIRegion") infiniteRegion];
}

static UIRegion *archived(UIRegion *region)
{
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:region requiringSecureCoding:NO error:NULL];
    NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingFromData:data error:NULL];
    unarchiver.requiresSecureCoding = NO;
    return [unarchiver decodeObjectForKey:NSKeyedArchiveRootObjectKey];
}

static NSDictionary<NSString *, RegionMaker> *regions(void)
{
    return @{
        @"circle 50": ^(Side s) { return circle(s, 50); },
        @"circle 0": ^(Side s) { return circle(s, 0); },
        @"circle -5": ^(Side s) { return circle(s, -5); },
        @"circle 0.3": ^(Side s) { return circle(s, 0.3); },
        @"rect 100x50": ^(Side s) { return rectangle(s, 100, 50); },
        @"rect -10x10": ^(Side s) { return rectangle(s, -10, 10); },
        @"rect 0x20": ^(Side s) { return rectangle(s, 0, 20); },
        @"rect 33.3x0.7": ^(Side s) { return rectangle(s, 33.3, 0.7); },
        @"infinite": ^(Side s) { return infinite(s); },
        @"init": ^(Side s) { return [MAKE(s, UIRegion) init]; },
        @"inverse circle": ^(Side s) { return [circle(s, 50) inverseRegion]; },
        @"inverse rect": ^(Side s) { return [rectangle(s, 100, 50) inverseRegion]; },
        @"inverse infinite": ^(Side s) { return [infinite(s) inverseRegion]; },
        @"inverse inverse rect": ^(Side s) { return [[rectangle(s, 100, 50) inverseRegion] inverseRegion]; },
        @"inverse init": ^(Side s) { return [[MAKE(s, UIRegion) init] inverseRegion]; },
        @"circle | rect": ^(Side s) { return [circle(s, 50) regionByUnionWithRegion:rectangle(s, 100, 50)]; },
        @"circle - rect": ^(Side s) { return [circle(s, 50) regionByDifferenceFromRegion:rectangle(s, 100, 50)]; },
        @"circle & rect": ^(Side s) { return [circle(s, 50) regionByIntersectionWithRegion:rectangle(s, 100, 50)]; },
        @"rect & circle": ^(Side s) { return [rectangle(s, 100, 50) regionByIntersectionWithRegion:circle(s, 50)]; },
        @"rect - circle 30": ^(Side s) { return [rectangle(s, 100, 50) regionByDifferenceFromRegion:circle(s, 30)]; },
        @"circle | inverse rect": ^(Side s) { return [circle(s, 50) regionByUnionWithRegion:[rectangle(s, 100, 50) inverseRegion]]; },
        @"circle - inverse rect": ^(Side s) { return [circle(s, 50) regionByDifferenceFromRegion:[rectangle(s, 100, 50) inverseRegion]]; },
        @"circle & inverse rect": ^(Side s) { return [circle(s, 50) regionByIntersectionWithRegion:[rectangle(s, 100, 50) inverseRegion]]; },
        @"inverse circle | rect": ^(Side s) { return [[circle(s, 50) inverseRegion] regionByUnionWithRegion:rectangle(s, 100, 50)]; },
        @"inverse circle & rect": ^(Side s) { return [[circle(s, 50) inverseRegion] regionByIntersectionWithRegion:rectangle(s, 100, 50)]; },
        @"inverse (circle | rect)": ^(Side s) { return [[circle(s, 50) regionByUnionWithRegion:rectangle(s, 100, 50)] inverseRegion]; },
        @"(circle | rect) & circle 30": ^(Side s) { return [[circle(s, 50) regionByUnionWithRegion:rectangle(s, 100, 50)] regionByIntersectionWithRegion:circle(s, 30)]; },
        @"circle | (rect - circle 30)": ^(Side s) { return [circle(s, 20) regionByUnionWithRegion:[rectangle(s, 100, 50) regionByDifferenceFromRegion:circle(s, 30)]]; },
        @"circle | infinite": ^(Side s) { return [circle(s, 50) regionByUnionWithRegion:infinite(s)]; },
        @"circle - infinite": ^(Side s) { return [circle(s, 50) regionByDifferenceFromRegion:infinite(s)]; },
        @"circle & infinite": ^(Side s) { return [circle(s, 50) regionByIntersectionWithRegion:infinite(s)]; },
        @"circle - inverse infinite": ^(Side s) { return [circle(s, 50) regionByDifferenceFromRegion:[infinite(s) inverseRegion]]; },
        @"infinite - circle": ^(Side s) { return [infinite(s) regionByDifferenceFromRegion:circle(s, 50)]; },
        @"init | circle": ^(Side s) { return [[MAKE(s, UIRegion) init] regionByUnionWithRegion:circle(s, 50)]; },
        @"copy of circle - rect": ^(Side s) { return [[circle(s, 50) regionByDifferenceFromRegion:rectangle(s, 100, 50)] copy]; },
        @"archived inverse (circle | rect)": ^(Side s) { return archived([[circle(s, 50) regionByUnionWithRegion:rectangle(s, 100, 50)] inverseRegion]); },
        @"archived circle & rect": ^(Side s) { return archived([circle(s, 50) regionByIntersectionWithRegion:rectangle(s, 100, 50)]); },
    };
}

static NSArray<NSValue *> *points(void)
{
    const CGPoint list[] = {
        {0, 0}, {50, 0}, {0, 25}, {-50, -25}, {-50, 0}, {49.999, 0}, {50.001, 0}, {0, 24.999}, {3, 0}, {-3, 0},
        {5, 0}, {100, 0}, {60, 0}, {45, 20}, {35.3553, 35.3553}, {35.3554, 35.3554}, {30, 0}, {0, 30}, {25, 24.99},
        {10, -100}, {1e9, 1e9}, {-1e9, 3}, {0.3, 0}, {0.29, 0.05}, {16.65, 0.35}, {16.649, 0.349}, {0, 10}, {5, 10},
        {NAN, 0}, {0, NAN}, {INFINITY, 0}, {-INFINITY, -INFINITY},
    };
    NSMutableArray *found = [NSMutableArray array];
    for (size_t index = 0; index < sizeof(list) / sizeof(list[0]); index++)
        [found addObject:[NSValue valueWithCGPoint:list[index]]];
    return found;
}

static void test_truth_table(void)
{
    NSDictionary<NSString *, RegionMaker> *made = regions();
    NSArray<NSValue *> *probes = points();
    for (NSString *name in [made.allKeys sortedArrayUsingSelector:@selector(compare:)]) {
        UIRegion *oracle = made[name](Oracle), *ours = made[name](Ours);
        for (NSValue *value in probes) {
            CGPoint point = value.CGPointValue;
            BOOL expected = [oracle containsPoint:point], actual = [ours containsPoint:point];
            charon_check(actual == expected, "F2 a region contains what the oracle's contains",
                         [NSString stringWithFormat:@"%@ at (%g, %g): ours %d oracle %d", name, point.x, point.y, actual, expected]);
        }
    }
}

// The rows facts/UIKit/UIFieldBehavior.md §10.6 gives as measured (s_reg.m), asked of the oracle, so a change of the
// host shows here and not as a silent change of what ours is compared with.
static void test_oracle_as_measured(void)
{
    UIRegion *round = circle(Oracle, 50), *box = rectangle(Oracle, 100, 50);
    UIRegion *both = [round regionByIntersectionWithRegion:box];
    CHECK([round containsPoint:CGPointMake(50, 0)] && ![round containsPoint:CGPointMake(50.001, 0)], "oracle regions are as s_reg measured");
    CHECK(![box containsPoint:CGPointMake(50, 0)] && ![box containsPoint:CGPointMake(0, 25)], "oracle regions are as s_reg measured");
    CHECK([both containsPoint:CGPointMake(50, 0)] && [both containsPoint:CGPointMake(0, 25)], "oracle regions are as s_reg measured");
    CHECK([circle(Oracle, -5) containsPoint:CGPointMake(3, 0)], "oracle regions are as s_reg measured");
}

static NSArray *identities(Side side)
{
    UIRegion *shared = infinite(side), *round = circle(side, 5), *copy = [round copy];
    return @[@(shared == infinite(side)), @([shared copy] == shared), @(copy == round), @([copy isEqual:round]),
             @([circle(side, 5) isEqual:circle(side, 5)]), @([copy class] == [round class]),
             @([[round inverseRegion] class] == [round class]), @([side_class(side, @"UIRegion") conformsToProtocol:@protocol(NSCopying)]),
             @([side_class(side, @"UIRegion") conformsToProtocol:@protocol(NSCoding)]),
             @([side_class(side, @"UIRegion") respondsToSelector:@selector(supportsSecureCoding)])];
}

static void test_identities(void)
{
    NSArray *oracle = identities(Oracle), *ours = identities(Ours);
    const char *rows[] = {"infiniteRegion is shared", "a copy of the infinite region is new", "a copy is new", "a copy is not equal",
                          "equal circles are not equal", "a copy has the class", "an inverse has the class", "NSCopying", "NSCoding",
                          "no secure coding"};
    for (NSUInteger index = 0; index < oracle.count; index++) {
        charon_check([ours[index] isEqual:oracle[index]], "F2 region identity is the oracle's",
                     [NSString stringWithFormat:@"%s: ours %@ oracle %@", rows[index], ours[index], oracle[index]]);
    }
}

// The host dereferences the other region's PKRegion unchecked, so a nil operand, or one made with -init, is a bad
// access there (-[UIRegion regionByUnionWithRegion:] loads [nil + 8]); ours raises instead. Not asked of the oracle.
static void test_refused_operand(void)
{
    UIRegion *round = circle(Ours, 5);
    for (int kind = 0; kind < 2; kind++) {
        UIRegion *other = kind == 0 ? nil : [MAKE(Ours, UIRegion) init];
        NSString *name = nil;
        @try {
            (void)[round regionByUnionWithRegion:other];
        } @catch (NSException *exception) {
            name = exception.name;
        }
        CHECK_EQUAL(name, NSInvalidArgumentException, "an operand without a shape is refused, not dereferenced");
    }
}

int main(void)
{
    @autoreleasepool {
        // PhysicsKit's points-per-metre ratio is SpriteKit's 150 until the process makes its first UIDynamicAnimator,
        // which sets it to UIKit's 100 for good (p4.m: PKGet_PTM_RATIO 150 before, 100 after); a region takes it at
        // init, so a circle of 0.3 made before any animator is 45 * (1/150f) = 0.300000012 and one made after is
        // 30 * 0.01f = 0.29999998. Ours always uses 100, the ratio UIKit Dynamics runs with: the oracle is put in that
        // state first.
        (void)make_animator(Oracle, nil);
        test_truth_table();
        test_oracle_as_measured();
        test_identities();
        test_refused_operand();
        return finish();
    }
}
