#ifndef CharonSpatial_h
#define CharonSpatial_h

// The Spatial value types and the functions this library carries, as the port declares them. The declarations are
// the generator's (packages/a/apple-backports/spec/Spatial/declarations.tsv); no SDK header of the release this
// port builds against carries them, and the bodies are the port's own (facts/Spatial/SPAngle.md).

#include <stdbool.h>

typedef struct SPAngle {
    double radians;
} SPAngle;

SPAngle SPAngleMakeWithDegrees(double degrees);
SPAngle SPAngleMakeWithRadians(double radians);
double SPAngleGetDegrees(SPAngle angle);
bool SPAngleEqualToAngle(SPAngle angle1, SPAngle angle2);

#endif /* CharonSpatial_h */
