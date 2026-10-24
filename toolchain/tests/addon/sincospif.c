#include <math.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

void revenant_sincospif(float, float *, float *);
void revenant_sincospi(double, double *, double *);
float revenant_sinpif(float);
float revenant_cospif(float);
float revenant_tanpif(float);
double revenant_sinpi(double);
double revenant_cospi(double);
double revenant_tanpi(double);

static uint32_t ordered(float value)
{
    uint32_t bits;
    memcpy(&bits, &value, sizeof(bits));
    return bits & 0x80000000u ? ~bits : bits | 0x80000000u;
}

static uint32_t distance(float left, float right)
{
    uint32_t a = ordered(left);
    uint32_t b = ordered(right);
    return a > b ? a - b : b - a;
}

static uint32_t reported;
static uint32_t reported_double;
static uint32_t maximum_float_tangent_distance;
static uint64_t maximum_double_tangent_distance;

static int check(float x, float expected_sine, float expected_cosine, uint32_t limit)
{
    float sine;
    float cosine;
    revenant_sincospif(x, &sine, &cosine);
    uint32_t sine_distance = distance(sine, expected_sine);
    uint32_t cosine_distance = distance(cosine, expected_cosine);
    if (sine_distance > limit || cosine_distance > limit) {
        if (!reported)
            fprintf(stderr, "x=%.9g sine=%.9g expected=%.9g ulp=%u cosine=%.9g expected=%.9g ulp=%u\n",
                    x, sine, expected_sine, sine_distance, cosine, expected_cosine, cosine_distance);
        ++reported;
        return 1;
    }
    return 0;
}

static uint64_t ordered_double(double value)
{
    uint64_t bits;
    memcpy(&bits, &value, sizeof(bits));
    return bits & 0x8000000000000000ull ? ~bits : bits | 0x8000000000000000ull;
}

static uint64_t distance_double(double left, double right)
{
    uint64_t a = ordered_double(left);
    uint64_t b = ordered_double(right);
    return a > b ? a - b : b - a;
}

static int check_double(double x, double expected_sine, double expected_cosine, uint64_t limit)
{
    double sine;
    double cosine;
    revenant_sincospi(x, &sine, &cosine);
    uint64_t sine_distance = distance_double(sine, expected_sine);
    uint64_t cosine_distance = distance_double(cosine, expected_cosine);
    if (sine_distance > limit || cosine_distance > limit) {
        if (!reported_double) {
            fprintf(stderr, "x=%.17g sine=%.17g expected=%.17g ulp=%llu cosine=%.17g expected=%.17g ulp=%llu\n",
                    x, sine, expected_sine, (unsigned long long)sine_distance,
                    cosine, expected_cosine, (unsigned long long)cosine_distance);
        }
        ++reported_double;
        return 1;
    }
    return 0;
}

static int check_float_functions(float x, uint32_t limit)
{
    float sine = revenant_sinpif(x);
    float cosine = revenant_cospif(x);
    float tangent = revenant_tanpif(x);
    uint32_t sine_distance = distance(sine, __sinpif(x));
    uint32_t cosine_distance = distance(cosine, __cospif(x));
    uint32_t tangent_distance = distance(tangent, __tanpif(x));
    if (tangent_distance > maximum_float_tangent_distance)
        maximum_float_tangent_distance = tangent_distance;
    if (sine_distance > limit || cosine_distance > limit || tangent_distance > limit) {
        if (!reported)
            fprintf(stderr, "float wrappers x=%.9g sin=%u cos=%u tan=%u\n", x, sine_distance, cosine_distance, tangent_distance);
        ++reported;
        return 1;
    }
    return 0;
}

static int check_double_functions(double x, uint64_t limit)
{
    double sine = revenant_sinpi(x);
    double cosine = revenant_cospi(x);
    double tangent = revenant_tanpi(x);
    uint64_t sine_distance = distance_double(sine, __sinpi(x));
    uint64_t cosine_distance = distance_double(cosine, __cospi(x));
    uint64_t tangent_distance = distance_double(tangent, __tanpi(x));
    if (tangent_distance > maximum_double_tangent_distance)
        maximum_double_tangent_distance = tangent_distance;
    if (sine_distance > limit || cosine_distance > limit || tangent_distance > limit) {
        if (!reported_double)
            fprintf(stderr, "double wrappers x=%.17g sin=%llu cos=%llu tan=%llu actual=%.17g expected=%.17g\n", x,
                    (unsigned long long)sine_distance, (unsigned long long)cosine_distance,
                    (unsigned long long)tangent_distance, tangent, __tanpi(x));
        ++reported_double;
        return 1;
    }
    return 0;
}

int main(void)
{
    uint32_t failures = 0;
    for (int32_t i = -524288; i <= 524288; ++i) {
        float x = (float)i / 32768.0f;
        if (x * 2.0f == floorf(x * 2.0f))
            continue;
        struct __float2 expected = __sincospif_stret(x);
        failures += (uint32_t)check(x, expected.__sinval, expected.__cosval, 1);
        failures += (uint32_t)check_float_functions(x, 1);
    }
    for (int32_t i = -65536; i <= 65536; ++i) {
        double x = (double)i / 16384.0;
        if (x * 2.0 == floor(x * 2.0))
            continue;
        struct __double2 expected = __sincospi_stret(x);
        failures += (uint32_t)check_double(x, expected.__sinval, expected.__cosval, 2);
        failures += (uint32_t)check_double_functions(x, 4);
    }
    failures += (uint32_t)check(0.0f, 0.0f, 1.0f, 0);
    failures += (uint32_t)check(-0.0f, -0.0f, 1.0f, 0);
    failures += (uint32_t)check(1.0f, 0.0f, -1.0f, 0);
    failures += (uint32_t)check(-1.0f, -0.0f, -1.0f, 0);
    failures += (uint32_t)check(0.5f, 1.0f, 0.0f, 0);
    failures += (uint32_t)check(-0.5f, -1.0f, 0.0f, 0);
    failures += (uint32_t)check(1.5f, -1.0f, 0.0f, 0);
    failures += (uint32_t)check_float_functions(0.5f, 0);
    failures += (uint32_t)check_float_functions(-0.5f, 0);
    failures += (uint32_t)check_float_functions(1.5f, 0);
    failures += (uint32_t)check_float_functions(-1.5f, 0);
    failures += (uint32_t)check_double(0.0, 0.0, 1.0, 0);
    failures += (uint32_t)check_double(-0.0, -0.0, 1.0, 0);
    failures += (uint32_t)check_double(1.0, 0.0, -1.0, 0);
    failures += (uint32_t)check_double(0.5, 1.0, 0.0, 0);
    failures += (uint32_t)check_double(1.5, -1.0, 0.0, 0);
    failures += (uint32_t)check_double_functions(0.5, 0);
    failures += (uint32_t)check_double_functions(-0.5, 0);
    failures += (uint32_t)check_double_functions(1.5, 0);
    failures += (uint32_t)check_double_functions(-1.5, 0);
    float sine;
    float cosine;
    revenant_sincospif(INFINITY, &sine, &cosine);
    failures += (uint32_t)(!isnan(sine) || !isnan(cosine));
    revenant_sincospif(NAN, &sine, &cosine);
    failures += (uint32_t)(!isnan(sine) || !isnan(cosine));
    double sine_double;
    double cosine_double;
    revenant_sincospi(INFINITY, &sine_double, &cosine_double);
    failures += (uint32_t)(!isnan(sine_double) || !isnan(cosine_double));
    revenant_sincospi(NAN, &sine_double, &cosine_double);
    failures += (uint32_t)(!isnan(sine_double) || !isnan(cosine_double));
    if (failures)
        fprintf(stderr, "sincospif failures=%u\n", failures);
    else
        printf("sincospif passed dense host libm comparison; max tangent distance float=%u double=%llu ULP\n",
               maximum_float_tangent_distance, (unsigned long long)maximum_double_tangent_distance);
    return failures ? 1 : 0;
}
