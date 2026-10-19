#include <float.h>
#include <math.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include "CharonSpatial.h"

double host_angle_make_degrees(double degrees);
double host_angle_make_radians(double radians);
double host_angle_get_degrees(double radians);
int host_angle_equal(double a, double b);

static const double edges[] = {
    0.0, -0.0, 1.0, -1.0, 45.0, 90.0, 180.0, 360.0, -360.0, 1e300, -1e300, 1e-300, 5e-324,
    INFINITY, -INFINITY, NAN, 1.0 / 3.0, M_PI, 2 * M_PI, -M_PI, DBL_MAX, DBL_MIN, 0x1.0000000000001p0, 0.5,
};
#define EDGE_COUNT (sizeof edges / sizeof edges[0])
#define RANDOM_COUNT 1000000
#define VALUE_COUNT (EDGE_COUNT + RANDOM_COUNT)

static double values[VALUE_COUNT];
static uint64_t state = 0x5f3759df2b8e4d1dull;

static uint64_t bits(double value)
{
    uint64_t out;
    memcpy(&out, &value, sizeof out);
    return out;
}

static int same(double a, double b)
{
    return (isnan(a) && isnan(b)) || bits(a) == bits(b);
}

static int failures = 0;

static void report(const char *name, long cases, long differ, double in, double host, double port)
{
    if (differ == 0) {
        printf("ok %s %ld cases\n", name, cases);
        return;
    }
    failures++;
    printf("FAIL %s %ld of %ld differ; first in=%.17g host=%.17g port=%.17g\n", name, differ, cases, in, host, port);
}

int main(void)
{
    for (size_t i = 0; i < EDGE_COUNT; i++)
        values[i] = edges[i];
    for (size_t i = EDGE_COUNT; i < VALUE_COUNT; i++) {
        state = state * 6364136223846793005ull + 1442695040888963407ull;
        uint64_t raw = state;
        double value;
        memcpy(&value, &raw, sizeof value);
        values[i] = value;
    }

    long differ_degrees = 0, differ_radians = 0, differ_get = 0, differ_equal = 0;
    double first_degrees_in = 0, first_degrees_host = 0, first_degrees_port = 0;
    double first_radians_in = 0, first_radians_host = 0, first_radians_port = 0;
    double first_get_in = 0, first_get_host = 0, first_get_port = 0;
    double first_equal_in = 0, first_equal_other = 0;
    long cases_equal = 0;
    for (size_t i = 0; i < VALUE_COUNT; i++) {
        double x = values[i];
        double host = host_angle_make_degrees(x);
        double port = SPAngleMakeWithDegrees(x).radians;
        if (!same(host, port)) {
            if (differ_degrees++ == 0) { first_degrees_in = x; first_degrees_host = host; first_degrees_port = port; }
        }
        host = host_angle_make_radians(x);
        port = SPAngleMakeWithRadians(x).radians;
        if (!same(host, port)) {
            if (differ_radians++ == 0) { first_radians_in = x; first_radians_host = host; first_radians_port = port; }
        }
        host = host_angle_get_degrees(x);
        port = SPAngleGetDegrees((SPAngle){x});
        if (!same(host, port)) {
            if (differ_get++ == 0) { first_get_in = x; first_get_host = host; first_get_port = port; }
        }
    }
    for (size_t i = 0; i < VALUE_COUNT; i++)
        for (size_t step = 0; step < 2; step++) {
            size_t j = i + step;
            if (j >= VALUE_COUNT)
                continue;
            double a = values[i], b = values[j];
            int host = host_angle_equal(a, b), port = SPAngleEqualToAngle((SPAngle){a}, (SPAngle){b});
            cases_equal++;
            if (host != port && differ_equal++ == 0) { first_equal_in = a; first_equal_other = b; }
        }
    for (size_t i = 0; i < EDGE_COUNT; i++)
        for (size_t j = 0; j < EDGE_COUNT; j++) {
            int host = host_angle_equal(edges[i], edges[j]), port = SPAngleEqualToAngle((SPAngle){edges[i]}, (SPAngle){edges[j]});
            cases_equal++;
            if (host != port && differ_equal++ == 0) { first_equal_in = edges[i]; first_equal_other = edges[j]; }
        }

    report("SPAngleMakeWithDegrees", VALUE_COUNT, differ_degrees, first_degrees_in, first_degrees_host, first_degrees_port);
    report("SPAngleMakeWithRadians", VALUE_COUNT, differ_radians, first_radians_in, first_radians_host, first_radians_port);
    report("SPAngleGetDegrees", VALUE_COUNT, differ_get, first_get_in, first_get_host, first_get_port);
    if (differ_equal == 0) {
        printf("ok SPAngleEqualToAngle %ld cases\n", cases_equal);
    } else {
        failures++;
        printf("FAIL SPAngleEqualToAngle %ld of %ld differ; first in=%.17g other=%.17g\n", differ_equal, cases_equal,
               first_equal_in, first_equal_other);
    }
    return failures == 0 ? 0 : 1;
}
