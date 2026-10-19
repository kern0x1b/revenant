#import <UIKit/UIKit.h>
#include <float.h>
#include <math.h>
#include <stddef.h>

#pragma STDC FP_CONTRACT OFF

static const float RevenantFieldPTM = 100.0f;
static const float RevenantFieldInversePTM = 0.01f;

static const float RevenantFieldEpsilon = 0x1p-15f;

static const float RevenantFieldDefaultMinimumRadius = 0x1p-15f;

static const NSUInteger RevenantFieldCategories = 32;

typedef NS_ENUM(NSInteger, RevenantFieldKind) {
    RevenantFieldDrag,
    RevenantFieldVortex,
    RevenantFieldRadialGravity,
    RevenantFieldLinearGravity,
    RevenantFieldVelocity,
    RevenantFieldNoise,
    RevenantFieldTurbulence,
    RevenantFieldSpring,
    RevenantFieldElectric,
    RevenantFieldMagnetic,
    RevenantFieldCustom,
};

typedef struct {
    RevenantFieldKind kind;
    float positionX, positionY;
    float strength, falloff, minimumRadius;
    float directionX, directionY;
    float smoothness, animationSpeed;
} RevenantField;

typedef struct {
    float x, y;
} RevenantFieldForce;

#pragma mark srdnoise3

#define RevenantNoiseA 0x1.a20bd6p-1f

static const struct {
    float u[16][3];
    float v[16][3];
    unsigned char permutation[512];
} revenant_noise_tables = {
    {
        {1.0f, 0.0f, 1.0f},
        {0.0f, 1.0f, 1.0f},
        {-1.0f, 0.0f, 1.0f},
        {0.0f, -1.0f, 1.0f},
        {1.0f, 0.0f, -1.0f},
        {0.0f, 1.0f, -1.0f},
        {-1.0f, 0.0f, -1.0f},
        {0.0f, -1.0f, -1.0f},
        {RevenantNoiseA, RevenantNoiseA, RevenantNoiseA},
        {-RevenantNoiseA, RevenantNoiseA, -RevenantNoiseA},
        {-RevenantNoiseA, -RevenantNoiseA, RevenantNoiseA},
        {RevenantNoiseA, -RevenantNoiseA, -RevenantNoiseA},
        {-RevenantNoiseA, RevenantNoiseA, RevenantNoiseA},
        {RevenantNoiseA, -RevenantNoiseA, RevenantNoiseA},
        {RevenantNoiseA, -RevenantNoiseA, -RevenantNoiseA},
        {-RevenantNoiseA, RevenantNoiseA, -RevenantNoiseA}
    },
    {
        {-RevenantNoiseA, RevenantNoiseA, RevenantNoiseA},
        {-RevenantNoiseA, -RevenantNoiseA, RevenantNoiseA},
        {RevenantNoiseA, -RevenantNoiseA, RevenantNoiseA},
        {RevenantNoiseA, RevenantNoiseA, RevenantNoiseA},
        {-RevenantNoiseA, -RevenantNoiseA, -RevenantNoiseA},
        {RevenantNoiseA, -RevenantNoiseA, -RevenantNoiseA},
        {RevenantNoiseA, RevenantNoiseA, -RevenantNoiseA},
        {-RevenantNoiseA, RevenantNoiseA, -RevenantNoiseA},
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

static unsigned char revenant_noise_permutation(int index)
{
    const unsigned char *base = (const unsigned char *)&revenant_noise_tables + offsetof(__typeof__(revenant_noise_tables), permutation);
    return base[index];
}

static int revenant_noise_floor(float value)
{
    return value > 0 ? (int)value : (int)value - 1;
}

static int revenant_noise_wrap(int value)
{
    return (value + 512) % 256;
}

static float revenant_noise_falloff(float x, float y, float z)
{
    return fmaf(-z, z, fmaf(-y, y, fmaf(-x, x, 0.6f)));
}

static void revenant_noise_gradient(int hash, float sine, float cosine, float *gx, float *gy, float *gz)
{
    int h = hash & 15;
    *gx = fmaf(cosine, revenant_noise_tables.u[h][0], sine * revenant_noise_tables.v[h][0]);
    *gy = fmaf(cosine, revenant_noise_tables.u[h][1], sine * revenant_noise_tables.v[h][1]);
    *gz = fmaf(cosine, revenant_noise_tables.u[h][2], sine * revenant_noise_tables.v[h][2]);
}

static float revenant_noise_dot(float gx, float gy, float gz, float x, float y, float z)
{
    return fmaf(gz, z, fmaf(gx, x, gy * y));
}

typedef struct {
    float t, t2, t4, gx, gy, gz, n;
} RevenantNoiseCorner;

static RevenantNoiseCorner revenant_noise_corner(float x, float y, float z, int hash, float sine, float cosine)
{
    RevenantNoiseCorner corner = {0, 0, 0, 0, 0, 0, 0};
    float t = revenant_noise_falloff(x, y, z);
    if (t < 0.0f)
        return corner;
    revenant_noise_gradient(hash, sine, cosine, &corner.gx, &corner.gy, &corner.gz);
    corner.t = t;
    corner.t2 = t * t;
    corner.t4 = corner.t2 * corner.t2;
    corner.n = corner.t4 * revenant_noise_dot(corner.gx, corner.gy, corner.gz, x, y, z);
    return corner;
}

static float revenant_noise(float x, float y, float z, float sine, float cosine, float *dx, float *dy, float *dz)
{
    const float F3 = 0.333333343f, G3 = 0.166666672f;
    float s = (x + y + z) * F3;
    int i = revenant_noise_floor(x + s), j = revenant_noise_floor(y + s), k = revenant_noise_floor(z + s);
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

    int ii = revenant_noise_wrap(i), jj = revenant_noise_wrap(j), kk = revenant_noise_wrap(k);
    RevenantNoiseCorner c0 = revenant_noise_corner(x0, y0, z0,
        revenant_noise_permutation(ii + revenant_noise_permutation(jj + revenant_noise_permutation(kk))), sine, cosine);
    RevenantNoiseCorner c1 = revenant_noise_corner(x1, y1, z1,
        revenant_noise_permutation(ii + i1 + revenant_noise_permutation(jj + j1 + revenant_noise_permutation(kk + k1))), sine, cosine);
    RevenantNoiseCorner c2 = revenant_noise_corner(x2, y2, z2,
        revenant_noise_permutation(ii + i2 + revenant_noise_permutation(jj + j2 + revenant_noise_permutation(kk + k2))), sine, cosine);
    RevenantNoiseCorner c3 = revenant_noise_corner(x3, y3, z3,
        revenant_noise_permutation(ii + 1 + revenant_noise_permutation(jj + 1 + revenant_noise_permutation(kk + 1))), sine, cosine);

    float temp0 = (c0.t2 * c0.t) * revenant_noise_dot(c0.gx, c0.gy, c0.gz, x0, y0, z0);
    float gx = temp0 * x0, gy = temp0 * y0, gz = temp0 * z0;
    float temp1 = revenant_noise_dot(c1.gx, c1.gy, c1.gz, x1, y1, z1) * (c1.t * c1.t2);
    gx = fmaf(temp1, x1, gx);
    gy = fmaf(temp1, y1, gy);
    gz = fmaf(temp1, z1, gz);
    float temp2 = revenant_noise_dot(c2.gx, c2.gy, c2.gz, x2, y2, z2) * (c2.t * c2.t2);
    gx = fmaf(temp2, x2, gx);
    gy = fmaf(temp2, y2, gy);
    gz = fmaf(temp2, z2, gz);
    float temp3 = revenant_noise_dot(c3.gx, c3.gy, c3.gz, x3, y3, z3) * (c3.t * c3.t2);
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

static float revenant_field_falloff(const RevenantField *field, float r)
{
    if (fabsf(field->falloff) < RevenantFieldEpsilon)
        return 1.0f;
    return powf(r < field->minimumRadius ? field->minimumRadius : r, -field->falloff);
}

static float revenant_field_distance(float dx, float dy)
{
    return sqrtf(0.0f * 0.0f + (dx * dx + dy * dy));
}

static RevenantFieldForce revenant_field_noise(const RevenantField *field, float px, float py, double time)
{
    RevenantFieldForce zero = {0, 0};
    if (fabsf(field->strength) < RevenantFieldEpsilon)
        return zero;
    float shift = (float)(time * (double)field->animationSpeed);
    float lx = (px + shift) + -field->positionX, ly = (py + shift) + -field->positionY, lz = 0.0f + shift;
    float frequency = 1.25f / (fmaxf(field->smoothness, 0.0f) + 0.0833333358f) + -1.0f;
    float gx, gy, gz;
    float n = revenant_noise(frequency * lx, frequency * ly, frequency * lz, sinf(shift), cosf(shift), &gx, &gy, &gz);
    float fall = revenant_field_falloff(field, revenant_field_distance(px - field->positionX, py - field->positionY));
    RevenantFieldForce force = {((gx * fall) * n) * field->strength, ((gy * fall) * n) * field->strength};
    return force;
}

static RevenantFieldForce revenant_field_force(const RevenantField *field, float px, float py, float vx, float vy, float m, float q, double time)
{
    RevenantFieldForce zero = {0, 0};
    float S = field->strength;
    float dx = px - field->positionX, dy = py - field->positionY;
    switch (field->kind) {
    case RevenantFieldLinearGravity: {
        if (fabsf(m * S) < RevenantFieldEpsilon)
            return zero;
        float fall = revenant_field_falloff(field, revenant_field_distance(dx, dy));
        RevenantFieldForce force = {((field->directionX * S) * m) * fall, ((field->directionY * S) * m) * fall};
        return force;
    }
    case RevenantFieldRadialGravity: {
        if (fabsf(m * S) < RevenantFieldEpsilon)
            return zero;
        float r2 = 0.0f * 0.0f + (dx * dx + dy * dy);
        if (r2 < 1e-5f)
            return zero;
        float r = sqrtf(r2);
        float scale = (-(m * S)) * revenant_field_falloff(field, r);
        RevenantFieldForce force = {(dx / r) * scale, (dy / r) * scale};
        return force;
    }
    case RevenantFieldElectric: {
        float charged = q * S;
        if (fabsf(charged) < RevenantFieldEpsilon)
            return zero;
        float r = revenant_field_distance(dx, dy);
        float scale = charged * revenant_field_falloff(field, r);
        RevenantFieldForce force = {(dx / r) * scale, (dy / r) * scale};
        return force;
    }
    case RevenantFieldMagnetic: {
        if (fabsf(q * S) < RevenantFieldEpsilon)
            return zero;
        float scale = S * revenant_field_falloff(field, revenant_field_distance(dx, dy));
        RevenantFieldForce force = {vy * scale, -vx * scale};
        return force;
    }
    case RevenantFieldSpring: {
        if (fabsf(S) < RevenantFieldEpsilon)
            return zero;
        float r = revenant_field_distance(dx, dy);
        if (r < 1e-5f)
            return zero;
        float scale = (-S) * revenant_field_falloff(field, r);
        RevenantFieldForce force = {(dx / r) * scale, (dy / r) * scale};
        return force;
    }
    case RevenantFieldVortex: {
        if (fabsf(m * S) < RevenantFieldEpsilon)
            return zero;
        float r = revenant_field_distance(dx, dy);
        float ux = dx / r, uy = dy / r;
        float scale = (-S) * revenant_field_falloff(field, r);
        RevenantFieldForce force = {(uy * scale) / m, (-ux * scale) / m};
        return force;
    }
    case RevenantFieldDrag: {
        if (fabsf(S) < RevenantFieldEpsilon)
            return zero;
        float ux = vx - field->directionX, uy = vy - field->directionY;
        float speed = revenant_field_distance(ux, uy);
        if (speed <= RevenantFieldEpsilon)
            return zero;
        float fall = revenant_field_falloff(field, revenant_field_distance(dx, dy));
        RevenantFieldForce force = {((ux * speed) * -S) * fall, ((uy * speed) * -S) * fall};
        return force;
    }
    case RevenantFieldNoise:
        return revenant_field_noise(field, px, py, time);
    case RevenantFieldTurbulence: {
        if (fabsf(S) < RevenantFieldEpsilon)
            return zero;
        RevenantFieldForce force = revenant_field_noise(field, px, py, time);
        float speed = sqrtf(0.0f * 0.0f + (vx * vx + vy * vy));
        force.x = ((force.x * m) * speed) * speed;
        force.y = ((force.y * m) * speed) * speed;
        return force;
    }
    case RevenantFieldVelocity:
    case RevenantFieldCustom:
        return zero;
    }
    return zero;
}

#pragma mark Items

typedef struct {
    CGFloat density;
    CGFloat charge;
    BOOL anchored;
} RevenantFieldMaterial;

static void revenant_field_visit(UIDynamicBehavior *behavior, id<UIDynamicItem> item, RevenantFieldMaterial *material)
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
        revenant_field_visit(child, item, material);
}

static RevenantFieldMaterial revenant_field_material(UIDynamicAnimator *animator, id<UIDynamicItem> item)
{
    RevenantFieldMaterial material = {1, 0, NO};
    for (UIDynamicBehavior *behavior in animator.behaviors)
        revenant_field_visit(behavior, item, &material);
    return material;
}

@interface UIFieldBehavior ()
- (UIDynamicAnimator *)revenant_registeredAnimator;
@end

static NSUInteger revenant_field_count(UIDynamicBehavior *behavior, UIDynamicAnimator *animator, UIFieldBehavior *except)
{
    NSUInteger count = 0;
    if (behavior != except && [behavior isKindOfClass:[UIFieldBehavior class]] && [(UIFieldBehavior *)behavior revenant_registeredAnimator] == animator)
        count += 1;
    for (UIDynamicBehavior *child in behavior.childBehaviors)
        count += revenant_field_count(child, animator, except);
    return count;
}

@implementation UIFieldBehavior {
    RevenantField _field;
    UIRegion *_region;
    CGVector (^_evaluator)(UIFieldBehavior *field, CGPoint position, CGVector velocity, CGFloat mass, CGFloat charge, NSTimeInterval deltaTime);
    UIDynamicItemBehavior *_carrier;
    __weak UIDynamicAnimator *_registeredAnimator;
    NSTimeInterval _lastElapsedTime;
}

- (instancetype)init
{
    [[NSException exceptionWithName:@"Invalid initialization" reason:@"Use one of the supplied convenience initializers" userInfo:nil] raise];
    return nil;
}

- (instancetype)revenant_initWithKind:(RevenantFieldKind)kind falloff:(float)falloff __attribute__((objc_method_family(init)))
{
    if (!(self = [super init]))
        return nil;
    _field.kind = kind;
    _field.strength = 1;
    _field.falloff = falloff;
    _field.minimumRadius = RevenantFieldDefaultMinimumRadius;
    _region = [UIRegion infiniteRegion];
    _carrier = [[UIDynamicItemBehavior alloc] initWithItems:@[]];
    __weak UIFieldBehavior *field = self;
    _carrier.action = ^{
        [field revenant_applyToItems];
    };
    return self;
}

+ (instancetype)dragField
{
    return [[self alloc] revenant_initWithKind:RevenantFieldDrag falloff:0];
}

+ (instancetype)vortexField
{
    return [[self alloc] revenant_initWithKind:RevenantFieldVortex falloff:0];
}

+ (instancetype)radialGravityFieldWithPosition:(CGPoint)position
{
    UIFieldBehavior *field = [[self alloc] revenant_initWithKind:RevenantFieldRadialGravity falloff:2];
    field.position = position;
    return field;
}

+ (instancetype)linearGravityFieldWithVector:(CGVector)direction
{
    UIFieldBehavior *field = [[self alloc] revenant_initWithKind:RevenantFieldLinearGravity falloff:0];
    field.direction = direction;
    return field;
}

+ (instancetype)velocityFieldWithVector:(CGVector)direction
{
    UIFieldBehavior *field = [[self alloc] revenant_initWithKind:RevenantFieldVelocity falloff:0];
    field.direction = direction;
    return field;
}

+ (instancetype)noiseFieldWithSmoothness:(CGFloat)smoothness animationSpeed:(CGFloat)speed
{
    UIFieldBehavior *field = [[self alloc] revenant_initWithKind:RevenantFieldNoise falloff:0];
    field.smoothness = smoothness;
    field.animationSpeed = speed;
    return field;
}

+ (instancetype)turbulenceFieldWithSmoothness:(CGFloat)smoothness animationSpeed:(CGFloat)speed
{
    UIFieldBehavior *field = [[self alloc] revenant_initWithKind:RevenantFieldTurbulence falloff:0];
    field.smoothness = smoothness;
    field.animationSpeed = speed;
    return field;
}

+ (instancetype)springField
{
    return [[self alloc] revenant_initWithKind:RevenantFieldSpring falloff:-1];
}

+ (instancetype)electricField
{
    return [[self alloc] revenant_initWithKind:RevenantFieldElectric falloff:1];
}

+ (instancetype)magneticField
{
    return [[self alloc] revenant_initWithKind:RevenantFieldMagnetic falloff:1];
}

+ (instancetype)fieldWithEvaluationBlock:(CGVector (^)(UIFieldBehavior *field, CGPoint position, CGVector velocity, CGFloat mass, CGFloat charge, NSTimeInterval deltaTime))block
{
    UIFieldBehavior *field = [[self alloc] revenant_initWithKind:RevenantFieldCustom falloff:0];
    field->_evaluator = [block copy];
    return field;
}

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

- (UIDynamicAnimator *)revenant_registeredAnimator
{
    return _registeredAnimator;
}

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
        fields += revenant_field_count(behavior, animator, self);
    if (fields >= RevenantFieldCategories)
        [[NSException exceptionWithName:@"Invalid Association" reason:@"UIDynamicAnimator supports a maximum of 32 distinct fields" userInfo:nil] raise];
    _registeredAnimator = animator;
    _lastElapsedTime = animator.elapsedTime;
    [super addChildBehavior:_carrier];
}

#pragma mark The step

- (CGVector)revenant_accelerationAt:(CGPoint)center velocity:(CGPoint)velocity mass:(CGFloat)mass charge:(CGFloat)charge time:(NSTimeInterval)time
{
    float px = (float)((double)RevenantFieldInversePTM * center.x), py = (float)((double)RevenantFieldInversePTM * center.y);
    float vx = (float)((double)RevenantFieldInversePTM * velocity.x), vy = (float)((double)RevenantFieldInversePTM * velocity.y);
    float m = (float)mass, q = (float)charge;
    RevenantFieldForce force;
    if (_field.kind == RevenantFieldCustom) {
        force.x = force.y = 0;
        if (_evaluator && fabsf(_field.strength) >= RevenantFieldEpsilon) {
            CGPoint local = CGPointMake((double)((px - _field.positionX) * RevenantFieldPTM), (double)((py - _field.positionY) * RevenantFieldPTM));
            CGVector answer = _evaluator(self, local, CGVectorMake(vx, vy), m, q, time);
            force.x = (float)answer.dx;
            force.y = (float)answer.dy;
        }
    } else {
        force = revenant_field_force(&_field, px, py, vx, vy, m, q, time);
    }
    float inverseMass = 1.0f / m;
    return CGVectorMake((double)(inverseMass * force.x) * RevenantFieldPTM, (double)(inverseMass * force.y) * RevenantFieldPTM);
}

- (BOOL)revenant_regionContains:(CGPoint)center
{
    if (!_region)
        return YES;
    float px = (float)((double)RevenantFieldInversePTM * center.x), py = (float)((double)RevenantFieldInversePTM * center.y);
    return [_region containsPoint:CGPointMake((double)((px - _field.positionX) * RevenantFieldPTM), (double)((py - _field.positionY) * RevenantFieldPTM))];
}

- (void)revenant_applyToItems
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
        if (![self revenant_regionContains:center])
            continue;
        RevenantFieldMaterial material = revenant_field_material(animator, item);
        if (material.anchored)
            continue;
        CGPoint velocity = [_carrier linearVelocityForItem:item];
        if (_field.kind == RevenantFieldVelocity) {
            [_carrier addLinearVelocity:CGPointMake((double)(_field.directionX * RevenantFieldPTM) - velocity.x,
                                                    (double)(_field.directionY * RevenantFieldPTM) - velocity.y)
                                forItem:item];
            continue;
        }
        CGSize size = item.bounds.size;
        CGFloat mass = material.density * size.width * size.height / ((double)RevenantFieldPTM * (double)RevenantFieldPTM);
        CGVector acceleration = [self revenant_accelerationAt:center velocity:velocity mass:mass charge:material.charge time:now];
        [_carrier addLinearVelocity:CGPointMake(acceleration.dx * dt, acceleration.dy * dt) forItem:item];
    }
}

#pragma mark Properties

- (CGPoint)position
{
    return CGPointMake((double)_field.positionX * (double)RevenantFieldPTM, (double)_field.positionY * (double)RevenantFieldPTM);
}

- (void)setPosition:(CGPoint)position
{
    _field.positionX = (float)position.x * RevenantFieldInversePTM;
    _field.positionY = (float)position.y * RevenantFieldInversePTM;
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

- (CGFloat)minimumRadius
{
    return _field.minimumRadius / RevenantFieldInversePTM;
}

- (void)setMinimumRadius:(CGFloat)minimumRadius
{
    _field.minimumRadius = (float)minimumRadius * RevenantFieldInversePTM;
}

- (CGVector)direction
{
    return CGVectorMake(_field.directionX, _field.directionY);
}

- (void)setDirection:(CGVector)direction
{
    _field.directionX = (float)direction.dx;
    _field.directionY = (float)direction.dy;
}

- (BOOL)revenant_isNoise
{
    return _field.kind == RevenantFieldNoise || _field.kind == RevenantFieldTurbulence;
}

- (CGFloat)smoothness
{
    return [self revenant_isNoise] ? _field.smoothness : 0;
}

- (void)setSmoothness:(CGFloat)smoothness
{
    if ([self revenant_isNoise])
        _field.smoothness = (float)smoothness;
}

- (CGFloat)animationSpeed
{
    return [self revenant_isNoise] ? _field.animationSpeed : 0;
}

- (void)setAnimationSpeed:(CGFloat)animationSpeed
{
    if ([self revenant_isNoise])
        _field.animationSpeed = (float)animationSpeed;
}

@end
