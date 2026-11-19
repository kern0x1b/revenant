#import "../app/revenant_check.h"
#import <QuartzCore/QuartzCore.h>

#pragma clang diagnostic ignored "-Wunguarded-availability-new"

REVENANT_CASE(caspring_animation_cast)
{
    CASpringAnimation *spring = [CASpringAnimation animation];
    revenant_expect_true(@"CASpringAnimation is the device class",
                         [spring isKindOfClass:[CASpringAnimation class]] && [spring class] == NSClassFromString(@"CASpringAnimation"),
                         [NSString stringWithFormat:@"class %@, named %@", [spring class], NSClassFromString(@"CASpringAnimation")]);

    BOOL members = [spring respondsToSelector:@selector(initialVelocity)] &&
                   [spring respondsToSelector:@selector(setInitialVelocity:)] &&
                   [spring respondsToSelector:@selector(allowsOverdamping)] &&
                   [spring respondsToSelector:@selector(setAllowsOverdamping:)] &&
                   [spring respondsToSelector:@selector(settlingDuration)] &&
                   [spring respondsToSelector:@selector(perceptualDuration)] &&
                   [spring respondsToSelector:@selector(bounce)];
    revenant_expect_true(@"the later SDK members are on the real class", members, @"category members are installed on the device class");

    spring.initialVelocity = -3;
    spring.allowsOverdamping = YES;
    revenant_expect_true(@"the later members keep their values",
                         spring.initialVelocity == -3 && spring.allowsOverdamping,
                         [NSString stringWithFormat:@"v %.17g allow %d", spring.initialVelocity, spring.allowsOverdamping]);
}
