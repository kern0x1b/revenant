// The resampling filter of vImage's shears: **the caller's own object, read**.
//
// `ResamplingFilter` is a `void *`, and behind it on every release a shear row runs on is the RELEASE's own
// object: `vImageNewResamplingFilter` is exported from 5.0 (6.0.tsv), so the caller makes the filter with the
// system constructor and hands it to the shear. The port reads that object rather than making one of its own,
// and this file is the reader.
//
// **Why the port does not generate a table.** The kernel is Lanczos3, or Lanczos5 under
// `kvImageHighQualityResampling`, and its weights are exactly computable - but the release stores them as
// int16 Q14 and *the stored integers are the release's own single-precision `sinf`/`cosf`* (v-tail-a11 read the
// kernel function at 0x30418d48 on the 6.1.3 armv7 cache: `blx sinf`, `blx cosf`, and a `vcvt.s32.f32`
// truncation with no correction pass). There is no formula to reproduce, so a generated table is an
// approximation of the caller's own numbers by construction, and every sheared pixel would carry the
// difference. Reading the caller's object is exact by construction on every release, and it is what the
// release itself does: its worker sums the int16 row it is about to use (`ldrsh` over `numTaps` at
// 0x3040f488 on 6.1.3 armv7).
//
// **The layout is two shapes and the architecture decides which.** Both hold the same nine fields in the
// same order; a field is a 32-bit slot at byte `4k` on armv7/armv7s and a 64-bit slot at byte `8k` on arm64:
//
//   | field        | armv7 | arm64 | what it holds |
//   | --- | --- | --- | --- |
//   | reciprocal   | 0 | 0 | the double `1.0 / scale`, which is what the release multiplies a position by |
//   | numTaps      | 8 | 8 | the tap count, `(int)(2*min(lobes/scale, lobes) + 0.5)` |
//   | floatStride  | 12 | 16 | the float table's row stride, `(15 + 4*numTaps) & ~15` |
//   | int16Stride  | 16 | 24 | the Q14 row's stride in bytes, `(((2 + 2*numTaps) & ~3) + 15) & ~15` |
//   | phases       | 20 | 32 | the phase count, a power of two of at most 64 |
//   | exponent     | 24 | 40 | the phase exponent, `clamp(133 - exponent(float(1/scale)), 0, 6)` |
//   | offset       | 28 | 48 | **the Q14 table's end, as an OFFSET from the object** |
//   | table        | 32 | 56 | **the Q14 table's first byte, as a pointer** |
//   | base         | 36 | 64 | `(object + 55) & ~15` on armv7, `(object + 87) & ~15` on arm64 |
//
// Measured by disassembly of ten writers - 6.1.3, 7.0, 8.0, 9.3.6 and 10.3.4 armv7/armv7s, and 7.0, 7.0.1,
// 10.0.1, 11.0 and 12.0 arm64 - and by execution on an iPhone3,1 6.1.3 10B329 guest for the armv7 shape. **The
// arm64 shape is one shape on all five arm64 releases**: `stp x10, x13, [x0, #56]` on 7.0 stores bytes 56 and
// 64, and the next instruction stores the offset at byte 48, so the table's own pointer is in the object on
// every release read and nothing is computed from another field. An earlier reading of that store pair took
// `#56` for `#48` and claimed 7.0 overwrote the field; `d4ed12b1c` takes that back.
//
// **The offset is an offset on both shapes**, and this is the one that a reader gets wrong: a refusal that
// compares it against a pointer refuses the release's own filter, which is exactly what the first version of
// the 6.1.3 probe did - and that refusal was the measurement that word 7 is an offset. The identity the
// writer computes, and the one the refusal below checks, is
//
//     offset == (table - object) + phases * int16Stride
//
// which holds on all nine guest shapes and all ten host shapes, and which ties the table's pointer to the
// object so a buffer that is not a filter cannot be read as one. **It is not `offset == phases *
// int16Stride`**, which is false on every shape measured - the offset also carries the float table's size -
// and a refusal written that way would refuse every filter the port exists to read.
//
// **What the row is, and the two properties the engine relies on.** A row is `int16Stride/2` int16 Q14
// weights, and the tail past `numTaps` is zero in every row of every shape measured, so summing the row the
// port read is summing the release's own `numTaps` weights. The row's peak is **not at one index**: it sits at
// `K0` for the first half of the phases and at `K0 + 1` for the second, and is TIED at the half phase - which
// is how a table with one index per phase can carry a fractional position at all. `K0` is therefore the lowest
// index attaining **row 0's** maximum, and the engine uses that one index for every phase; it agrees with
// `(numTaps - 2)/2` on all nineteen shapes measured and is READ rather than recomputed, so a filter whose
// rows are shaped the other way round still reads correctly.
//
// **The divisor is the row's own sum.** On macOS every row sums to exactly 16384 and dividing by 16384 is
// indistinguishable; on 6.1.3 the sums are within 5 of it and 15 of the sixteen rows at a scale of 0.25 are
// not equal to it, so a constant divisor would be wrong on the release the rows are written for.

#pragma once

#import <Accelerate/Accelerate.h>

enum {
    // A field is a 32-bit slot on armv7 and armv7s and a 64-bit slot on arm64. The compiler's own architecture
    // macros name which, so the port keys the layout on the target and not on a release number it cannot see
    // from here.
    CharonResampleSlot = (int)(sizeof(void *) >= 8 ? 8 : 4),
    // The phase count the release's own writer clamps to, and the bound the sum array below is sized by.
    CharonResampleMaxPhases = 64
};

// **The first field is the DOUBLE and it is TWO slots wide, so field `index` is NOT at `index * slot`.** On
// arm64 the double occupies bytes 0..7 and field `k` is at byte `8 * k`, which is `index * slot` with an 8-byte
// slot. On armv7 the same double occupies bytes 0..7 out of four-byte slots, so field 1 would land at byte 4 -
// inside the double - and the release puts `numTaps` at byte **8**, which is slot **2**. Every field from
// `numTaps` on was therefore read one word early on every armv7 release: `taps` came back as the double's own
// mantissa (`1072693248`, which is `0x3FF00000` - the low word of `1.0`), the table pointer came back as the
// offset, and the reader refused the caller's filter, so every shear answered `kvImageInvalidParameter`.
//
// Measured on iPhone3,1 6.1.3 10B329, the release's own object, forty bytes, and `taps` is the `06` at byte 8:
//
//     00 00 00 00 00 00 f0 3f   byte 0   the double 1.0
//     06 00 00 00               byte 8   numTaps 6
//     20 00 00 00               byte 12  floatStride 32
//     10 00 00 00               byte 16  int16Stride 16
//     40 00 00 00               byte 20  phases 64
//     06 00 00 00               byte 24  the exponent 6
//     50 0c 00 00               byte 28  the offset 3152
//     50 44 90 10               byte 32  the Q14 table
//     30 3c 90 10               byte 36  the float table's base
//
// and with these offsets every identity below holds on it: `offset == (table - object) + phases*int16Stride`
// is `3152 == 2128 + 64*16`, and `table - base == floatStride*(phases+1)` is `2080 == 32*65`.
//
// Nothing here changes arm64, where `8 + 8*(k-1)` is `8*k` - the same address it always was. It is invisible on
// this Mac, where every filter the host differential reads is an arm64 one, and it was invisible in 11916 host
// checks for that reason.
#define CHARON_RESAMPLE_OFFSET(index) \
    ((index) == 0 ? (size_t)0 : (size_t)8 + (size_t)(CharonResampleSlot) * (size_t)((index) - 1))

// Field `index` of the object, as the width that architecture gives it.
#define CHARON_RESAMPLE_SLOT(object, index, type) \
    (*(type *)(void *)((const char *)(object) + CHARON_RESAMPLE_OFFSET(index)))

// The filter, as the engine wants it: the release's table, described. `reciprocal` is the release's own double
// and the engine multiplies positions by it, because that is what the release's worker does with the value it
// kept beside `floor` of it; `scale` is the same number divided back, for anything that wants the scale itself.
typedef struct CharonResampleFilter {
    double reciprocal;
    double scale;
    const int16_t *row;
    unsigned width;              // int16Stride / 2, the Q14 row's own width in int16
    unsigned phases;
    unsigned exponent;           // the filter's own field 5: log2(phases) on every shape measured
    unsigned taps;               // numTaps
    unsigned centre;             // K0: the lowest index attaining row 0's maximum
    unsigned offset;             // the Q14 table's end, as an offset from the object
} CharonResampleFilter;

// Reading the caller's object, and refusing everything that is not one. Returns 1 and fills `out` when the
// object is a resampling filter of a shape measured, and 0 with `out` zeroed otherwise; the caller turns the
// 0 into `kvImageInvalidParameter`, which is what the host answers for a NULL filter.
//
// The six refusals, each of which is a field the writer computed and not a value this file invented:
//
//   1. `reciprocal > 0` - the release's writer divides 1.0 by the scale and stores the result, so a filter
//      that has one is a filter whose scale is finite.
//   2. `numTaps >= 1`.
//   3. `int16Stride >= 2` and even, so a row is at least one int16 and is addressable by `int16_t *`.
//   4. `phases` a power of two of at most 64 - the writer's own `1 << clamp(133 - exponent, 0, 6)`.
//   5. the table strictly inside `[object, object + offset)`: it starts inside the object and ends at or
//      before the offset, which is the bound the release itself uses. **`vImageGetResamplingFilterSize` is not
//      that bound and must not be used as one**: it answers two runs of the same binary two different numbers
//      (3168 and 3160 for one shape), because the size is computed on the caller's stack where `((sp+55)&~15)
//      - sp` is 16 or 8 by that frame's alignment, while the stored offset is not.
//   6. `offset == (table - object) + phases * int16Stride`, the writer's own arithmetic. This is the check that
//      refuses a buffer that is not a filter, and it is checked as an offset on both shapes.
//
// **There is deliberately no check on the row's sum.** The release's own rows sum to `16384 +- 5` on 6.1.3 and
// to exactly 16384 on macOS, so a refusal built on the sum refuses the filter this port exists to read - the
// defect v-tail-a11 measured when its first probe did exactly that.
static inline int CharonResampleFilterOf(ResamplingFilter filter, CharonResampleFilter *out)
{
    out->reciprocal = 0.0;
    out->scale = 0.0;
    out->row = 0;
    out->width = 0;
    out->phases = 0;
    out->exponent = 0;
    out->taps = 0;
    out->centre = 0;
    out->offset = 0;
    if (!filter || !out)
        return 0;

    double reciprocal = CHARON_RESAMPLE_SLOT(filter, 0, double);
    unsigned taps = CHARON_RESAMPLE_SLOT(filter, 1, unsigned);
    unsigned floatStride = CHARON_RESAMPLE_SLOT(filter, 2, unsigned);
    unsigned int16Stride = CHARON_RESAMPLE_SLOT(filter, 3, unsigned);
    unsigned phases = CHARON_RESAMPLE_SLOT(filter, 4, unsigned);
    unsigned exponent = CHARON_RESAMPLE_SLOT(filter, 5, unsigned);
    unsigned offset = CHARON_RESAMPLE_SLOT(filter, 6, unsigned);
    const char *table = (const char *)CHARON_RESAMPLE_SLOT(filter, 7, const char *);

    if (!(reciprocal > 0.0) || taps < 1 || int16Stride < 2 || (int16Stride & 1))
        return 0;
    if (phases == 0 || phases > (unsigned)CharonResampleMaxPhases || (phases & (phases - 1)) != 0)
        return 0;
    // The offset is an OFFSET: `table - object` is what the writer subtracted, and comparing the field against
    // a pointer instead is what refused all nine guest shapes in the first version of this reader.
    if (!table || table <= (const char *)filter)
        return 0;
    size_t inside = (size_t)(table - (const char *)filter);
    if (inside >= (size_t)offset)
        return 0;
    if (inside + (size_t)phases * (size_t)int16Stride > (size_t)offset)
        return 0;
    if ((size_t)offset != inside + (size_t)phases * (size_t)int16Stride)
        return 0;
    // The float table sits between the base and the Q14 table and is `phases + 1` rows of it, which is the
    // writer's own last `madd`. Checked because it is free and it is the one arithmetic that ties the table's
    // pointer to the header's own numbers rather than only to its own offset.
    const char *base = CHARON_RESAMPLE_SLOT(filter, 8, const char *);
    if (!base || base > table)
        return 0;
    size_t fromBase = (size_t)(table - base);
    if (fromBase != (size_t)floatStride * (size_t)(phases + 1))
        return 0;

    const int16_t *row = (const int16_t *)table;
    unsigned width = int16Stride / 2;
    int best = -(1 << 30);
    unsigned centre = 0;
    for (unsigned k = 0; k < width; k++) {
        int value = row[k];
        if (value > best) {
            best = value;
            centre = k;
        }
    }

    out->reciprocal = reciprocal;
    out->scale = 1.0 / reciprocal;
    out->row = row;
    out->width = width;
    out->phases = phases;
    out->exponent = exponent;
    out->taps = taps;
    out->centre = centre;
    out->offset = offset;
    return 1;
}

// **The release carries the position as a Q32 FIXED-POINT ACCUMULATOR and advances it by an integer, so this
// takes the accumulator and not a `double` centre.** Read instruction by instruction on 6.1.3 armv7 and on
// 7.0 arm64 (facts/Accelerate/vImageGeometry.md, "The release's own position arithmetic" and "The two open
// terms closed"), and scored on the 6.1.3 guest against 1210 of 1210 named destination samples at five
// scales, both axes and seven translates:
//
//     phase = ((A & 0xffffffff) >> (32 - exponent)) & (phases - 1)
//     base  = (A >> 32) + K0
//
// Three things in that are not what a `double` centre would give, and each is the release's:
//
// * **the phase is a TRUNCATION of `frac(centre)*phases`, with no rounding and no carry.** There is no tie
//   to settle anywhere: the top `exponent` bits of the fraction are the row, and a position a hair below a
//   phase boundary reads the row below whatever the rounding would have said. At a scale of 0.75 the stored
//   reciprocal is `1.3333333333333333`, so `S mod 2^32` is `0x55555555` - a third of a pixel short of `1/3` -
//   and the phase cycles 21, 42, 63 with a `+-1/192` wobble, which no rounding rule produces.
// * **the base is the accumulator's own integer part, which is the source index of the row's FIRST tap**, so
//   the port's centre tap is `K0` above it. `K0 = (numTaps - 2)/2` on every shape measured and it is READ
//   (the lowest index attaining row 0's maximum) rather than recomputed.
// * **the two axes are the same arithmetic.** The horizontal does not round to nearest with a carry and the
//   vertical does not truncate: both truncate, and what the two axes differ on is the START (see
//   CharonShear.h), not the phase.
//
// `exponent` is the filter's own field, read at byte 24 on armv7 and byte 40 on arm64, and it is `log2(phases)`
// on every shape measured. **A filter's own writer clamps it to `0..6`, and `exponent == 0` is reachable -
// `phases == 1` - where the release's own `lsr.w` by 32 leaves the phase at 0**, which is what the guard
// below answers rather than a shift by 32 that is undefined.
//
// The caller's region offset is NOT added here: the release adds it where it forms the row's base address,
// and the caller adds it to the centre this returns (CharonShear.h).
static inline void CharonResamplePhase(const CharonResampleFilter *filter, long long position,
                                       unsigned *phase, long *base)
{
    unsigned bits = filter->exponent;
    unsigned value = (bits >= 1u && bits <= 31u)
        ? (unsigned)(((unsigned long long)position & 0xffffffffULL) >> (32u - bits))
        : 0u;
    *phase = value & (filter->phases - 1u);
    *base = (long)(position >> 32) + (long)filter->centre;
}

// **The release's Q32 conversion: `(int64_t)(x * 2^32)`, whose C cast truncates toward zero** - and `x` here
// is ALREADY the scaled double, because that is the shape of the release's own code: it multiplies by `2^32`
// in a `vmul.f64` (0x30413e2e) or an `fmul` (0x1804a59ac) and hands the PRODUCT to the conversion. A caller
// that has the start in source pixels multiplies it by 4294967296.0 first; `CharonResampleStep` below does
// exactly that for the step.
//
// This is the one term four bands could not settle from the mapping alone, and it is settled here from the
// release's own bytes rather than from an arrangement: the stub both armv7 workers call is followed through
// its own pointer word to `0x39263199` in `libcompiler_rt`, and that function shifts the significand RIGHT
// into place and applies the sign with `eor`/`subs`/`sbc` - a two's-complement negate, not a decrement, which
// is truncation. There is no bias added to the significand and no test-and-subtract after the call, so there
// is no floor anywhere. The 7.0 arm64 worker says it in one instruction of its own, `fcvtzs`, which the
// architecture defines as rounding toward zero. **This matters, and a floor is not a harmless difference**:
// it decides the sample whose fraction lands exactly on a phase boundary, where the truncation's fraction is
// 0 and the floor's is `0xffffffff`, so the two name phase 0 and phase 63 and bases a whole pixel apart. Five
// of the 6.1.3 guest's own answers are one or the other.
//
// The clamps are the release's own (`vcmpe`/`vmovgt` against `2^63` and `-2^63` around the call, `fcmp`/`fcsel`
// around `fcvtzs` on arm64) and they are here so the cast is defined for every double a caller's filter can
// produce: the saturating end the release reaches converts to `LLONG_MIN`, because its conversion shifts the
// significand until the top bit falls off, and that is the answer spelled rather than the one a cast would
// give by accident.
static inline long long CharonResampleQ32(double scaled)
{
    if (scaled >= 9223372036854775808.0)
        return (-9223372036854775807LL - 1);
    if (!(scaled > -9223372036854775808.0))
        return (-9223372036854775807LL - 1);
    return (long long)scaled;
}

// The step between two destination samples: `(int64_t)(reciprocal * 2^32)`, advanced by an integer add per
// sample (`adds`/`adcs` on armv7 at 0x30414314 and 0x3041431c, one `add` on arm64). The release computes it
// once per call, beside the reciprocal and the saturation, and never recomputes it per sample.
static inline long long CharonResampleStep(const CharonResampleFilter *filter)
{
    return CharonResampleQ32(filter->reciprocal * 4294967296.0);
}

// The row's own sum, which is the divisor. **Not 16384**: on 6.1.3 the rows are within 5 of it and at a scale
// of 0.25 all sixteen rows are not equal to it, while the release's own worker sums the row it is about to
// use. On macOS the sum is exactly 16384 on every row of every shape, which is why the host differential
// cannot tell the two spellings apart and why the device is the oracle for this one.
static inline double CharonResampleRowSum(const CharonResampleFilter *filter, unsigned phase)
{
    const int16_t *row = filter->row + (size_t)phase * filter->width;
    long sum = 0;
    for (unsigned k = 0; k < filter->width; k++)
        sum += row[k];
    return (double)sum;
}