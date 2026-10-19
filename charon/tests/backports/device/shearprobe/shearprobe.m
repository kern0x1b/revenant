// The port's integer shear engine against the 6.1.3 release's own ARGB8888 shear, over one filter the
// RELEASE made, naming the `(phase, base)` pair each destination sample reads from BOTH engines' bytes. The
// prediction this run answers is tests/backports/device/shearprobe/PREDICTION.md, written before it and not
// edited after; the summary this prints is the deliverable.
//
// WHY PAIRS AND NOT BYTES: 6.1.3 exports `vImageVerticalShear_ARGB8888` and no 16-bit shear at all (the
// sixteen-bit forms arrive at 7.0), so the two engines cannot be handed the same pixel type. The release
// stores `round(sum/divisor)` in the input's own 0..255 units and the port stores `round(sum/rowsum*65535)` in
// 0..65535, and there is no exact relation between those two stored numbers for one convolution. What IS
// comparable, and is the whole of the mapping, is which row of the release's own Q14 table and which source
// pixel each destination sample reads.
//
// HOW A PAIR IS READ OFF ONE ENGINE'S BYTES, with no model of the engine:
//   * the source's channel 0 carries its full value at exactly ONE position along the shear and zero at every
//     other position; every other channel carries its full value everywhere, so the alpha sits at its full
//     value on the path the 8-bit shear takes and nothing else is disturbed;
//   * the backColor is zero, so a tap outside the picture contributes zero rather than a colour;
//   * one shear call then answers, at every destination sample, `store(row[p][j] * max / divisor)` and
//     nothing else, because the only tap with a non-zero argument is the one over the delta and every other
//     weight multiplies a zero. The whole accumulator is therefore ONE tap, and the observed byte names one
//     weight of one row;
//   * repeating that for every position along the axis gives, for each destination sample, the chosen row's
//     own weight profile shifted to where the engine put it. Every `(phase, base)` whose profile reproduces
//     ALL of the observed bytes is a candidate, and how many there are is reported rather than resolved: a
//     negative lobe stores as zero in eight bits and a weight of zero stores as zero too, so some
//     destination samples are genuinely ambiguous and picking one of the candidates would be a guess.
//
// The model in `ShearPredict` is the release's own Q14 integers, either 16384 or the row's own sum as the
// divisor, and the release's measured round-half-up into the stored type. It is v-tail-a12's model, which
// reproduced this device's own bytes 768 of 768 at a scale of one, 1344 of 1344 at two and 480 of 480 at a
// half, and this run identifies under BOTH divisors so the choice is visible rather than assumed.
//
// The port's pair is named TWO ways and both are printed: from the port's bytes by this instrument, and from
// the port's own `CharonResamplePhase` fed the mapping `CharonShearRun` spells. The summary counts the
// destinations where those two disagree, so an instrument that is wrong says so on its own face.
//
// ONE CASE PER PROCESS, through a pipe: on this guest a forked child's writes to standard output do not reach
// the runner's capture (v-crutch6 measured it - twelve children each printed one line and not one line
// arrived), so every case is a forked child whose lines come back through a pipe and are printed by the
// parent, whose own output does arrive. A child that ends on a signal is reported with `WTERMSIG`, never with
// `WEXITSTATUS` alone.

#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/wait.h>
#include <unistd.h>

#include <Accelerate/Accelerate.h>

#include "CharonResampling.h"
#include "CharonShear.h"

// The source is 24 along the shear and 9 across it, and the destination is the same 9 across and
// `ceil(scale*24) + 8` along - sized FOR the scale, because a magnification into a destination the size of the
// source asks the release to compress, which is a different call (v-tail-a11 measured that shape, and the
// reading it drew was wrong).
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

// **The arrays are sized by the MAXIMUM the loops allow and initialised with fewer, so the loops run over the
// COUNT and not over `sizeof`.** The first version looped over `sizeof ShearScales / sizeof *ShearScales`,
// which is the array's declared size: three zero scales and one zero translate were measured as if they were
// cases, which is why the first guest run reported 128 cases where there are 70. A scale of zero is refused by
// the release's own writer, so those cases printed the refusal and no measurement - harmless here, but a
// count in a report that does not match the enumeration is exactly the kind of thing a reader cannot check.
static const float ShearScales[ShearMaxScales] = { 1.0f, 2.0f, 0.5f, 0.75f, 0.25f };
enum { ShearScaleCount = 5, ShearTranslateCount = 7 };
static const double ShearTranslates[ShearMaxTranslates] = { 0.0, 1.0, -1.0, 0.5, -0.5, 2.5, 0.0078125 };

typedef struct ShearPair {
    unsigned phase;
    long base;
} ShearPair;

typedef struct ShearRun {
    ResamplingFilter filter;          // the release's own object, made by the release's own writer
    CharonResampleFilter ours;        // the port's reading of it
    vImage_Buffer src8, dst8;         // the release's side: ARGB8888, channel 0 is the first byte
    vImage_Buffer src16, dst16;       // the port's side: ARGB16U, channel 0 is the first uint16
    unsigned char *src8Data, *dst8Data;
    unsigned short *src16Data, *dst16Data;
    unsigned short relObs[ShearMaxDst][ShearSrcAlong];
    unsigned short portObs[ShearMaxDst][ShearSrcAlong];
} ShearRun;

// The store, as both engines do it: saturate into the stored type FIRST, then round half up toward plus
// infinity (CharonShear.h's `CharonSaturate` and `CHARON_ROUND_HALF_UP`, both measured).
static double ShearStore(double value, double max)
{
    if (value < 0.0)
        value = 0.0;
    if (value > max)
        value = max;
    return floor(value + 0.5);
}

// One tap's contribution to one destination sample, as a stored value. `first` is the source position of the
// row's index 0 and `j` the index the observed delta position falls on. A `j` outside the row is a tap that
// does not exist and an `at` outside the picture is a tap that reads the zero backColor: both answer zero, and
// neither is the delta's position, so both are zero here for the same reason they are zero in the engines.
static double ShearPredict(const CharonResampleFilter *filter, unsigned phase, long first, long c,
                           double amplitude, int divisorMode, double max)
{
    long j = c - first;
    if (j < 0 || j >= (long)filter->width)
        return 0.0;
    long at = first + j;
    if (at < 0 || at >= (long)ShearSrcAlong)
        return 0.0;
    double divisor = divisorMode == ShearDivisorRowSum
        ? CharonResampleRowSum(filter, phase)
        : 16384.0;
    return ShearStore((double)filter->row[(size_t)phase * filter->width + (size_t)j] * amplitude / divisor, max);
}

// Every `(phase, base)` whose profile reproduces every observed byte of one destination sample. `count` comes
// back as the TOTAL number found even when `list` stops filling, so a destination sample that thirty rows
// explain says thirty rather than six.
static unsigned ShearIdentify(const CharonResampleFilter *filter, const unsigned short *observed,
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

// Two candidate lists are the same answer when they name the same number of pairs and the same pairs in the
// same order, which is what the enumeration produces: it walks phases and bases in order.
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

// The port's accumulator at one destination sample: the start `CharonShearRun` forms, in the release's own
// order, converted to Q32, advanced by the release's step. The slope is zero throughout this run, so the
// horizontal's per-row term is the same on every row and only the translate and the scale are left.
static long long ShearAccumulator(const CharonResampleFilter *filter, int horizontal, double translate,
                                  vImagePixelCount dstAlong, vImagePixelCount along)
{
    long long position = 0;
    if (horizontal) {
        double scaled = 0.0 - filter->reciprocal * translate;
        scaled = scaled + (double)filter->taps * -0.5;
        position = CharonResampleQ32((scaled + 1.0) * 4294967296.0);
    } else {
        double oneMinusReciprocal = 1.0 - filter->reciprocal;
        double scaled = (double)dstAlong * oneMinusReciprocal;
        scaled = scaled + filter->reciprocal * translate;
        scaled = scaled + (double)filter->taps * -0.5;
        position = CharonResampleQ32((scaled + 1.0) * 4294967296.0);
    }
    return position + (long long)along * CharonResampleStep(filter);
}

// The port's own pair for one destination sample: the port's own phase function fed the mapping
// `CharonShearRun` spells in its own header, which is the Q32 accumulator the release computes. This is a
// TRANSCRIPTION and the port's own bytes check it - the summary counts the destinations where the two
// disagree.
static void ShearPortFunction(const CharonResampleFilter *filter, int horizontal, double translate,
                              vImagePixelCount dstAlong, vImagePixelCount along, ShearPair *out)
{
    long base = 0;
    unsigned phase = 0;
    CharonResamplePhase(filter, ShearAccumulator(filter, horizontal, translate, dstAlong, along),
                        &phase, &base);
    out->phase = phase;
    out->base = base;
}

// The port's mapped centre for one destination sample, which is what the boundary test below is stated on.
// **It is the accumulator's own number, `(A >> 32) + (A & 0xffffffff)/2^32`, and not a double the engine ever
// evaluates** - the engine reads a row at the top `exponent` bits of that fraction and at nothing finer, so
// this is the finest position the engine has. `frac * phases` is a whole number here exactly where the
// Q32 conversion's own rounding decides the row, which is the sample the two spellings of that conversion
// disagree on.
static double ShearCentre(const CharonResampleFilter *filter, int horizontal, double translate,
                          vImagePixelCount dstAlong, vImagePixelCount along)
{
    long long position = ShearAccumulator(filter, horizontal, translate, dstAlong, along);
    return (double)(position >> 32) + (double)(position & 0xffffffff) * (1.0 / 4294967296.0);
}

// Fill the source so channel 0 carries its full value at `c` and zero at every other position along the shear,
// and every other channel carries its full value everywhere.
//
// **Every offset into the port's own buffer is a BYTE offset added to a `unsigned char *`, and the cast to
// `unsigned short *` comes after the addition, never before it.** That is what the port does with its own
// `CHARON_SHEAR_AT`, and getting it wrong is what the first version of this file did: it added the byte offset
// straight to a `unsigned short *`, so the port's side was written and read at twice the offset - the source's
// row 6 landed where row 12 was read from, and past the end of the buffer at that. The tell was that the two
// sides' buffers have different element sizes, the release's side was right, and the port's observations came
// back all zero with 265 candidate pairs per destination sample where the release's side named one. Casting
// the RESULT rather than the base is the same mistake with a cast on the end of it.
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

// One delta sweep of both engines over the same filter, keeping channel 0 of every destination sample.
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
        vImage_Error ready = CharonShearReady(&run->src16, &run->dst16, &run->ours, horizontal, 0, 0);
        if (ready != kvImageNoError) {
            printf("  delta %u: the port refused the shape with %d\n", (unsigned)c, (int)ready);
            continue;
        }
        vImage_Error ours = CharonShearRun(&run->src16, &run->dst16, &run->ours, CharonARGB16U, horizontal,
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

// ---------------------------------------------------------------------------------------------------
// The arms: every combination of the four measured terms of the mapping, scored against each side's OWN
// identified pair. This is what settles the question the byte-level ladder could not.
//
// v-tail-a14's `FORMS` ladder scored twelve spellings of the centre and four of them tied at 524 host
// mismatches, and its own report then says all twelve arms computed the same thing - the ladder subtracted
// the half pixel twice. A ladder that cannot tell its own arms apart cannot choose between them, and the
// search stayed open. This one cannot make that mistake: each arm is a separate function of the centre, it is
// checked against a pair read out of the ENGINE'S OWN BYTES rather than out of a model, and the arm the port
// implements is one of the twenty-four and is scored like every other. If the port's arm does not score best
// against the port's own bytes, this file says so on its face.
//
// The four terms, and where each of them was measured (facts/Accelerate/vImageGeometry.md):
//   * the half pixel on the position: present, and it is in the scale's bracket (v-tail-a13);
//   * the translate's sign: inside the bracket, SUBTRACTING on the horizontal and ADDING on the vertical,
//     measured on the host at five scales and on the 6.1.3 guest at one;
//   * the centre's arrangement: NEAR anchored (`position*recip - 0.5`), FAR FACTORED
//     (`A + (position - A)*recip - 0.5`) or FAR DISTRIBUTED (`position*recip + A*(1-recip) - 0.5`). The last
//     two are the same expression and differ by about an ulp, which at an inexact reciprocal is the difference
//     between a centre of 32/64 and one an ulp below it - and the vertical TRUNCATES, so that ulp is a phase;
//   * the phase's rule: ROUND TO NEAREST with the carry that wraps the phase and advances the base, or
//     TRUNCATE with no carry. Measured to be different per axis on the host.
// The arms are ENUMERATED by nested loops, not packed into the bits of an index. The first version packed them
// - half pixel bit 0, sign bit 1, centre bits 2-3, rule bit 4 - and walked twenty-four indices, and the port's
// own arm packs to 27, which no loop of twenty-four reaches: every arm scored a few per cent against the
// PORT'S OWN BYTES, which the port's own `portfn` column reproduces exactly. Two index bugs are in this file's
// record for that reason and both were found the same way, by the instrument scoring its own subject badly.
//
// FOUR terms, and the third and the fourth are this file's own findings rather than inherited ones:
//
//   * the half pixel on the position: present, and it is in the scale's bracket (v-tail-a13);
//   * the translate's sign: inside the bracket, SUBTRACTING on the horizontal and ADDING on the vertical
//     (measured on the host at five scales and on the 6.1.3 guest at one);
//   * the centre's arrangement, SEVEN spellings. NEAR anchored (`position*recip - 0.5`). FAR FACTORED and FAR
//     DISTRIBUTED in double (`A + (position - A)*recip - 0.5` and `position*recip + A*(1 - recip) - 0.5`),
//     which are the same expression and differ by an ulp. The same two with EVERY operation in single
//     precision. And the same two with the POSITION'S PRODUCT in double and the far-edge ANCHOR rounded to
//     single precision - which is the arm that fits, and it is in the table because the release's own bytes put
//     it there: on this Mac's vImage at a scale of 0.75 on the vertical, destination rows 6, 9, 12, 15, 18, 21
//     and 24 all sit on `frac*phases = 32`, and in double that is exactly 32 at rows 18, 21 and 24 - so a
//     double centre cannot produce the row the release names there - while an anchor rounded to float lands
//     those rows at 31.999918619791515 and rows 6 to 15 at 31.999918619791629. At scales 1, 2, 0.5 and 0.25
//     the reciprocal is a power of two, the anchor is exact in float, and every arm collapses onto the same
//     answer, which is why four of the five scales could never have found this;
//   * the phase's rule: ROUND TO NEAREST with the carry that wraps the phase and advances the base; TRUNCATE
//     with no carry; or CEIL-MINUS-ONE, the largest integer strictly below `frac*phases`, floored at zero.
//     The third is in the table and is REFUTED by this run - see the report - because it fires at a scale of
//     0.5, where `frac*phases` is exactly 16 and the release names row 16.
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
    // **The port's own two arms are FOUND BY NAME, not written down as indices.** An index here would be the
    // same class of bug as the packing above: it would keep pointing at the wrong arm if the enumeration's
    // order changed, and nothing in the table would notice. A name that is not in the table leaves both at -1
    // and the per-case line says so, which is the failure a reader can see.
    for (int a = 0; a < ShearArms; a++) {
        // `+t` is right on BOTH axes here, and that reads wrong until the sign convention above is read: `delta`
        // is the axis's OWN measured direction (subtracting on the horizontal, adding on the vertical) and the
        // arm's sign bit is applied to it. So `hp1+t` on the horizontal is `along + 0.5 - translate`, which is
        // what CharonShearRun computes, and `hp1+t` on the vertical is `along + 0.5 + translate`, which is also
        // what it computes. The first version of this lookup spelled both with `-t` and scored the port's own
        // arm at zero against the port's own bytes, which is the instrument's self-check failing on itself.
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

static void ShearArmPair(const CharonResampleFilter *filter, int index, int horizontal, double translate,
                         vImagePixelCount dstAlong, vImagePixelCount along, ShearPair *out)
{
    const ShearArm *arm = &ShearArmTable[index];
    // The translate's own direction is measured per axis, so the sign is applied as the measurement states:
    // subtracting on the horizontal and adding on the vertical, and the two arms here are that and its mirror.
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
        // Every operation in single precision, the reciprocal included.
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
        // The position's product in double; the far-edge ANCHOR rounded to single precision.
        //
        // NOT the arm the release uses. v-tail-a17 read the release's own arithmetic out of its instructions
        // and it is a Q32 accumulator, which no arm in this table has: the table is twenty-four arrangements
        // of a `double` centre and the release evaluates the position once per row and then adds an integer
        // per sample. The arm is kept because it scored best here against the HOST, which is how the
        // arrangement below was arrived at and then refuted. What it looked like it could be, at a scale of
        // 0.75 on the vertical, is that destination row 18 has an exactly-half centre in every other
        // spelling, so no rule consistent with a scale of 0.5 can reach the row the host names.
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
    static ShearRun run;   // a few kilobytes, which is what fork wants
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
                    // The release's OWN writer, through the SDK's own spelling: `ResamplingFilter` is a
                    // `void *` on iOS and on this Mac alike (vImage_Types.h:378), and the object it hands
                    // back carries the header CharonResampling.h reads - the host's own filter has the same
                    // shape as the 6.1.3 one's, ten shapes and nineteen of nineteen (checkheader.py).
                    run.filter = vImageNewResamplingFilter(scale, kvImageNoFlags);
                    if (!run.filter) {
                        printf("  the release made no filter at a scale of %g\n", (double)scale);
                        fflush(stdout);
                        _exit(0);
                    }
                    if (!CharonResampleFilterOf(run.filter, &run.ours)) {
                        // A refusal with no numbers is not a measurement, so every field the reader reads and
                        // both sides of every identity it checks are printed. The reader is
                        // CharonResampling.h's, unchanged; this only says WHICH of its six checks failed and
                        // on what, on the release's own object.
                        const char *base = (const char *)run.filter;
                        printf("  the port refused the release's own filter at a scale of %g\n", (double)scale);
                        printf("    object %p, slot %d bytes\n", (void *)run.filter, (int)CharonResampleSlot);
                        printf("    word 0 reciprocal %g\n", *(double *)(void *)(base + 0 * CharonResampleSlot));
                        printf("    word 1 taps       %u\n", *(unsigned *)(void *)(base + 1 * CharonResampleSlot));
                        printf("    word 2 floatStride %u\n", *(unsigned *)(void *)(base + 2 * CharonResampleSlot));
                        printf("    word 3 int16Stride %u\n", *(unsigned *)(void *)(base + 3 * CharonResampleSlot));
                        printf("    word 4 phases     %u\n", *(unsigned *)(void *)(base + 4 * CharonResampleSlot));
                        printf("    word 5 exponent   %u\n", *(unsigned *)(void *)(base + 5 * CharonResampleSlot));
                        printf("    word 6 offset     %u\n", *(unsigned *)(void *)(base + 6 * CharonResampleSlot));
                        const char *table = *(const char *const *)(void *)(base + 7 * CharonResampleSlot);
                        const char *fbase = *(const char *const *)(void *)(base + 8 * CharonResampleSlot);
                        unsigned i16 = *(unsigned *)(void *)(base + 3 * CharonResampleSlot);
                        unsigned ph = *(unsigned *)(void *)(base + 4 * CharonResampleSlot);
                        unsigned off = *(unsigned *)(void *)(base + 6 * CharonResampleSlot);
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
                                   *(unsigned *)(void *)(base + 2 * CharonResampleSlot) * (ph + 1));
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

                        // A destination sample whose every observed byte is zero on BOTH sides carries no
                        // information: the source cannot fill it, so no pair can be read out of it. It is
                        // counted as BLANK and says so, rather than being reported as an ambiguity.
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

                        // Where the two engines name DIFFERENT pairs, the three arrangements of the centre are
                        // printed at full precision: they are the same expression and differ by an ulp, and at
                        // an inexact reciprocal an ulp of the centre is a whole phase because the vertical
                        // TRUNCATES. Which one the release wants is the measurement, and the port's own
                        // arrangement is one of the three.
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

                        // The arm table, scored only where the RELEASE's own pair is unique - a pair the
                        // release's bytes do not name cannot be scored against anything.
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
                    // The arms, scored over the `armUnique` destination samples where the release's own bytes
                    // name exactly one pair. The port's own arm is one of them, FOUND BY NAME, and is scored
                    // against the port's own bytes the same way - so an arm table that does not put the port's
                    // own arm at the top against the port's own bytes is an instrument failure and shows as
                    // one on this line. The whole table is printed only where the two engines name different
                    // pairs, because that is where the arms separate; everywhere else the best arm and the
                    // port's arm are the same arm and the count is on the line.
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
                        // The arms that explain EVERY sample the release names uniquely are listed by name,
                        // which is the statement the reader needs: an arm is a candidate for the release's
                        // mapping only if it reproduces all of them, and the ones that do are printed even
                        // when there is no disagreement to chase.
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