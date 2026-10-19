#import <Accelerate/Accelerate.h>
#import <Foundation/Foundation.h>
#include <math.h>
#include <stdio.h>

void charon_host_vvcbrt(double *y, const double *x, const int *n);
void charon_host_vvcbrtf(float *y, const float *x, const int *n);

static int checks;
static int failures;
static char detail[256];

static void report(int passed, const char *name, const char *why)
{
    checks++;
    if (passed) {
        printf("ok %s\n", name);
    } else {
        failures++;
        printf("FAIL %s: %s\n", name, why);
    }
    fflush(stdout);
}

static const double inputs[] = {
    0.0,        -0.0,       1.0,        -1.0,      8.0,        -8.0,      27.0,      -27.0,
    125.0,      -125.0,     0.9999999,  1.0000001, 7.999999,   8.000001,  2.0,        -2.0,
    1e-300,     -1e-300,    1e-30,      1e30,      -1e30,      1e300,     -1e300,     4.9e-324,
    -4.9e-324,  2.2250738585072014e-308, 0.5, 0.1, 0.001, 123456.789, -123456.789, 3.0, 10.0, 1000.0,
};
#define INPUTS ((int)(sizeof inputs / sizeof *inputs))

int main(void)
{
    setbuf(stdout, NULL);
    @autoreleasepool {
        double mine[INPUTS], theirs[INPUTS], x[INPUTS];
        float minef[INPUTS], theirsf[INPUTS], xf[INPUTS];
        int count = INPUTS;
        for (int at = 0; at < INPUTS; at++) {
            x[at] = inputs[at];
            xf[at] = (float)inputs[at];
            mine[at] = minef[at] = 1234.5;
            theirs[at] = theirsf[at] = 1234.5;
        }
        vvcbrt(mine, x, &count);
        charon_host_vvcbrt(theirs, x, &count);
        vvcbrtf(minef, xf, &count);
        charon_host_vvcbrtf(theirsf, xf, &count);
        for (int at = 0; at < INPUTS; at++) {
            double mine_answer = mine[at], host_answer = theirs[at];
            char label[96];
            double scale = fabs(host_answer) > 1.0 ? fabs(host_answer) : 1.0;
            int agreed = mine_answer == host_answer || fabs(mine_answer - host_answer) <= 1e-6 * scale;
            snprintf(detail, sizeof detail, "of %.17g the port says %.17g and the host %.17g", inputs[at], mine_answer,
                     host_answer);
            snprintf(label, sizeof label, "vvcbrt of %.17g", inputs[at]);
            report(agreed, label, agreed ? "" : detail);

            scale = fabs(theirsf[at]) > 1.0f ? fabs(theirsf[at]) : 1.0f;
            agreed = minef[at] == theirsf[at] || fabs((double)minef[at] - (double)theirsf[at]) <= 1e-6 * scale;
            snprintf(detail, sizeof detail, "of %.9g the port says %.9g and the host %.9g", xf[at], minef[at],
                     theirsf[at]);
            snprintf(label, sizeof label, "vvcbrtf of %.9g", (double)xf[at]);
            report(agreed, label, agreed ? "" : detail);
        }
        {
            int none = 0, one = 1;
            double out = 1234.5, in = 27.0, host = 1234.5;
            vvcbrt(&out, &in, &none);
            charon_host_vvcbrt(&host, &in, &none);
            report(out == 1234.5 && host == 1234.5, "a length of zero writes nothing on either side", "");
            out = 1234.5;
            host = 1234.5;
            vvcbrt(&out, &in, &one);
            charon_host_vvcbrt(&host, &in, &one);
            report(out == host && out == 3.0, "a length of one answers 3 for 27 on both sides", "");
        }
        printf("%d checks, %d failures\n", checks, failures);
    }
    return failures == 0 ? 0 : 1;
}
