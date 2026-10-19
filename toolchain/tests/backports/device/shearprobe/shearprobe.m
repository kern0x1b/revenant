#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/wait.h>
#include <unistd.h>

#include <Accelerate/Accelerate.h>

#include "RevenantResampling.h"
#include "RevenantShear.h"

enum {
    ShearSrcAlong = 24,
    ShearSrcCross = 9,
    ShearMargin = 8,
    ShearMaxDst = 64,
    ShearMaxCandidates = 6,
    ShearMaxScales = 8,
    ShearMaxTranslates = 8,
    ShearDivisor16384 = 0,
    ShearDivisorRowSum = 1
};

static const float ShearScales[ShearMaxScales] = { 1.0f, 2.0f, 0.5f, 0.75f, 0.25f };
enum { ShearScaleCount = 5, ShearTranslateCount = 7 };
static const double ShearTranslates[ShearMaxTranslates] = { 0.0, 1.0, -1.0, 0.5, -0.5, 2.5, 0.0078125 };

typedef struct ShearPair {
    unsigned phase;
    long base;
} ShearPair;

typedef struct ShearRun {
    ResamplingFilter filter;
    RevenantResampleFilter ours;
    vImage_Buffer src8, dst8;
    vImage_Buffer src16, dst16;
    unsigned char *src8Data, *dst8Data;
    unsigned short *src16Data, *dst16Data;
    unsigned short relObs[ShearMaxDst][ShearSrcAlong];
    unsigned short portObs[ShearMaxDst][ShearSrcAlong];
} ShearRun;

static double ShearStore(double value, double max)
{
    if (value < 0.0)
        value = 0.0;
    if (value > max)
        value = max;
    return floor(value + 0.5);
}

static double ShearPredict(const RevenantResampleFilter *filter, unsigned phase, long first, long c,
                           double amplitude, int divisorMode, double max)
{
    long j = c - first;
    if (j < 0 || j >= (long)filter->width)
        return 0.0;
    long at = first + j;
    if (at < 0 || at >= (long)ShearSrcAlong)
        return 0.0;
    double divisor = divisorMode == ShearDivisorRowSum
        ? RevenantResampleRowSum(filter, phase)
        : 16384.0;
    return ShearStore((double)filter->row[(size_t)phase * filter->width + (size_t)j] * amplitude / divisor, max);
}

static unsigned ShearIdentify(const RevenantResampleFilter *filter, const unsigned short *observed,
                              double amplitude, int divisorMode, double max, ShearPair *list, unsigned room)
{
    unsigned found = 0;
    for (unsigned phase = 0; phase < filter->phases; phase++) {
        for (long first = -(long)filter->width; first <= (long)ShearSrcAlong; first++) {
            int ok = 1;
            for (long c = 0; c < (long)ShearSrcAlong; c++) {
                if (ShearPredict(filter, phase, first, c, amplitude, divisorMode, max) != (double)observed[c]) {
                    ok = 0;
                    break;
                }
            }
            if (ok) {
                if (found < room) {
                    list[found].phase = phase;
                    list[found].base = first + (long)filter->centre;
                }
                found++;
            }
        }
    }
    return found;
}

static void ShearPrintPairs(const char *label, const ShearPair *list, unsigned count, unsigned room)
{
    printf(" %s=", label);
    if (count == 0) {
        printf("none");
        return;
    }
    if (count == 1) {
        printf("%u:%ld", list[0].phase, list[0].base);
        return;
    }
    printf("ambig%u(", count);
    unsigned shown = count < room ? count : room;
    for (unsigned i = 0; i < shown; i++)
        printf("%s%u:%ld", i ? "," : "", list[i].phase, list[i].base);
    printf(")");
}

static int ShearPairEq(const ShearPair *a, const ShearPair *b)
{
    return a->phase == b->phase && a->base == b->base;
}

static int ShearSameList(const ShearPair *a, unsigned na, const ShearPair *b, unsigned nb, unsigned room)
{
    if (na != nb)
        return 0;
    unsigned shown = na < room ? na : room;
    for (unsigned i = 0; i < shown; i++)
        if (!ShearPairEq(&a[i], &b[i]))
            return 0;
    return 1;
}

static long long ShearAccumulator(const RevenantResampleFilter *filter, int horizontal, double translate,
                                  vImagePixelCount dstAlong, vImagePixelCount along)
{
    long long position = 0;
    if (horizontal) {
        double scaled = 0.0 - filter->reciprocal * translate;
        scaled = scaled + (double)filter->taps * -0.5;
        position = RevenantResampleQ32((scaled + 1.0) * 4294967296.0);
    } else {
        double oneMinusReciprocal = 1.0 - filter->reciprocal;
        double scaled = (double)dstAlong * oneMinusReciprocal;
        scaled = scaled + filter->reciprocal * translate;
        scaled = scaled + (double)filter->taps * -0.5;
        position = RevenantResampleQ32((scaled + 1.0) * 4294967296.0);
    }
    return position + (long long)along * RevenantResampleStep(filter);
}

static void ShearPortFunction(const RevenantResampleFilter *filter, int horizontal, double translate,
                              vImagePixelCount dstAlong, vImagePixelCount along, ShearPair *out)
{
    long base = 0;
    unsigned phase = 0;
    RevenantResamplePhase(filter, ShearAccumulator(filter, horizontal, translate, dstAlong, along),
                        &phase, &base);
    out->phase = phase;
    out->base = base;
}

static double ShearCentre(const RevenantResampleFilter *filter, int horizontal, double translate,
                          vImagePixelCount dstAlong, vImagePixelCount along)
{
    long long position = ShearAccumulator(filter, horizontal, translate, dstAlong, along);
    return (double)(position >> 32) + (double)(position & 0xffffffff) * (1.0 / 4294967296.0);
}

static void ShearFill(ShearRun *run, int horizontal, vImagePixelCount c)
{
    vImagePixelCount srcAlong = horizontal ? run->src8.width : run->src8.height;
    vImagePixelCount srcCross = horizontal ? run->src8.height : run->src8.width;
    unsigned char *src16Bytes = (unsigned char *)(void *)run->src16Data;
    for (vImagePixelCount along = 0; along < srcAlong; along++) {
        for (vImagePixelCount cross = 0; cross < srcCross; cross++) {
            size_t row = horizontal ? (size_t)cross : (size_t)along;
            size_t col = horizontal ? (size_t)along : (size_t)cross;
            unsigned char *p8 = run->src8Data + row * run->src8.rowBytes + col * 4;
            unsigned short *p16 = (unsigned short *)(void *)(src16Bytes + row * run->src16.rowBytes + col * 8);
            int on = along == c;
            p8[0] = on ? 255 : 0;
            p8[1] = 255;
            p8[2] = 255;
            p8[3] = 255;
            p16[0] = on ? 65535 : 0;
            p16[1] = 65535;
            p16[2] = 65535;
            p16[3] = 65535;
        }
    }
}

static vImagePixelCount ShearSweep(ShearRun *run, int horizontal, float scale, double translate)
{
    vImagePixelCount srcAlong = (vImagePixelCount)ShearSrcAlong;
    vImagePixelCount dstAlong = (vImagePixelCount)ceil((double)scale * (double)ShearSrcAlong) + ShearMargin;
    if (dstAlong > (vImagePixelCount)ShearMaxDst)
        dstAlong = (vImagePixelCount)ShearMaxDst;

    run->src8.data = run->src8Data;
    run->src8.height = horizontal ? (vImagePixelCount)ShearSrcCross : srcAlong;
    run->src8.width = horizontal ? srcAlong : (vImagePixelCount)ShearSrcCross;
    run->src8.rowBytes = run->src8.width * 4;
    run->dst8.data = run->dst8Data;
    run->dst8.height = horizontal ? (vImagePixelCount)ShearSrcCross : dstAlong;
    run->dst8.width = horizontal ? dstAlong : (vImagePixelCount)ShearSrcCross;
    run->dst8.rowBytes = run->dst8.width * 4;

    run->src16.data = run->src16Data;
    run->src16.height = run->src8.height;
    run->src16.width = run->src8.width;
    run->src16.rowBytes = run->src8.rowBytes * 2;
    run->dst16.data = run->dst16Data;
    run->dst16.height = run->dst8.height;
    run->dst16.width = run->dst8.width;
    run->dst16.rowBytes = run->dst8.rowBytes * 2;

    memset(run->dst8Data, 0, (size_t)ShearMaxDst * ShearSrcCross * 4);
    memset(run->dst16Data, 0, (size_t)ShearMaxDst * ShearSrcCross * 8);

    Pixel_8888 back8888 = { 0, 0, 0, 0 };
    double back16[4] = { 0.0, 0.0, 0.0, 0.0 };

    unsigned char *dst16Bytes = (unsigned char *)(void *)run->dst16Data;
    for (vImagePixelCount c = 0; c < srcAlong; c++) {
        ShearFill(run, horizontal, c);
        vImage_Error theirs = horizontal
            ? vImageHorizontalShear_ARGB8888(&run->src8, &run->dst8, 0, 0, (float)translate, 0.0f,
                                             run->filter, back8888, kvImageNoFlags)
            : vImageVerticalShear_ARGB8888(&run->src8, &run->dst8, 0, 0, (float)translate, 0.0f,
                                           run->filter, back8888, kvImageNoFlags);
        if (theirs != kvImageNoError) {
            printf("  delta %u: the release's own shear answered %d\n", (unsigned)c, (int)theirs);
            continue;
        }
        vImage_Error ready = RevenantShearReady(&run->src16, &run->dst16, &run->ours, horizontal, 0, 0);
        if (ready != kvImageNoError) {
            printf("  delta %u: the port refused the shape with %d\n", (unsigned)c, (int)ready);
            continue;
        }
        vImage_Error ours = RevenantShearRun(&run->src16, &run->dst16, &run->ours, RevenantARGB16U, horizontal,
                                           translate, 0.0, 0, 0, back16, kvImageNoFlags);
        if (ours != kvImageNoError) {
            printf("  delta %u: the port's engine answered %d\n", (unsigned)c, (int)ours);
            continue;
        }
        for (vImagePixelCount along = 0; along < dstAlong; along++) {
            size_t row = horizontal ? (size_t)0 : (size_t)along;
            size_t col = horizontal ? (size_t)along : (size_t)0;
            const unsigned char *d8 = run->dst8Data + row * run->dst8.rowBytes + col * 4;
            const unsigned short *d16 = (const unsigned short *)(const void *)(dst16Bytes + row * run->dst16.rowBytes + col * 8);
            run->relObs[along][c] = d8[0];
            run->portObs[along][c] = d16[0];
        }
    }
    return dstAlong;
}

enum { ShearSignSubtract = 0, ShearSignAdd = 1 };
enum { ShearCentreNear64 = 0, ShearCentreFarFactored64 = 1, ShearCentreFarDistributed64 = 2,
       ShearCentreFarFactored32 = 3, ShearCentreFarDistributed32 = 4,
       ShearCentreFarFactoredAnchor32 = 5, ShearCentreFarDistributedAnchor32 = 6 };
enum { ShearCentres = 7 };
enum { ShearRuleRoundCarry = 0, ShearRuleTruncate = 1, ShearRuleCeilMinusOne = 2 };
enum { ShearArms = 2 * 2 * ShearCentres * 3 };

typedef struct ShearArm {
    int halfPixel;
    int sign;
    int centre;
    int rule;
    char name[32];
} ShearArm;

static ShearArm ShearArmTable[ShearArms];
static int ShearArmTableDone = 0;
static int ShearArmPortVertical = -1;
static int ShearArmPortHorizontal = -1;

static void ShearArmTableBuild(void)
{
    if (ShearArmTableDone)
        return;
    ShearArmTableDone = 1;
    static const char *const centreNames[ShearCentres] = {
        "near64", "farfac64", "fardis64", "farfac32", "fardis32", "farfacA32", "fardisA32"
    };
    int at = 0;
    for (int hp = 0; hp < 2; hp++) {
        for (int sign = 0; sign < 2; sign++) {
            for (int centre = 0; centre < ShearCentres; centre++) {
                for (int rule = 0; rule < 3; rule++) {
                    ShearArm *arm = &ShearArmTable[at];
                    arm->halfPixel = hp;
                    arm->sign = sign;
                    arm->centre = centre;
                    arm->rule = rule;
                    snprintf(arm->name, sizeof arm->name, "hp%d%s%s:%s", hp, sign ? "+t" : "-t",
                             centreNames[centre],
                             rule == ShearRuleRoundCarry ? "round"
                                 : rule == ShearRuleTruncate ? "trunc" : "ceil-1");
                    at++;
                }
            }
        }
    }
    for (int a = 0; a < ShearArms; a++) {
        if (strcmp(ShearArmTable[a].name, "hp1+tfardis64:trunc") == 0)
            ShearArmPortVertical = a;
        if (strcmp(ShearArmTable[a].name, "hp1+tnear64:round") == 0)
            ShearArmPortHorizontal = a;
    }
}

static int ShearArmPort(int horizontal)
{
    ShearArmTableBuild();
    return horizontal ? ShearArmPortHorizontal : ShearArmPortVertical;
}

static void ShearArmPair(const RevenantResampleFilter *filter, int index, int horizontal, double translate,
                         vImagePixelCount dstAlong, vImagePixelCount along, ShearPair *out)
{
    const ShearArm *arm = &ShearArmTable[index];
    double delta = horizontal ? -translate : translate;
    double recip = filter->reciprocal;
    double a = (double)dstAlong;
    double position = (double)along + (arm->halfPixel ? 0.5 : 0.0) + (double)arm->sign * delta;
    double mapped;
    switch (arm->centre) {
    case ShearCentreNear64:
        mapped = position * recip - 0.5;
        break;
    case ShearCentreFarFactored64:
        mapped = a + (position - a) * recip - 0.5;
        break;
    case ShearCentreFarDistributed64:
        mapped = position * recip + a * (1.0 - recip) - 0.5;
        break;
    case ShearCentreFarFactored32: {
        float fr = (float)recip, fa = (float)a, fp = (float)position;
        float fv = arm->centre == ShearCentreFarFactored32
            ? fa + (fp - fa) * fr - 0.5f
            : fp * fr + fa * (1.0f - fr) - 0.5f;
        mapped = (double)fv;
        break;
    }
    case ShearCentreFarDistributed32: {
        float fr = (float)recip, fa = (float)a, fp = (float)position;
        mapped = (double)(fp * fr + fa * (1.0f - fr) - 0.5f);
        break;
    }
    case ShearCentreFarFactoredAnchor32: {
        float anchor = (float)(a * (1.0 - (double)(float)recip));
        mapped = a + (position - a) * recip - 0.5 + ((double)anchor - a * (1.0 - recip));
        break;
    }
    default: {
        float anchor = (float)(a * (1.0 - (double)(float)recip));
        mapped = position * recip + (double)anchor - 0.5;
        break;
    }
    }
    double whole = floor(mapped);
    double fraction = mapped - whole;
    long base = (long)whole;
    if (arm->rule == ShearRuleRoundCarry) {
        long q = (long)floor(fraction * (double)filter->phases + 0.5);
        long carry = q / (long)filter->phases;
        out->phase = (unsigned)(q - carry * (long)filter->phases);
        out->base = base + carry;
    } else if (arm->rule == ShearRuleTruncate) {
        out->phase = (unsigned)(long)floor(fraction * (double)filter->phases);
        out->base = base;
    } else {
        long q = (long)ceil(fraction * (double)filter->phases) - 1;
        if (q < 0)
            q = 0;
        out->phase = (unsigned)q;
        out->base = base;
    }
}

static void ShearHeader(const ShearRun *run, float scale)
{
    long worst = 0;
    for (unsigned p = 0; p < run->ours.phases; p++) {
        long sum = 0;
        for (unsigned k = 0; k < run->ours.width; k++)
            sum += run->ours.row[(size_t)p * run->ours.width + k];
        long delta = sum - 16384;
        if (delta < 0)
            delta = -delta;
        if (delta > worst)
            worst = delta;
    }
    printf("filter at a scale of %g: reciprocal %.17g taps %u width %u phases %u centre %u offset %u\n",
           (double)scale, run->ours.reciprocal, run->ours.taps, run->ours.width, run->ours.phases,
           run->ours.centre, run->ours.offset);
    printf("filter at a scale of %g: widest |row sum - 16384| over every row is %ld\n", (double)scale, worst);
}

int main(void)
{
    static ShearRun run;
    unsigned char src8[ShearSrcAlong * ShearSrcCross * 4];
    unsigned char dst8[ShearMaxDst * ShearSrcCross * 4];
    unsigned short src16[ShearSrcAlong * ShearSrcCross * 4];
    unsigned short dst16[ShearMaxDst * ShearSrcCross * 4];

    printf("shearprobe: the port's integer shear engine against the release's own ARGB8888 shear\n");
    printf("shearprobe: source %d along the shear by %d across; channel 0 carries its full value at one"
           " position at a time and every other channel its full value everywhere\n",
           (int)ShearSrcAlong, (int)ShearSrcCross);
    printf("shearprobe: a zero backColor, kvImageNoFlags, slope 0, offsets 0,0; the release's pair is"
           " identified under 16384 and the port's under the row's own sum\n");
    ShearArmTableBuild();
    fflush(stdout);

    unsigned cases = 0, signalled = 0;
    for (unsigned si = 0; si < (unsigned)ShearScaleCount; si++) {
        for (int horizontal = 0; horizontal < 2; horizontal++) {
            for (unsigned ti = 0; ti < (unsigned)ShearTranslateCount; ti++) {
                float scale = ShearScales[si];
                double translate = ShearTranslates[ti];
                fflush(stdout);
                fflush(stderr);
                int fds[2];
                if (pipe(fds) != 0) {
                    printf("shearprobe: pipe failed\n");
                    return 1;
                }
                pid_t pid = fork();
                if (pid < 0) {
                    printf("shearprobe: fork failed\n");
                    return 1;
                }
                if (pid == 0) {
                    close(fds[0]);
                    dup2(fds[1], 1);
                    close(fds[1]);

                    run.src8Data = src8;
                    run.dst8Data = dst8;
                    run.src16Data = src16;
                    run.dst16Data = dst16;
                    run.filter = vImageNewResamplingFilter(scale, kvImageNoFlags);
                    if (!run.filter) {
                        printf("  the release made no filter at a scale of %g\n", (double)scale);
                        fflush(stdout);
                        _exit(0);
                    }
                    if (!RevenantResampleFilterOf(run.filter, &run.ours)) {
                        const char *base = (const char *)run.filter;
                        printf("  the port refused the release's own filter at a scale of %g\n", (double)scale);
                        printf("    object %p, slot %d bytes\n", (void *)run.filter, (int)RevenantResampleSlot);
                        printf("    word 0 reciprocal %g\n", *(double *)(void *)(base + 0 * RevenantResampleSlot));
                        printf("    word 1 taps       %u\n", *(unsigned *)(void *)(base + 1 * RevenantResampleSlot));
                        printf("    word 2 floatStride %u\n", *(unsigned *)(void *)(base + 2 * RevenantResampleSlot));
                        printf("    word 3 int16Stride %u\n", *(unsigned *)(void *)(base + 3 * RevenantResampleSlot));
                        printf("    word 4 phases     %u\n", *(unsigned *)(void *)(base + 4 * RevenantResampleSlot));
                        printf("    word 5 exponent   %u\n", *(unsigned *)(void *)(base + 5 * RevenantResampleSlot));
                        printf("    word 6 offset     %u\n", *(unsigned *)(void *)(base + 6 * RevenantResampleSlot));
                        const char *table = *(const char *const *)(void *)(base + 7 * RevenantResampleSlot);
                        const char *fbase = *(const char *const *)(void *)(base + 8 * RevenantResampleSlot);
                        unsigned i16 = *(unsigned *)(void *)(base + 3 * RevenantResampleSlot);
                        unsigned ph = *(unsigned *)(void *)(base + 4 * RevenantResampleSlot);
                        unsigned off = *(unsigned *)(void *)(base + 6 * RevenantResampleSlot);
                        printf("    word 7 table      %p (inside %ld)\n", (const void *)table,
                               table ? (long)(table - base) : -1L);
                        printf("    word 8 base       %p\n", (const void *)fbase);
                        if (table && ph && i16) {
                            printf("    identity 1 offset == (table - object) + phases*int16Stride:"
                                   " %u against %ld + %u\n", off, (long)(table - base), ph * i16);
                            printf("    identity 2 offset == (table - object) + int16Stride:"
                                   " %u against %ld + %u\n", off, (long)(table - base), i16);
                            printf("    identity 3 table - base == floatStride*(phases+1): %ld against %u\n",
                                   (long)(table - fbase),
                                   *(unsigned *)(void *)(base + 2 * RevenantResampleSlot) * (ph + 1));
                        }
                        printf("    first 40 bytes of the object:");
                        for (int z = 0; z < 40; z++)
                            printf(" %02x", (unsigned char)base[z]);
                        printf("\n");
                        fflush(stdout);
                        _exit(0);
                    }
                    if (ti == 0)
                        ShearHeader(&run, scale);

                    vImagePixelCount dstAlong = ShearSweep(&run, horizontal, scale, translate);

                    unsigned agree = 0, differ = 0, nonunique = 0, nopair = 0, blank = 0;
                    unsigned portFnBad = 0, differBoundary = 0, differOff = 0, agreeBoundary = 0, divisorDiff = 0;
                    unsigned armRelease[ShearArms], armPort[ShearArms], armUnique = 0, armBoth = 0;
                    ShearPair relList[ShearMaxCandidates], portList[ShearMaxCandidates];
                    ShearPair altList[ShearMaxCandidates], portAltList[ShearMaxCandidates];
                    for (int a = 0; a < ShearArms; a++)
                        armRelease[a] = armPort[a] = 0;

                    printf("case %s scale %g translate %g: %u destination samples\n",
                           horizontal ? "horizontal" : "vertical", (double)scale, translate,
                           (unsigned)dstAlong);
                    for (vImagePixelCount along = 0; along < dstAlong; along++) {
                        unsigned nRel = ShearIdentify(&run.ours, run.relObs[along], 255.0, ShearDivisor16384,
                                                     255.0, relList, ShearMaxCandidates);
                        unsigned nRelAlt = ShearIdentify(&run.ours, run.relObs[along], 255.0, ShearDivisorRowSum,
                                                         255.0, altList, ShearMaxCandidates);
                        unsigned nPort = ShearIdentify(&run.ours, run.portObs[along], 65535.0,
                                                       ShearDivisorRowSum, 65535.0, portList,
                                                       ShearMaxCandidates);
                        unsigned nPortAlt = ShearIdentify(&run.ours, run.portObs[along], 65535.0,
                                                          ShearDivisor16384, 65535.0, portAltList,
                                                          ShearMaxCandidates);
                        if (!ShearSameList(relList, nRel, altList, nRelAlt, ShearMaxCandidates) ||
                            !ShearSameList(portList, nPort, portAltList, nPortAlt, ShearMaxCandidates))
                            divisorDiff++;

                        double centre = ShearCentre(&run.ours, horizontal, translate, dstAlong, along);
                        double fraction = centre - floor(centre);
                        double q = fraction * (double)run.ours.phases;
                        int boundary = q == floor(q);
                        ShearPair fn;
                        ShearPortFunction(&run.ours, horizontal, translate, dstAlong, along, &fn);
                        int fnBad = nPort == 1 && !ShearPairEq(&fn, &portList[0]);
                        if (fnBad)
                            portFnBad++;

                        int empty = 1;
                        for (unsigned z = 0; z < (unsigned)ShearSrcAlong; z++)
                            if (run.relObs[along][z] || run.portObs[along][z]) {
                                empty = 0;
                                break;
                            }
                        if (empty)
                            blank++;

                        const char *verdict;
                        if (empty) {
                            verdict = "BLANK";
                        } else if (!nRel || !nPort) {
                            verdict = "NONE";
                            nopair++;
                        } else if (nRel != 1 || nPort != 1) {
                            verdict = "AMBIG";
                            nonunique++;
                        } else if (ShearPairEq(&relList[0], &portList[0])) {
                            verdict = "AGREE";
                            agree++;
                            if (boundary)
                                agreeBoundary++;
                        } else {
                            verdict = "DIFFER";
                            differ++;
                            if (boundary)
                                differBoundary++;
                            else
                                differOff++;
                        }
                        printf("  along %u boundary %d fracPhases %.17g %s", (unsigned)along, boundary, q,
                               verdict);
                        ShearPrintPairs("release", relList, nRel, ShearMaxCandidates);
                        ShearPrintPairs("port", portList, nPort, ShearMaxCandidates);
                        printf(" portfn %u:%ld\n", fn.phase, fn.base);

                        if (verdict[0] == 'D' && verdict[1] == 'I') {
                            double a = (double)dstAlong;
                            double position = (double)along + 0.5 + (horizontal ? -translate : translate);
                            double spellings[3];
                            spellings[0] = position * run.ours.reciprocal - 0.5;
                            spellings[1] = a + (position - a) * run.ours.reciprocal - 0.5;
                            spellings[2] = position * run.ours.reciprocal + a * (1.0 - run.ours.reciprocal) - 0.5;
                            printf("    centres near %.17g farfac %.17g fardis %.17g | frac*phases near %.17g"
                                   " farfac %.17g fardis %.17g | release named phase %ld base %ld\n",
                                   spellings[0], spellings[1], spellings[2],
                                   (spellings[0] - floor(spellings[0])) * (double)run.ours.phases,
                                   (spellings[1] - floor(spellings[1])) * (double)run.ours.phases,
                                   (spellings[2] - floor(spellings[2])) * (double)run.ours.phases,
                                   (long)relList[0].phase, (long)relList[0].base);
                        }

                        if (nRel == 1) {
                            armUnique++;
                            for (int a = 0; a < ShearArms; a++) {
                                ShearPair got;
                                ShearArmPair(&run.ours, a, horizontal, translate, dstAlong, along, &got);
                                if (ShearPairEq(&got, &relList[0]))
                                    armRelease[a]++;
                                if (nPort == 1 && ShearPairEq(&got, &portList[0]))
                                    armPort[a]++;
                            }
                            if (nPort == 1)
                                armBoth++;
                        }
                    }
                    printf("case %s scale %g translate %g: samples %u agree %u differ %u ambig %u none %u"
                           " blank %u; agree on a boundary %u; differ on a boundary %u differ off one %u;"
                           " the port's own function and the port's bytes disagree %u; the two divisors name"
                           " different pairs %u\n",
                           horizontal ? "horizontal" : "vertical", (double)scale, translate,
                           (unsigned)dstAlong, agree, differ, nonunique, nopair, blank, agreeBoundary,
                           differBoundary, differOff, portFnBad, divisorDiff);
                    {
                        int portArm = ShearArmPort(horizontal);
                        int bestRel = 0, bestPort = 0, tieRel = 0, tiePort = 0;
                        for (int a = 1; a < ShearArms; a++) {
                            if (armRelease[a] > armRelease[bestRel]) bestRel = a;
                            if (armPort[a] > armPort[bestPort]) bestPort = a;
                        }
                        for (int a = 0; a < ShearArms; a++) {
                            if (armRelease[a] == armRelease[bestRel]) tieRel++;
                            if (armPort[a] == armPort[bestPort]) tiePort++;
                        }
                        printf("arms: %d of them, scored over %u destination samples the release names"
                               " uniquely; best against the release %s %u (with %d tying); best against the"
                               " port %s %u of %u both-unique (with %d tying); the port's own arm %s scores %u against the port"
                               " and %u against the release; the arms that explain every sample:",
                               (int)ShearArms, armUnique, ShearArmTable[bestRel].name, armRelease[bestRel],
                               tieRel, ShearArmTable[bestPort].name, armPort[bestPort], armBoth, tiePort,
                               portArm >= 0 ? ShearArmTable[portArm].name : "(NOT IN THE TABLE)",
                               portArm >= 0 ? armPort[portArm] : 0u,
                               portArm >= 0 ? armRelease[portArm] : 0u);
                        {
                            int any = 0;
                            for (int a = 0; a < ShearArms; a++) {
                                if (armUnique && armRelease[a] == armUnique) {
                                    printf("%s%s", any ? " " : " ", ShearArmTable[a].name);
                                    any = 1;
                                }
                            }
                            if (!any)
                                printf(" NONE");
                            printf("\n");
                        }
                        if (differ) {
                            for (int a = 0; a < ShearArms; a++)
                                printf("arm %-22s against the release %u/%u, against the port %u/%u\n",
                                       ShearArmTable[a].name, armRelease[a], armUnique, armPort[a], armUnique);
                        }
                    }
                    fflush(stdout);
                    _exit(0);
                }
                close(fds[1]);
                char buf[4096];
                ssize_t got;
                while ((got = read(fds[0], buf, sizeof buf)) > 0)
                    (void)!write(1, buf, (size_t)got);
                close(fds[0]);
                int status = 0;
                waitpid(pid, &status, 0);
                cases++;
                if (WIFSIGNALED(status)) {
                    signalled++;
                    printf("case %s scale %g translate %g: CHILD ENDED ON SIGNAL %d\n",
                           horizontal ? "horizontal" : "vertical", (double)scale, translate, WTERMSIG(status));
                } else if (WEXITSTATUS(status) != 0) {
                    printf("case %s scale %g translate %g: the child exited %d\n",
                           horizontal ? "horizontal" : "vertical", (double)scale, translate, WEXITSTATUS(status));
                }
                fflush(stdout);
            }
        }
    }
    printf("shearprobe: %u cases, %u ended on a signal\n", cases, signalled);
    return 0;
}
