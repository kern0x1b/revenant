#include <math.h>

static inline double revenant_spring_value(double omega, double zeta, double velocity, double time)
{
    if (zeta < 1) {
        double damped = omega * sqrt(1 - zeta * zeta);
        double amplitude = (zeta * omega - velocity) / damped;
        return 1 - exp(-zeta * omega * time) * (cos(damped * time) + amplitude * sin(damped * time));
    }
    if (zeta == 1) {
        return 1 - (1 + (omega - velocity) * time) * exp(-omega * time);
    }
    double root = omega * sqrt(zeta * zeta - 1);
    double r1 = -zeta * omega + root, r2 = -zeta * omega - root;
    double c2 = (-velocity - r1) / (r2 - r1), c1 = 1 - c2;
    return 1 - (c1 * exp(r1 * time) + c2 * exp(r2 * time));
}
