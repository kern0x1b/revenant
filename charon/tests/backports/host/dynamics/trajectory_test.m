// trajectory_test.m — facts/UIKit/UIDynamicAnimator.md §12 rows T1, T1b, T2, T4, T4b, T5, T6, T15, T16: the same
// scene on the host's animator and on ours (built with the host's integrator, CHARON_HOST_DIFFERENTIAL), stepped frame
// by frame with 1/60 s. Ours is compared with the oracle live, within the row's tolerance; the oracle itself is
// compared with the numbers the facts file gives as measured (by the probe named in each row), so a scene that is not
// the probe's shows up as such.
#import "dynamics.h"
#include <math.h>

static const double frame = 1.0 / 60.0;

#pragma mark T1 / T1b: free fall

// T1 (resistance 0) and T1b (default resistance 0.1): 100x100 Item at (150,50), gravity only, 5 steps.
static void fall(Side side, BOOL resistanceZero, double y[5])
{
    UIDynamicAnimator *animator = make_animator(side, nil);
    Item *item = [Item itemAt:CGPointMake(150, 50) size:CGSizeMake(100, 100)];
    UIGravityBehavior *gravity = [MAKE(side, UIGravityBehavior) initWithItems:@[item]];
    [animator addBehavior:gravity];
    if (resistanceZero) {
        UIDynamicItemBehavior *material = [MAKE(side, UIDynamicItemBehavior) initWithItems:@[item]];
        material.resistance = 0;
        [animator addBehavior:material];
    }
    for (int index = 0; index < 5; index++) {
        animator_step(animator, frame);
        y[index] = item.center.y;
    }
}

static void test_fall(void)
{
    // w_fall2 arg 0 (T1) and w_fall2 (T1b), facts/UIKit/UIDynamicAnimator.md §1.3.
    const double measured[2][5] = {{50.0694466, 50.4166718, 51.0416679, 51.9444466, 53.1250076},
                                   {50.0693855, 50.4160881, 51.0396423, 51.9395943, 53.1154747}};
    for (int row = 0; row < 2; row++) {
        double oracle[5], ours[5];
        fall(Oracle, row == 0, oracle);
        fall(Ours, row == 0, ours);
        for (int index = 0; index < 5; index++) {
            NSString *context = [NSString stringWithFormat:@"%@ step %d", row == 0 ? @"T1" : @"T1b", index];
            // The facts file (§1.3) prints 9 significant digits: the oracle reproduces them to the last one.
            check_near(oracle[index], measured[row][index], 5e-7, "oracle falls as w_fall2 measured", context);
            // 1e-4 pt: float order (T1); 2.2.1's clamp damping against the host's 1/(1+hc), 4e-6 pt over 5 steps (T1b).
            check_near(ours[index], oracle[index], 1e-4, row == 0 ? "T1 free fall as the oracle" : "T1b free fall with resistance 0.1 as the oracle", context);
        }
    }
}

#pragma mark T2: push

typedef struct {
    double velocity[4];
    double angular[4];
    BOOL active;
} PushRun;

// A 100x100 item (1 kg) at (100,100) with resistance and angular resistance 0, pushed by `push`.
static PushRun push(Side side, UIPushBehaviorMode mode, CGVector direction, UIOffset offset, CGSize size, CGFloat density, int steps)
{
    UIDynamicAnimator *animator = make_animator(side, nil);
    Item *item = [Item itemAt:CGPointMake(100, 100) size:size];
    UIDynamicItemBehavior *material = [MAKE(side, UIDynamicItemBehavior) initWithItems:@[item]];
    material.resistance = 0;
    material.angularResistance = 0;
    material.density = density;
    [animator addBehavior:material];
    UIPushBehavior *pushing = [MAKE(side, UIPushBehavior) initWithItems:@[item] mode:mode];
    pushing.pushDirection = direction;
    if (offset.horizontal || offset.vertical)
        [pushing setTargetOffsetFromCenter:offset forItem:item];
    [animator addBehavior:pushing];
    PushRun run = {{0}, {0}, NO};
    for (int index = 0; index < steps; index++) {
        animator_step(animator, frame);
        CGPoint velocity = [material linearVelocityForItem:item];
        run.velocity[index] = hypot(velocity.x, velocity.y);
        run.angular[index] = [material angularVelocityForItem:item];
    }
    run.active = pushing.active;
    return run;
}

static void check_relative(double actual, double expected, const char *name, NSString *context)
{
    // T2: 1e-5 relative (compat mode).
    check_near(actual, expected, 1e-5 * fabs(expected), name, context);
}

static void test_push(void)
{
    // s_push.m, facts/UIKit/UIDynamicAnimator.md §4.2.
    PushRun oracle = push(Oracle, UIPushBehaviorModeContinuous, CGVectorMake(1, 0), UIOffsetZero, CGSizeMake(100, 100), 1, 4);
    PushRun ours = push(Ours, UIPushBehaviorModeContinuous, CGVectorMake(1, 0), UIOffsetZero, CGSizeMake(100, 100), 1, 4);
    const double continuous[4] = {0.833333373, 2.50000024, 4.16666698, 5.83333349};
    for (int index = 0; index < 4; index++) {
        NSString *context = [NSString stringWithFormat:@"continuous (1,0) step %d", index + 1];
        check_relative(oracle.velocity[index], continuous[index], "oracle pushes as s_push measured", context);
        check_relative(ours.velocity[index], oracle.velocity[index], "T2 continuous push velocity as the oracle", context);
    }

    oracle = push(Oracle, UIPushBehaviorModeInstantaneous, CGVectorMake(1, 0), UIOffsetZero, CGSizeMake(100, 100), 1, 1);
    ours = push(Ours, UIPushBehaviorModeInstantaneous, CGVectorMake(1, 0), UIOffsetZero, CGSizeMake(100, 100), 1, 1);
    check_relative(oracle.velocity[0], 100, "oracle pushes as s_push measured", @"instantaneous (1,0)");
    check_relative(ours.velocity[0], oracle.velocity[0], "T2 instantaneous push velocity as the oracle", @"instantaneous (1,0)");
    charon_check(!oracle.active && ours.active == oracle.active, "T2 an instantaneous push is inactive after its step, as the oracle's",
                 [NSString stringWithFormat:@"ours %d oracle %d", ours.active, oracle.active]);

    oracle = push(Oracle, UIPushBehaviorModeContinuous, CGVectorMake(1, 0), UIOffsetMake(0, 50), CGSizeMake(100, 100), 1, 4);
    ours = push(Ours, UIPushBehaviorModeContinuous, CGVectorMake(1, 0), UIOffsetMake(0, 50), CGSizeMake(100, 100), 1, 4);
    const double angular[4] = {-0.0250000022, -0.075000003, -0.125000015, -0.175000027};
    for (int index = 0; index < 4; index++) {
        NSString *context = [NSString stringWithFormat:@"continuous (1,0) at offset (0,50) step %d", index + 1];
        check_relative(oracle.angular[index], angular[index], "oracle pushes as s_push measured", context);
        check_relative(ours.angular[index], oracle.angular[index], "T2 off-centre push angular velocity as the oracle", context);
    }

    oracle = push(Oracle, UIPushBehaviorModeInstantaneous, CGVectorMake(0, 1), UIOffsetMake(50, 0), CGSizeMake(100, 100), 1, 1);
    ours = push(Ours, UIPushBehaviorModeInstantaneous, CGVectorMake(0, 1), UIOffsetMake(50, 0), CGSizeMake(100, 100), 1, 1);
    check_relative(oracle.angular[0], 3.00000007, "oracle pushes as s_push measured", @"instantaneous (0,1) at offset (50,0)");
    check_relative(ours.angular[0], oracle.angular[0], "T2 off-centre impulse angular velocity as the oracle", @"instantaneous (0,1) at offset (50,0)");
    check_relative(ours.velocity[0], oracle.velocity[0], "T2 off-centre impulse velocity as the oracle", @"instantaneous (0,1) at offset (50,0)");

    oracle = push(Oracle, UIPushBehaviorModeInstantaneous, CGVectorMake(0.3, 0), UIOffsetZero, CGSizeMake(200, 50), 2, 1);
    ours = push(Ours, UIPushBehaviorModeInstantaneous, CGVectorMake(0.3, 0), UIOffsetZero, CGSizeMake(200, 50), 2, 1);
    check_relative(oracle.velocity[0], 15.000001, "oracle pushes as s_push measured", @"200x50 density 2 impulse 0.3");
    check_relative(ours.velocity[0], oracle.velocity[0], "T2 impulse on a 2 kg item as the oracle", @"200x50 density 2 impulse 0.3");
}

#pragma mark T4 / T4b: attachment

typedef struct {
    CGPoint position[4];
    double length;
} Pendulum;

static const int pendulum_frames[4] = {1, 10, 30, 60};

// T4: 40x40 at (200,100) on an anchor at (100,100), under gravity. T4b: 40x40 at (100,250), anchor (100,100),
// frequency 2, damping 0.3, length 100 set before adding, no gravity. Resistance and angular resistance 0.
static Pendulum pendulum(Side side, BOOL spring)
{
    UIDynamicAnimator *animator = make_animator(side, nil);
    Item *item = [Item itemAt:spring ? CGPointMake(100, 250) : CGPointMake(200, 100) size:CGSizeMake(40, 40)];
    UIAttachmentBehavior *attachment = [MAKE(side, UIAttachmentBehavior) initWithItem:item attachedToAnchor:CGPointMake(100, 100)];
    if (spring) {
        attachment.frequency = 2;
        attachment.damping = 0.3;
        attachment.length = 100;
    }
    UIDynamicItemBehavior *material = [MAKE(side, UIDynamicItemBehavior) initWithItems:@[item]];
    material.resistance = 0;
    material.angularResistance = 0;
    [animator addBehavior:material];
    if (!spring)
        [animator addBehavior:[MAKE(side, UIGravityBehavior) initWithItems:@[item]]];
    [animator addBehavior:attachment];
    Pendulum run;
    run.length = attachment.length;
    int next = 0;
    for (int index = 1; index <= 60; index++) {
        animator_step(animator, frame);
        if (index == pendulum_frames[next])
            run.position[next++] = item.center;
    }
    return run;
}

static void test_pendulum(void)
{
    // s_oracle.m, facts/UIKit/UIDynamicAnimator.md §12 (T4, T4b).
    const CGPoint measured[2][4] = {{{199.999969, 100.069443}, {199.132126, 113.146225}, {139.359573, 191.92836}, {2.06188917, 120.202171}},
                                    {{100, 249.48938}, {100, 201.092148}, {100, 204.031586}, {100, 200.142715}}};
    for (int spring = 0; spring < 2; spring++) {
        Pendulum oracle = pendulum(Oracle, spring), ours = pendulum(Ours, spring);
        if (!spring)
            check_near(ours.length, oracle.length, 1e-4, "T4 the rod is as long as the oracle's", @"length after add");
        for (int index = 0; index < 4; index++) {
            NSString *context = [NSString stringWithFormat:@"%@ frame %d", spring ? @"T4b spring" : @"T4 pendulum", pendulum_frames[index]];
            check_near(oracle.position[index].x, measured[spring][index].x, 5e-5, "oracle swings as s_oracle measured", [context stringByAppendingString:@" x"]);
            check_near(oracle.position[index].y, measured[spring][index].y, 5e-5, "oracle swings as s_oracle measured", [context stringByAppendingString:@" y"]);
            // T4: 0.05 pt up to frame 30, 0.5 pt at frame 60; T4b: 0.05 pt.
            double tolerance = !spring && pendulum_frames[index] == 60 ? 0.5 : 0.05;
            const char *name = spring ? "T4b spring as the oracle" : "T4 pendulum as the oracle";
            check_near(ours.position[index].x, oracle.position[index].x, tolerance, name, [context stringByAppendingString:@" x"]);
            check_near(ours.position[index].y, oracle.position[index].y, tolerance, name, [context stringByAppendingString:@" y"]);
        }
    }
}

#pragma mark T5: fall onto a boundary

static void test_landing(void)
{
    // s_oracle.m, facts/UIKit/UIDynamicAnimator.md §12 (T5): y at frames 26, 27, 28 and at rest (frame 300). In this build
    // (the host's integrator and shapes: no skin, full-size box) the port's rest is the oracle's to the digit, measured
    // 248.216629 on both, so the rest is held to the same 1e-3 pt as the fall.
    const double measured[4] = {192.083298, 199.374969, 206.944397, 248.216629};
    double oracle[4], ours[4];
    landing_scene(Oracle, oracle);
    landing_scene(Ours, ours);
    for (int index = 0; index < 4; index++) {
        NSString *context = index < 3 ? [NSString stringWithFormat:@"frame %d", 26 + index] : @"at rest, frame 300";
        check_near(oracle[index], measured[index], 5e-5, "oracle lands as s_oracle measured", context);
        check_near(ours[index], oracle[index], 1e-3, index < 3 ? "T5 fall before the contact as the oracle" : "T5 rest on the boundary as the oracle", context);
    }
}

#pragma mark T6: snap

typedef struct {
    CGPoint first, last;
    double firstAngle;
    NSTimeInterval elapsedAcrossTurn;
} Snap;

static Snap snap(Side side)
{
    UIDynamicAnimator *animator = make_animator(side, nil);
    Item *item = [Item itemAt:CGPointMake(100, 100) size:CGSizeMake(100, 50)];
    UISnapBehavior *snapping = [MAKE(side, UISnapBehavior) initWithItem:item snapToPoint:CGPointMake(300, 200)];
    snapping.damping = 0.5;
    [animator addBehavior:snapping];
    NSTimeInterval before = animator.elapsedTime;
    turn_run_loop();
    Snap run;
    run.elapsedAcrossTurn = animator.elapsedTime - before;
    animator_step(animator, frame);
    run.first = item.center;
    run.firstAngle = atan2(item.transform.b, item.transform.a);
    for (int index = 2; index <= 200; index++)
        animator_step(animator, frame);
    run.last = item.center;
    return run;
}

static void test_snap(void)
{
    // j_snap3.m, facts/UIKit/UIDynamicAnimator.md §5: frame 1 after the run-loop turn, and the final position.
    Snap oracle = snap(Oracle), ours = snap(Ours);
    charon_check(oracle.elapsedAcrossTurn == 0 && ours.elapsedAcrossTurn == 0, "no display link steps an animator while the run loop turns",
                 [NSString stringWithFormat:@"oracle %g ours %g", oracle.elapsedAcrossTurn, ours.elapsedAcrossTurn]);
    check_near(oracle.first.x, 113.265648, 5e-6, "oracle snaps as j_snap3 measured", @"frame 1 x");
    check_near(oracle.first.y, 106.623589, 5e-6, "oracle snaps as j_snap3 measured", @"frame 1 y");
    check_near(oracle.firstAngle, 0.0361267589, 5e-10, "oracle snaps as j_snap3 measured", @"frame 1 angle");
    check_near(oracle.last.x, 299.999969, 5e-6, "oracle snaps as j_snap3 measured", @"frame 200 x");
    check_near(oracle.last.y, 199.999222, 5e-5, "oracle snaps as j_snap3 measured", @"frame 200 y");
    // 2e-4 pt: the Box2D model's residual against Apple's, 1.4e-4 pt; the angle's was 1.28e-6 rad
    // (facts/UIKit/UIDynamicAnimator.md §5).
    check_near(ours.first.x, oracle.first.x, 2e-4, "T6 snap frame 1 as the oracle", @"x");
    check_near(ours.first.y, oracle.first.y, 2e-4, "T6 snap frame 1 as the oracle", @"y");
    check_near(ours.firstAngle, oracle.firstAngle, 2e-6, "T6 snap frame 1 as the oracle", @"angle");
    check_near(ours.last.x, oracle.last.x, 2e-4, "T6 snap comes to rest as the oracle", @"x");
    check_near(ours.last.y, oracle.last.y, 2e-4, "T6 snap comes to rest as the oracle", @"y");
}

#pragma mark T15 / T16: resting stop, elapsed time

static int calls_until_rest(Side side)
{
    UIDynamicAnimator *animator = make_animator(side, nil);
    Item *item = [Item itemAt:CGPointMake(100, 100) size:CGSizeMake(100, 100)];
    [animator addBehavior:[MAKE(side, UIDynamicItemBehavior) initWithItems:@[item]]];
    for (int call = 1; call <= 200; call++) {
        if (!animator_step(animator, frame))
            return call;
    }
    return 0;
}

static void test_rest_and_time(void)
{
    int oracle = calls_until_rest(Oracle), ours = calls_until_rest(Ours);
    // s_anim.m "C": the 31st call answers NO.
    charon_check(oracle == 31, "oracle rests as s_anim measured", [NSString stringWithFormat:@"call %d", oracle]);
    charon_check(abs(ours - oracle) <= 1, "T15 a resting item stops the animator at the oracle's call (+-1)",
                 [NSString stringWithFormat:@"ours call %d, oracle call %d", ours, oracle]);

    NSTimeInterval elapsed[2];
    for (Side side = Oracle; side <= Ours; side++) {
        UIDynamicAnimator *animator = make_animator(side, nil);
        Item *item = [Item itemAt:CGPointMake(100, 100) size:CGSizeMake(10, 10)];
        [animator addBehavior:[MAKE(side, UIGravityBehavior) initWithItems:@[item]]];
        for (int index = 0; index < 4; index++)
            animator_step(animator, frame);
        elapsed[side] = animator.elapsedTime;
    }
    // s_anim.m: 0.0666666667 after 4 steps of 1/60, the plain sum of the dt values.
    check_near(elapsed[Oracle], 0.0666666667, 5e-11, "oracle's elapsedTime as s_anim measured", @"4 steps");
    check_equal_double(elapsed[Ours], elapsed[Oracle], "T16 elapsedTime after 4 steps is the oracle's", @"4 steps");
}

int main(void)
{
    @autoreleasepool {
        test_fall();
        test_push();
        test_pendulum();
        test_landing();
        test_snap();
        test_rest_and_time();
        return finish();
    }
}
