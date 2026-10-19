#import "dynamics.h"

int main(void)
{
    @autoreleasepool {
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
