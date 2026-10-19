// structure_test.m — the rows of facts/UIKit/UIDynamicAnimator.md §12 that do not depend on the integrator: T3 (push
// algebra), T7 (collision masks), T8 (the world's gravity), T9 (exception names and texts), T10 (the order of a step),
// T11/T12 (attachment geometry and the 9.0 factories), T13 (anchored, charge), T14 (itemsInRect:), T17 (several item
// behaviors on one item), and an animator released while its display link could still start. Each scene runs on the
// host's animator (the oracle) and on ours, and ours is compared with the oracle's answer, exactly unless the row says
// otherwise.
#import "dynamics.h"
#include <math.h>

static const double frame = 1.0 / 60.0;

static void check_same(double ours, double oracle, const char *name, NSString *context)
{
    check_equal_double(ours, oracle, name, context);
}

#pragma mark T3: push direction, angle and magnitude

static NSArray *push_algebra(Side side)
{
    NSMutableArray *answers = [NSMutableArray array];
    Item *item = [Item itemAt:CGPointMake(50, 50) size:CGSizeMake(10, 10)];
    UIPushBehavior *push = [MAKE(side, UIPushBehavior) initWithItems:@[item] mode:UIPushBehaviorModeContinuous];
    [answers addObject:@[@(push.angle), @(push.magnitude), @(push.pushDirection.dx), @(push.pushDirection.dy), @(push.active)]];
    push.pushDirection = CGVectorMake(3, 4);
    [answers addObject:@[@(push.angle), @(push.magnitude)]];
    push.magnitude = 0;
    [answers addObject:@[@(push.angle), @(push.magnitude), @(push.pushDirection.dx), @(push.pushDirection.dy)]];
    push.magnitude = 2;
    [answers addObject:@[@(push.pushDirection.dx), @(push.pushDirection.dy)]];
    push.angle = M_PI;
    [answers addObject:@[@(push.pushDirection.dx), @(push.pushDirection.dy)]];
    [push setAngle:1 magnitude:-1];
    [answers addObject:@[@(push.angle), @(push.magnitude), @(push.pushDirection.dx), @(push.pushDirection.dy)]];
    return answers;
}

static void test_push_algebra(void)
{
    NSArray *oracle = push_algebra(Oracle), *ours = push_algebra(Ours);
    for (NSUInteger row = 0; row < oracle.count; row++) {
        for (NSUInteger column = 0; column < [oracle[row] count]; column++) {
            check_same([ours[row][column] doubleValue], [oracle[row][column] doubleValue], "T3 push property algebra",
                       [NSString stringWithFormat:@"step %lu value %lu", (unsigned long)row, (unsigned long)column]);
        }
    }
    // s_push.m: (3,4) is angle 0.927295218, magnitude 5; setAngle:1 magnitude:-1 reads (-0.540302277,-0.841470957).
    check_near([oracle[1][0] doubleValue], 0.927295218, 5e-10, "oracle pushes as s_push measured", @"angle of (3,4)");
    check_near([oracle[5][2] doubleValue], -0.540302277, 5e-10, "oracle pushes as s_push measured", @"dx of angle 1 magnitude -1");
}

#pragma mark T7: collision masks

static NSArray *masks(Side side)
{
    UIDynamicAnimator *animator = make_animator(side, nil);
    Item *a = [Item itemAt:CGPointMake(100, 100) size:CGSizeMake(20, 20)];
    Item *b = [Item itemAt:CGPointMake(200, 100) size:CGSizeMake(20, 20)];
    Item *c = [Item itemAt:CGPointMake(300, 100) size:CGSizeMake(20, 20)];
    UICollisionBehavior *first = [MAKE(side, UICollisionBehavior) initWithItems:@[a, b]];
    UICollisionBehavior *second = [MAKE(side, UICollisionBehavior) initWithItems:@[b, c]];
    second.collisionMode = UICollisionBehaviorModeItems;
    UICollisionBehavior *third = [MAKE(side, UICollisionBehavior) initWithItems:@[a, c]];
    third.collisionMode = UICollisionBehaviorModeBoundaries;
    [third addBoundaryWithIdentifier:@"floor" fromPoint:CGPointMake(0, 400) toPoint:CGPointMake(400, 400)];
    [animator addBehavior:first];
    [animator addBehavior:second];
    [animator addBehavior:third];
    animator_step(animator, frame);
    NSMutableArray *found = [NSMutableArray array];
    for (Item *item in @[a, b, c]) {
        id body = animator_body(animator, item);
        [found addObject:@[@([body categoryBitMask]), @([body collisionBitMask]), @([body contactTestBitMask])]];
    }
    [animator removeBehavior:second];
    animator_step(animator, frame);
    for (Item *item in @[a, b, c]) {
        id body = animator_body(animator, item);
        [found addObject:@[@([body categoryBitMask]), @([body collisionBitMask]), @([body contactTestBitMask])]];
    }
    return found;
}

static void test_masks(void)
{
    NSArray *oracle = masks(Oracle), *ours = masks(Ours);
    const char *names[] = {"a", "b", "c"};
    for (NSUInteger row = 0; row < oracle.count; row++) {
        charon_check([ours[row] isEqual:oracle[row]], "T7 collision masks are the oracle's",
                     [NSString stringWithFormat:@"%s%@: ours %@ oracle %@", names[row % 3], row < 3 ? @"" : @" after removing the second",
                                                [ours[row] componentsJoinedByString:@","], [oracle[row] componentsJoinedByString:@","]]);
    }
}

#pragma mark T8: the world's gravity

static NSArray *gravities(Side side)
{
    UIDynamicAnimator *animator = make_animator(side, nil);
    Item *item = [Item itemAt:CGPointMake(100, 100) size:CGSizeMake(20, 20)];
    NSMutableArray *found = [NSMutableArray array];
    void (^record)(void) = ^{
        animator_step(animator, frame);
        CGVector gravity = animator_gravity(animator);
        [found addObject:@[@(gravity.dx), @(gravity.dy)]];
    };
    UIGravityBehavior *first = [MAKE(side, UIGravityBehavior) initWithItems:@[item]];
    [animator addBehavior:first];
    record();
    UIGravityBehavior *second = [MAKE(side, UIGravityBehavior) initWithItems:@[item]];
    [second setAngle:0.25 magnitude:2];
    [animator addBehavior:second];
    record();
    first.magnitude = 3;
    record();
    [animator removeBehavior:first];
    record();
    [found addObject:@[@(second.angle), @(second.magnitude), @(second.gravityDirection.dx), @(second.gravityDirection.dy)]];
    return found;
}

static void test_gravity(void)
{
    NSArray *oracle = gravities(Oracle), *ours = gravities(Ours);
    for (NSUInteger row = 0; row < oracle.count; row++) {
        for (NSUInteger column = 0; column < [oracle[row] count]; column++) {
            check_near([ours[row][column] doubleValue], [oracle[row][column] doubleValue], 1e-6, "T8 world gravity and gravity properties are the oracle's",
                       [NSString stringWithFormat:@"step %lu value %lu", (unsigned long)row, (unsigned long)column]);
        }
    }
}

#pragma mark T9: exceptions

static NSString *raised(void (^block)(void))
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
    NSMutableArray *found = [NSMutableArray array];
    [found addObject:raised(^{
        (void)[MAKE(side, UISnapBehavior) init];
    })];
    [found addObject:raised(^{
        (void)[MAKE(side, UIAttachmentBehavior) init];
    })];
    [found addObject:raised(^{
        UIDynamicAnimator *animator = make_animator(side, nil);
        UIGravityBehavior *gravity = [MAKE(side, UIGravityBehavior) initWithItems:@[]];
        UIDynamicBehavior *parent = [MAKE(side, UIDynamicBehavior) init];
        [parent addChildBehavior:gravity];
        [animator addBehavior:parent];
        [animator addBehavior:gravity];
    })];
    [found addObject:raised(^{
        UIView *reference = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 400, 400)];
        UIView *outside = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 10, 10)];
        UIDynamicAnimator *animator = make_animator(side, reference);
        [animator addBehavior:[MAKE(side, UIGravityBehavior) initWithItems:@[outside]]];
        animator_step(animator, frame);
    })];
    [found addObject:raised(^{
        UIDynamicAnimator *animator = make_animator(side, nil);
        UIGravityBehavior *gravity = [MAKE(side, UIGravityBehavior) initWithItems:@[]];
        [animator addBehavior:gravity];
        [animator addBehavior:gravity];
    })];
    return found;
}

static void test_exceptions(void)
{
    NSArray *oracle = exceptions(Oracle), *ours = exceptions(Ours);
    const char *cases[] = {"UISnapBehavior init", "UIAttachmentBehavior init", "a child added as a top-level behavior",
                           "a view outside the reference view", "one behavior added twice"};
    for (NSUInteger index = 0; index < oracle.count; index++) {
        charon_check([ours[index] isEqualToString:oracle[index]], "T9 exception name and text are the oracle's",
                     [NSString stringWithFormat:@"%s: ours \"%@\" oracle \"%@\"", cases[index], ours[index], oracle[index]]);
    }
    // s_anim.m: init of a snap is refused with NSInvalidArgumentException.
    charon_check([oracle[0] hasPrefix:@"NSInvalidArgumentException: init is undefined for objects of type UISnapBehavior"],
                 "oracle refuses as s_anim measured", oracle[0]);
}

#pragma mark T10: the order of one step

@interface Recorder : NSObject <UICollisionBehaviorDelegate>
@property (nonatomic, strong) NSMutableArray *events;
@end

@implementation Recorder
- (void)collisionBehavior:(UICollisionBehavior *)behavior beganContactForItem:(id<UIDynamicItem>)item
   withBoundaryIdentifier:(id<NSCopying>)identifier atPoint:(CGPoint)point
{
    [self.events addObject:[NSString stringWithFormat:@"begin boundary %@", identifier]];
}

- (void)collisionBehavior:(UICollisionBehavior *)behavior endedContactForItem:(id<UIDynamicItem>)item
   withBoundaryIdentifier:(id<NSCopying>)identifier
{
    [self.events addObject:[NSString stringWithFormat:@"end boundary %@", identifier]];
}
@end

static NSArray *step_order(Side side)
{
    UIDynamicAnimator *animator = make_animator(side, nil);
    Item *item = [Item itemAt:CGPointMake(100, 380) size:CGSizeMake(20, 20)];
    Recorder *recorder = [Recorder new];
    recorder.events = [NSMutableArray array];
    UICollisionBehavior *collision = [MAKE(side, UICollisionBehavior) initWithItems:@[item]];
    [collision addBoundaryWithIdentifier:@"floor" fromPoint:CGPointMake(0, 400) toPoint:CGPointMake(400, 400)];
    collision.collisionDelegate = recorder;
    UIGravityBehavior *gravity = [MAKE(side, UIGravityBehavior) initWithItems:@[item]];
    __block CGPoint seen = CGPointZero;
    __block int step = 0;
    __weak UIDynamicAnimator *weakAnimator = animator;
    UIGravityBehavior *late = [MAKE(side, UIGravityBehavior) initWithItems:@[]];
    gravity.action = ^{
        seen = item.center;
        step++;
        [recorder.events addObject:[NSString stringWithFormat:@"action %d center moved %d", step, !CGPointEqualToPoint(seen, CGPointMake(100, 380))]];
        if (step == 2) {
            [weakAnimator addBehavior:late];
            [recorder.events addObject:[NSString stringWithFormat:@"added inside the step: behaviors %lu", (unsigned long)weakAnimator.behaviors.count]];
        }
    };
    [animator addBehavior:collision];
    [animator addBehavior:gravity];
    for (int index = 0; index < 30; index++) {
        animator_step(animator, frame);
        [recorder.events addObject:@"|"];
    }
    [recorder.events addObject:[NSString stringWithFormat:@"after: behaviors %lu", (unsigned long)animator.behaviors.count]];
    return recorder.events;
}

// The order within each step (T10 is "order only"): the step's contact callbacks, then its action, which already
// sees the written-back centre; a behavior added inside the step waits for the step's end. When a contact begins or
// ends is physics, not order: the two engines are held to a tolerance there (T5), so the frame of a contact event
// may differ by one, and only which events occur is compared.
static NSString *step_shape(NSArray *events)
{
    NSMutableArray *shape = [NSMutableArray array];
    NSMutableSet *kinds = [NSMutableSet set];
    BOOL acted = NO, ordered = YES;
    for (NSString *event in events) {
        if ([event isEqualToString:@"|"]) {
            acted = NO;
        } else if ([event hasPrefix:@"action"]) {
            acted = YES;
            [shape addObject:event];
        } else if ([event hasPrefix:@"begin"] || [event hasPrefix:@"end"]) {
            ordered = ordered && !acted;
            [kinds addObject:event];
        } else {
            [shape addObject:event];
        }
    }
    return [NSString stringWithFormat:@"contacts before the action of their step: %d; kinds: %@; %@", ordered,
            [[kinds.allObjects sortedArrayUsingSelector:@selector(compare:)] componentsJoinedByString:@", "], [shape componentsJoinedByString:@"; "]];
}

static void test_step_order(void)
{
    NSString *oracle = step_shape(step_order(Oracle)), *ours = step_shape(step_order(Ours));
    charon_check([ours isEqualToString:oracle], "T10 write-back, contacts and actions come in the oracle's order",
                 [NSString stringWithFormat:@"ours %@ oracle %@", ours, oracle]);
    charon_check([oracle hasPrefix:@"contacts before the action of their step: 1; kinds: begin boundary floor, end boundary floor;"],
                 "oracle reports the floor contacts before its actions", oracle);
}

#pragma mark T11 / T12: attachments

static NSArray *attachment_answers(UIAttachmentBehavior *attachment)
{
    return @[@(attachment.attachedBehaviorType), @(attachment.length), @(attachment.damping), @(attachment.frequency),
             @(attachment.frictionTorque), @(attachment.attachmentRange.minimum), @(attachment.attachmentRange.maximum),
             @(attachment.anchorPoint.x), @(attachment.anchorPoint.y), @(attachment.items.count)];
}

static NSArray *attachments(Side side)
{
    NSMutableArray *found = [NSMutableArray array];
    Item *a = [Item itemAt:CGPointMake(100, 100) size:CGSizeMake(40, 40)];
    Item *b = [Item itemAt:CGPointMake(260, 220) size:CGSizeMake(40, 40)];
    NSArray *made = @[
        [MAKE(side, UIAttachmentBehavior) initWithItem:a attachedToAnchor:CGPointMake(300, 100)],
        [MAKE(side, UIAttachmentBehavior) initWithItem:a offsetFromCenter:UIOffsetMake(10, -20) attachedToAnchor:CGPointMake(250, 30)],
        [MAKE(side, UIAttachmentBehavior) initWithItem:a attachedToItem:b],
        [MAKE(side, UIAttachmentBehavior) initWithItem:a offsetFromCenter:UIOffsetMake(-5, 5) attachedToItem:b offsetFromCenter:UIOffsetMake(8, 3)],
        [side_class(side, @"UIAttachmentBehavior") fixedAttachmentWithItem:a attachedToItem:b attachmentAnchor:CGPointMake(180, 160)],
        [side_class(side, @"UIAttachmentBehavior") pinAttachmentWithItem:a attachedToItem:b attachmentAnchor:CGPointMake(180, 160)],
        [side_class(side, @"UIAttachmentBehavior") slidingAttachmentWithItem:a attachedToItem:b attachmentAnchor:CGPointMake(180, 160) axisOfTranslation:CGVectorMake(1, 1)],
        [side_class(side, @"UIAttachmentBehavior") slidingAttachmentWithItem:a attachmentAnchor:CGPointMake(180, 160) axisOfTranslation:CGVectorMake(0, 1)],
        [side_class(side, @"UIAttachmentBehavior") limitAttachmentWithItem:a offsetFromCenter:UIOffsetMake(3, 4) attachedToItem:b offsetFromCenter:UIOffsetMake(-2, 1)],
    ];
    for (UIAttachmentBehavior *attachment in made)
        [found addObject:attachment_answers(attachment)];
    // In an animator: the length a distance joint answers once associated, and after the items moved.
    UIDynamicAnimator *animator = make_animator(side, nil);
    UIAttachmentBehavior *rope = made[2];
    [animator addBehavior:rope];
    animator_step(animator, frame);
    [found addObject:attachment_answers(rope)];
    rope.length = 50;
    rope.frequency = 2;
    rope.damping = 0.3;
    for (int index = 0; index < 10; index++)
        animator_step(animator, frame);
    [found addObject:attachment_answers(rope)];
    UIAttachmentBehavior *pin = made[5];
    pin.frictionTorque = 4;
    pin.attachmentRange = UIFloatRangeMake(-1, 1);
    [found addObject:attachment_answers(pin)];
    return found;
}

static void test_attachments(void)
{
    NSArray *oracle = attachments(Oracle), *ours = attachments(Ours);
    for (NSUInteger row = 0; row < oracle.count; row++) {
        for (NSUInteger column = 0; column < [oracle[row] count]; column++) {
            // 1e-4 pt: T11's tolerance, the lengths are float products on both sides.
            check_near([ours[row][column] doubleValue], [oracle[row][column] doubleValue], 1e-4,
                       row < 4 || row >= 9 ? "T11 attachment geometry is the oracle's" : "T12 the 9.0 factories answer as the oracle's",
                       [NSString stringWithFormat:@"attachment %lu value %lu", (unsigned long)row, (unsigned long)column]);
        }
    }
}

#pragma mark T13: anchored and charge

static NSArray *anchoring(Side side)
{
    UIDynamicAnimator *animator = make_animator(side, nil);
    Item *item = [Item itemAt:CGPointMake(100, 100) size:CGSizeMake(40, 40)];
    UIDynamicItemBehavior *properties = [MAKE(side, UIDynamicItemBehavior) initWithItems:@[item]];
    NSMutableArray *found = [NSMutableArray arrayWithObject:@[@(properties.anchored), @(properties.charge)]];
    properties.anchored = YES;
    properties.charge = 2.5;
    [animator addBehavior:properties];
    [animator addBehavior:[MAKE(side, UIGravityBehavior) initWithItems:@[item]]];
    for (int index = 0; index < 10; index++)
        animator_step(animator, frame);
    id body = animator_body(animator, item);
    [found addObject:@[@(properties.anchored), @(properties.charge), @(item.center.y), @(body_dynamic(body)), @([body charge])]];
    properties.anchored = NO;
    for (int index = 0; index < 10; index++)
        animator_step(animator, frame);
    [found addObject:@[@(body_dynamic(body)), @(item.center.y > 100)]];
    return found;
}

static void test_anchoring(void)
{
    NSArray *oracle = anchoring(Oracle), *ours = anchoring(Ours);
    for (NSUInteger row = 0; row < oracle.count; row++) {
        for (NSUInteger column = 0; column < [oracle[row] count]; column++) {
            check_same([ours[row][column] doubleValue], [oracle[row][column] doubleValue], "T13 anchored and charge are the oracle's",
                       [NSString stringWithFormat:@"step %lu value %lu", (unsigned long)row, (unsigned long)column]);
        }
    }
}

#pragma mark T14: itemsInRect:

static NSArray *in_rect(Side side)
{
    NSMutableArray *found = [NSMutableArray array];
    // s_anim.m "E": a 50x50 item is included at a gap of 9.9 pt and not at 10.5; the test reads 8 and 11.
    for (NSNumber *gap in @[@8, @11]) {
        UIDynamicAnimator *animator = make_animator(side, nil);
        Item *item = [Item itemAt:CGPointMake(100, 100) size:CGSizeMake(50, 50)];
        [animator addBehavior:[MAKE(side, UIDynamicItemBehavior) initWithItems:@[item]]];
        animator_step(animator, frame);
        CGRect rect = CGRectMake(125 + gap.doubleValue, 75, 50, 50);
        [found addObject:@([animator itemsInRect:rect].count)];
    }
    return found;
}

static void test_in_rect(void)
{
    NSArray *oracle = in_rect(Oracle), *ours = in_rect(Ours);
    charon_check([ours isEqualToArray:oracle], "T14 itemsInRect: takes the item at the oracle's gaps",
                 [NSString stringWithFormat:@"ours %@ oracle %@", [ours componentsJoinedByString:@","], [oracle componentsJoinedByString:@","]]);
    charon_check([oracle isEqualToArray:@[@1, @0]], "oracle takes an item as s_anim measured", [oracle componentsJoinedByString:@","]);
}

#pragma mark T17: several item behaviors on one item

static NSArray *body_properties(id body)
{
    return @[@([body restitution]), @([body friction]), @([body normalizedDensity]), @([body linearDamping]),
             @([body angularDamping]), @([body allowsRotation])];
}

static NSArray *mixing(Side side)
{
    UIDynamicAnimator *animator = make_animator(side, nil);
    Item *item = [Item itemAt:CGPointMake(100, 100) size:CGSizeMake(40, 40)];
    UIDynamicItemBehavior *first = [MAKE(side, UIDynamicItemBehavior) initWithItems:@[item]];
    first.elasticity = 0.7;
    first.density = 3;
    UIDynamicItemBehavior *second = [MAKE(side, UIDynamicItemBehavior) initWithItems:@[item]];
    second.friction = 0.9;
    second.resistance = 2;
    second.allowsRotation = NO;
    NSMutableArray *found = [NSMutableArray array];
    [animator addBehavior:first];
    animator_step(animator, frame);
    [found addObject:body_properties(animator_body(animator, item))];
    [animator addBehavior:second];
    animator_step(animator, frame);
    [found addObject:body_properties(animator_body(animator, item))];
    first.elasticity = 0.1;
    animator_step(animator, frame);
    [found addObject:body_properties(animator_body(animator, item))];
    [animator removeBehavior:second];
    animator_step(animator, frame);
    [found addObject:body_properties(animator_body(animator, item))];
    return found;
}

static void test_mixing(void)
{
    NSArray *oracle = mixing(Oracle), *ours = mixing(Ours);
    for (NSUInteger row = 0; row < oracle.count; row++) {
        for (NSUInteger column = 0; column < [oracle[row] count]; column++) {
            check_near([ours[row][column] doubleValue], [oracle[row][column] doubleValue], 1e-6, "T17 item behaviors mix on a body as the oracle's",
                       [NSString stringWithFormat:@"step %lu property %lu", (unsigned long)row, (unsigned long)column]);
        }
    }
}

#pragma mark An animator released with its behaviors

static void test_release(void)
{
    // Dissociating the behaviors from -dealloc tickles the animator, and a display link started there would hold a
    // weak reference to an animator already deallocating (objc aborts): the crash the snap scene met before the fix.
    __weak id gone = nil;
    @autoreleasepool {
        UIDynamicAnimator *animator = [side_class(Ours, @"UIDynamicAnimator") new];
        Item *item = [Item itemAt:CGPointMake(100, 100) size:CGSizeMake(40, 40)];
        UICollisionBehavior *collision = [MAKE(Ours, UICollisionBehavior) initWithItems:@[item]];
        [collision addBoundaryWithIdentifier:@"floor" fromPoint:CGPointMake(0, 400) toPoint:CGPointMake(400, 400)];
        [animator addBehavior:collision];
        [animator addBehavior:[MAKE(Ours, UIGravityBehavior) initWithItems:@[item]]];
        [animator addBehavior:[MAKE(Ours, UIAttachmentBehavior) initWithItem:item attachedToAnchor:CGPointMake(100, 50)]];
        animator_step(animator, frame);
        // Stopped and allowed to start again, as an animator whose items came to rest: -dealloc finds no display link.
        [animator _setAlwaysDisableDisplayLink:YES];
        [animator _setAlwaysDisableDisplayLink:NO];
        gone = animator;
    }
    charon_check(gone == nil, "an animator released with its behaviors deallocates", @"ours");
}

int main(void)
{
    @autoreleasepool {
        test_push_algebra();
        test_masks();
        test_gravity();
        test_exceptions();
        test_step_order();
        test_attachments();
        test_anchoring();
        test_in_rect();
        test_mixing();
        test_release();
        return finish();
    }
}
