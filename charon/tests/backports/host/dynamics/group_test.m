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
            check_near([actual[column] doubleValue], [expected[column] doubleValue], 1e-9, "G1 group algebra as the oracle",
                       [NSString stringWithFormat:@"%@ [%lu]", oracle[row][0], (unsigned long)column]);
        }
    }
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
    CHECK_EQUAL(oracle[0], @"Invalid Argument: UIDynamicItemGroup cannot be initialized with items containing UIDynamicItemGroup",
                "oracle group exceptions are as g_conf measured");
    CHECK([oracle[1] hasPrefix:@"NSInternalInconsistencyException: Invalid size {0, 0} for item <UIDynamicItemGroup: 0x"],
          "oracle group exceptions are as g_conf measured");
}

#pragma mark G3: a group in an animator

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
        check_point(ours[index], proxy[index], 1e-3, "G3 group falls as the box proxy on the oracle", context);
        check_point(ours[index], oracle[index], 0.21, "G3 group falls as the oracle's group within its rounding", context);
    }
    check_point(oracle[frames - 1], CGPointMake(220, 183.5), 5e-7, "oracle group falls as s_grp measured", @"compound B frame 20");
    check_point(proxy[frames - 1], CGPointMake(220, 183.5551), 5e-5, "oracle group falls as s_grp measured", @"box proxy B frame 20");
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
