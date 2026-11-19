#import "../app/revenant_check.h"
#import <QuartzCore/QuartzCore.h>

#pragma clang diagnostic ignored "-Wunguarded-availability-new"

static id revenant_round_trip(id object)
{
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:object];
    return [NSKeyedUnarchiver unarchiveObjectWithData:data];
}

REVENANT_CASE(caspring_animation_coding)
{
    CABasicAnimation *basic = [CABasicAnimation animationWithKeyPath:@"opacity"];
    basic.duration = 2;
    CAKeyframeAnimation *keyframes = [CAKeyframeAnimation animationWithKeyPath:@"position.x"];
    keyframes.values = @[@0, @10];
    CAAnimationGroup *group = [CAAnimationGroup animation];
    group.animations = @[basic];

    BOOL plain = YES;
    NSString *detail = @"";
    for (CAAnimation *animation in @[basic, keyframes, group]) {
        CAAnimation *copy = nil;
        CAAnimation *decoded = nil;
        @try {
            copy = [animation copy];
            decoded = revenant_round_trip(animation);
        } @catch (NSException *exception) {
            plain = NO;
            detail = [detail stringByAppendingFormat:@"%@ raised %@; ", [animation class], exception.reason];
            continue;
        }
        if (![copy isMemberOfClass:[animation class]] || ![decoded isMemberOfClass:[animation class]]) {
            plain = NO;
            detail = [detail stringByAppendingFormat:@"%@ came back as %@ and %@; ", [animation class], [copy class], [decoded class]];
        }
    }
    revenant_expect_true(@"copying and archiving the other animations is untouched", plain, detail);

    CASpringAnimation *spring = [CASpringAnimation animationWithKeyPath:@"position.y"];
    spring.mass = 3;
    spring.stiffness = 40;
    spring.damping = 9;
    spring.initialVelocity = -2;
    spring.allowsOverdamping = YES;
    CASpringAnimation *copy = [spring copy];
    CASpringAnimation *decoded = revenant_round_trip(spring);
    BOOL kept = [copy isMemberOfClass:[CASpringAnimation class]] && [decoded isMemberOfClass:[CASpringAnimation class]] &&
                copy.allowsOverdamping && decoded.allowsOverdamping &&
                copy.mass == 3 && decoded.mass == 3 && copy.initialVelocity == -2 && decoded.initialVelocity == -2;
    revenant_expect_true(@"a spring keeps its added members through copy and archive", kept != (BOOL)negative,
                         [NSString stringWithFormat:@"copy %d %g %g, decoded %d %g %g", copy.allowsOverdamping, copy.mass, copy.initialVelocity,
                                                    decoded.allowsOverdamping, decoded.mass, decoded.initialVelocity]);
}
