#import <QuartzCore/QuartzCore.h>
#include <math.h>

static const double CharonSpringEpsilon = 0.001;
static const double CharonSpringStep = 0.1;

@interface CASpringAnimation (CharonSpringVelocity)
- (CGFloat)velocity;
- (void)setVelocity:(CGFloat)velocity;
@end

static double charon_spring_remainder(double omega, double velocity, double time)
{
    return fabs(1 + (omega - velocity) * time) * exp(-omega * time);
}

double charon_spring_settling(double mass, double stiffness, double damping, double velocity)
{
    double omega = sqrt(stiffness / mass);
    double zeta = damping / (2 * sqrt(mass * stiffness));
    if (!(zeta > 0) || !(omega > 0) || !isfinite(omega))
        return MAXFLOAT;
    if (zeta < 1) {
        double decay = omega * zeta, damped = omega * sqrt(1 - zeta * zeta);
        double settling = (-log(CharonSpringEpsilon) + log(1 + fabs((decay - velocity) / damped))) / decay;
        return settling > 0 ? settling : 0;
    }
    double reach = fabs(omega - velocity);
    double time = -log(CharonSpringEpsilon) / omega;
    for (int round = 0; round < 64; round++) {
        double next = (-log(CharonSpringEpsilon) + log(1 + reach * time)) / omega;
        double moved = fabs(next - time);
        time = next;
        if (!isfinite(time) || moved <= 1e-12 * (time > 1 ? time : 1))
            break;
    }
    if (!isfinite(time))
        return MAXFLOAT;
    double steps = time > CharonSpringStep ? ceil(time / CharonSpringStep) : 1;
    while (steps > 1 && charon_spring_remainder(omega, velocity, (steps - 1) * CharonSpringStep) <= CharonSpringEpsilon)
        steps -= 1;
    while (charon_spring_remainder(omega, velocity, steps * CharonSpringStep) > CharonSpringEpsilon)
        steps += 1;
    return steps * CharonSpringStep;
}

@implementation CASpringAnimation (CharonSpring)

- (CGFloat)initialVelocity
{
    return [self velocity];
}

- (void)setInitialVelocity:(CGFloat)initialVelocity
{
    [self setVelocity:initialVelocity];
}

- (CFTimeInterval)settlingDuration
{
    return charon_spring_settling([self mass], [self stiffness], [self damping], [self velocity]);
}

@end
