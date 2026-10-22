#import "../Foundation/check.h"
#import <QuartzCore/QuartzCore.h>
#import "../../src/UIKit/RevenantCASpringAnimation.h"
#import "../../src/UIKit/RevenantSpringKeyframes.h"
#import "../../src/UIKit/RevenantSpringSolver.h"
#include <float.h>
#include <math.h>

@interface CASpringAnimation (RevenantMeasurement)
- (double)_timeFunction:(double)time;
@end

static BOOL revenant_close(double value, double expected, double tolerance)
{
    return fabs(value - expected) <= tolerance;
}

static double revenant_test_position(double time, void *context)
{
    return revenant_spring_position(*(RevenantSpringParameters *)context, time);
}

static CASpringAnimation *revenant_apple_spring(RevenantSpringParameters parameters)
{
    CASpringAnimation *spring = [CASpringAnimation animation];
    spring.mass = parameters.mass;
    spring.stiffness = parameters.stiffness;
    spring.damping = parameters.damping;
    spring.initialVelocity = parameters.initialVelocity;
    if ([spring respondsToSelector:@selector(setAllowsOverdamping:)])
        spring.allowsOverdamping = parameters.allowsOverdamping;
    return spring;
}

int main(int argc, char **argv)
{
    revenant_read_arguments(argc, argv);
    if (![CASpringAnimation instancesRespondToSelector:@selector(_timeFunction:)]) {
        printf("FAIL measurement: CASpringAnimation does not expose _timeFunction:\n");
        return 1;
    }
    if (![CASpringAnimation instancesRespondToSelector:@selector(settlingDuration)]) {
        printf("FAIL measurement: CASpringAnimation does not expose settlingDuration\n");
        return 1;
    }

    RevenantSpringParameters sets[] = {
        {1, 100, 10, 0, false},
        {1, 100, 5, 0, false},
        {1, 100, 20, 0, false},
        {1, 100, 20, 5, false},
        {1, 100, 20, -5, false},
        {2, 300, 30, 0, false},
        {0.5, 50, 15, 1, false},
        {3, 120, 25, -2, false},
        {0.25, 400, 20, -1, false},
        {4, 50, 40, 2, false},
        {1, 10, 10, 0, true},
        {1, 10, 10, -3, true},
        {0.5, 50, 15, 1, true},
        {3, 20, 30, -2, true},
        {1, 100, 30, 10, true},
        {2, 8, 12, 0, true},
        {1, 100, 100, -20, true},
        {1, 10, 10, -1.127, true},
        {1, 10, 10, -1.2, true},
        {1, 10, 10, -1.0, true},
        {1, 10, 10, -1.117, true},
    };
    for (size_t index = 0; index < sizeof(sets) / sizeof(*sets); index++) {
        RevenantSpringParameters parameters = sets[index];
        CASpringAnimation *apple = revenant_apple_spring(parameters);
        double expected = apple.settlingDuration;
        double actual = revenant_spring_settling(parameters);
        NSString *name = [NSString stringWithFormat:@"settling %zu", index];
        revenant_check(revenant_close(actual, expected, 1e-6), [name UTF8String],
                       [NSString stringWithFormat:@"%.17g is not %.17g", actual, expected]);
        if (!(expected > 0) || !isfinite(expected))
            continue;
        apple.duration = expected;
        double worst = 0;
        for (int step = 0; step <= 100; step++) {
            double unit = step / 100.0;
            double measured = [apple _timeFunction:unit];
            double solved = revenant_spring_position(parameters, unit * expected);
            worst = fmax(worst, fabs(measured - solved));
        }
        name = [NSString stringWithFormat:@"curve %zu", index];
        revenant_check(worst <= 1e-9, [name UTF8String],
                       [NSString stringWithFormat:@"worst error %.17g", worst]);
    }

    double masses[] = {0.5, 1, 2, 3};
    double stiffnesses[] = {10, 50, 100, 400};
    double ratios[] = {0, 0.1, 0.25, 0.5, 0.75, 0.9, 0.999, 1.0, 1.001, 1.05, 1.2, 1.5, 2, 4};
    double velocities[] = {-20, -10, -3, -2, -1, 0, 1, 2, 3, 10, 20};
    double gridWorst = 0;
    unsigned long gridCount = 0;
    for (size_t mass = 0; mass < sizeof(masses) / sizeof(*masses); mass++) {
        for (size_t stiffness = 0; stiffness < sizeof(stiffnesses) / sizeof(*stiffnesses); stiffness++) {
            for (size_t ratio = 0; ratio < sizeof(ratios) / sizeof(*ratios); ratio++) {
                for (size_t velocity = 0; velocity < sizeof(velocities) / sizeof(*velocities); velocity++) {
                    RevenantSpringParameters parameters = {
                        masses[mass], stiffnesses[stiffness],
                        2 * ratios[ratio] * sqrt(masses[mass] * stiffnesses[stiffness]),
                        velocities[velocity], ratios[ratio] > 1
                    };
                    CASpringAnimation *apple = revenant_apple_spring(parameters);
                    double delta = fabs(revenant_spring_settling(parameters) - apple.settlingDuration);
                    if (delta > gridWorst)
                        gridWorst = delta;
                    gridCount++;
                }
            }
        }
    }
    revenant_check(gridWorst <= 1e-6, "settling grid",
                   [NSString stringWithFormat:@"%lu sets, worst error %.17g", gridCount, gridWorst]);

    double durations[] = {0.2, 0.5, 1.0};
    double bounces[] = {-0.4, 0, 0.4, 0.8};
    for (size_t duration = 0; duration < sizeof(durations) / sizeof(*durations); duration++) {
        for (size_t index = 0; index < sizeof(bounces) / sizeof(*bounces); index++) {
            CASpringAnimation *apple = [[CASpringAnimation alloc] initWithPerceptualDuration:durations[duration] bounce:bounces[index]];
            RevenantSpringParameters parameters;
            revenant_spring_perceptual(durations[duration], bounces[index], &parameters);
            NSString *name = [NSString stringWithFormat:@"perceptual constants %zu/%zu", duration, index];
            BOOL same = revenant_close(parameters.mass, apple.mass, 1e-9) &&
                        revenant_close(parameters.stiffness, apple.stiffness, fmax(1, apple.stiffness) * 1e-9) &&
                        revenant_close(parameters.damping, apple.damping, fmax(1, apple.damping) * 1e-9) &&
                        revenant_close(parameters.initialVelocity, apple.initialVelocity, 1e-9) &&
                        parameters.allowsOverdamping == apple.allowsOverdamping;
            revenant_check(same, [name UTF8String],
                           [NSString stringWithFormat:@"m %.17g k %.17g c %.17g v %.17g allow %d", parameters.mass, parameters.stiffness, parameters.damping, parameters.initialVelocity, parameters.allowsOverdamping]);
            name = [NSString stringWithFormat:@"perceptual settling %zu/%zu", duration, index];
            revenant_check(revenant_close(revenant_spring_settling(parameters), apple.settlingDuration, 1e-6), [name UTF8String],
                           [NSString stringWithFormat:@"%.17g is not %.17g", revenant_spring_settling(parameters), apple.settlingDuration]);
            name = [NSString stringWithFormat:@"perceptual duration %zu/%zu", duration, index];
            revenant_check(revenant_close(apple.duration, apple.settlingDuration, 1e-9), [name UTF8String],
                           [NSString stringWithFormat:@"%.17g is not %.17g", apple.duration, apple.settlingDuration]);

            RevenantCASpringAnimation *ours = [[RevenantCASpringAnimation alloc] initWithPerceptualDuration:durations[duration] bounce:bounces[index]];
            name = [NSString stringWithFormat:@"perceptual class %zu/%zu", duration, index];
            same = revenant_close(ours.mass, apple.mass, 1e-9) &&
                   revenant_close(ours.stiffness, apple.stiffness, fmax(1, apple.stiffness) * 1e-9) &&
                   revenant_close(ours.damping, apple.damping, fmax(1, apple.damping) * 1e-9) &&
                   revenant_close(ours.initialVelocity, apple.initialVelocity, 1e-9) &&
                   ours.allowsOverdamping == apple.allowsOverdamping &&
                   revenant_close(ours.settlingDuration, apple.settlingDuration, 1e-6) &&
                   revenant_close(ours.perceptualDuration, apple.perceptualDuration, 1e-9) &&
                   revenant_close(ours.bounce, apple.bounce, 1e-9);
            revenant_check(same, [name UTF8String],
                           [NSString stringWithFormat:@"m %.17g k %.17g c %.17g T %.17g pd %.17g b %.17g", ours.mass, ours.stiffness, ours.damping, ours.settlingDuration, ours.perceptualDuration, ours.bounce]);
        }
    }

    RevenantCASpringAnimation *spring = [RevenantCASpringAnimation animation];
    revenant_check(revenant_close(spring.mass, 1, 0) && revenant_close(spring.stiffness, 100, 0) &&
                   revenant_close(spring.damping, 10, 0) && revenant_close(spring.initialVelocity, 0, 0) &&
                   !spring.allowsOverdamping, "defaults",
                   [NSString stringWithFormat:@"m %.17g k %.17g c %.17g v %.17g allow %d", spring.mass, spring.stiffness, spring.damping, spring.initialVelocity, spring.allowsOverdamping]);
    revenant_check(revenant_close(spring.settlingDuration, 1.472700335, 1e-6), "default settling",
                   [NSString stringWithFormat:@"%.17g", spring.settlingDuration]);

    spring.mass = 2;
    spring.stiffness = 8;
    spring.damping = 12;
    spring.initialVelocity = -3;
    spring.allowsOverdamping = YES;
    RevenantCASpringAnimation *copy = [spring copy];
    revenant_check([copy isKindOfClass:[RevenantCASpringAnimation class]] && copy != spring &&
                   revenant_close(copy.mass, 2, 0) && revenant_close(copy.stiffness, 8, 0) &&
                   revenant_close(copy.damping, 12, 0) && revenant_close(copy.initialVelocity, -3, 0) &&
                   copy.allowsOverdamping, "copy",
                   [NSString stringWithFormat:@"m %.17g k %.17g c %.17g v %.17g allow %d", copy.mass, copy.stiffness, copy.damping, copy.initialVelocity, copy.allowsOverdamping]);
    revenant_check(revenant_close(copy.settlingDuration, spring.settlingDuration, 0), "copy settling",
                   [NSString stringWithFormat:@"%.17g is not %.17g", copy.settlingDuration, spring.settlingDuration]);

    NSData *archive = [NSKeyedArchiver archivedDataWithRootObject:spring requiringSecureCoding:YES error:NULL];
    RevenantCASpringAnimation *decoded = archive ? [NSKeyedUnarchiver unarchivedObjectOfClass:[RevenantCASpringAnimation class] fromData:archive error:NULL] : nil;
    revenant_check([decoded isKindOfClass:[RevenantCASpringAnimation class]] &&
                   revenant_close(decoded.mass, 2, 0) && revenant_close(decoded.stiffness, 8, 0) &&
                   revenant_close(decoded.damping, 12, 0) && revenant_close(decoded.initialVelocity, -3, 0) &&
                   decoded.allowsOverdamping, "archive",
                   [NSString stringWithFormat:@"m %.17g k %.17g c %.17g v %.17g allow %d", decoded.mass, decoded.stiffness, decoded.damping, decoded.initialVelocity, decoded.allowsOverdamping]);

    RevenantSpringParameters keyframeParameters = {1, 100, 10, 0, false};
    CALayer *layer = [CALayer layer];
    layer.position = CGPointMake(0, 0);
    RevenantCASpringAnimation *keyframeSpring = [RevenantCASpringAnimation animation];
    keyframeSpring.keyPath = @"position.x";
    keyframeSpring.fromValue = @0;
    keyframeSpring.toValue = @100;
    keyframeSpring.duration = 1;
    CAKeyframeAnimation *frames = revenant_spring_keyframes(keyframeSpring, layer, 1, revenant_test_position, &keyframeParameters, NO);
    double first = frames.values.count ? [[frames.values objectAtIndex:0] doubleValue] : NAN;
    double last = frames.values.count ? [[frames.values lastObject] doubleValue] : NAN;
    revenant_check(frames && frames.values.count > 1 && [frames.keyPath isEqualToString:@"position.x"] &&
                   revenant_close(first, 0, 1e-9) && revenant_close(last, 100 * revenant_spring_position(keyframeParameters, 1), 1e-9),
                   "keyframe samples",
                   [NSString stringWithFormat:@"count %lu first %.17g last %.17g", (unsigned long)frames.values.count, first, last]);

    keyframeSpring.fromValue = nil;
    keyframeSpring.byValue = @10;
    frames = revenant_spring_keyframes(keyframeSpring, layer, 1, revenant_test_position, &keyframeParameters, NO);
    first = frames.values.count ? [[frames.values objectAtIndex:0] doubleValue] : NAN;
    revenant_check(frames && revenant_close(first, 90, 1e-9), "keyframe by value",
                   [NSString stringWithFormat:@"first %.17g", first]);

    keyframeSpring.keyPath = @"backgroundColor";
    CGColorRef red = CGColorCreateSRGB(1, 0, 0, 1);
    CGColorRef blue = CGColorCreateSRGB(0, 0, 1, 1);
    keyframeSpring.fromValue = (__bridge id)red;
    keyframeSpring.toValue = (__bridge id)blue;
    frames = revenant_spring_keyframes(keyframeSpring, layer, 1, revenant_test_position, &keyframeParameters, NO);
    revenant_check(frames == nil, "unsupported value falls back", @"a keyframe animation was built");
    CGColorRelease(red);
    CGColorRelease(blue);

    revenant_check(revenant_negative ? NO : YES, "negative control", @"the negative control is inverted");
    return revenant_finish();
}
