#import <CoreGraphics/CoreGraphics.h>
#include <math.h>

// The matrix is [a b; c d] acting on row vectors, with the translation (tx, ty) last. The components are the
// product scale * shear * rotation, with the translation applied after them: the first row of the matrix is
// sx times the unit vector u of the rotation, and the second is sy times (sh * u + v), v being u turned a quarter.
// Measured on the host (tests/backports/host/affine-components): the rotation is the angle of the first row, and sy is
// the second row's component across that angle. A negative sy is the flip: it is made positive, sx is made negative,
// and the rotation is turned a half circle back into [-pi, pi). The host takes the sine and the cosine of an angle
// through one call, and the shear of a singular transform is a quotient of rounding, so the port does the same.
// A matrix with a zero first row has no such angle: the rotation is zero, or a half circle when d is negative.

/* The release takes the sine and the cosine of an angle through __sincos_stret (iOS 7 and later, and macOS). A build for
   an older release links apple-compat's copy of it, which takes the two one at a time, as the SDK does for a deployment
   target before 7.0 (facts/CoreGraphics/AffineComponents.md). */
typedef struct {
    double sine;
    double cosine;
} charon_sine_cosine;

extern charon_sine_cosine charon_sincos_stret(double) __asm("___sincos_stret");

static void charon_sincos(CGFloat angle, CGFloat *sine, CGFloat *cosine)
{
    charon_sine_cosine pair = charon_sincos_stret(angle);
    *sine = pair.sine;
    *cosine = pair.cosine;
}

CGAffineTransformComponents CGAffineTransformDecompose(CGAffineTransform transform)
{
    CGFloat a = transform.a, b = transform.b, c = transform.c, d = transform.d;
    CGFloat length = hypot(a, b);
    CGFloat sx, sy, rotation;
    if (length == 0) {
        BOOL flip = d < 0;
        sx = flip ? -0.0 : 0;
        sy = fabs(d);
        rotation = flip ? -M_PI : 0;
    } else {
        CGFloat angle = atan2(b, a);
        CGFloat sine, cosine;
        charon_sincos(angle, &sine, &cosine);
        CGFloat across = d * cosine - c * sine;
        BOOL flip = across < 0;
        sx = flip ? -length : length;
        sy = flip ? -across : across;
        rotation = angle - (flip ? M_PI : 0);
        if (rotation < -M_PI)
            rotation += 2 * M_PI;
    }
    CGFloat shear = 0;
    if (sy != 0) {
        CGFloat sine, cosine;
        charon_sincos(rotation, &sine, &cosine);
        shear = (c * cosine + d * sine) / sy;
    }
    CGAffineTransformComponents components;
    components.scale = CGSizeMake(sx, sy);
    components.horizontalShear = shear;
    components.rotation = rotation;
    components.translation = CGVectorMake(transform.tx, transform.ty);
    return components;
}

CGAffineTransform CGAffineTransformMakeWithComponents(CGAffineTransformComponents components)
{
    CGFloat sx = components.scale.width, sy = components.scale.height, shear = components.horizontalShear;
    CGFloat cosine = cos(components.rotation), sine = sin(components.rotation);
    return CGAffineTransformMake(sx * cosine, sx * sine,
                                 sy * (shear * cosine - sine), sy * (shear * sine + cosine),
                                 components.translation.dx, components.translation.dy);
}
