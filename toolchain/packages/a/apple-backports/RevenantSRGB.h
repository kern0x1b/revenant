#include <math.h>

static inline double charon_srgb_decode(double encoded)
{
    return encoded <= 0.04045 ? encoded / 12.92 : pow((encoded + 0.055) / 1.055, 2.4);
}

static inline double charon_srgb_encode(double linear)
{
    linear = fmin(fmax(linear, 0), 1);
    return linear <= 0.0031308 ? 12.92 * linear : 1.055 * pow(linear, 1 / 2.4) - 0.055;
}
