#import <QuartzCore/QuartzCore.h>
#include <math.h>

static const double RevenantSpringEpsilon = 0.001;
static const double RevenantSpringStep = 0.1;

@interface CASpringAnimation (RevenantSpringVelocity)
- (CGFloat)velocity;
- (void)setVelocity:(CGFloat)velocity;
@end

static double revenant_spring_remainder(double omega, double velocity, double time)
{
    return fabs(1 + (omega - velocity) * time) * exp(-omega * time);
}

double revenant_spring_settling(double mass, double stiffness, double damping, double velocity)
{
    double omega = sqrt(stiffness / mass);
    double zeta = damping / (2 * sqrt(mass * stiffness));
    if (!(zeta > 0) || !(omega > 0) || !isfinite(omega))
        return MAXFLOAT;
    if (zeta < 1) {
        double decay = omega * zeta, damped = omega * sqrt(1 - zeta * zeta);
        double settling = (-log(RevenantSpringEpsilon) + log(1 + fabs((decay - velocity) / damped))) / decay;
        return settling > 0 ? settling : 0;
    }
    double reach = fabs(omega - velocity);
    double time = -log(RevenantSpringEpsilon) / omega;
    for (int round = 0; round < 64; round++) {
        double next = (-log(RevenantSpringEpsilon) + log(1 + reach * time)) / omega;
        double moved = fabs(next - time);
        time = next;
        if (!isfinite(time) || moved <= 1e-12 * (time > 1 ? time : 1))
            break;
    }
    if (!isfinite(time))
        return MAXFLOAT;
    double steps = time > RevenantSpringStep ? ceil(time / RevenantSpringStep) : 1;
    while (steps > 1 && revenant_spring_remainder(omega, velocity, (steps - 1) * RevenantSpringStep) <= RevenantSpringEpsilon)
        steps -= 1;
    while (revenant_spring_remainder(omega, velocity, steps * RevenantSpringStep) > RevenantSpringEpsilon)
        steps += 1;
    return steps * RevenantSpringStep;
}

@implementation CASpringAnimation (RevenantSpring)

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
    return revenant_spring_settling([self mass], [self stiffness], [self damping], [self velocity]);
}

@end
