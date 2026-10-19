// group_test.m - facts/UIKit/UIFieldBehavior.md §16 rows G1, G2 and G3: UIDynamicItemGroup outside an animator (the
// center, bounds and transform algebra of §12.1), its exceptions (§12.1, §12.5), and a group falling in an animator
// (§12.5). Each scene runs with the host's group (the oracle) and with ours over the same kind of items; ours is
// compared with the oracle's answer, and the oracle with the numbers the facts file gives as measured, so a scene that
// is not the probe's shows up as such.
//
// In an animator the two are not the same thing: the host's 9.0 animator builds one compound body with a box per member
// and rounds the group's center like a view's, ours (written over the 7.0 animator API) is one rectangle of the union
// box, not rounded (§12.5). G3 therefore compares ours with two oracles: the host's own group, within the rounding the
// facts file measured, and the host's animator driving a plain item of the union box at the group's center (the
// "box proxy" of s_grp.m), which is what ours must match.
#import "dynamics.h"
#include <math.h>

static const double frame = 1.0 / 60.0;

static UIDynamicItemGroup *group_of(Side side, NSArray *items)
{
    return [MAKE(side, UIDynamicItemGroup) initWithItems:items];
}

static void check_point(CGPoint ours, CGPoint oracle, double tolerance, const char *name, NSString *context)
{
    check_near(ours.x, oracle.x, tolerance, name, [context stringByAppendingString:@" x"]);
    check_near(ours.y, oracle.y, tolerance, name, [context stringByAppendingString:@" y"]);
}

static NSArray *transform_values(CGAffineTransform t)
{
    return @[@(t.a), @(t.b), @(t.c), @(t.d), @(t.tx), @(t.ty)];
}

#pragma mark G1: the object

// Every number the group and its members answer along one script, in order.
static NSArray *algebra(Side side)
{
    NSMutableArray *found = [NSMutableArray array];
    void (^record)(NSString *, NSArray *) = ^(NSString *label, NSArray *values) {
        [found addObject:@[label, values]];
    };

    UIDynamicItemGroup *made = [MAKE(side, UIDynamicItemGroup) init];
    record(@"-init: items is nil, center, bounds", @[@(made.items == nil), @(made.center.x), @(made.center.y), @(made.bounds.size.width)]);
    UIDynamicItemGroup *empty = group_of(side, @[]);
    record(@"empty: items, center, bounds, transform",
           [@[@(empty.items.count), @(empty.center.x), @(empty.bounds.origin.x), @(empty.bounds.size.width), @(empty.bounds.size.height)]
               arrayByAddingObjectsFromArray:transform_values(empty.transform)]);

    Item *a = [Item itemAt:CGPointMake(100, 100) size:CGSizeMake(100, 100)];
    Item *b = [Item itemAt:CGPointMake(220, 130) size:CGSizeMake(50, 20)];
    UIDynamicItemGroup *group = group_of(side, @[a, b]);
    record(@"init: center is the middle of the union, bounds its size, transform all zero",
           [@[@(group.center.x), @(group.center.y), @(group.bounds.origin.x), @(group.bounds.origin.y), @(group.bounds.size.width), @(group.bounds.size.height)]
               arrayByAddingObjectsFromArray:transform_values(group.transform)]);
    record(@"items are the members", @[@(group.items.count), @([group.items containsObject:a]), @([group.items containsObject:b])]);
    record(@"no collision bounds members", @[@([group respondsToSelector:@selector(collisionBoundsType)]), @([group respondsToSelector:@selector(collisionBoundingPath)])]);

    group.center = CGPointMake(157.5, 105);
    record(@"setCenter: moves the members by the change", @[@(a.center.x), @(a.center.y), @(b.center.x), @(b.center.y), @(group.center.x), @(group.center.y)]);

    CGAffineTransform turn = CGAffineTransformMakeRotation(0.3);
    turn.tx = 7;
    group.transform = turn;
    record(@"setTransform: rot 0.3 tx 7 places the members from their init offsets",
           [@[@(a.center.x), @(a.center.y), @(b.center.x), @(b.center.y)] arrayByAddingObjectsFromArray:transform_values(a.transform)]);
    record(@"bounds follow the members", @[@(group.bounds.size.width), @(group.bounds.size.height), @(group.center.x), @(group.center.y)]);

    a.center = CGPointMake(0, 0);
    group.transform = turn;
    record(@"an equal transform writes nothing", @[@(a.center.x), @(a.center.y)]);

    group.center = CGPointMake(167.5, 100);
    record(@"setCenter: keeps a member's own displacement", @[@(a.center.x), @(a.center.y), @(b.center.x), @(b.center.y)]);

    group.transform = CGAffineTransformIdentity;
    record(@"identity puts the members at center plus offset", [@[@(a.center.x), @(a.center.y), @(b.center.x), @(b.center.y)]
                                                                   arrayByAddingObjectsFromArray:transform_values(b.transform)]);

    Item *turned = [Item itemAt:CGPointMake(0, 0) size:CGSizeMake(100, 20)];
    turned.transform = CGAffineTransformMakeRotation(M_PI_2);
    Item *other = [Item itemAt:CGPointMake(200, 0) size:CGSizeMake(10, 10)];
    UIDynamicItemGroup *rotated = group_of(side, @[turned, other]);
    record(@"a member's transform is not looked at", @[@(rotated.bounds.size.width), @(rotated.bounds.size.height), @(rotated.center.x), @(rotated.center.y)]);

    UIDynamicItemGroup *twice = group_of(side, @[a, a]);
    record(@"a duplicate member is one member", @[@(twice.items.count)]);
    return found;
}

static void test_algebra(void)
{
    NSArray *oracle = algebra(Oracle), *ours = algebra(Ours);
    for (NSUInteger row = 0; row < oracle.count; row++) {
        NSArray *expected = oracle[row][1], *actual = ours[row][1];
        for (NSUInteger column = 0; column < expected.count; column++) {
            // 1e-9 (§16): the setters' arithmetic is double on both sides.
            check_near([actual[column] doubleValue], [expected[column] doubleValue], 1e-9, "G1 group algebra as the oracle",
                       [NSString stringWithFormat:@"%@ [%lu]", oracle[row][0], (unsigned long)column]);
        }
    }
    // g_group1.m (§12.1): A (119.121517, 90.9627902), B (224.896289, 155.08531) after rot 0.3 tx 7; bounds 180.774772 x
    // 124.122519; the fresh transform all zero. Printed to 9 digits.
    NSArray *placed = oracle[6][1], *bounds = oracle[7][1], *fresh = oracle[2][1];
    check_near([placed[0] doubleValue], 119.121517, 5e-7, "oracle group is as g_group1 measured", @"A x");
    check_near([placed[1] doubleValue], 90.9627902, 5e-8, "oracle group is as g_group1 measured", @"A y");
    check_near([placed[2] doubleValue], 224.896289, 5e-7, "oracle group is as g_group1 measured", @"B x");
    check_near([placed[3] doubleValue], 155.08531, 5e-6, "oracle group is as g_group1 measured", @"B y");
    check_near([bounds[0] doubleValue], 180.774772, 5e-7, "oracle group is as g_group1 measured", @"bounds width");
    check_near([bounds[1] doubleValue], 124.122519, 5e-7, "oracle group is as g_group1 measured", @"bounds height");
    CHECK([fresh[6] doubleValue] == 0 && [fresh[9] doubleValue] == 0, "oracle group is as g_group1 measured");
}

#pragma mark G2: exceptions

static NSString *outcome(void (^block)(void))
{
    @try {
        block();
    } @catch (NSException *exception) {
        return [NSString stringWithFormat:@"%@: %@", exception.name, normalized(exception.reason)];
    }
    return @"no exception";
}

static NSArray *exceptions(Side side)
{
    Item *a = [Item itemAt:CGPointMake(100, 100) size:CGSizeMake(10, 10)];
    UIDynamicItemGroup *inner = group_of(side, @[a]);
    NSString *nested = outcome(^{
        (void)group_of(side, @[[Item itemAt:CGPointMake(0, 0) size:CGSizeMake(5, 5)], inner]);
    });
    UIDynamicItemGroup *empty = group_of(side, @[]);
    UIDynamicAnimator *animator = make_animator(side, nil);
    NSString *emptyInAnimator = outcome(^{
        [animator addBehavior:[MAKE(side, UIGravityBehavior) initWithItems:@[empty]]];
    });
    return @[nested, emptyInAnimator];
}

static void test_exceptions(void)
{
    NSArray *oracle = exceptions(Oracle), *ours = exceptions(Ours);
    const char *rows[] = {"a group among the items", "an empty group in an animator"};
    for (NSUInteger index = 0; index < oracle.count; index++) {
        charon_check([ours[index] isEqualToString:oracle[index]], "G2 group exception name and text are the oracle's",
                     [NSString stringWithFormat:@"%s: ours \"%@\" oracle \"%@\"", rows[index], ours[index], oracle[index]]);
    }
    // g_conf.m (§12.1, §12.2): the name is literally "Invalid Argument".
    CHECK_EQUAL(oracle[0], @"Invalid Argument: UIDynamicItemGroup cannot be initialized with items containing UIDynamicItemGroup",
                "oracle group exceptions are as g_conf measured");
    CHECK([oracle[1] hasPrefix:@"NSInternalInconsistencyException: Invalid size {0, 0} for item <UIDynamicItemGroup: 0x"],
          "oracle group exceptions are as g_conf measured");
}

#pragma mark G3: a group in an animator

// s_grp.m's members, A 100x100 at (100,100) and B 50x20 at (220,130), under gravity for `frames` frames. `proxy`: the
// host's animator drives a plain item of the group's union box at the group's center instead, and B is placed from it.
static void fall(Side side, BOOL proxy, int frames, CGPoint b[], CGAffineTransform *firstTransform)
{
    UIDynamicAnimator *animator = make_animator(side, nil);
    Item *a = [Item itemAt:CGPointMake(100, 100) size:CGSizeMake(100, 100)];
    Item *member = [Item itemAt:CGPointMake(220, 130) size:CGSizeMake(50, 20)];
    UIDynamicItemGroup *group = group_of(side, @[a, member]);
    Item *box = [Item itemAt:group.center size:group.bounds.size];
    CGPoint offset = CGPointMake(member.center.x - group.center.x, member.center.y - group.center.y);
    [animator addBehavior:[MAKE(side, UIGravityBehavior) initWithItems:@[proxy ? box : group]]];
    for (int index = 0; index < frames; index++) {
        animator_step(animator, frame);
        b[index] = proxy ? CGPointMake(box.center.x + offset.x, box.center.y + offset.y) : member.center;
        if (index == 0 && firstTransform)
            *firstTransform = member.transform;
    }
}

static void test_animator(void)
{
    enum { frames = 20 };
    CGPoint oracle[frames], proxy[frames], ours[frames];
    CGAffineTransform oracleFirst = {0}, oursFirst = {0};
    fall(Oracle, NO, frames, oracle, &oracleFirst);
    fall(Oracle, YES, frames, proxy, NULL);
    fall(Ours, NO, frames, ours, &oursFirst);
    for (int index = 0; index < frames; index++) {
        NSString *context = [NSString stringWithFormat:@"member B frame %d", index + 1];
        // 1e-3 pt (§16 G3): ours is one box body, as the proxy.
        check_point(ours[index], proxy[index], 1e-3, "G3 group falls as the box proxy on the oracle", context);
        // §12.5: the host's compound body is rounded like a view, measured at most 0.2068 pt from the box over 20 frames.
        check_point(ours[index], oracle[index], 0.21, "G3 group falls as the oracle's group within its rounding", context);
    }
    // s_grp.m (§12.5): B at frame 20, Apple (220, 183.5), box (220, 183.5551).
    check_point(oracle[frames - 1], CGPointMake(220, 183.5), 5e-7, "oracle group falls as s_grp measured", @"compound B frame 20");
    check_point(proxy[frames - 1], CGPointMake(220, 183.5551), 5e-5, "oracle group falls as s_grp measured", @"box proxy B frame 20");
    // §12.3: the first step writes the rotation 0 over the fresh zero transform, to the group and every member.
    NSArray *expected = transform_values(oracleFirst), *actual = transform_values(oursFirst);
    CHECK([expected isEqual:transform_values(CGAffineTransformIdentity)], "oracle group's first step writes identity to the members");
    charon_check([actual isEqual:expected], "G3 the first step writes the members' transform as the oracle",
                 [NSString stringWithFormat:@"ours %@ oracle %@", actual, expected]);
}

int main(void)
{
    @autoreleasepool {
        test_algebra();
        test_exceptions();
        test_animator();
        return finish();
    }
}
