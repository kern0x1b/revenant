#import <Foundation/Foundation.h>
#import <Accelerate/Accelerate.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

#include "CharonResampling.h"

static int checks, failures;
static int loopMisses;
static int quiet;

typedef struct {
    const char *name;
    int horizontal, channels, bytes, isHalf, isSigned, packed, translateIsDouble, scalar;
    double peak;
    unsigned acceptedFlags;
    vImage_Error (*host)(const vImage_Buffer *, const vImage_Buffer *, vImagePixelCount, vImagePixelCount,
                         double, double, ResamplingFilter, const void *, vImage_Flags);
    vImage_Error (*port)(const vImage_Buffer *, const vImage_Buffer *, vImagePixelCount, vImagePixelCount,
                         double, double, ResamplingFilter, const void *, vImage_Flags);
} Shear;

#define ARRAY_BACK(ELEMENT) ((const ELEMENT *)back)
#define SCALAR_BACK(TYPE) (*(const TYPE *)back)
#define HOST_THUNK(NAME, PIXEL, BACK, T)                                                            \
    static vImage_Error host_##NAME(const vImage_Buffer *s, const vImage_Buffer *d, vImagePixelCount ox, \
                                    vImagePixelCount oy, double t, double m, ResamplingFilter f,       \
                                    const void *back, vImage_Flags fl)                              \
    { return NAME(s, d, ox, oy, (T)t, (T)m, f, BACK, fl); }
#define PORT_THUNK(NAME, PIXEL, BACK, T)                                                            \
    static vImage_Error port_##NAME(const vImage_Buffer *s, const vImage_Buffer *d, vImagePixelCount ox, \
                                    vImagePixelCount oy, double t, double m, ResamplingFilter f,       \
                                    const void *back, vImage_Flags fl)                              \
    { return charon_host_##NAME(s, d, ox, oy, (T)t, (T)m, f, BACK, fl); }

#define DECLARE(NAME, PIXEL, BACK, T) \
    vImage_Error charon_host_##NAME(const vImage_Buffer *, const vImage_Buffer *, vImagePixelCount, \
                                    vImagePixelCount, T, T, ResamplingFilter, const PIXEL, vImage_Flags)

DECLARE(vImageHorizontalShearD_ARGB16S, Pixel_ARGB_16S, , double);
DECLARE(vImageHorizontalShearD_ARGB16U, Pixel_ARGB_16U, , double);
DECLARE(vImageHorizontalShear_ARGB16S, Pixel_ARGB_16S, , float);
DECLARE(vImageHorizontalShear_ARGB16U, Pixel_ARGB_16U, , float);
DECLARE(vImageVerticalShearD_ARGB16S, Pixel_ARGB_16S, , double);
DECLARE(vImageVerticalShearD_ARGB16U, Pixel_ARGB_16U, , double);
DECLARE(vImageVerticalShear_ARGB16S, Pixel_ARGB_16S, , float);
DECLARE(vImageVerticalShear_ARGB16U, Pixel_ARGB_16U, , float);
DECLARE(vImageHorizontalShear_Planar16S, Pixel_16S, , float);
DECLARE(vImageHorizontalShear_Planar16U, Pixel_16U, , float);
DECLARE(vImageVerticalShear_Planar16S, Pixel_16S, , float);
DECLARE(vImageVerticalShear_Planar16U, Pixel_16U, , float);
DECLARE(vImageHorizontalShear_CbCr16U, Pixel_16U16U, , float);
DECLARE(vImageHorizontalShear_CbCr8, Pixel_88, , float);
DECLARE(vImageHorizontalShear_XRGB2101010W, Pixel_32U, , float);
DECLARE(vImageVerticalShear_CbCr16U, Pixel_16U16U, , float);
DECLARE(vImageVerticalShear_CbCr8, Pixel_88, , float);
DECLARE(vImageVerticalShear_XRGB2101010W, Pixel_32U, , float);
DECLARE(vImageHorizontalShearD_ARGB16F, Pixel_ARGB_16F, , double);
DECLARE(vImageHorizontalShearD_CbCr16F, Pixel_16F16F, , double);
DECLARE(vImageHorizontalShearD_CbCr16S, Pixel_16S16S, , double);
DECLARE(vImageHorizontalShearD_CbCr16U, Pixel_16U16U, , double);
DECLARE(vImageHorizontalShearD_Planar16F, Pixel_16F, , double);
DECLARE(vImageHorizontalShear_ARGB16F, Pixel_ARGB_16F, , float);
DECLARE(vImageHorizontalShear_CbCr16F, Pixel_16F16F, , float);
DECLARE(vImageHorizontalShear_CbCr16S, Pixel_16S16S, , float);
DECLARE(vImageHorizontalShear_Planar16F, Pixel_16F, , float);
DECLARE(vImageVerticalShearD_ARGB16F, Pixel_ARGB_16F, , double);
DECLARE(vImageVerticalShearD_CbCr16F, Pixel_16F16F, , double);
DECLARE(vImageVerticalShearD_CbCr16S, Pixel_16S16S, , double);
DECLARE(vImageVerticalShearD_CbCr16U, Pixel_16U16U, , double);
DECLARE(vImageVerticalShearD_Planar16F, Pixel_16F, , double);
DECLARE(vImageVerticalShear_ARGB16F, Pixel_ARGB_16F, , float);
DECLARE(vImageVerticalShear_CbCr16F, Pixel_16F16F, , float);
DECLARE(vImageVerticalShear_CbCr16S, Pixel_16S16S, , float);
DECLARE(vImageVerticalShear_Planar16F, Pixel_16F, , float);

HOST_THUNK(vImageHorizontalShearD_ARGB16S, Pixel_ARGB_16S, ARRAY_BACK(int16_t), double)
PORT_THUNK(vImageHorizontalShearD_ARGB16S, Pixel_ARGB_16S, ARRAY_BACK(int16_t), double)
HOST_THUNK(vImageHorizontalShearD_ARGB16U, Pixel_ARGB_16U, ARRAY_BACK(uint16_t), double)
PORT_THUNK(vImageHorizontalShearD_ARGB16U, Pixel_ARGB_16U, ARRAY_BACK(uint16_t), double)
HOST_THUNK(vImageHorizontalShear_ARGB16S, Pixel_ARGB_16S, ARRAY_BACK(int16_t), float)
PORT_THUNK(vImageHorizontalShear_ARGB16S, Pixel_ARGB_16S, ARRAY_BACK(int16_t), float)
HOST_THUNK(vImageHorizontalShear_ARGB16U, Pixel_ARGB_16U, ARRAY_BACK(uint16_t), float)
PORT_THUNK(vImageHorizontalShear_ARGB16U, Pixel_ARGB_16U, ARRAY_BACK(uint16_t), float)
HOST_THUNK(vImageVerticalShearD_ARGB16S, Pixel_ARGB_16S, ARRAY_BACK(int16_t), double)
PORT_THUNK(vImageVerticalShearD_ARGB16S, Pixel_ARGB_16S, ARRAY_BACK(int16_t), double)
HOST_THUNK(vImageVerticalShearD_ARGB16U, Pixel_ARGB_16U, ARRAY_BACK(uint16_t), double)
PORT_THUNK(vImageVerticalShearD_ARGB16U, Pixel_ARGB_16U, ARRAY_BACK(uint16_t), double)
HOST_THUNK(vImageVerticalShear_ARGB16S, Pixel_ARGB_16S, ARRAY_BACK(int16_t), float)
PORT_THUNK(vImageVerticalShear_ARGB16S, Pixel_ARGB_16S, ARRAY_BACK(int16_t), float)
HOST_THUNK(vImageVerticalShear_ARGB16U, Pixel_ARGB_16U, ARRAY_BACK(uint16_t), float)
PORT_THUNK(vImageVerticalShear_ARGB16U, Pixel_ARGB_16U, ARRAY_BACK(uint16_t), float)

HOST_THUNK(vImageHorizontalShear_Planar16S, Pixel_16S, SCALAR_BACK(int16_t), float)
PORT_THUNK(vImageHorizontalShear_Planar16S, Pixel_16S, SCALAR_BACK(int16_t), float)
HOST_THUNK(vImageHorizontalShear_Planar16U, Pixel_16U, SCALAR_BACK(uint16_t), float)
PORT_THUNK(vImageHorizontalShear_Planar16U, Pixel_16U, SCALAR_BACK(uint16_t), float)
HOST_THUNK(vImageVerticalShear_Planar16S, Pixel_16S, SCALAR_BACK(int16_t), float)
PORT_THUNK(vImageVerticalShear_Planar16S, Pixel_16S, SCALAR_BACK(int16_t), float)
HOST_THUNK(vImageVerticalShear_Planar16U, Pixel_16U, SCALAR_BACK(uint16_t), float)
PORT_THUNK(vImageVerticalShear_Planar16U, Pixel_16U, SCALAR_BACK(uint16_t), float)

HOST_THUNK(vImageHorizontalShear_CbCr16U, Pixel_16U16U, ARRAY_BACK(uint16_t), float)
PORT_THUNK(vImageHorizontalShear_CbCr16U, Pixel_16U16U, ARRAY_BACK(uint16_t), float)
HOST_THUNK(vImageHorizontalShear_CbCr8, Pixel_88, ARRAY_BACK(uint8_t), float)
PORT_THUNK(vImageHorizontalShear_CbCr8, Pixel_88, ARRAY_BACK(uint8_t), float)
HOST_THUNK(vImageHorizontalShear_XRGB2101010W, Pixel_32U, SCALAR_BACK(uint32_t), float)
PORT_THUNK(vImageHorizontalShear_XRGB2101010W, Pixel_32U, SCALAR_BACK(uint32_t), float)
HOST_THUNK(vImageVerticalShear_CbCr16U, Pixel_16U16U, ARRAY_BACK(uint16_t), float)
PORT_THUNK(vImageVerticalShear_CbCr16U, Pixel_16U16U, ARRAY_BACK(uint16_t), float)
HOST_THUNK(vImageVerticalShear_CbCr8, Pixel_88, ARRAY_BACK(uint8_t), float)
PORT_THUNK(vImageVerticalShear_CbCr8, Pixel_88, ARRAY_BACK(uint8_t), float)
HOST_THUNK(vImageVerticalShear_XRGB2101010W, Pixel_32U, SCALAR_BACK(uint32_t), float)
PORT_THUNK(vImageVerticalShear_XRGB2101010W, Pixel_32U, SCALAR_BACK(uint32_t), float)

HOST_THUNK(vImageHorizontalShearD_ARGB16F, Pixel_ARGB_16F, ARRAY_BACK(uint16_t), double)
PORT_THUNK(vImageHorizontalShearD_ARGB16F, Pixel_ARGB_16F, ARRAY_BACK(uint16_t), double)
HOST_THUNK(vImageHorizontalShearD_CbCr16F, Pixel_16F16F, ARRAY_BACK(uint16_t), double)
PORT_THUNK(vImageHorizontalShearD_CbCr16F, Pixel_16F16F, ARRAY_BACK(uint16_t), double)
HOST_THUNK(vImageHorizontalShearD_CbCr16S, Pixel_16S16S, ARRAY_BACK(int16_t), double)
PORT_THUNK(vImageHorizontalShearD_CbCr16S, Pixel_16S16S, ARRAY_BACK(int16_t), double)
HOST_THUNK(vImageHorizontalShearD_CbCr16U, Pixel_16U16U, ARRAY_BACK(uint16_t), double)
PORT_THUNK(vImageHorizontalShearD_CbCr16U, Pixel_16U16U, ARRAY_BACK(uint16_t), double)
HOST_THUNK(vImageHorizontalShearD_Planar16F, Pixel_16F, SCALAR_BACK(uint16_t), double)
PORT_THUNK(vImageHorizontalShearD_Planar16F, Pixel_16F, SCALAR_BACK(uint16_t), double)
HOST_THUNK(vImageHorizontalShear_ARGB16F, Pixel_ARGB_16F, ARRAY_BACK(uint16_t), float)
PORT_THUNK(vImageHorizontalShear_ARGB16F, Pixel_ARGB_16F, ARRAY_BACK(uint16_t), float)
HOST_THUNK(vImageHorizontalShear_CbCr16F, Pixel_16F16F, ARRAY_BACK(uint16_t), float)
PORT_THUNK(vImageHorizontalShear_CbCr16F, Pixel_16F16F, ARRAY_BACK(uint16_t), float)
HOST_THUNK(vImageHorizontalShear_CbCr16S, Pixel_16S16S, ARRAY_BACK(int16_t), float)
PORT_THUNK(vImageHorizontalShear_CbCr16S, Pixel_16S16S, ARRAY_BACK(int16_t), float)
HOST_THUNK(vImageHorizontalShear_Planar16F, Pixel_16F, SCALAR_BACK(uint16_t), float)
PORT_THUNK(vImageHorizontalShear_Planar16F, Pixel_16F, SCALAR_BACK(uint16_t), float)
HOST_THUNK(vImageVerticalShearD_ARGB16F, Pixel_ARGB_16F, ARRAY_BACK(uint16_t), double)
PORT_THUNK(vImageVerticalShearD_ARGB16F, Pixel_ARGB_16F, ARRAY_BACK(uint16_t), double)
HOST_THUNK(vImageVerticalShearD_CbCr16F, Pixel_16F16F, ARRAY_BACK(uint16_t), double)
PORT_THUNK(vImageVerticalShearD_CbCr16F, Pixel_16F16F, ARRAY_BACK(uint16_t), double)
HOST_THUNK(vImageVerticalShearD_CbCr16S, Pixel_16S16S, ARRAY_BACK(int16_t), double)
PORT_THUNK(vImageVerticalShearD_CbCr16S, Pixel_16S16S, ARRAY_BACK(int16_t), double)
HOST_THUNK(vImageVerticalShearD_CbCr16U, Pixel_16U16U, ARRAY_BACK(uint16_t), double)
PORT_THUNK(vImageVerticalShearD_CbCr16U, Pixel_16U16U, ARRAY_BACK(uint16_t), double)
HOST_THUNK(vImageVerticalShearD_Planar16F, Pixel_16F, SCALAR_BACK(uint16_t), double)
PORT_THUNK(vImageVerticalShearD_Planar16F, Pixel_16F, SCALAR_BACK(uint16_t), double)
HOST_THUNK(vImageVerticalShear_ARGB16F, Pixel_ARGB_16F, ARRAY_BACK(uint16_t), float)
PORT_THUNK(vImageVerticalShear_ARGB16F, Pixel_ARGB_16F, ARRAY_BACK(uint16_t), float)
HOST_THUNK(vImageVerticalShear_CbCr16F, Pixel_16F16F, ARRAY_BACK(uint16_t), float)
PORT_THUNK(vImageVerticalShear_CbCr16F, Pixel_16F16F, ARRAY_BACK(uint16_t), float)
HOST_THUNK(vImageVerticalShear_CbCr16S, Pixel_16S16S, ARRAY_BACK(int16_t), float)
PORT_THUNK(vImageVerticalShear_CbCr16S, Pixel_16S16S, ARRAY_BACK(int16_t), float)
HOST_THUNK(vImageVerticalShear_Planar16F, Pixel_16F, SCALAR_BACK(uint16_t), float)
PORT_THUNK(vImageVerticalShear_Planar16F, Pixel_16F, SCALAR_BACK(uint16_t), float)

static const Shear shears[] = {
#define ENTRY(NAME, H, C, B, HALF, SIGNED, PACKED, T, SCALAR, PEAK, FLAGS) \
    { #NAME, H, C, B, HALF, SIGNED, PACKED, T, SCALAR, PEAK, FLAGS, host_##NAME, port_##NAME }
    ENTRY(vImageHorizontalShearD_ARGB16S, 1, 4, 2, 0, 1, 0, 1, 0, 30000.0, 0xFFFFFFFFu),
    ENTRY(vImageHorizontalShearD_ARGB16U, 1, 4, 2, 0, 0, 0, 1, 0, 30000.0, 0xFFFFFFFFu),
    ENTRY(vImageHorizontalShear_ARGB16S, 1, 4, 2, 0, 1, 0, 0, 0, 30000.0, 0xFFFFFFFFu),
    ENTRY(vImageHorizontalShear_ARGB16U, 1, 4, 2, 0, 0, 0, 0, 0, 30000.0, 0xFFFFFFFFu),
    ENTRY(vImageVerticalShearD_ARGB16S, 0, 4, 2, 0, 1, 0, 1, 0, 30000.0, 0xFFFFFFFFu),
    ENTRY(vImageVerticalShearD_ARGB16U, 0, 4, 2, 0, 0, 0, 1, 0, 30000.0, 0xFFFFFFFFu),
    ENTRY(vImageVerticalShear_ARGB16S, 0, 4, 2, 0, 1, 0, 0, 0, 30000.0, 0xFFFFFFFFu),
    ENTRY(vImageVerticalShear_ARGB16U, 0, 4, 2, 0, 0, 0, 0, 0, 30000.0, 0xFFFFFFFFu),
    ENTRY(vImageHorizontalShear_Planar16S, 1, 1, 2, 0, 1, 0, 0, 1, 30000.0, 0xFFFFFFFFu),
    ENTRY(vImageHorizontalShear_Planar16U, 1, 1, 2, 0, 0, 0, 0, 1, 30000.0, 0xFFFFFFFFu),
    ENTRY(vImageVerticalShear_Planar16S, 0, 1, 2, 0, 1, 0, 0, 1, 30000.0, 0xFFFFFFFFu),
    ENTRY(vImageVerticalShear_Planar16U, 0, 1, 2, 0, 0, 0, 0, 1, 30000.0, 0xFFFFFFFFu),
    ENTRY(vImageHorizontalShear_CbCr16U, 1, 2, 2, 0, 0, 0, 0, 0, 30000.0, 0xFFFFFFFFu),
    ENTRY(vImageHorizontalShear_CbCr8, 1, 2, 1, 0, 0, 0, 0, 0, 255.0, 0xFFFFFFFFu),
    ENTRY(vImageHorizontalShear_XRGB2101010W, 1, 4, 0, 0, 0, 1, 0, 1, 1023.0, 0xFFFFFFFFu),
    ENTRY(vImageVerticalShear_CbCr16U, 0, 2, 2, 0, 0, 0, 0, 0, 30000.0, 0xFFFFFFFFu),
    ENTRY(vImageVerticalShear_CbCr8, 0, 2, 1, 0, 0, 0, 0, 0, 255.0, 0xFFFFFFFFu),
    ENTRY(vImageVerticalShear_XRGB2101010W, 0, 4, 0, 0, 0, 1, 0, 1, 1023.0, 0xFFFFFFFFu),
    ENTRY(vImageHorizontalShearD_ARGB16F, 1, 4, 0, 1, 0, 0, 1, 0, 3.0, 0x000011bcu),
    ENTRY(vImageHorizontalShearD_CbCr16F, 1, 2, 0, 1, 0, 0, 1, 0, 3.0, 0x000011bcu),
    ENTRY(vImageHorizontalShearD_CbCr16S, 1, 2, 2, 0, 1, 0, 1, 0, 30000.0, 0xFFFFFFFFu),
    ENTRY(vImageHorizontalShearD_CbCr16U, 1, 2, 2, 0, 0, 0, 1, 0, 30000.0, 0xFFFFFFFFu),
    ENTRY(vImageHorizontalShearD_Planar16F, 1, 1, 0, 1, 0, 0, 1, 1, 3.0, 0x000011bcu),
    ENTRY(vImageHorizontalShear_ARGB16F, 1, 4, 0, 1, 0, 0, 0, 0, 3.0, 0x000011bcu),
    ENTRY(vImageHorizontalShear_CbCr16F, 1, 2, 0, 1, 0, 0, 0, 0, 3.0, 0x000011bcu),
    ENTRY(vImageHorizontalShear_CbCr16S, 1, 2, 2, 0, 1, 0, 0, 0, 30000.0, 0xFFFFFFFFu),
    ENTRY(vImageHorizontalShear_Planar16F, 1, 1, 0, 1, 0, 0, 0, 1, 3.0, 0x000011bcu),
    ENTRY(vImageVerticalShearD_ARGB16F, 0, 4, 0, 1, 0, 0, 1, 0, 3.0, 0x000011bcu),
    ENTRY(vImageVerticalShearD_CbCr16F, 0, 2, 0, 1, 0, 0, 1, 0, 3.0, 0x000011bcu),
    ENTRY(vImageVerticalShearD_CbCr16S, 0, 2, 2, 0, 1, 0, 1, 0, 30000.0, 0xFFFFFFFFu),
    ENTRY(vImageVerticalShearD_CbCr16U, 0, 2, 2, 0, 0, 0, 1, 0, 30000.0, 0xFFFFFFFFu),
    ENTRY(vImageVerticalShearD_Planar16F, 0, 1, 0, 1, 0, 0, 1, 1, 3.0, 0x000011bcu),
    ENTRY(vImageVerticalShear_ARGB16F, 0, 4, 0, 1, 0, 0, 0, 0, 3.0, 0x000011bcu),
    ENTRY(vImageVerticalShear_CbCr16F, 0, 2, 0, 1, 0, 0, 0, 0, 3.0, 0x000011bcu),
    ENTRY(vImageVerticalShear_CbCr16S, 0, 2, 2, 0, 1, 0, 0, 0, 30000.0, 0xFFFFFFFFu),
    ENTRY(vImageVerticalShear_Planar16F, 0, 1, 0, 1, 0, 0, 0, 1, 3.0, 0x000011bcu),
#undef ENTRY
};
static const int shearCount = (int)(sizeof shears / sizeof *shears);

static uint16_t packHalf(double value)
{
    uint32_t bits;
    double magnitude = fabs(value);
    if (magnitude >= 65520.0) {
        bits = 0x7BFF;
    } else if (magnitude < 6.103515625e-05) {
        double scaled = magnitude / 5.9604644775390625e-08;
        uint32_t mantissa = (uint32_t)(scaled + 0.5);
        bits = mantissa > 1023 ? 1023 : mantissa;
    } else {
        int exponent = 0;
        double scaled = magnitude;
        while (scaled >= 2.0) { scaled /= 2.0; exponent++; }
        while (scaled < 1.0) { scaled *= 2.0; exponent--; }
        uint32_t round = (uint32_t)((scaled - 1.0) * 1024.0 + 0.5);
        uint32_t exponentField = (uint32_t)(exponent + 15);
        if (round >= 1024) { round = 0; exponentField++; }
        bits = exponentField >= 31 ? 0x7C00u : ((exponentField << 10) | round);
    }
    return (uint16_t)((value < 0.0) ? (bits | 0x8000u) : bits);
}

static double unpackHalf(uint16_t bits)
{
    uint32_t exponent = (bits >> 10) & 0x1Fu, mantissa = bits & 0x3FFu;
    double value;
    if (exponent == 0) value = (double)mantissa * 5.9604644775390625e-08;
    else if (exponent == 31) value = mantissa ? 0.0 / 0.0 : 1.0 / 0.0;
    else value = ldexp((double)(mantissa + 1024) / 1024.0, (int)exponent - 15);
    return (bits & 0x8000u) ? -value : value;
}

static size_t bytesPerPixel(const Shear *shear)
{
    if (shear->packed) return 4;
    if (shear->isHalf) return (size_t)shear->channels * 2;
    return (size_t)shear->channels * (size_t)shear->bytes;
}

static double loadChannel(const void *pixel, unsigned channel, const Shear *shear)
{
    if (shear->isHalf) return unpackHalf(((const uint16_t *)pixel)[channel]);
    switch (shear->bytes) {
    case 1: return (double)((const uint8_t *)pixel)[channel];
    case 2: return shear->isSigned ? (double)((const int16_t *)pixel)[channel]
                                   : (double)((const uint16_t *)pixel)[channel];
    default: break;
    }
    return (double)((*((const uint32_t *)pixel) >> (channel * 10)) & 0x3FFu);
}

static double clampChannel(double value, int isSigned, int bytes)
{
    if (bytes == 1) return value < 0.0 ? 0.0 : (value > 255.0 ? 255.0 : value);
    if (isSigned) return value < -32768.0 ? -32768.0 : (value > 32767.0 ? 32767.0 : value);
    return value < 0.0 ? 0.0 : (value > 65535.0 ? 65535.0 : value);
}

static double roundHalfUp(double value)
{
    return value >= 0.0 ? floor(value + 0.5) : ceil(value - 0.5);
}

static void storeChannel(void *pixel, unsigned channel, double value, const Shear *shear)
{
    if (shear->isHalf) {
        ((uint16_t *)pixel)[channel] = packHalf(value);
        return;
    }
    switch (shear->bytes) {
    case 1: ((uint8_t *)pixel)[channel] = (uint8_t)roundHalfUp(clampChannel(value, 0, 1)); return;
    case 2:
        if (shear->isSigned) ((int16_t *)pixel)[channel] = (int16_t)roundHalfUp(clampChannel(value, 1, 2));
        else ((uint16_t *)pixel)[channel] = (uint16_t)roundHalfUp(clampChannel(value, 0, 2));
        return;
    default: break;
    }
    uint32_t word = *(uint32_t *)pixel, shift = channel * 10;
    word = (word & ~(0x3FFu << shift)) | (((uint32_t)roundHalfUp(clampChannel(value, 0, 2)) & 0x3FFu) << shift);
    *(uint32_t *)pixel = word;
}

typedef struct {
    double reciprocal;
    unsigned numTaps, floatStride, int16Stride, phases, exponent, offset;
    const int16_t *table;
    unsigned width, centre;
} ReadFilter;

static uint64_t fieldSlot(const void *object, unsigned index)
{
    return *(const uintptr_t *)((const char *)object + (size_t)index * sizeof(uintptr_t));
}

static int readFilter(ResamplingFilter filter, ReadFilter *out)
{
    memset(out, 0, sizeof *out);
    if (!filter)
        return 0;
    double reciprocal;
    uint64_t bits = fieldSlot(filter, 0);
    memcpy(&reciprocal, &bits, sizeof reciprocal);
    out->reciprocal = reciprocal;
    out->numTaps = (unsigned)fieldSlot(filter, 1);
    out->floatStride = (unsigned)fieldSlot(filter, 2);
    out->int16Stride = (unsigned)fieldSlot(filter, 3);
    out->phases = (unsigned)fieldSlot(filter, 4);
    out->exponent = (unsigned)fieldSlot(filter, 5);
    out->offset = (unsigned)fieldSlot(filter, 6);
    out->table = (const int16_t *)(uintptr_t)fieldSlot(filter, 7);
    out->width = out->int16Stride / 2;
    if (!(out->reciprocal > 0.0) || out->numTaps < 1 || out->int16Stride < 2 || (out->int16Stride & 1))
        return 0;
    if (out->phases == 0 || out->phases > 64 || (out->phases & (out->phases - 1)))
        return 0;
    size_t inside = (size_t)((const char *)out->table - (const char *)filter);
    if (inside == 0 || inside >= (size_t)out->offset)
        return 0;
    if (inside + (size_t)out->phases * out->int16Stride != (size_t)out->offset)
        return 0;
    int best = -(1 << 30);
    for (unsigned k = 0; k < out->width; k++)
        if (out->table[k] > best) { best = out->table[k]; out->centre = k; }
    return 1;
}

typedef struct { double alongShift; int translateSign; double slopeShift; int halfPixel; int farAnchor; } Mapping;
static Mapping mapping = { 0.0, 1, 0.5, 1, 1 };

static double expectSample(const Shear *shear, const uint8_t *srcRow, size_t srcStep, vImagePixelCount srcAlong,
                           const ReadFilter *filter, int extend, const double *back, unsigned channel,
                           double centre, int horizontal)
{
    double whole = floor(centre);
    double fraction = centre - whole;
    long low = (long)whole;
    unsigned phase;
    long base;
    if (horizontal) {
        long q = (long)floor(fraction * (double)filter->phases + 0.5);
        long carry = q / (long)filter->phases;
        phase = (unsigned)(q - carry * (long)filter->phases);
        base = low + carry;
    } else {
        phase = (unsigned)(long)floor(fraction * (double)filter->phases);
        base = low;
    }

    const int16_t *row = filter->table + (size_t)phase * filter->width;
    long total = 0;
    for (unsigned k = 0; k < filter->width; k++)
        total += row[k];
    double accumulator = 0.0;
    for (unsigned k = 0; k < filter->width; k++) {
        long at = base + (long)k - (long)filter->centre;
        double weight = (double)row[k];
        if (row[k] == 0)
            continue;
        double value;
        if (at < 0 || at >= (long)srcAlong) {
            if (!extend) value = back[channel];
            else value = loadChannel(srcRow + (size_t)(at < 0 ? 0 : (long)srcAlong - 1) * srcStep, channel, shear);
        } else {
            value = loadChannel(srcRow + (size_t)at * srcStep, channel, shear);
        }
        accumulator += weight * value;
    }
    return total ? accumulator / (double)total : 0.0;
}

static const char *formLabel[] = {
    "A + (position - A)*recip - 0.5               the far anchor bracketed",
    "position*recip + (A - A*recip) - 0.5         the same, the anchor as a difference",
    "position*recip + A*(1 - recip) - 0.5         the same, the anchor a product",
    "position*recip + A*(1 - 1/scale) - 0.5       the anchor against 1/scale rather than against recip",
    "A + (position - A)*recip + 0.5*recip - 0.5   the half pixel distributed over the two ends",
    "A + (position - A)*recip + (0.5*recip - 0.5) the half pixel as one constant",
    "A + (position - A)/scale - 0.5               DIVIDE by 1/recip rather than multiply by recip",
    "position*recip - 0.5                         NO far anchor at all",
    "A + (position - A)*recip - 0.5*recip + 0.5   the half pixel moved to the far end",
    "(position - 0.5)*recip + A*(1 - recip) + 0.5 the half pixel moved inside, the anchor a product",
    "position*recip + A*(1 - recip) - 0.5         the anchor a product, position WITHOUT the +0.5",
    "position*recip + A*(1 - recip) - 0.5         the anchor a product, position WITH the +0.5",
};
enum { FormBracketed, FormDifference, FormProduct, FormAgainstScale, FormHalfDistributed, FormHalfConstant,
       FormDivide, FormNoAnchor, FormHalfInside, FormHalfAtFarEnd, FormHalfInsideOut, FormDistributed, FormCount };

static int form = FormDistributed;

static void expectDestination(const Shear *shear, const vImage_Buffer *src, const vImage_Buffer *dest,
                              vImagePixelCount along0, vImagePixelCount cross0, double translate, double slope,
                              const ReadFilter *filter, int extend, const double *back, vImage_Buffer *out)
{
    vImagePixelCount dstAlong = shear->horizontal ? dest->width : dest->height;
    vImagePixelCount dstCross = shear->horizontal ? dest->height : dest->width;
    vImagePixelCount srcAlong = shear->horizontal ? src->width : src->height;
    size_t pixelBytes = bytesPerPixel(shear);
    double recip = filter->reciprocal, scale = filter->reciprocal ? 1.0 / filter->reciprocal : 1.0;
    double A = (double)dstAlong;
    for (vImagePixelCount cross = 0; cross < dstCross; cross++) {
        long sourceCross = (long)cross0 + (long)cross;
        const uint8_t *srcRow = shear->horizontal
                                    ? (const uint8_t *)src->data + (size_t)sourceCross * src->rowBytes
                                    : (const uint8_t *)src->data + (size_t)sourceCross * pixelBytes;
        for (vImagePixelCount along = 0; along < dstAlong; along++) {
            int horizontal = shear->horizontal;
            int insideHalfPixel = (form == FormHalfInside || form == FormHalfInsideOut);
            double position = (double)(along0 + along) + mapping.alongShift
                              + (horizontal ? mapping.translateSign * -translate : mapping.translateSign * translate)
                              + slope * (horizontal ? (double)cross - (double)dstCross + mapping.slopeShift
                                                    : (double)cross + mapping.slopeShift);
            if (mapping.halfPixel && !insideHalfPixel)
                position += 0.5;
            double centre;
            if (horizontal) {
                centre = mapping.halfPixel ? position * recip - 0.5 : position * recip;
            } else {
                switch (form) {
                case FormBracketed: centre = A + (position - A) * recip - 0.5; break;
                case FormDifference: centre = position * recip + (A - A * recip) - 0.5; break;
                case FormProduct: centre = position * recip + A * (1.0 - recip) - 0.5; break;
                case FormAgainstScale: centre = position * recip + A * (1.0 - 1.0 / scale) - 0.5; break;
                case FormHalfDistributed: centre = A + (position - A) * recip + 0.5 * recip - 0.5; break;
                case FormHalfConstant: centre = A + (position - A) * recip + (0.5 * recip - 0.5); break;
                case FormDivide: centre = A + (position - A) / scale - 0.5; break;
                case FormNoAnchor: centre = position * recip - 0.5; break;
                case FormHalfInside: centre = A + (position - A) * recip - 0.5 * recip + 0.5; break;
                case FormHalfInsideOut: centre = (position - 0.5) * recip + A * (1.0 - recip) + 0.5; break;
                case FormDistributed: centre = position * recip + A * (1.0 - recip) - 0.5; break;
                default: centre = position * recip + A * (1.0 - recip) - 0.5; break;
                }
            }
            uint8_t *pixel = shear->horizontal
                                 ? (uint8_t *)out->data + (size_t)cross * out->rowBytes + (size_t)along * pixelBytes
                                 : (uint8_t *)out->data + (size_t)along * out->rowBytes + (size_t)cross * pixelBytes;
            for (unsigned channel = 0; channel < (unsigned)shear->channels; channel++) {
                double sample = expectSample(shear, srcRow,
                                             shear->horizontal ? pixelBytes : src->rowBytes, srcAlong,
                                             filter, extend, back, channel, centre, shear->horizontal);
                storeChannel(pixel, channel, sample, shear);
            }
        }
    }
}

#define GUARD 0xA5

static vImage_Buffer makeBuffer(vImagePixelCount width, vImagePixelCount height, size_t pixelBytes, size_t pad)
{
    vImage_Buffer b = {0};
    b.width = width;
    b.height = height;
    b.rowBytes = width * pixelBytes + pad;
    b.data = malloc((size_t)b.rowBytes * height);
    memset(b.data, GUARD, (size_t)b.rowBytes * height);
    return b;
}

static void fillSource(vImage_Buffer *src, const Shear *shear)
{
    size_t pixelBytes = bytesPerPixel(shear);
    for (vImagePixelCount row = 0; row < src->height; row++)
        for (vImagePixelCount column = 0; column < src->width; column++) {
            uint8_t *pixel = (uint8_t *)src->data + (size_t)row * src->rowBytes + (size_t)column * pixelBytes;
            for (unsigned channel = 0; channel < (unsigned)shear->channels; channel++) {
                double value = 1.0 + (double)((row * 7 + column * 13 + channel * 29) % 61) * (shear->peak / 61.0);
                storeChannel(pixel, channel, value, shear);
            }
        }
}

static void fillBackColor(const Shear *shear, void *back, double *backScale)
{
    for (unsigned channel = 0; channel < 4; channel++) {
        double value = channel < (unsigned)shear->channels ? -(0.5 + 0.25 * channel) : 0.0;
        backScale[channel] = value;
        if (channel < (unsigned)shear->channels) storeChannel(back, channel, value, shear);
    }
    for (unsigned channel = 0; channel < (unsigned)shear->channels; channel++)
        backScale[channel] = loadChannel(back, channel, shear);
}

static int sameBuffer(char *into, size_t n, const char *prefix, const uint8_t *a, const uint8_t *b,
                      const vImage_Buffer *buffer, const char *what)
{
    size_t total = (size_t)buffer->rowBytes * buffer->height;
    for (size_t at = 0; at < total; at++) {
        if (a[at] == b[at]) continue;
        snprintf(into, n, "%s at byte %zu of a %ux%u buffer, %g against %g (%s)", prefix, at, (unsigned)buffer->width,
                 (unsigned)buffer->height, (double)a[at], (double)b[at], what);
        return 0;
    }
    snprintf(into, n, "%s, and the buffers are byte for byte equal", prefix);
    return 1;
}

static void one(const Shear *shear, vImagePixelCount srcW, vImagePixelCount srcH, vImagePixelCount dstW,
                vImagePixelCount dstH, vImagePixelCount along0, vImagePixelCount cross0, double translate,
                double slope, float scale, vImage_Flags flags, int lobes, const char *label)
{
    size_t pixelBytes = bytesPerPixel(shear);
    size_t pad = pixelBytes + 3;
    if (pad % 2) pad++;
    vImage_Buffer src = makeBuffer(srcW, srcH, pixelBytes, 0), theirDest = makeBuffer(dstW, dstH, pixelBytes, pad),
                 ourDest = makeBuffer(dstW, dstH, pixelBytes, pad), mine = makeBuffer(dstW, dstH, pixelBytes, pad);
    fillSource(&src, shear);
    uint8_t back[8];
    memset(back, 0, sizeof back);
    double backScale[4];
    fillBackColor(shear, back, backScale);

    ResamplingFilter theirFilter = vImageNewResamplingFilter(scale, (flags & kvImageHighQualityResampling));
    vImage_Error theirs = shear->host(&src, &theirDest, along0, cross0, translate, slope, theirFilter, back, flags);
    ReadFilter read;
    if (!readFilter(theirFilter, &read)) {
        printf("FAIL %s: this Mac's own filter is not one of the two measured shapes, so the port cannot be "
               "exercised at all (reciprocal %g numTaps %u iStride %u phases %u offset %u)\n",
               shear->name, read.reciprocal, read.numTaps, read.int16Stride, read.phases, read.offset);
        checks++;
        failures++;
        vImageDestroyResamplingFilter(theirFilter);
        free(src.data); free(theirDest.data); free(ourDest.data); free(mine.data);
        return;
    }
    vImage_Error ours = shear->port(&src, &ourDest, along0, cross0, translate, slope, theirFilter, back, flags);

    static int dumped = 0;
    char what[256], note[320];
    snprintf(what, sizeof what, "%s %s %ux%u into %ux%u offsets %u,%u translate %g slope %g scale %g flags 0x%x",
             shear->name, label, (unsigned)srcW, (unsigned)srcH, (unsigned)dstW, (unsigned)dstH,
             (unsigned)along0, (unsigned)cross0, translate, slope, (double)scale, (unsigned)flags);

    checks++;
    if (theirs != ours) {
        failures++;
        if (!quiet) printf("FAIL %s: the host answers %ld and the port %ld\n", what, (long)theirs, (long)ours);
    }
    if (theirs != kvImageNoError) {
        if (!sameBuffer(note, sizeof note, "the case was refused and one side wrote over the guard",
                        (const uint8_t *)theirDest.data, (const uint8_t *)ourDest.data, &theirDest,
                        "host against port")) {
            failures++;
            if (!quiet) printf("FAIL %s: %s\n", what, note);
        }
        free(src.data); free(theirDest.data); free(ourDest.data); free(mine.data);
        return;
    }
    expectDestination(shear, &src, &theirDest, along0, cross0, translate, slope, &read,
                      (flags & kvImageEdgeExtend) ? 1 : 0, backScale, &mine);

    if (!sameBuffer(note, sizeof note, "the port and the host differ",
                    (const uint8_t *)theirDest.data, (const uint8_t *)ourDest.data, &theirDest,
                    "host against port")) {
        failures++;
        if (!quiet) printf("FAIL %s: %s\n", what, note);
        if (getenv("DUMP") && dumped < 3) {
            dumped++;
            for (int side = 0; side < 3; side++) {
                const vImage_Buffer *buffer = side == 0 ? &theirDest : (side == 1 ? &ourDest : &mine);
                for (vImagePixelCount r = 0; r < buffer->height; r++) {
                    printf("      %-5s row %u:", side == 0 ? "host" : (side == 1 ? "port" : "loops"),
                           (unsigned)r);
                    for (vImagePixelCount c = 0; c < buffer->width; c++)
                        printf(" %6ld", (long)loadChannel((const uint8_t *)buffer->data
                                                          + (size_t)r * buffer->rowBytes + (size_t)c * pixelBytes,
                                                          0, shear));
                    printf("\n");
                }
            }
        }
    }
    if (!sameBuffer(note, sizeof note, "the host and this file's own loops differ",
                    (const uint8_t *)theirDest.data, (const uint8_t *)mine.data, &theirDest,
                    "host against expectation")) {
        failures++;
        loopMisses++;
        if (!quiet) printf("FAIL %s: %s\n", what, note);
    }
    if (!sameBuffer(note, sizeof note, "the port and this file's own loops differ",
                    (const uint8_t *)ourDest.data, (const uint8_t *)mine.data, &ourDest,
                    "port against expectation")) {
        failures++;
        if (!quiet) printf("FAIL %s: %s\n", what, note);
    }
    free(src.data); free(theirDest.data); free(ourDest.data); free(mine.data);
}

static void refusals(const Shear *shear)
{
    vImage_Buffer src = makeBuffer(9, 5, bytesPerPixel(shear), 0), dest = makeBuffer(9, 5, bytesPerPixel(shear), 0);
    fillSource(&src, shear);
    uint8_t back[8];
    memset(back, 0, sizeof back);
    double backScale[4];
    fillBackColor(shear, back, backScale);
    ResamplingFilter filter = vImageNewResamplingFilter(1.0f, kvImageNoFlags);
    char what[256], note[256];

    struct { const char *name; const vImage_Buffer *src; const vImage_Buffer *dest; ResamplingFilter filter; }
    cases[] = {
        { "a NULL source", NULL, &dest, filter },
        { "a NULL destination", &src, NULL, filter },
        { "a NULL filter", &src, &dest, NULL },
    };
    for (unsigned c = 0; c < 3; c++) {
        vImage_Error theirs = shear->host(cases[c].src, cases[c].dest, 0, 0, 0.0, 0.0, cases[c].filter, back,
                                          kvImageBackgroundColorFill);
        vImage_Error ours = shear->port(cases[c].src, cases[c].dest, 0, 0, 0.0, 0.0,
                                        cases[c].filter, back, kvImageBackgroundColorFill);
        checks++;
        snprintf(what, sizeof what, "%s: %s", shear->name, cases[c].name);
        if (theirs != ours) {
            failures++;
            if (!quiet) printf("FAIL %s: the host answers %ld and the port %ld\n", what, (long)theirs, (long)ours);
        }
    }

    struct { const char *name; vImagePixelCount sa, sc, da, dc, along, cross; vImage_Error want; } shapes[] = {
        { "the region at the origin", 9, 5, 9, 5, 0, 0, kvImageNoError },
        { "an across offset of one", 9, 5, 9, 5, 0, 1, kvImageBufferSizeMismatch },
        { "an across offset of one with a destination of three", 9, 5, 9, 3, 0, 1, kvImageNoError },
        { "an across offset of three with a destination of three", 9, 5, 9, 3, 0, 3, kvImageBufferSizeMismatch },
        { "a destination wider across than the source", 9, 5, 9, 6, 0, 0, kvImageBufferSizeMismatch },
        { "a destination longer along than the source", 9, 5, 12, 5, 0, 0, kvImageNoError },
        { "an along offset of two", 9, 5, 9, 5, 2, 0, kvImageNoError },
        { "an along offset beyond the source", 9, 5, 9, 5, 12, 0, kvImageNoError },
    };
    for (unsigned c = 0; c < sizeof shapes / sizeof *shapes; c++) {
        vImagePixelCount sw = shear->horizontal ? shapes[c].sa : shapes[c].sc;
        vImagePixelCount sh = shear->horizontal ? shapes[c].sc : shapes[c].sa;
        vImagePixelCount dw = shear->horizontal ? shapes[c].da : shapes[c].dc;
        vImagePixelCount dh = shear->horizontal ? shapes[c].dc : shapes[c].da;
        vImagePixelCount ox = shear->horizontal ? shapes[c].along : shapes[c].cross;
        vImagePixelCount oy = shear->horizontal ? shapes[c].cross : shapes[c].along;
        vImage_Buffer shaped = makeBuffer(sw, sh, bytesPerPixel(shear), 0);
        vImage_Buffer wide = makeBuffer(dw, dh, bytesPerPixel(shear), 0);
        fillSource(&shaped, shear);
        fillSource(&wide, shear);
        vImage_Error theirs = shear->host(&shaped, &wide, ox, oy, 0.0, 0.0, filter, back, kvImageBackgroundColorFill);
        vImage_Error ours = shear->port(&shaped, &wide, ox, oy, 0.0, 0.0, filter, back, kvImageBackgroundColorFill);
        checks++;
        snprintf(what, sizeof what, "%s: %s", shear->name, shapes[c].name);
        snprintf(note, sizeof note, "the host answers %ld, the port %ld, and the measurement is %ld",
                 (long)theirs, (long)ours, (long)shapes[c].want);
        if (theirs != shapes[c].want || ours != shapes[c].want) {
            failures++;
            if (!quiet) printf("FAIL %s: %s\n", what, note);
        }
        free(wide.data);
        free(shaped.data);
    }

    for (unsigned bit = 0; bit < 32; bit++) {
        vImage_Flags flags = (vImage_Flags)1u << bit;
        vImage_Error theirs = shear->host(&src, &dest, 0, 0, 0.0, 0.0, filter, back, flags);
        vImage_Error ours = shear->port(&src, &dest, 0, 0, 0.0, 0.0, filter, back, flags);
        vImage_Error want = (shear->acceptedFlags & (1u << bit)) ? kvImageNoError : kvImageUnknownFlagsBit;
        checks++;
        if (theirs != want || ours != want) {
            failures++;
            snprintf(what, sizeof what, "%s: the flag 0x%x", shear->name, (unsigned)flags);
            snprintf(note, sizeof note, "the host answers %ld, the port %ld, and the measurement is %ld",
                     (long)theirs, (long)ours, (long)want);
            if (!quiet) printf("FAIL %s: %s\n", what, note);
        }
    }
    vImageDestroyResamplingFilter(filter);
    free(src.data);
    free(dest.data);
}

static void surveyFlags(void)
{
    uint8_t back[8];
    memset(back, 0, sizeof back);
    printf("SURVEY the bits of the flag word each function accepts\n");
    for (int s = 0; s < shearCount; s++) {
        const Shear *shear = &shears[s];
        vImage_Buffer src = makeBuffer(9, 5, bytesPerPixel(shear), 0), dest = makeBuffer(9, 5, bytesPerPixel(shear), 0);
        fillSource(&src, shear);
        unsigned mask = 0;
        for (unsigned bit = 0; bit < 32; bit++) {
            vImage_Flags flags = (vImage_Flags)1u << bit;
            ResamplingFilter filter = vImageNewResamplingFilter(1.0f, flags);
            vImage_Error answer = shear->host(&src, &dest, 0, 0, 0.0, 0.0, filter, back, flags);
            vImageDestroyResamplingFilter(filter);
            if (answer == kvImageNoError) mask |= 1u << bit;
        }
        printf("SURVEY %-40s 0x%08x\n", shear->name, mask);
        free(src.data);
        free(dest.data);
    }
}

static int sweepSubset(const int *ids, unsigned nIds, const float *scalesIn, unsigned nScales)
{
    int before = failures, loopsBefore = loopMisses;
    float own[] = { 1.0f, 2.0f, 0.5f, 0.25f, 0.75f };
    const float *scales = scalesIn ? scalesIn : own;
    unsigned nScalesUsed = scalesIn ? nScales : (unsigned)(sizeof own / sizeof *own);
    double translates[] = { 0.0, 1.0, -1.0, 0.5, -0.5, 2.5, 0.0078125 };
    double slopes[] = { 0.0, 1.0, -0.5, 2.0 };
    vImage_Flags modes[] = { kvImageBackgroundColorFill, kvImageEdgeExtend };
    struct { vImagePixelCount sw, sh, dw, dh; const char *label; } shapes[] = {
        { 9, 5, 9, 5, "" }, { 9, 5, 14, 5, " wide" }, { 9, 5, 4, 5, " narrow" },
        { 9, 5, 9, 2, " short" }, { 9, 5, 9, 8, " tall" }, { 5, 12, 12, 5, " transposed" },
    };
    for (unsigned pick = 0; pick < (ids ? nIds : (unsigned)shearCount); pick++) {
        int s = ids ? ids[pick] : (int)pick;
        const Shear *shear = &shears[s];
        for (int m = 0; m < 2; m++)
            for (unsigned sc = 0; sc < nScalesUsed; sc++)
                for (unsigned tr = 0; tr < sizeof translates / sizeof *translates; tr++)
                    for (unsigned sl = 0; sl < 4; sl++)
                        one(shear, 9, 5, 9, 5, 0, 0, translates[tr], slopes[sl], scales[sc],
                            modes[m] | (scales[sc] == 0.25f ? kvImageHighQualityResampling : kvImageNoFlags),
                            3, "sweep");
        if (!ids) {
            for (unsigned sh = 0; sh < 6; sh++)
                one(shear, shapes[sh].sw, shapes[sh].sh, shapes[sh].dw, shapes[sh].dh, 0, 0, 0.5, 1.0, 1.0f,
                    kvImageBackgroundColorFill, 3, shapes[sh].label);
            one(shear, 9, 5, 9, 5, 2, 0, 0.0, 0.0, 1.0f, kvImageBackgroundColorFill, 3, " along offset 2");
            one(shear, 9, 5, 9, 5, 12, 0, 0.0, 0.0, 1.0f, kvImageBackgroundColorFill, 3, " along offset 12");
            refusals(shear);
        }
    }
    (void)loopsBefore;
    return failures - before;
}

static int sweep(void)
{
    return sweepSubset(NULL, 0, NULL, 0);
}

static void searchForms(void)
{
    int ids[16], n = 0;
    for (int s = 0; s < shearCount; s++)
        if (!shears[s].horizontal && !shears[s].isHalf && !shears[s].packed)
            ids[n++] = s;
    float scale[] = { 0.75f };
    quiet = 1;
    printf("FORMS the vertical integer shears at 0.75, %d of them, scored on the HOST against this file's own "
           "loops\n", n);
    for (int f = 0; f < FormCount; f++) {
        form = f;
        checks = 0;
        failures = 0;
        loopMisses = 0;
        sweepSubset(ids, (unsigned)n, scale, 1);
        printf("FORMS %5d host-vs-loops misses   %s\n", loopMisses, formLabel[f]);
        fflush(stdout);
    }
    form = FormBracketed;
}

static void search(void)
{
    Mapping best;
    int bestScore = 1 << 30;
    quiet = 1;
    double shifts[] = { -0.5, -0.375, -0.25, -0.125, 0.0, 0.125, 0.25, 0.375, 0.5 };
    double slopes[] = { -0.5, 0.0, 0.5, 1.0 };
    for (int halfPixel = 0; halfPixel < 2; halfPixel++)
        for (int farAnchor = 0; farAnchor < 2; farAnchor++)
            for (int sign = -1; sign <= 1; sign += 2)
                for (unsigned a = 0; a < sizeof shifts / sizeof *shifts; a++)
                    for (unsigned b = 0; b < sizeof slopes / sizeof *slopes; b++) {
                        mapping.alongShift = shifts[a];
                        mapping.translateSign = sign;
                        mapping.slopeShift = slopes[b];
                        mapping.halfPixel = halfPixel;
                        mapping.farAnchor = farAnchor;
                        checks = 0;
                        failures = 0;
                        int score = sweep();
                        if (score < bestScore) {
                            bestScore = score;
                            best = mapping;
                            if (score == 0) printf("SEARCH a mapping with NO expectation failures\n");
                            printf("SEARCH along %+.3f translate %+d slopeShift %+.3f halfPixel %d farAnchor %d"
                                   " -> %d expectation failures\n", best.alongShift, best.translateSign,
                                   best.slopeShift, best.halfPixel, best.farAnchor, bestScore);
                            fflush(stdout);
                        }
                    }
    printf("SEARCH best: along %+.3f translate %+d slopeShift %+.3f halfPixel %d farAnchor %d -> %d failures\n",
           best.alongShift, best.translateSign, best.slopeShift, best.halfPixel, best.farAnchor, bestScore);
}

int main(void)
{
    setbuf(stdout, NULL);
    @autoreleasepool {
        if (getenv("SURVEY")) { surveyFlags(); return 0; }
        if (getenv("FORMS")) { searchForms(); return 0; }
        if (getenv("SEARCH")) { search(); return 0; }
        sweep();
        printf("\n%d checks, %d failures\n", checks, failures);
    }
    return failures ? 1 : 0;
}
