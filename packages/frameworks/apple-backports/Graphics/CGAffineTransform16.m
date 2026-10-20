#import <CoreGraphics/CoreGraphics.h>
#include <math.h>

typedef struct {
    double sine;
    double cosine;
} revenant_sine_cosine;

extern revenant_sine_cosine revenant_sincos_stret(double) __asm("___sincos_stret");

static void revenant_sincos(CGFloat angle, CGFloat *sine, CGFloat *cosine)
{
    revenant_sine_cosine pair = revenant_sincos_stret(angle);
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
        revenant_sincos(angle, &sine, &cosine);
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
        revenant_sincos(rotation, &sine, &cosine);
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
