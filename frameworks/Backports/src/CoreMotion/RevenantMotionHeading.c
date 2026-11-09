#include "RevenantMotionHeading.h"
#include <math.h>

double RevenantMotionHeadingDegrees(double m21, double m22, double m23, double m31, double m32, double m33)
{
    double north;
    double east;
    if (fabs(m33) >= fabs(m23)) {
        north = m21;
        east = -m22;
    } else {
        north = -m31;
        east = m32;
    }
    double degrees = atan2(east, north) * 180.0 / M_PI;
    if (degrees < 0.0) {
        degrees += 360.0;
    }
    if (degrees >= 360.0) {
        degrees -= 360.0;
    }
    return degrees;
}
