#import "RevenantSpringSolver.h"
#include <float.h>
#include <math.h>

static const double RevenantSpringEpsilon = 0.001;
static const double RevenantSpringStep = 0.1;

static double revenant_spring_remainder(double omega, double velocity, double time)
{
    return fabs(1 + (omega - velocity) * time) * exp(-omega * time);
}

static bool revenant_spring_parameters_valid(RevenantSpringParameters parameters)
{
    return parameters.mass > 0 && parameters.stiffness > 0 && parameters.damping >= 0 &&
           isfinite(parameters.mass) && isfinite(parameters.stiffness) && isfinite(parameters.damping) &&
           isfinite(parameters.initialVelocity);
}

double revenant_spring_position(RevenantSpringParameters parameters, double time)
{
    if (!(time > 0) || !revenant_spring_parameters_valid(parameters))
        return time > 0 ? 1 : 0;
    double omega = sqrt(parameters.stiffness / parameters.mass);
    if (!(omega > 0) || !isfinite(omega))
        return 1;
    double zeta = parameters.damping / (2 * sqrt(parameters.mass * parameters.stiffness));
    if (!isfinite(zeta) || zeta < 1) {
        if (!isfinite(zeta))
            return 1;
        double decay = zeta * omega;
        double damped = omega * sqrt(1 - zeta * zeta);
        double amplitude = (decay - parameters.initialVelocity) / damped;
        return 1 - exp(-decay * time) * (cos(damped * time) + amplitude * sin(damped * time));
    }
    if (zeta == 1 || !parameters.allowsOverdamping)
        return 1 - (1 + (omega - parameters.initialVelocity) * time) * exp(-omega * time);
    double damped = omega * sqrt(zeta * zeta - 1);
    double slow = exp(-(zeta * omega - damped) * time);
    double fast = exp(-(zeta * omega + damped) * time);
    double amplitude = -(zeta * omega + parameters.initialVelocity) / damped;
    return 1 - 0.5 * ((1 + amplitude) * slow + (1 - amplitude) * fast);
}

static double revenant_spring_critical_settling(double omega, double velocity)
{
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
        return FLT_MAX;
    double steps = time > RevenantSpringStep ? ceil(time / RevenantSpringStep) : 1;
    while (steps > 1 && revenant_spring_remainder(omega, velocity, (steps - 1) * RevenantSpringStep) <= RevenantSpringEpsilon)
        steps -= 1;
    while (revenant_spring_remainder(omega, velocity, steps * RevenantSpringStep) > RevenantSpringEpsilon)
        steps += 1;
    return steps * RevenantSpringStep;
}

static double revenant_spring_overdamped_remainder(double slow, double fast, double slowRate, double fastRate, double time)
{
    return fabs(slow * exp(-slowRate * time) + fast * exp(-fastRate * time)) * 0.5;
}

static double revenant_spring_overdamped_root(double slow, double fast, double slowRate, double fastRate, double lower, double upper)
{
    for (int round = 0; round < 80; round++) {
        double middle = (lower + upper) * 0.5;
        if (revenant_spring_overdamped_remainder(slow, fast, slowRate, fastRate, middle) > RevenantSpringEpsilon)
            lower = middle;
        else
            upper = middle;
    }
    return upper;
}

static double revenant_spring_overdamped_settling(double omega, double zeta, double velocity)
{
    double damped = omega * sqrt(zeta * zeta - 1);
    if (!(damped > 0) || !isfinite(damped))
        return revenant_spring_critical_settling(omega, velocity);
    double slowRate = zeta * omega - damped;
    double fastRate = zeta * omega + damped;
    double amplitude = -(zeta * omega + velocity) / damped;
    double slow = 1 + amplitude;
    double fast = 1 - amplitude;
    double total = (fabs(slow) + fabs(fast)) * 0.5;
    if (!(total > 0))
        return 0;
    double upper = (log(total) - log(RevenantSpringEpsilon)) / slowRate;
    if (!(upper > 0) || !isfinite(upper))
        return FLT_MAX;
    double time;
    if (slow < 0 && fast > 0) {
        double zero = -log(-slow / fast) / (fastRate - slowRate);
        double entry = revenant_spring_overdamped_root(slow, fast, slowRate, fastRate, 0, zero);
        double peak = -log(-slowRate * slow / (fastRate * fast)) / (fastRate - slowRate);
        double tail = 0;
        if (peak > zero && peak < upper && revenant_spring_overdamped_remainder(slow, fast, slowRate, fastRate, peak) > RevenantSpringEpsilon)
            tail = revenant_spring_overdamped_root(slow, fast, slowRate, fastRate, peak, upper);
        time = tail > entry ? tail : entry;
    } else {
        time = revenant_spring_overdamped_root(slow, fast, slowRate, fastRate, 0, upper);
    }
    if (!(time > 0) || !isfinite(time))
        return 0;
    double steps = ceil(time / RevenantSpringStep - 1e-9);
    if (steps < 1)
        steps = 1;
    return steps * RevenantSpringStep;
}

double revenant_spring_settling(RevenantSpringParameters parameters)
{
    if (!revenant_spring_parameters_valid(parameters))
        return FLT_MAX;
    double omega = sqrt(parameters.stiffness / parameters.mass);
    double zeta = parameters.damping / (2 * sqrt(parameters.mass * parameters.stiffness));
    if (!(omega > 0) || !isfinite(omega) || !(zeta > 0) || !isfinite(zeta))
        return FLT_MAX;
    if (zeta < 1) {
        double decay = omega * zeta;
        double damped = omega * sqrt(1 - zeta * zeta);
        double settling = (-log(RevenantSpringEpsilon) + log(1 + fabs((decay - parameters.initialVelocity) / damped))) / decay;
        return settling > 0 ? settling : 0;
    }
    if (zeta == 1 || !parameters.allowsOverdamping)
        return revenant_spring_critical_settling(omega, parameters.initialVelocity);
    return revenant_spring_overdamped_settling(omega, zeta, parameters.initialVelocity);
}

bool revenant_spring_perceptual(double perceptualDuration, double bounce, RevenantSpringParameters *parameters)
{
    if (!parameters)
        return false;
    parameters->mass = 1;
    parameters->initialVelocity = 0;
    parameters->allowsOverdamping = true;
    if (!(perceptualDuration > 0) || !isfinite(perceptualDuration)) {
        parameters->stiffness = INFINITY;
        parameters->damping = 10;
        return false;
    }
    double omega = 2 * M_PI / perceptualDuration;
    parameters->stiffness = omega * omega;
    double zeta = bounce >= 0 ? 1 - bounce : 1 / (1 + bounce);
    parameters->damping = 2 * zeta * omega;
    if (!(parameters->damping >= 0))
        parameters->damping = 10;
    return true;
}
