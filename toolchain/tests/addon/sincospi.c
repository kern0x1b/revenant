#include <float.h>
#include <math.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

#include "sincospi_truth.h"

double revenant_sinpi(double);
double revenant_cospi(double);
double revenant_tanpi(double);
void revenant_sincospi(double, double *, double *);
float revenant_sinpif(float);
float revenant_cospif(float);
float revenant_tanpif(float);
void revenant_sincospif(float, float *, float *);

static const double SINE_ULP = 1.0;
static const double TANGENT_ULP = 1.0;
static const double HOST_ULP = 2.0;
static const double FLOAT_ULP = 0.5;
static const int SAMPLES = 1000000;

static int failures;
static uint64_t state = 0x9E3779B97F4A7C15ULL;

static uint64_t next_random(void)
{
    uint64_t z = (state += 0x9E3779B97F4A7C15ULL);
    z = (z ^ (z >> 30)) * 0xBF58476D1CE4E5B9ULL;
    z = (z ^ (z >> 27)) * 0x94D049BB133111EBULL;
    return z ^ (z >> 31);
}

static double random_in_range(double width)
{
    return ((double)(next_random() >> 11) * 0x1p-53 * 2.0 - 1.0) * width;
}

static double random_in_binades(int low, int high)
{
    const uint64_t exponent = (uint64_t)(1023 + low + (int)(next_random() % (uint64_t)(high - low + 1)));
    const uint64_t bits = (next_random() & 1ULL) << 63 | exponent << 52 | (next_random() & ((1ULL << 52) - 1));
    double value;
    memcpy(&value, &bits, sizeof value);
    return value;
}

static double ulp_of(double value)
{
    const double magnitude = fabs(value);
    return nextafter(magnitude, INFINITY) - magnitude;
}

static double ulp_of_float(float value)
{
    const float magnitude = fabsf(value);
    return nextafterf(magnitude, INFINITY) - magnitude;
}

static double error_in_ulps(double ours, double truth)
{
    if (isnan(ours) || isnan(truth))
        return isnan(ours) == isnan(truth) ? 0.0 : INFINITY;
    if (ours == truth)
        return 0.0;
    if (ours == 0.0 || truth == 0.0 || isinf(ours) || isinf(truth))
        return INFINITY;
    return fabs(ours - truth) / ulp_of(truth);
}

static double error_in_ulps_float(float ours, float truth)
{
    if (isnan(ours) || isnan(truth))
        return isnan(ours) == isnan(truth) ? 0.0 : INFINITY;
    if (ours == truth)
        return 0.0;
    if (ours == 0.0f || truth == 0.0f || isinf(ours) || isinf(truth))
        return INFINITY;
    return fabs((double)ours - (double)truth) / (double)ulp_of_float(truth);
}

static double error_with_host_zero(double ours, double host)
{
    if (ours == 0.0 && host == 0.0)
        return signbit(ours) == signbit(host) ? 0.0 : INFINITY;
    return error_in_ulps(ours, host);
}

static void judge(const char *name, double error, double bound, const char *input)
{
    if (!(error <= bound)) {
        failures += 1;
        printf("FAIL  %s(%s) is %.6g ulp from its reference, over the bound %.6g\n", name, input, error, bound);
    }
}

static void check_table(void)
{
    for (size_t index = 0; index < sizeof TRUTH_DOUBLE / sizeof TRUTH_DOUBLE[0]; ++index) {
        const double x = TRUTH_DOUBLE[index].x;
        char input[64];
        snprintf(input, sizeof input, "%a", x);
        double sine;
        double cosine;
        revenant_sincospi(x, &sine, &cosine);
        judge("sinpi", error_in_ulps(revenant_sinpi(x), TRUTH_DOUBLE[index].sine), SINE_ULP, input);
        judge("cospi", error_in_ulps(revenant_cospi(x), TRUTH_DOUBLE[index].cosine), SINE_ULP, input);
        judge("tanpi", error_in_ulps(revenant_tanpi(x), TRUTH_DOUBLE[index].tangent), TANGENT_ULP, input);
        judge("sincospi.sin", error_in_ulps(sine, TRUTH_DOUBLE[index].sine), SINE_ULP, input);
        judge("sincospi.cos", error_in_ulps(cosine, TRUTH_DOUBLE[index].cosine), SINE_ULP, input);
    }
    for (size_t index = 0; index < sizeof TRUTH_FLOAT / sizeof TRUTH_FLOAT[0]; ++index) {
        const float x = (float)TRUTH_FLOAT[index].x;
        char input[64];
        snprintf(input, sizeof input, "%a", (double)x);
        float sine;
        float cosine;
        revenant_sincospif(x, &sine, &cosine);
        judge("sinpif", error_in_ulps_float(revenant_sinpif(x), (float)TRUTH_FLOAT[index].sine), FLOAT_ULP, input);
        judge("cospif", error_in_ulps_float(revenant_cospif(x), (float)TRUTH_FLOAT[index].cosine), FLOAT_ULP, input);
        judge("tanpif", error_in_ulps_float(revenant_tanpif(x), (float)TRUTH_FLOAT[index].tangent), FLOAT_ULP, input);
        judge("sincospif.sin", error_in_ulps_float(sine, (float)TRUTH_FLOAT[index].sine), FLOAT_ULP, input);
        judge("sincospif.cos", error_in_ulps_float(cosine, (float)TRUTH_FLOAT[index].cosine), FLOAT_ULP, input);
    }
}

static void check_edges(void)
{
    const double values[] = {
        0.0, -0.0, 0.25, -0.25, 0.5, -0.5, 0.75, -0.75, 1.0, -1.0, 1.5, -1.5, 2.0, -2.0, 2.5, -2.5,
        3.0, -3.0, 0.125, -0.125, 1e-300, -1e-300, DBL_MIN, DBL_TRUE_MIN, -DBL_TRUE_MIN, 1e-17,
        4503599627370495.5, 4503599627370496.0, 4503599627370497.0, 9007199254740991.0, 9007199254740992.0,
        9007199254740994.0, 1e300, -1e300, DBL_MAX, -DBL_MAX, 1e15 + 0.5, INFINITY, -INFINITY, NAN
    };
    for (size_t index = 0; index < sizeof values / sizeof values[0]; ++index) {
        const double x = values[index];
        char input[64];
        snprintf(input, sizeof input, "%.17g", x);
        double sine;
        double cosine;
        revenant_sincospi(x, &sine, &cosine);
        judge("sinpi", error_with_host_zero(revenant_sinpi(x), __sinpi(x)), HOST_ULP, input);
        judge("cospi", error_with_host_zero(revenant_cospi(x), __cospi(x)), HOST_ULP, input);
        judge("sincospi.sin", error_with_host_zero(sine, __sinpi(x)), HOST_ULP, input);
        judge("sincospi.cos", error_with_host_zero(cosine, __cospi(x)), HOST_ULP, input);
    }
}

static void check_integers_and_halves(void)
{
    for (int n = -4096; n <= 4096; ++n) {
        const double whole = (double)n;
        const double expected = n & 1 ? -1.0 : 1.0;
        if (revenant_cospi(whole) != expected) {
            failures += 1;
            printf("FAIL  cospi(%d) is not exactly %g\n", n, expected);
        }
        if (revenant_sinpi(whole) != 0.0 || signbit(revenant_sinpi(whole)) != signbit(__sinpi(whole))) {
            failures += 1;
            printf("FAIL  sinpi(%d) is not a zero with the host's sign\n", n);
        }
        const double half = whole + 0.5;
        if (revenant_cospi(half) != 0.0 || signbit(revenant_cospi(half))) {
            failures += 1;
            printf("FAIL  cospi(%d.5) is not +0\n", n);
        }
        judge("tanpi(half)", error_in_ulps(revenant_tanpi(half), __tanpi(half)), HOST_ULP, "half-integer");
    }
}

static void sweep_host(const char *label, int low, int high)
{
    double worst_sine = 0.0;
    double worst_cosine = 0.0;
    for (int index = 0; index < SAMPLES; ++index) {
        const double x = low == high ? random_in_range(8.0) : random_in_binades(low, high);
        if (!isfinite(x))
            continue;
        const double e_sine = error_in_ulps(revenant_sinpi(x), __sinpi(x));
        const double e_cosine = error_in_ulps(revenant_cospi(x), __cospi(x));
        if (e_sine > worst_sine)
            worst_sine = e_sine;
        if (e_cosine > worst_cosine)
            worst_cosine = e_cosine;
    }
    printf("host sweep %-10s sinpi %.4f ulp, cospi %.4f ulp\n", label, worst_sine, worst_cosine);
    judge("sinpi host sweep", worst_sine, HOST_ULP, label);
    judge("cospi host sweep", worst_cosine, HOST_ULP, label);
}

static void sweep_host_float(void)
{
    double worst_sine = 0.0;
    double worst_cosine = 0.0;
    uint64_t checked = 0;
    for (uint64_t pattern = 0; pattern < 0x80000000ULL; pattern += 61) {
        const uint32_t bits = (uint32_t)pattern;
        float x;
        memcpy(&x, &bits, sizeof x);
        if (!isfinite(x))
            continue;
        checked += 1;
        const double e_sine = error_in_ulps_float(revenant_sinpif(x), __sinpif(x));
        const double e_cosine = error_in_ulps_float(revenant_cospif(x), __cospif(x));
        if (e_sine > worst_sine)
            worst_sine = e_sine;
        if (e_cosine > worst_cosine)
            worst_cosine = e_cosine;
    }
    printf("host sweep float %llu patterns: sinpif %.4f ulp, cospif %.4f ulp\n", (unsigned long long)checked, worst_sine,
           worst_cosine);
    judge("sinpif host sweep", worst_sine, 1.0, "float sweep");
    judge("cospif host sweep", worst_cosine, 1.0, "float sweep");
}

int main(void)
{
    check_table();
    check_edges();
    check_integers_and_halves();
    sweep_host("[-8,8]", 0, 0);
    sweep_host("binades", -20, 20);
    sweep_host_float();
    printf("sincospi check finished with %d failures\n", failures);
    return failures;
}
