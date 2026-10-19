#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

int main(void)
{
    @autoreleasepool {
        double durations[] = {0.1, 0.25, 0.5, 0.8, 1.0, 2.0};
        double dampings[] = {0.05, 0.2, 0.4, 0.7, 1.0, 1.5};
        double velocities[] = {0, -3};
        for (int duration = 0; duration < 6; duration++) {
            for (int damping = 0; damping < 6; damping++) {
                for (int velocity = 0; velocity < 2; velocity++) {
                    UIView *view = [[UIView alloc] init];
                    [UIView animateWithDuration:durations[duration] delay:0 usingSpringWithDamping:dampings[damping]
                          initialSpringVelocity:velocities[velocity] options:0 animations:^{ view.alpha = 0.5; } completion:nil];
                    CASpringAnimation *spring = (CASpringAnimation *)[view.layer animationForKey:@"opacity"];
                    if (![spring isKindOfClass:[CASpringAnimation class]])
                        continue;
                    printf("case %.17g %.17g %.17g %.17g %.17g\n", durations[duration], dampings[damping], velocities[velocity], spring.stiffness, spring.damping);
                }
            }
        }
    }
}
