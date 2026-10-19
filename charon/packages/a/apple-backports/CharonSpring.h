#include <math.h>

// The progress, from 0 to 1, of a damped spring released at 0 toward 1 with an initial velocity in fractions of the
// way per second: omega = sqrt(stiffness / mass), zeta = damping / (2 sqrt(stiffness mass)). One formula for the port:
// UIKit's spring animations and SceneKit's CASpringAnimation both take it from here.
static inline double charon_spring_value(double omega, double zeta, double velocity, double time)
{
    if (zeta < 1) {
        double damped = omega * sqrt(1 - zeta * zeta);
        double amplitude = (zeta * omega - velocity) / damped;
        return 1 - exp(-zeta * omega * time) * (cos(damped * time) + amplitude * sin(damped * time));
    }
    if (zeta == 1) {
        return 1 - (1 + (omega - velocity) * time) * exp(-omega * time);
    }
    // overdamped: x(t) = c1 e^(r1 t) + c2 e^(r2 t) with x(0) = 1 and x'(0) = -velocity; the progress is 1 - x
    double root = omega * sqrt(zeta * zeta - 1);
    double r1 = -zeta * omega + root, r2 = -zeta * omega - root;
    double c2 = (-velocity - r1) / (r2 - r1), c1 = 1 - c2;
    return 1 - (c1 * exp(r1 * time) + c2 * exp(r2 * time));
}
