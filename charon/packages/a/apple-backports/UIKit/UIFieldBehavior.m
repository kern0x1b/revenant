#import <UIKit/UIKit.h>
#include <float.h>
#include <math.h>
#include <stddef.h>

// A physics field (9.0), written once over the public 7.0 animator API (facts/UIKit/UIFieldBehavior.md §10.7): the
// same code runs over Apple's 7.0 classes on iOS 7.0-8.x, where this file is kept and the 7.0 files are not, and over
// the port's own below 7.0. So it sends no message the 7.0 classes do not answer: no charon_ method, no Box2D.
//
// 9.0's field lives in PhysicsKit and is evaluated inside b2Island::Solve, once per 1/120 s sub-step, before the
// velocity solver (§0). The public 7.0 API has no such hook. Here a field is a composite behavior owning a child
// UIDynamicItemBehavior, the carrier, which holds the field's items (so each gets a body, as 9.0's field items do,
// §10.4) and sets none of its properties (so it pushes nothing to the bodies); the carrier's action, run once per
// animator step after the world step, gives each item in the region the velocity the field's force would have given
// it over that step, through -addLinearVelocity:forItem:. The force itself is 9.0's, float for float (§10.2, M7, and
// the host listings of each PKCField*::evalForce named below); the trajectory is approximate: the velocity arrives
// one step late and is evaluated once per step instead of once per sub-step (§10.7, measured: 0.09 to 2.1 pt over 60
// frames against Apple's field; radial gravity only away from its centre). Where 9.0 answers from the body and the
// 7.0 API has no getter, the emulation reads what the animator's behaviours give the item (charon_field_material).
//
// A parameter change does not wake a paused animator here, as 9.0's -_changedParameter does: the 7.0 API has no call
// that only wakes one. While the field acts, its items never rest, so the animator does not pause under it.

// Built without fused multiply-add contraction: the host's field code has none outside srdnoise3_sincos, and there
// every fused operation of the host listing is written below as fmaf(), so arm64 and armv7 (Cortex-A9, no fused
// multiply-add) compute the same floats as the host (M7: without the fused sites 15293 of 60000 noise forces exact).
#pragma STDC FP_CONTRACT OFF

// PKGet_PTM_RATIO and PKGet_INV_PTM_RATIO under UIKit Dynamics: 100 points per metre, as float (§10.1).
static const float CharonFieldPTM = 100.0f;
static const float CharonFieldInversePTM = 0.01f;

// Every kind's first test: a force whose scale is below 2^-15 is zero (host listings: movi.2s #0x38, lsl #24).
static const float CharonFieldEpsilon = 0x1p-15f;

// A new PKCField's minimum radius, in metres: 2^-15 (§10.1, measured: the getter reads 0.00305175781).
static const float CharonFieldDefaultMinimumRadius = 0x1p-15f;

// UIKit's _availableFieldCategories holds 32 indexes (§10.4, M5).
static const NSUInteger CharonFieldCategories = 32;

typedef NS_ENUM(NSInteger, CharonFieldKind) {
    CharonFieldDrag,
    CharonFieldVortex,
    CharonFieldRadialGravity,
    CharonFieldLinearGravity,
    CharonFieldVelocity,
    CharonFieldNoise,
    CharonFieldTurbulence,
    CharonFieldSpring,
    CharonFieldElectric,
    CharonFieldMagnetic,
    CharonFieldCustom,
};

// A PKCField's parameters, in its own units: position and minimum radius in metres, the rest as UIKit hands them over,
// each rounded to float (host listings of the UIFieldBehavior setters: fcvt to single before the PKPhysicsField call).
typedef struct {
    CharonFieldKind kind;
    float positionX, positionY;
    float strength, falloff, minimumRadius;
    float directionX, directionY;
    float smoothness, animationSpeed;
} CharonField;

typedef struct {
    float x, y;
} CharonFieldForce;

#pragma mark srdnoise3

// Stefan Gustavson's public-domain simplex noise with rotating gradients (srdnoise3), as PhysicsKit's
// srdnoise3_sincos has it (M7: bit-exact over 200000 samples). The tables are the ones read from the host's memory
// (the band's oracle run, m_srd_tables.txt): Gustavson's published gradients and Ken Perlin's permutation, twice. They
// are laid out as the host lays them out, the u gradients, then the v gradients, then the permutation, because the
// host's index (i + 512) % 256 keeps C's sign and so reads up to 255 bytes before the permutation for a coordinate
// below -512 (M7).
#define CharonNoiseA 0x1.a20bd6p-1f // 0.816496551f, 0x3f5105eb in the host's table

static const struct {
    float u[16][3];
    float v[16][3];
    unsigned char permutation[512];
} charon_noise_tables = {
    {
        {1.0f, 0.0f, 1.0f},
        {0.0f, 1.0f, 1.0f},
        {-1.0f, 0.0f, 1.0f},
        {0.0f, -1.0f, 1.0f},
        {1.0f, 0.0f, -1.0f},
        {0.0f, 1.0f, -1.0f},
        {-1.0f, 0.0f, -1.0f},
        {0.0f, -1.0f, -1.0f},
        {CharonNoiseA, CharonNoiseA, CharonNoiseA},
        {-CharonNoiseA, CharonNoiseA, -CharonNoiseA},
        {-CharonNoiseA, -CharonNoiseA, CharonNoiseA},
        {CharonNoiseA, -CharonNoiseA, -CharonNoiseA},
        {-CharonNoiseA, CharonNoiseA, CharonNoiseA},
        {CharonNoiseA, -CharonNoiseA, CharonNoiseA},
        {CharonNoiseA, -CharonNoiseA, -CharonNoiseA},
        {-CharonNoiseA, CharonNoiseA, -CharonNoiseA}
    },
    {
        {-CharonNoiseA, CharonNoiseA, CharonNoiseA},
        {-CharonNoiseA, -CharonNoiseA, CharonNoiseA},
        {CharonNoiseA, -CharonNoiseA, CharonNoiseA},
        {CharonNoiseA, CharonNoiseA, CharonNoiseA},
        {-CharonNoiseA, -CharonNoiseA, -CharonNoiseA},
        {CharonNoiseA, -CharonNoiseA, -CharonNoiseA},
        {CharonNoiseA, CharonNoiseA, -CharonNoiseA},
        {-CharonNoiseA, CharonNoiseA, -CharonNoiseA},
        {1.0f, -1.0f, 0.0f},
        {1.0f, 1.0f, 0.0f},
        {-1.0f, 1.0f, 0.0f},
        {-1.0f, -1.0f, 0.0f},
        {1.0f, 0.0f, 1.0f},
        {-1.0f, 0.0f, 1.0f},
        {0.0f, 1.0f, -1.0f},
        {0.0f, -1.0f, -1.0f}
    },
    {
        151, 160, 137, 91, 90, 15, 131, 13, 201, 95, 96, 53, 194, 233, 7, 225,
        140, 36, 103, 30, 69, 142, 8, 99, 37, 240, 21, 10, 23, 190, 6, 148,
        247, 120, 234, 75, 0, 26, 197, 62, 94, 252, 219, 203, 117, 35, 11, 32,
        57, 177, 33, 88, 237, 149, 56, 87, 174, 20, 125, 136, 171, 168, 68, 175,
        74, 165, 71, 134, 139, 48, 27, 166, 77, 146, 158, 231, 83, 111, 229, 122,
        60, 211, 133, 230, 220, 105, 92, 41, 55, 46, 245, 40, 244, 102, 143, 54,
        65, 25, 63, 161, 1, 216, 80, 73, 209, 76, 132, 187, 208, 89, 18, 169,
        200, 196, 135, 130, 116, 188, 159, 86, 164, 100, 109, 198, 173, 186, 3, 64,
        52, 217, 226, 250, 124, 123, 5, 202, 38, 147, 118, 126, 255, 82, 85, 212,
        207, 206, 59, 227, 47, 16, 58, 17, 182, 189, 28, 42, 223, 183, 170, 213,
        119, 248, 152, 2, 44, 154, 163, 70, 221, 153, 101, 155, 167, 43, 172, 9,
        129, 22, 39, 253, 19, 98, 108, 110, 79, 113, 224, 232, 178, 185, 112, 104,
        218, 246, 97, 228, 251, 34, 242, 193, 238, 210, 144, 12, 191, 179, 162, 241,
        81, 51, 145, 235, 249, 14, 239, 107, 49, 192, 214, 31, 181, 199, 106, 157,
        184, 84, 204, 176, 115, 121, 50, 45, 127, 4, 150, 254, 138, 236, 205, 93,
        222, 114, 67, 29, 24, 72, 243, 141, 128, 195, 78, 66, 215, 61, 156, 180,
        151, 160, 137, 91, 90, 15, 131, 13, 201, 95, 96, 53, 194, 233, 7, 225,
        140, 36, 103, 30, 69, 142, 8, 99, 37, 240, 21, 10, 23, 190, 6, 148,
        247, 120, 234, 75, 0, 26, 197, 62, 94, 252, 219, 203, 117, 35, 11, 32,
        57, 177, 33, 88, 237, 149, 56, 87, 174, 20, 125, 136, 171, 168, 68, 175,
        74, 165, 71, 134, 139, 48, 27, 166, 77, 146, 158, 231, 83, 111, 229, 122,
        60, 211, 133, 230, 220, 105, 92, 41, 55, 46, 245, 40, 244, 102, 143, 54,
        65, 25, 63, 161, 1, 216, 80, 73, 209, 76, 132, 187, 208, 89, 18, 169,
        200, 196, 135, 130, 116, 188, 159, 86, 164, 100, 109, 198, 173, 186, 3, 64,
        52, 217, 226, 250, 124, 123, 5, 202, 38, 147, 118, 126, 255, 82, 85, 212,
        207, 206, 59, 227, 47, 16, 58, 17, 182, 189, 28, 42, 223, 183, 170, 213,
        119, 248, 152, 2, 44, 154, 163, 70, 221, 153, 101, 155, 167, 43, 172, 9,
        129, 22, 39, 253, 19, 98, 108, 110, 79, 113, 224, 232, 178, 185, 112, 104,
        218, 246, 97, 228, 251, 34, 242, 193, 238, 210, 144, 12, 191, 179, 162, 241,
        81, 51, 145, 235, 249, 14, 239, 107, 49, 192, 214, 31, 181, 199, 106, 157,
        184, 84, 204, 176, 115, 121, 50, 45, 127, 4, 150, 254, 138, 236, 205, 93,
        222, 114, 67, 29, 24, 72, 243, 141, 128, 195, 78, 66, 215, 61, 156, 180
    },
};

// The permutation, indexed as the host does, with a signed index that may reach back into the gradients.
static unsigned char charon_noise_permutation(int index)
{
    const unsigned char *base = (const unsigned char *)&charon_noise_tables + offsetof(__typeof__(charon_noise_tables), permutation);
    return base[index];
}

static int charon_noise_floor(float value)
{
    // Gustavson's FASTFLOOR: an integral value that is not positive is one too low, as on the host (cset le).
    return value > 0 ? (int)value : (int)value - 1;
}

static int charon_noise_wrap(int value)
{
    return (value + 512) % 256;
}

// 0.6 - x*x - y*y - z*z, three fused multiply-subtracts on the host.
static float charon_noise_falloff(float x, float y, float z)
{
    return fmaf(-z, z, fmaf(-y, y, fmaf(-x, x, 0.6f)));
}

// gradrot3: the gradient of the hash turned by the angle whose sine and cosine are given; each component fused.
static void charon_noise_gradient(int hash, float sine, float cosine, float *gx, float *gy, float *gz)
{
    int h = hash & 15;
    *gx = fmaf(cosine, charon_noise_tables.u[h][0], sine * charon_noise_tables.v[h][0]);
    *gy = fmaf(cosine, charon_noise_tables.u[h][1], sine * charon_noise_tables.v[h][1]);
    *gz = fmaf(cosine, charon_noise_tables.u[h][2], sine * charon_noise_tables.v[h][2]);
}

// graddotp3, fused as the host fuses it: the y product first, then x and z added onto it.
static float charon_noise_dot(float gx, float gy, float gz, float x, float y, float z)
{
    return fmaf(gz, z, fmaf(gx, x, gy * y));
}

// One corner: its attenuation t, t^2, t^4, gradient and contribution, all zero outside the corner's radius.
typedef struct {
    float t, t2, t4, gx, gy, gz, n;
} CharonNoiseCorner;

static CharonNoiseCorner charon_noise_corner(float x, float y, float z, int hash, float sine, float cosine)
{
    CharonNoiseCorner corner = {0, 0, 0, 0, 0, 0, 0};
    float t = charon_noise_falloff(x, y, z);
    if (t < 0.0f)
        return corner;
    charon_noise_gradient(hash, sine, cosine, &corner.gx, &corner.gy, &corner.gz);
    corner.t = t;
    corner.t2 = t * t;
    corner.t4 = corner.t2 * corner.t2;
    corner.n = corner.t4 * charon_noise_dot(corner.gx, corner.gy, corner.gz, x, y, z);
    return corner;
}

// srdnoise3_sincos(x, y, z, sin t, cos t, &dx, &dy, &dz): the noise and its gradient, in the host's operation order
// (host listing of srdnoise3_sincos, 413 instructions, 58 fused).
static float charon_noise(float x, float y, float z, float sine, float cosine, float *dx, float *dy, float *dz)
{
    const float F3 = 0.333333343f, G3 = 0.166666672f;
    float s = (x + y + z) * F3;
    int i = charon_noise_floor(x + s), j = charon_noise_floor(y + s), k = charon_noise_floor(z + s);
    float t = (float)(i + j + k) * G3;
    float x0 = x - ((float)i - t), y0 = y - ((float)j - t), z0 = z - ((float)k - t);

    int i1, j1, k1, i2, j2, k2;
    if (x0 >= y0) {
        if (y0 >= z0) {
            i1 = 1; j1 = 0; k1 = 0; i2 = 1; j2 = 1; k2 = 0;
        } else if (x0 >= z0) {
            i1 = 1; j1 = 0; k1 = 0; i2 = 1; j2 = 0; k2 = 1;
        } else {
            i1 = 0; j1 = 0; k1 = 1; i2 = 1; j2 = 0; k2 = 1;
        }
    } else {
        if (y0 < z0) {
            i1 = 0; j1 = 0; k1 = 1; i2 = 0; j2 = 1; k2 = 1;
        } else if (x0 < z0) {
            i1 = 0; j1 = 1; k1 = 0; i2 = 0; j2 = 1; k2 = 1;
        } else {
            i1 = 0; j1 = 1; k1 = 0; i2 = 1; j2 = 1; k2 = 0;
        }
    }

    float x1 = x0 - (float)i1 + G3, y1 = y0 - (float)j1 + G3, z1 = z0 - (float)k1 + G3;
    float x2 = x0 - (float)i2 + 2.0f * G3, y2 = y0 - (float)j2 + 2.0f * G3, z2 = z0 - (float)k2 + 2.0f * G3;
    float x3 = x0 - 1.0f + 3.0f * G3, y3 = y0 - 1.0f + 3.0f * G3, z3 = z0 - 1.0f + 3.0f * G3;

    int ii = charon_noise_wrap(i), jj = charon_noise_wrap(j), kk = charon_noise_wrap(k);
    CharonNoiseCorner c0 = charon_noise_corner(x0, y0, z0,
        charon_noise_permutation(ii + charon_noise_permutation(jj + charon_noise_permutation(kk))), sine, cosine);
    CharonNoiseCorner c1 = charon_noise_corner(x1, y1, z1,
        charon_noise_permutation(ii + i1 + charon_noise_permutation(jj + j1 + charon_noise_permutation(kk + k1))), sine, cosine);
    CharonNoiseCorner c2 = charon_noise_corner(x2, y2, z2,
        charon_noise_permutation(ii + i2 + charon_noise_permutation(jj + j2 + charon_noise_permutation(kk + k2))), sine, cosine);
    CharonNoiseCorner c3 = charon_noise_corner(x3, y3, z3,
        charon_noise_permutation(ii + 1 + charon_noise_permutation(jj + 1 + charon_noise_permutation(kk + 1))), sine, cosine);

    float temp0 = (c0.t2 * c0.t) * charon_noise_dot(c0.gx, c0.gy, c0.gz, x0, y0, z0);
    float gx = temp0 * x0, gy = temp0 * y0, gz = temp0 * z0;
    float temp1 = charon_noise_dot(c1.gx, c1.gy, c1.gz, x1, y1, z1) * (c1.t * c1.t2);
    gx = fmaf(temp1, x1, gx);
    gy = fmaf(temp1, y1, gy);
    gz = fmaf(temp1, z1, gz);
    float temp2 = charon_noise_dot(c2.gx, c2.gy, c2.gz, x2, y2, z2) * (c2.t * c2.t2);
    gx = fmaf(temp2, x2, gx);
    gy = fmaf(temp2, y2, gy);
    gz = fmaf(temp2, z2, gz);
    float temp3 = charon_noise_dot(c3.gx, c3.gy, c3.gz, x3, y3, z3) * (c3.t * c3.t2);
    gx = fmaf(temp3, x3, gx);
    gy = fmaf(temp3, y3, gy);
    gz = fmaf(temp3, z3, gz);
    gx *= -8.0f;
    gy *= -8.0f;
    gz *= -8.0f;
    gx = fmaf(c3.t4, c3.gx, fmaf(c2.t4, c2.gx, fmaf(c0.t4, c0.gx, c1.gx * c1.t4))) + gx;
    gy = fmaf(c3.t4, c3.gy, fmaf(c2.t4, c2.gy, fmaf(c0.t4, c0.gy, c1.gy * c1.t4))) + gy;
    gz = fmaf(c3.t4, c3.gz, fmaf(c2.t4, c2.gz, fmaf(c0.t4, c0.gz, c1.gz * c1.t4))) + gz;
    *dx = gx * 28.0f;
    *dy = gy * 28.0f;
    *dz = gz * 28.0f;
    return (((c0.n + c1.n) + c2.n) + c3.n) * 28.0f;
}

#pragma mark Forces

// PKCField::calculatedFalloff: |k| < 2^-15 is no falloff; else the distance from the field's position, clamped up to
// the minimum radius, to the power -k (host listing: z^2 + (x^2 + y^2), fsqrt, fcsel mi, powf).
static float charon_field_falloff(const CharonField *field, float r)
{
    if (fabsf(field->falloff) < CharonFieldEpsilon)
        return 1.0f;
    return powf(r < field->minimumRadius ? field->minimumRadius : r, -field->falloff);
}

static float charon_field_distance(float dx, float dy)
{
    return sqrtf(0.0f * 0.0f + (dx * dx + dy * dy));
}

// PKCFieldNoise::evalForce (M7): the gradient of the noise at the time-shifted position, times the falloff of the
// unshifted one, the noise value and the strength.
static CharonFieldForce charon_field_noise(const CharonField *field, float px, float py, double time)
{
    CharonFieldForce zero = {0, 0};
    if (fabsf(field->strength) < CharonFieldEpsilon)
        return zero;
    float shift = (float)(time * (double)field->animationSpeed);
    float lx = (px + shift) + -field->positionX, ly = (py + shift) + -field->positionY, lz = 0.0f + shift;
    float frequency = 1.25f / (fmaxf(field->smoothness, 0.0f) + 0.0833333358f) + -1.0f;
    float gx, gy, gz;
    float n = charon_noise(frequency * lx, frequency * ly, frequency * lz, sinf(shift), cosf(shift), &gx, &gy, &gz);
    float fall = charon_field_falloff(field, charon_field_distance(px - field->positionX, py - field->positionY));
    CharonFieldForce force = {((gx * fall) * n) * field->strength, ((gy * fall) * n) * field->strength};
    return force;
}

// The force 9.0's field of this kind exerts on a body at (px, py) m, moving at (vx, vy) m/s, of mass m kg and charge
// q, at world time t s: newtons, which the island divides by the mass. Each kind as its host listing computes it
// (PKCField<Kind>::evalForce; the field's scale factor at +0xc0 is 1 in UIKit and left out, §10.2).
static CharonFieldForce charon_field_force(const CharonField *field, float px, float py, float vx, float vy, float m, float q, double time)
{
    CharonFieldForce zero = {0, 0};
    float S = field->strength;
    float dx = px - field->positionX, dy = py - field->positionY;
    switch (field->kind) {
    case CharonFieldLinearGravity: {
        if (fabsf(m * S) < CharonFieldEpsilon)
            return zero;
        float fall = charon_field_falloff(field, charon_field_distance(dx, dy));
        CharonFieldForce force = {((field->directionX * S) * m) * fall, ((field->directionY * S) * m) * fall};
        return force;
    }
    case CharonFieldRadialGravity: {
        if (fabsf(m * S) < CharonFieldEpsilon)
            return zero;
        float r2 = 0.0f * 0.0f + (dx * dx + dy * dy);
        if (r2 < 1e-5f)
            return zero;
        float r = sqrtf(r2);
        float scale = (-(m * S)) * charon_field_falloff(field, r);
        CharonFieldForce force = {(dx / r) * scale, (dy / r) * scale};
        return force;
    }
    case CharonFieldElectric: {
        // No guard at r = 0: the host divides by it too.
        float charged = q * S;
        if (fabsf(charged) < CharonFieldEpsilon)
            return zero;
        float r = charon_field_distance(dx, dy);
        float scale = charged * charon_field_falloff(field, r);
        CharonFieldForce force = {(dx / r) * scale, (dy / r) * scale};
        return force;
    }
    case CharonFieldMagnetic: {
        // v x (0, 0, 1): the charge takes part in the zero test only.
        if (fabsf(q * S) < CharonFieldEpsilon)
            return zero;
        float scale = S * charon_field_falloff(field, charon_field_distance(dx, dy));
        CharonFieldForce force = {vy * scale, -vx * scale};
        return force;
    }
    case CharonFieldSpring: {
        if (fabsf(S) < CharonFieldEpsilon)
            return zero;
        float r = charon_field_distance(dx, dy);
        if (r < 1e-5f)
            return zero;
        float scale = (-S) * charon_field_falloff(field, r);
        CharonFieldForce force = {(dx / r) * scale, (dy / r) * scale};
        return force;
    }
    case CharonFieldVortex: {
        // Divided by the mass once more, as the host does, so the acceleration goes with 1/m^2.
        if (fabsf(m * S) < CharonFieldEpsilon)
            return zero;
        float r = charon_field_distance(dx, dy);
        float ux = dx / r, uy = dy / r;
        float scale = (-S) * charon_field_falloff(field, r);
        CharonFieldForce force = {(uy * scale) / m, (-ux * scale) / m};
        return force;
    }
    case CharonFieldDrag: {
        // The direction is the medium's velocity; a relative speed at most 2^-15 is no drag.
        if (fabsf(S) < CharonFieldEpsilon)
            return zero;
        float ux = vx - field->directionX, uy = vy - field->directionY;
        float speed = charon_field_distance(ux, uy);
        if (speed <= CharonFieldEpsilon)
            return zero;
        float fall = charon_field_falloff(field, charon_field_distance(dx, dy));
        CharonFieldForce force = {((ux * speed) * -S) * fall, ((uy * speed) * -S) * fall};
        return force;
    }
    case CharonFieldNoise:
        return charon_field_noise(field, px, py, time);
    case CharonFieldTurbulence: {
        if (fabsf(S) < CharonFieldEpsilon)
            return zero;
        CharonFieldForce force = charon_field_noise(field, px, py, time);
        float speed = sqrtf(0.0f * 0.0f + (vx * vx + vy * vy));
        force.x = ((force.x * m) * speed) * speed;
        force.y = ((force.y * m) * speed) * speed;
        return force;
    }
    case CharonFieldVelocity:
    case CharonFieldCustom:
        // A velocity field sets the velocity instead (§10.3); a custom field asks its block (-charon_accelerationAt:).
        return zero;
    }
    return zero;
}

#pragma mark Items

// What 9.0 reads from an item's body and the 7.0 API does not answer: its density, charge and whether it is anchored.
// The animator gives a body the value of the last item behaviour in its hierarchy order that set it; the public API
// cannot tell a value set to the default from one never set, so the last behaviour holding the item whose value
// differs from the default stands for it (§10.7: exact when one behaviour sets it). charge and anchored exist only on
// a class that answers them (the port's; Apple's 7.0-8.x class has neither, so charge is 0 there and electric and
// magnetic fields do nothing, as Apple's would with charge 0).
typedef struct {
    CGFloat density;
    CGFloat charge;
    BOOL anchored;
} CharonFieldMaterial;

static void charon_field_visit(UIDynamicBehavior *behavior, id<UIDynamicItem> item, CharonFieldMaterial *material)
{
    if ([behavior isKindOfClass:[UIDynamicItemBehavior class]] && [[(UIDynamicItemBehavior *)behavior items] containsObject:item]) {
        UIDynamicItemBehavior *properties = (UIDynamicItemBehavior *)behavior;
        if (properties.density != 1)
            material->density = properties.density;
        if ([properties respondsToSelector:@selector(charge)] && properties.charge != 0)
            material->charge = properties.charge;
        if ([properties respondsToSelector:@selector(isAnchored)] && properties.isAnchored)
            material->anchored = YES;
    }
    for (UIDynamicBehavior *child in behavior.childBehaviors)
        charon_field_visit(child, item, material);
}

static CharonFieldMaterial charon_field_material(UIDynamicAnimator *animator, id<UIDynamicItem> item)
{
    CharonFieldMaterial material = {1, 0, NO};
    for (UIDynamicBehavior *behavior in animator.behaviors)
        charon_field_visit(behavior, item, &material);
    return material;
}

@interface UIFieldBehavior ()
- (UIDynamicAnimator *)charon_registeredAnimator;
@end

// The fields an animator has taken a category for: those of its hierarchy that were let in by -willMoveToAnimator:.
static NSUInteger charon_field_count(UIDynamicBehavior *behavior, UIDynamicAnimator *animator, UIFieldBehavior *except)
{
    NSUInteger count = 0;
    if (behavior != except && [behavior isKindOfClass:[UIFieldBehavior class]] && [(UIFieldBehavior *)behavior charon_registeredAnimator] == animator)
        count += 1;
    for (UIDynamicBehavior *child in behavior.childBehaviors)
        count += charon_field_count(child, animator, except);
    return count;
}

@implementation UIFieldBehavior {
    CharonField _field;
    UIRegion *_region;
    CGVector (^_evaluator)(UIFieldBehavior *field, CGPoint position, CGVector velocity, CGFloat mass, CGFloat charge, NSTimeInterval deltaTime);
    UIDynamicItemBehavior *_carrier;
    __weak UIDynamicAnimator *_registeredAnimator;
    NSTimeInterval _lastElapsedTime;
}

// The host's -init raises: a field is made only by a factory (measured).
- (instancetype)init
{
    [[NSException exceptionWithName:@"Invalid initialization" reason:@"Use one of the supplied convenience initializers" userInfo:nil] raise];
    return nil;
}

- (instancetype)charon_initWithKind:(CharonFieldKind)kind falloff:(float)falloff __attribute__((objc_method_family(init)))
{
    if (!(self = [super init]))
        return nil;
    _field.kind = kind;
    _field.strength = 1;
    _field.falloff = falloff;
    _field.minimumRadius = CharonFieldDefaultMinimumRadius;
    _region = [UIRegion infiniteRegion];
    _carrier = [[UIDynamicItemBehavior alloc] initWithItems:@[]];
    __weak UIFieldBehavior *field = self;
    _carrier.action = ^{
        [field charon_applyToItems];
    };
    return self;
}

// Falloff defaults per kind (§10.1): radial gravity 2, spring -1, electric and magnetic 1, the others 0.
+ (instancetype)dragField
{
    return [[self alloc] charon_initWithKind:CharonFieldDrag falloff:0];
}

+ (instancetype)vortexField
{
    return [[self alloc] charon_initWithKind:CharonFieldVortex falloff:0];
}

+ (instancetype)radialGravityFieldWithPosition:(CGPoint)position
{
    UIFieldBehavior *field = [[self alloc] charon_initWithKind:CharonFieldRadialGravity falloff:2];
    field.position = position;
    return field;
}

+ (instancetype)linearGravityFieldWithVector:(CGVector)direction
{
    UIFieldBehavior *field = [[self alloc] charon_initWithKind:CharonFieldLinearGravity falloff:0];
    field.direction = direction;
    return field;
}

+ (instancetype)velocityFieldWithVector:(CGVector)direction
{
    UIFieldBehavior *field = [[self alloc] charon_initWithKind:CharonFieldVelocity falloff:0];
    field.direction = direction;
    return field;
}

+ (instancetype)noiseFieldWithSmoothness:(CGFloat)smoothness animationSpeed:(CGFloat)speed
{
    UIFieldBehavior *field = [[self alloc] charon_initWithKind:CharonFieldNoise falloff:0];
    field.smoothness = smoothness;
    field.animationSpeed = speed;
    return field;
}

+ (instancetype)turbulenceFieldWithSmoothness:(CGFloat)smoothness animationSpeed:(CGFloat)speed
{
    UIFieldBehavior *field = [[self alloc] charon_initWithKind:CharonFieldTurbulence falloff:0];
    field.smoothness = smoothness;
    field.animationSpeed = speed;
    return field;
}

+ (instancetype)springField
{
    return [[self alloc] charon_initWithKind:CharonFieldSpring falloff:-1];
}

+ (instancetype)electricField
{
    return [[self alloc] charon_initWithKind:CharonFieldElectric falloff:1];
}

+ (instancetype)magneticField
{
    return [[self alloc] charon_initWithKind:CharonFieldMagnetic falloff:1];
}

+ (instancetype)fieldWithEvaluationBlock:(CGVector (^)(UIFieldBehavior *field, CGPoint position, CGVector velocity, CGFloat mass, CGFloat charge, NSTimeInterval deltaTime))block
{
    UIFieldBehavior *field = [[self alloc] charon_initWithKind:CharonFieldCustom falloff:0];
    field->_evaluator = [block copy];
    return field;
}

// The host's: the class and the address, nothing of the composite underneath (measured).
- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p>", NSStringFromClass([self class]), self];
}

#pragma mark Items and children

- (void)addItem:(id<UIDynamicItem>)item
{
    [_carrier addItem:item];
}

- (void)removeItem:(id<UIDynamicItem>)item
{
    [_carrier removeItem:item];
}

- (NSArray *)items
{
    return [_carrier items];
}

// 9.0's field is a primitive behavior: it has no children and takes none (measured: -addChildBehavior: leaves
// childBehaviors empty). The carrier is a child only for the animator.
- (NSArray *)childBehaviors
{
    return @[];
}

- (void)addChildBehavior:(UIDynamicBehavior *)behavior
{
}

- (void)removeChildBehavior:(UIDynamicBehavior *)behavior
{
}

- (UIDynamicAnimator *)charon_registeredAnimator
{
    return _registeredAnimator;
}

// An animator holds at most 32 fields, one category each (§10.4). 9.0 counts in -_registerBehavior:, before the field
// has a context; over the 7.0 API the count can only be made here, after the animator set the context, so after the
// exception the field answers the animator as its dynamicAnimator and does nothing, where 9.0's answers nil (M5). The
// carrier joins with the field and leaves with it, so a field that was refused holds nothing the animator registered.
- (void)willMoveToAnimator:(UIDynamicAnimator *)animator
{
    [super willMoveToAnimator:animator];
    if (!animator) {
        _registeredAnimator = nil;
        [super removeChildBehavior:_carrier];
        return;
    }
    NSUInteger fields = 0;
    for (UIDynamicBehavior *behavior in animator.behaviors)
        fields += charon_field_count(behavior, animator, self);
    if (fields >= CharonFieldCategories)
        [[NSException exceptionWithName:@"Invalid Association" reason:@"UIDynamicAnimator supports a maximum of 32 distinct fields" userInfo:nil] raise];
    _registeredAnimator = animator;
    _lastElapsedTime = animator.elapsedTime;
    [super addChildBehavior:_carrier];
}

#pragma mark The step

// The acceleration, in pt/s^2, the field gives an item whose center is `center` (reference coordinates), moving at
// `velocity` pt/s, of mass `mass` kg and charge `charge`, at time `time`: 9.0's force over the mass, in points. The
// body's position and velocity are taken in metres as the animator converts them (float, times 0.01f); the host's
// island multiplies the force by the float inverse mass. The region is not asked here.
- (CGVector)charon_accelerationAt:(CGPoint)center velocity:(CGPoint)velocity mass:(CGFloat)mass charge:(CGFloat)charge time:(NSTimeInterval)time
{
    float px = (float)((double)CharonFieldInversePTM * center.x), py = (float)((double)CharonFieldInversePTM * center.y);
    float vx = (float)((double)CharonFieldInversePTM * velocity.x), vy = (float)((double)CharonFieldInversePTM * velocity.y);
    float m = (float)mass, q = (float)charge;
    CharonFieldForce force;
    if (_field.kind == CharonFieldCustom) {
        // PKCFieldUser::evalForce: the block gets the position in field-local points, the velocity in m/s, the mass,
        // the charge and the time, and its answer is the force in newtons, not scaled by the strength; a strength
        // below 2^-15 turns it off (measured with p3.m; host listing).
        force.x = force.y = 0;
        if (_evaluator && fabsf(_field.strength) >= CharonFieldEpsilon) {
            CGPoint local = CGPointMake((double)((px - _field.positionX) * CharonFieldPTM), (double)((py - _field.positionY) * CharonFieldPTM));
            CGVector answer = _evaluator(self, local, CGVectorMake(vx, vy), m, q, time);
            force.x = (float)answer.dx;
            force.y = (float)answer.dy;
        }
    } else {
        force = charon_field_force(&_field, px, py, vx, vy, m, q, time);
    }
    float inverseMass = 1.0f / m;
    return CGVectorMake((double)(inverseMass * force.x) * CharonFieldPTM, (double)(inverseMass * force.y) * CharonFieldPTM);
}

// PKCField::contains: the region is asked in the field's local space, in points; no region contains everything.
- (BOOL)charon_regionContains:(CGPoint)center
{
    if (!_region)
        return YES;
    float px = (float)((double)CharonFieldInversePTM * center.x), py = (float)((double)CharonFieldInversePTM * center.y);
    return [_region containsPoint:CGPointMake((double)((px - _field.positionX) * CharonFieldPTM), (double)((py - _field.positionY) * CharonFieldPTM))];
}

// The carrier's action, once per animator step after the world step (§10.7). dt is the step's time; 9.0 evaluates
// with the clock after each sub-step, the emulation with the animator's elapsed time after the step.
- (void)charon_applyToItems
{
    UIDynamicAnimator *animator = _registeredAnimator;
    if (!animator)
        return;
    NSTimeInterval now = animator.elapsedTime;
    NSTimeInterval dt = now - _lastElapsedTime;
    _lastElapsedTime = now;
    UIView *reference = animator.referenceView;
    for (id<UIDynamicItem> item in [_carrier items]) {
        CGPoint center = item.center;
        if (reference && [(id)item isKindOfClass:[UIView class]])
            center = [reference convertPoint:center fromView:[(UIView *)item superview]];
        if (![self charon_regionContains:center])
            continue;
        CharonFieldMaterial material = charon_field_material(animator, item);
        // An anchored body is static and no field moves it (§10.4).
        if (material.anchored)
            continue;
        CGPoint velocity = [_carrier linearVelocityForItem:item];
        if (_field.kind == CharonFieldVelocity) {
            // The velocity becomes the direction, in m/s (§10.3).
            [_carrier addLinearVelocity:CGPointMake((double)(_field.directionX * CharonFieldPTM) - velocity.x,
                                                    (double)(_field.directionY * CharonFieldPTM) - velocity.y)
                                forItem:item];
            continue;
        }
        CGSize size = item.bounds.size;
        CGFloat mass = material.density * size.width * size.height / ((double)CharonFieldPTM * (double)CharonFieldPTM);
        CGVector acceleration = [self charon_accelerationAt:center velocity:velocity mass:mass charge:material.charge time:now];
        [_carrier addLinearVelocity:CGPointMake(acceleration.dx * dt, acceleration.dy * dt) forItem:item];
    }
}

#pragma mark Properties

// Stored as float metres, answered in double points: (30, 40) reads back (29.9999982, 39.9999976) (§10.1; host listings
// of -setPosition: (fcvtn, fmul by the inverse ratio) and -position (fcvtl, fmul.2d by the ratio)).
- (CGPoint)position
{
    return CGPointMake((double)_field.positionX * (double)CharonFieldPTM, (double)_field.positionY * (double)CharonFieldPTM);
}

- (void)setPosition:(CGPoint)position
{
    _field.positionX = (float)position.x * CharonFieldInversePTM;
    _field.positionY = (float)position.y * CharonFieldInversePTM;
}

- (UIRegion *)region
{
    return _region;
}

- (void)setRegion:(UIRegion *)region
{
    _region = region;
}

- (CGFloat)strength
{
    return _field.strength;
}

- (void)setStrength:(CGFloat)strength
{
    _field.strength = (float)strength;
}

- (CGFloat)falloff
{
    return _field.falloff;
}

- (void)setFalloff:(CGFloat)falloff
{
    _field.falloff = (float)falloff;
}

// Stored as (float)r * 0.01f and answered as stored / 0.01f, both in float (host listings of -[PKPhysicsField
// setMinimumRadius:] and -minimumRadius: fmul and fdiv by PKGet_INV_PTM_RATIO).
- (CGFloat)minimumRadius
{
    return _field.minimumRadius / CharonFieldInversePTM;
}

- (void)setMinimumRadius:(CGFloat)minimumRadius
{
    _field.minimumRadius = (float)minimumRadius * CharonFieldInversePTM;
}

// Not scaled by the ratio: a linear gravity's direction is m/s^2, a velocity's and a drag's m/s (§10.1).
- (CGVector)direction
{
    return CGVectorMake(_field.directionX, _field.directionY);
}

- (void)setDirection:(CGVector)direction
{
    _field.directionX = (float)direction.dx;
    _field.directionY = (float)direction.dy;
}

// Only a noise or turbulence field keeps a smoothness and an animation speed; the others answer 0 and ignore a set
// (§10.1; host listings test _fieldFlags.fieldIsKindOfNoiseField).
- (BOOL)charon_isNoise
{
    return _field.kind == CharonFieldNoise || _field.kind == CharonFieldTurbulence;
}

- (CGFloat)smoothness
{
    return [self charon_isNoise] ? _field.smoothness : 0;
}

- (void)setSmoothness:(CGFloat)smoothness
{
    if ([self charon_isNoise])
        _field.smoothness = (float)smoothness;
}

- (CGFloat)animationSpeed
{
    return [self charon_isNoise] ? _field.animationSpeed : 0;
}

- (void)setAnimationSpeed:(CGFloat)animationSpeed
{
    if ([self charon_isNoise])
        _field.animationSpeed = (float)animationSpeed;
}

@end
