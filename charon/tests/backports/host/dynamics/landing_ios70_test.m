// landing_ios70_test.m — facts/UIKit/UIDynamicAnimator.md §12 T5 and the scene of device/dynamics.m, on our animator as
// shipped: iOS 7.0's 0.004 s sub-steps, a box 1 pt inside the item, a skin of 0.001 m. There is no oracle here: the host's
// animator runs neither of them, so each number is a measurement of this port's build, held to 1e-3 pt so that a change to
// the box's inset or the sub-step shows. The skin is not guarded: T5's rest is the same with none as with 0.001 m, and with
// 0.01 m on the host's build (§2.3), so a guard of the skin needs a scene where it acts (0.05 m does there). They are the
// port's values, not 7.0's (there is no 7.0 device to have measured).
#import "dynamics.h"

int main(void)
{
    @autoreleasepool {
        // T5 as shipped: the same scene as trajectory_test.m's T5 (landing_scene). Against the oracle's 248.216629 the rest
        // y is 0.8022 pt larger: on the host's build the box's 1 pt inset alone adds 1.0028 to it, the sub-step alone
        // takes 0.2090 off and the skin, at 0.001 m, changes nothing (facts/UIKit/UIDynamicAnimator.md §2.3).
        const double shipped[4] = {194.1759491, 201.2479248, 208.5759125, 249.0188141};
        double ours[4];
        landing_scene(Ours, ours);
        for (int index = 0; index < 4; index++) {
            NSString *context = index < 3 ? [NSString stringWithFormat:@"frame %d", 26 + index] : @"at rest, frame 300";
            check_near(ours[index], shipped[index], 1e-3,
                       index < 3 ? "T5 as shipped: the fall before the contact (the port's value, not 7.0)"
                                 : "T5 as shipped: the rest on the boundary (the port's value, not 7.0)",
                       context);
        }

        // The scene of device/dynamics.m: a 40x40 view in a 320x480 reference view under gravity, the reference bounds
        // as the boundary. The loop is 1 pt outside the bounds and the box 1 pt inside the view, so the body comes to
        // rest 0.134 pt past the bounds' bottom: its center at 460.134, the view's bottom edge at 480.134.
        UIView *reference = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 480)];
        UIView *view = [[UIView alloc] initWithFrame:CGRectMake(140, 60, 40, 40)];
        [reference addSubview:view];
        UIDynamicAnimator *animator = make_animator(Ours, reference);
        UICollisionBehavior *collision = [MAKE(Ours, UICollisionBehavior) initWithItems:@[view]];
        collision.translatesReferenceBoundsIntoBoundary = YES;
        [animator addBehavior:[MAKE(Ours, UIGravityBehavior) initWithItems:@[view]]];
        [animator addBehavior:collision];
        for (int index = 0; index < 1500; index++)
            animator_step(animator, 1.0 / 60.0);
        check_near(body_position(animator_body(animator, view)).y, 460.1338806, 1e-3,
                   "the device scene as shipped: the body rests at 460.134 (the port's value, not 7.0)", @"after 25 s");
        return finish();
    }
}
