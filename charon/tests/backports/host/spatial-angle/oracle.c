#include <Spatial/Spatial.h>

double host_angle_make_degrees(double degrees) { return SPAngleMakeWithDegrees(degrees).radians; }
double host_angle_make_radians(double radians) { return SPAngleMakeWithRadians(radians).radians; }
double host_angle_get_degrees(double radians) { return SPAngleGetDegrees(SPAngleMakeWithRadians(radians)); }
int host_angle_equal(double a, double b) { return SPAngleEqualToAngle(SPAngleMakeWithRadians(a), SPAngleMakeWithRadians(b)); }
