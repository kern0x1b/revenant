#include <math.h>
#include "RevenantSpatial.h"

SPAngle SPAngleMakeWithDegrees(double degrees)
{
    SPAngle angle = {degrees / 180.0 * M_PI};
    return angle;
}

SPAngle SPAngleMakeWithRadians(double radians)
{
    SPAngle angle = {radians};
    return angle;
}

double SPAngleGetDegrees(SPAngle angle)
{
    return angle.radians * 180.0 / M_PI;
}

bool SPAngleEqualToAngle(SPAngle angle1, SPAngle angle2)
{
    return angle1.radians == angle2.radians;
}
