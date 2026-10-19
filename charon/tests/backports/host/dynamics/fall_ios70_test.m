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
            check_near(item.center.y, predicted[index], 1e-5, "T1c 7.0's integrator falls as w_sim7 predicts",
                       [NSString stringWithFormat:@"step %d", index]);
        }
        return finish();
    }
}
