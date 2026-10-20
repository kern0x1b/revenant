#ifndef RevenantSpatial_h
#define RevenantSpatial_h

#include <stdbool.h>

typedef struct SPAngle {
    double radians;
} SPAngle;

SPAngle SPAngleMakeWithDegrees(double degrees);
SPAngle SPAngleMakeWithRadians(double radians);
double SPAngleGetDegrees(SPAngle angle);
bool SPAngleEqualToAngle(SPAngle angle1, SPAngle angle2);

#endif
