#ifndef REVENANT_SPRING_SOLVER_H
#define REVENANT_SPRING_SOLVER_H

#include <stdbool.h>

typedef struct {
    double mass;
    double stiffness;
    double damping;
    double initialVelocity;
    bool allowsOverdamping;
} RevenantSpringParameters;

double revenant_spring_position(RevenantSpringParameters parameters, double time);
double revenant_spring_settling(RevenantSpringParameters parameters);
bool revenant_spring_perceptual(double perceptualDuration, double bounce, RevenantSpringParameters *parameters);

#endif
