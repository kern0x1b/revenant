#ifndef REVENANT_MPS9_REFERENCE_H
#define REVENANT_MPS9_REFERENCE_H

#include <math.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

static NSUInteger gCompared9 = 0;
static NSUInteger gMismatches9 = 0;

static double RevenantMPS9Ulp(float stored)
{
    return (double)fabsf(stored) * 1.19209290e-07 + 1.0e-30;
}

static void RevenantMPS9Compare(const char *name, double want, float got)
{
    gCompared9++;
    double ulp = RevenantMPS9Ulp(got);
    if (fabs((double)got - want) > ulp) {
        gMismatches9++;
        printf("  MISMATCH %s reference %.9g port %.9g, one ulp %.3g\n", name, want, (double)got, ulp);
    }
}

static double RevenantMPS9Integral(const double *values, NSUInteger w, NSUInteger h, NSInteger x,
                                 NSInteger y, BOOL squared)
{
    if (x < 0 || y < 0)
        return 0.0;
    double total = 0.0;
    for (NSInteger j = 0; j <= y; j++)
        for (NSInteger i = 0; i <= x; i++) {
            double v = values[(NSUInteger)j * w + (NSUInteger)i];
            total += squared ? v * v : v;
        }
    return total;
}

static void RevenantMPS9CheckIntegral(const char *name, const double *values, NSUInteger w, NSUInteger h,
                                    const float *got, BOOL squared)
{
    for (NSUInteger y = 0; y < h; y++)
        for (NSUInteger x = 0; x < w; x++) {
            double want = RevenantMPS9Integral(values, w, h, (NSInteger)x, (NSInteger)y, squared);
            char label[256];
            snprintf(label, sizeof(label), "%s (%lu,%lu)", name, (unsigned long)x, (unsigned long)y);
            RevenantMPS9Compare(label, want, got[y * w + x]);
        }
}

static void RevenantMPS9CheckSobel(const char *name, const double *values, NSUInteger w, NSUInteger h,
                                 const float *got, NSUInteger channels, const float *transform)
{
    static const int kx[9] = { -1, 0, 1, -2, 0, 2, -1, 0, 1 };
    static const int ky[9] = { -1, -2, -1, 0, 0, 0, 1, 2, 1 };
    for (NSUInteger c = 0; c < channels; c++) {
        for (NSUInteger y = 0; y < h; y++)
            for (NSUInteger x = 0; x < w; x++) {
                double gx = 0.0, gy = 0.0;
                for (int j = 0; j < 3; j++)
                    for (int i = 0; i < 3; i++) {
                        NSInteger sx = (NSInteger)x + i - 1, sy = (NSInteger)y + j - 1;
                        if (sx < 0 || sy < 0 || (NSUInteger)sx >= w || (NSUInteger)sy >= h)
                            continue;
                        NSUInteger pixel = (NSUInteger)sy * w + (NSUInteger)sx;
                        double sample;
                        if (channels >= 3) {
                            sample = transform[0] * values[pixel * channels + 0]
                                   + transform[1] * values[pixel * channels + 1]
                                   + transform[2] * values[pixel * channels + 2];
                        } else {
                            sample = values[pixel * channels + c];
                        }
                        gx += kx[j * 3 + i] * sample;
                        gy += ky[j * 3 + i] * sample;
                    }
                char label[256];
                snprintf(label, sizeof(label), "%s channel %lu (%lu,%lu)", name, (unsigned long)c,
                         (unsigned long)x, (unsigned long)y);
                RevenantMPS9Compare(label, sqrt(gx * gx + gy * gy), got[(y * w + x) * channels + c]);
            }
    }
}

#endif
