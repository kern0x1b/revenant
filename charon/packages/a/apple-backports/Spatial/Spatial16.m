#include <math.h>
#include "CharonSpatial.h"

// The SPAngle functions of iOS 16.0. An angle is held in radians; the conversions are the two expressions measured
// bit-for-bit against the host's own Spatial on one million generated inputs (tests/backports/host/spatial-angle,
// facts/Spatial/SPAngle.md). A value is never clamped or wrapped: 2 pi stays 2 pi.

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
