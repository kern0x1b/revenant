#include <math.h>

// The sRGB transfer function, the one copy of it for the port: SceneKit's colours and textures, and UIKit's bar appearance.
// decode takes an encoded value in 0...1 to linear light; encode takes a linear value, clamped to 0...1, back.
static inline double charon_srgb_decode(double encoded)
{
    return encoded <= 0.04045 ? encoded / 12.92 : pow((encoded + 0.055) / 1.055, 2.4);
}

static inline double charon_srgb_encode(double linear)
{
    linear = fmin(fmax(linear, 0), 1);
    return linear <= 0.0031308 ? 12.92 * linear : 1.055 * pow(linear, 1 / 2.4) - 0.055;
}
