#import <CoreGraphics/CoreGraphics.h>
#include <float.h>
#include <math.h>
#include <stdio.h>

CGAffineTransformComponents RevenantHostDecompose(CGAffineTransform transform);
CGAffineTransform RevenantHostMakeWithComponents(CGAffineTransformComponents components);

static int checks, failures;
static double worst;

static int agree(double host, double port)
{
    double size = fabs(host) > 1 ? fabs(host) : 1;
    double error = fabs(host - port) / size;
    if (error > worst)
        worst = error;
    return error <= 1e-12;
}

static void report(const char *label, const char *what, int ok)
{
    checks++;
    if (!ok)
        failures++;
    printf("%s %s: %s\n", ok ? "ok  " : "FAIL", label, what);
}

static int same_components(CGAffineTransformComponents h, CGAffineTransformComponents p)
{
    return agree(h.scale.width, p.scale.width) && agree(h.scale.height, p.scale.height)
        && agree(h.horizontalShear, p.horizontalShear) && agree(h.rotation, p.rotation)
        && agree(h.translation.dx, p.translation.dx) && agree(h.translation.dy, p.translation.dy);
}

static int same_matrix(CGAffineTransform h, CGAffineTransform p)
{
    return agree(h.a, p.a) && agree(h.b, p.b) && agree(h.c, p.c) && agree(h.d, p.d)
        && agree(h.tx, p.tx) && agree(h.ty, p.ty);
}

#define ROUNDING_ULPS 4

enum band { EXACT, SCALE_BAND, SIGN_BAND };

static int within(double value, double terms, double tolerance)
{
    return terms > 0 && fabs(value) <= ROUNDING_ULPS * DBL_EPSILON * terms / tolerance;
}

static enum band band_of(CGAffineTransform m)
{
    if (hypot(m.a, m.b) == 0)
        return EXACT;
    double angle = atan2(m.b, m.a);
    double sine = sin(angle), cosine = cos(angle);
    double across = m.d * cosine - m.c * sine;
    double across_terms = fabs(m.d * cosine) + fabs(m.c * sine);
    double numerator = m.c * cosine + m.d * sine;
    double numerator_terms = fabs(m.c * cosine) + fabs(m.d * sine);
    if (within(across, across_terms, 1))
        return SIGN_BAND;
    if (within(across, across_terms, 1e-12) || within(numerator, numerator_terms, 1e-12))
        return SCALE_BAND;
    return EXACT;
}

static int rebuilds(CGAffineTransform m, CGAffineTransformComponents k)
{
    CGAffineTransform r = CGAffineTransformMakeWithComponents(k);
    double size = fmax(fmax(fabs(m.a), fabs(m.b)), fmax(fabs(m.c), fabs(m.d)));
    size = size > 1 ? size : 1;
    double errors[4] = {fabs(m.a - r.a), fabs(m.b - r.b), fabs(m.c - r.c), fabs(m.d - r.d)};
    int second = k.scale.height != 0;
    for (int i = 0; i < 4; i++) {
        if (i >= 2 && !second)
            continue;
        if (errors[i] / size > worst)
            worst = errors[i] / size;
        if (errors[i] / size > 1e-12)
            return 0;
    }
    return agree(m.tx, r.tx) && agree(m.ty, r.ty);
}

static int accepts(CGAffineTransform m, CGAffineTransformComponents h, CGAffineTransformComponents p, enum band band)
{
    if (band == EXACT)
        return same_components(h, p);
    if (!agree(fabs(h.scale.width), fabs(p.scale.width)))
        return 0;
    if (band == SCALE_BAND && ((h.scale.width < 0) != (p.scale.width < 0) || !agree(h.rotation, p.rotation)))
        return 0;
    return rebuilds(m, p) && rebuilds(m, h);
}

static void battery(const char *label, double a, double b, double c, double d, double tx, double ty)
{
    CGAffineTransform m = CGAffineTransformMake(a, b, c, d, tx, ty);
    CGAffineTransformComponents hc = CGAffineTransformDecompose(m);
    CGAffineTransformComponents pc = RevenantHostDecompose(m);
    enum band band = band_of(m);
    if (band == EXACT)
        report(label, "decompose agrees with the host", accepts(m, hc, pc, band));
    else if (band == SCALE_BAND)
        report(label, "decompose agrees with the host on the sign, length and rotation, and both rebuild the matrix (rounding band)",
               accepts(m, hc, pc, band));
    else
        report(label, "both decompositions rebuild the matrix (sign within the rounding band)", accepts(m, hc, pc, band));
    report(label, "the port's components rebuild the matrix as the host's do",
           same_matrix(CGAffineTransformMakeWithComponents(pc), RevenantHostMakeWithComponents(pc)));
    if (fabs(a * d - b * c) > 1e-9 * (fabs(a * d) + fabs(b * c)))
        report(label, "the port's components rebuild the matrix", same_matrix(m, CGAffineTransformMakeWithComponents(pc)));
    report(label, "port builds the host's matrix from the host's components",
           same_matrix(CGAffineTransformMakeWithComponents(hc), RevenantHostMakeWithComponents(hc)));
}

static uint64_t seed = 20261016;

static double next_unit(void)
{
    seed = seed * 6364136223846793005ULL + 1442695040888963407ULL;
    return ((double)(seed >> 11) / 9007199254740992.0) * 2 - 1;
}

static void sweep(const char *label, int singular, int count)
{
    int disagreeing = 0, flips = 0, bands[3] = {0, 0, 0};
    for (int index = 0; index < count; index++) {
        double scale = pow(10, (double)(index % 7) - 3);
        double a = next_unit() * scale, b = next_unit() * scale, c, d;
        if (singular) {
            double multiple = next_unit() * 4;
            c = multiple * a;
            d = multiple * b;
        } else {
            c = next_unit() * scale;
            d = next_unit() * scale;
        }
        CGAffineTransform m = CGAffineTransformMake(a, b, c, d, 0, 0);
        CGAffineTransformComponents hc = CGAffineTransformDecompose(m);
        CGAffineTransformComponents pc = RevenantHostDecompose(m);
        enum band band = band_of(m);
        bands[band]++;
        if (!accepts(m, hc, pc, band))
            disagreeing++;
        if ((hc.scale.width < 0) != (pc.scale.width < 0))
            flips++;
    }
    report(label, disagreeing ? "some decompositions disagree with the host outside the rounding band"
                              : "every decomposition agrees with the host, or is valid within the rounding band",
           disagreeing == 0);
    printf("  %d exact, %d in the scale band, %d in the sign band; the sign of the x scale differs on %d\n",
           bands[EXACT], bands[SCALE_BAND], bands[SIGN_BAND], flips);
}

int main(void)
{
    double s30 = sin(M_PI / 6), c30 = cos(M_PI / 6);
    double s45 = sin(-M_PI / 4), c45 = cos(-M_PI / 4);
    battery("identity", 1, 0, 0, 1, 0, 0);
    battery("translate", 1, 0, 0, 1, 5, -7);
    battery("scale", 2, 0, 0, 3, 0, 0);
    battery("negx", -2, 0, 0, 3, 0, 0);
    battery("negy", 2, 0, 0, -3, 0, 0);
    battery("negboth", -2, 0, 0, -3, 0, 0);
    battery("flipx", -1, 0, 0, 1, 0, 0);
    battery("flipy", 1, 0, 0, -1, 0, 0);
    battery("rot30", c30, s30, -s30, c30, 0, 0);
    battery("rot90", 0, 1, -1, 0, 0, 0);
    battery("rot180", -1, 0, 0, -1, 0, 0);
    battery("rot-45", c45, -s45, s45, c45, 0, 0);
    battery("rotscale", 2 * c30, 2 * s30, -3 * s30, 3 * c30, 1, 2);
    battery("shear", 1, 0, 0.5, 1, 0, 0);
    battery("swap", 0, 1, 1, 0, 0, 0);
    battery("zero", 0, 0, 0, 0, 0, 0);
    battery("degen", 0, 0, 1, 1, 0, 0);
    battery("degen2", 0, 0, 0, 2, 3, 4);
    battery("d-neg", 0, 0, 0, -2, 0, 0);
    battery("c1d-neg", 0, 0, 1, -1, 0, 0);
    battery("rank1a", 1, 0, 0, 0, 0, 0);
    battery("rank1neg", -1, 0, 0, 0, 0, 0);
    battery("rank1c", 0, 1, 0, 0, 0, 0);
    battery("rank1d", 0, -1, 0, 0, 0, 0);
    battery("negdet", 0, 2, 3, 0, 0, 0);
    battery("arb", 1.3, 0.7, -0.4, 2.1, 3.5, -2.25);
    battery("arb2", -1.3, 0.7, 0.4, -2.1, 3.5, -2.25);
    battery("tiny", 1e-9, 0, 0, 1, 0, 0);
    battery("sing1", 2, 2, 1, 1, 0, 0);
    battery("sing2", 1, 2, 2, 4, 0, 0);
    battery("sing3", 3, 1, 6, 2, 0, 0);
    battery("sing4", 1, 1, 1, 1, 0, 0);
    battery("sing5", 5, -2, -10, 4, 0, 0);
    battery("sing6", 0.3, 0.7, 0.6, 1.4, 0, 0);
    battery("sing7", 1, 3, -2, -6, 0, 0);
    battery("sing8", 4, -1, -8, 2, 0, 0);
    sweep("generated singular", 1, 1000);
    sweep("generated general", 0, 1000);
    printf("%d checks, %d failures, largest relative difference %g\n", checks, failures, worst);
    return failures ? 1 : 0;
}
