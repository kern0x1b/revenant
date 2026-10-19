// fall_ios70_test.m — facts/UIKit/UIDynamicAnimator.md §12 T1c: our animator as shipped, with iOS 7.0's integrator
// (0.004 s sub-steps with the fmod accumulator, a box 1 pt inside the item with a 0.001 m skin), against the
// trajectory facts/UIKit/UIDynamicAnimator.md §1.3 predicts for 7.0 from its listing (w_sim7.c: the same float
// program, a prediction, not a device measurement).
// T1b's scene: a 100x100 item at (150,50), gravity only, default resistance, 5 steps of 1/60 s.
#import "dynamics.h"

int main(void)
{
    @autoreleasepool {
        const double predicted[5] = {50.1598701, 50.5752335, 51.2456779, 52.1707878, 53.3501625};
        UIDynamicAnimator *animator = make_animator(Ours, nil);
        Item *item = [Item itemAt:CGPointMake(150, 50) size:CGSizeMake(100, 100)];
        [animator addBehavior:[MAKE(Ours, UIGravityBehavior) initWithItems:@[item]]];
        for (int index = 0; index < 5; index++) {
            animator_step(animator, 1.0 / 60.0);
            // 1e-5 pt: the prediction is of the same float program, so only its printed digits separate them.
            check_near(item.center.y, predicted[index], 1e-5, "T1c 7.0's integrator falls as w_sim7 predicts",
                       [NSString stringWithFormat:@"step %d", index]);
        }
        return finish();
    }
}
