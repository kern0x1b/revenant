// The shears of vImage: the resampling engine, and the mapping the release's own workers compute.
//
// **The mapping, as the release computes it: one Q32 fixed-point accumulator, started once and advanced by a
// 64-bit integer step.** Read instruction by instruction out of the 6.1.3 armv7 workers and the 7.0 arm64 one
// and scored on the 6.1.3 guest against 1210 of 1210 named destination samples, at five scales, both axes and
// seven translates (facts/Accelerate/vImageGeometry.md, "The release's own position arithmetic" and "The two
// open terms closed"; the reading is the substrate, the count is the check). In the release's own order,
// because its rounding depends on it:
//
//     vertical     start = C*(1 - recip) + recip*t + (taps * -0.5) + 1.0        C = dest->height
//     horizontal   start = (row + 1 - dest->height) * (recip*slope)
//                          - recip*t + (taps * -0.5) + 1.0                     once per destination row
//     step           S   = (int64_t)(recip * 2^32)
//     A(along)        = (int64_t)(start * 2^32) + along*S, truncating, and one accumulator for the whole
//                        destination on the vertical; per row on the horizontal, whose start carries the slope
//     first tap       = (A >> 32) + the caller's offset along the shear
//     phase          = ((A & 0xffffffff) >> (32 - exponent)) & (phases - 1)     CharonResampling.h
//
// **There is NO half pixel in it, on either axis, at any scale.** The `1.0` and the `-0.5*numTaps` are what a
// half pixel does in macOS's arrangement; the `- 0.5` and the `+ 0.5` this file used to carry were that
// arrangement, and they are what four bands of host measurements converged on. **The vertical anchors at the
// destination's FAR edge and the horizontal at its NEAR edge**, which is the mirror the two axes have always
// shown here; `C` and the slope's row term are the two sides of it, and both are the DESTINATION's own
// extents (`vImage_Buffer` is `{data, height, width, rowBytes}`, so a vertical shear's along extent is
// `height` and a horizontal shear's across extent is `height` too).
//
// **Why it is an accumulator and not an expression in the destination coordinate.** Four bands searched
// "arrangements" of `centre = f(x)` and none of them could work, because no arrangement is a function of `x`
// at all: the release evaluates the position once per row and then adds a constant integer per sample. At a
// scale of 0.75 that constant is `4/3` a pixel with a `+-1/192` wobble, because `S mod 2^32` is `0x55555555`
// - `1/3` of a pixel short of a third - and a running fraction read a third short of `1/3` cycles 21, 42, 63.
// The port and the release were eleven sixty-fourths apart at every scale but one, and the eleven was that
// constant: the release's start fraction is `1/3` less a hundred-millionth and the port's was `1/2`.
//
// **The kernel is the caller's own.** The Q14 row, the phase it is read at and the base it is read around all
// come out of the release's filter object (CharonResampling.h), the divisor is that row's own sum, and the
// store rounds half up. Nothing here generates a weight: the release's stored integers are its own
// single-precision `sinf`, and a generated table would differ from the caller's numbers by construction.
//
// **The edging.** A tap outside the picture along the shear is REPLACED BY THE BACKCOLOR with its weight kept,
// not dropped: a source constant at 1.0 with a backColor of -1 makes the answer `2w - 1`. Under
// `kvImageEdgeExtend` the tap is pulled back to the edge instead, which is the header's own "the edge pixels of
// the source are extended". Neither mode renormalises over the survivors, which is what the overshoot at the
// last row is.
//
// **The refusals**, and they are the release's own: a NULL buffer is `kvImageNullPointerArgument`, a filter
// that is not a resampling filter is `kvImageInvalidParameter`, and a region or a destination that does not fit
// across the shear is `kvImageBufferSizeMismatch`. No flag is refused - every one of the thirty-two bits comes
// back `kvImageNoError`.

#pragma once

#import <Accelerate/Accelerate.h>
#include "CharonChannels.h"
#include "CharonResampling.h"
#include "CharonVImageFixed.h"

enum CharonPixelType {
    CharonARGB16U, CharonARGB16S, CharonPlanar16U, CharonPlanar16S, CharonPlanar16F, CharonPlanarF,
    CharonCbCr8, CharonCbCr16U, CharonCbCr16S, CharonCbCr16F, CharonCbCrF, CharonARGB16F, CharonARGBFFFF,
    CharonXRGB2101010W
};

static inline unsigned CharonChannels(enum CharonPixelType type)
{
    switch (type) {
    case CharonARGB16U: case CharonARGB16S: case CharonARGB16F: case CharonARGBFFFF: return 4;
    case CharonCbCr8: case CharonCbCr16U: case CharonCbCr16S: case CharonCbCr16F: case CharonCbCrF: return 2;
    case CharonXRGB2101010W: return 4;
    default: return 1;
    }
}

static inline size_t CharonBytesPerPixel(enum CharonPixelType type)
{
    switch (type) {
    case CharonARGB16U: case CharonARGB16S: case CharonARGB16F: return 8;
    case CharonARGBFFFF: return 16;
    case CharonPlanar16U: case CharonPlanar16S: case CharonPlanar16F: return 2;
    case CharonPlanarF: return 4;
    case CharonCbCr8: return 2;
    case CharonCbCr16U: case CharonCbCr16S: case CharonCbCr16F: return 4;
    case CharonCbCrF: return 8;
    case CharonXRGB2101010W: return 4;
    default: return 1;
    }
}

static inline double CharonChannelAt(const void *row, vImagePixelCount pixel, unsigned channel,
                                     enum CharonPixelType type)
{
    switch (type) {
    case CharonARGB16U: return (double)((const uint16_t *)row)[pixel * 4 + channel];
    case CharonARGB16S: return (double)((const int16_t *)row)[pixel * 4 + channel];
    case CharonPlanar16U: return (double)((const uint16_t *)row)[pixel];
    case CharonPlanar16S: return (double)((const int16_t *)row)[pixel];
    case CharonCbCr8: return (double)((const uint8_t *)row)[pixel * 2 + channel];
    case CharonCbCr16U: return (double)((const uint16_t *)row)[pixel * 2 + channel];
    case CharonCbCr16S: return (double)((const int16_t *)row)[pixel * 2 + channel];
    case CharonCbCr16F: return (double)charon_half_to_float(((const uint16_t *)row)[pixel * 2 + channel]);
    case CharonPlanar16F: return (double)charon_half_to_float(((const uint16_t *)row)[pixel]);
    case CharonARGB16F: return (double)charon_half_to_float(((const uint16_t *)row)[pixel * 4 + channel]);
    case CharonXRGB2101010W: return (double)((((const uint32_t *)row)[pixel] >> (channel * 10)) & 0x3FFu);
    case CharonPlanarF: return (double)((const float *)row)[pixel];
    case CharonCbCrF: return (double)((const float *)row)[pixel * 2 + channel];
    case CharonARGBFFFF: return (double)((const float *)row)[pixel * 4 + channel];
    default: return 0.0;
    }
}

static inline double CharonSaturate(double value, enum CharonPixelType type)
{
    switch (type) {
    case CharonARGB16U: case CharonPlanar16U: case CharonCbCr16U: case CharonXRGB2101010W:
        return value < 0.0 ? 0.0 : (value > 65535.0 ? 65535.0 : value);
    case CharonCbCr8:
        return value < 0.0 ? 0.0 : (value > 255.0 ? 255.0 : value);
    case CharonARGB16S: case CharonPlanar16S: case CharonCbCr16S:
        return value < -32768.0 ? -32768.0 : (value > 32767.0 ? 32767.0 : value);
    default:
        return value;
    }
}

// The release ROUNDS to nearest at the store, and the rounding is half UP - toward plus infinity, not away from
// zero. Three independent measurements, each with a control where the answer must be exact:
//
// - **The store.** `CharonChannelPut` used to cast, which truncates toward zero. At a whole-pixel phase the
//   kernel is the single tap at `L(0) = 1` and the sum is that tap's own integer, so the host's stored value is
//   exactly the source value on 180 of 180 samples, a round to nearest reproduces 180 of 180 and the
//   truncation 29 of 180.
// - **The tie.** Over eighty cells of 180 samples - both axes, six translates, four slopes, both edging modes -
//   the release's own Q14 weights summed as integers and rounded half up reproduce the host's stored value on
//   14400 of 14400, and rounding half away from zero does not (`.agent-work/probe/vsweep.m`, ARGB16S).
// - **The ulp.** The 109 samples a previous pass found "off by exactly 255" are this and nothing else: on
//   `ARGB16S` the backColor is `(int16_t)(-1.0)` = `0xFFFF` for channels 2 and 3, a wholly-outside sample's
//   sum is `-1` to within one ulp of double, and the truncating cast answers `0x0000` where the host answers
//   `0xFFFF`. Ninety-eight of the 109 are that, on the low byte of a channel; the other eleven are the same
//   cast the other way. The whole count is on the four `ARGB16S` spellings and one sample each elsewhere.
//
// `CharonSaturate` runs first, so the rounding is applied to the value already clamped to the stored type's
// range, and `floor(x + 0.5)` is the half-up rule for negatives as well: -1.5 rounds to -1, which is what the
// release does and what a cast never could.
#define CHARON_ROUND_HALF_UP(v) ((v) >= 0.0 ? floor((v) + 0.5) : ceil((v) - 0.5))

static inline void CharonChannelPut(void *row, vImagePixelCount pixel, unsigned channel, double value,
                                    enum CharonPixelType type)
{
    switch (type) {
    case CharonARGB16U: ((uint16_t *)row)[pixel * 4 + channel] = (uint16_t)CHARON_ROUND_HALF_UP(CharonSaturate(value, type)); break;
    case CharonARGB16S: ((int16_t *)row)[pixel * 4 + channel] = (int16_t)CHARON_ROUND_HALF_UP(CharonSaturate(value, type)); break;
    case CharonPlanar16U: ((uint16_t *)row)[pixel] = (uint16_t)CHARON_ROUND_HALF_UP(CharonSaturate(value, type)); break;
    case CharonPlanar16S: ((int16_t *)row)[pixel] = (int16_t)CHARON_ROUND_HALF_UP(CharonSaturate(value, type)); break;
    case CharonCbCr8: ((uint8_t *)row)[pixel * 2 + channel] = (uint8_t)CHARON_ROUND_HALF_UP(CharonSaturate(value, type)); break;
    case CharonCbCr16U: ((uint16_t *)row)[pixel * 2 + channel] = (uint16_t)CHARON_ROUND_HALF_UP(CharonSaturate(value, type)); break;
    case CharonCbCr16S: ((int16_t *)row)[pixel * 2 + channel] = (int16_t)CHARON_ROUND_HALF_UP(CharonSaturate(value, type)); break;
    case CharonCbCr16F: ((uint16_t *)row)[pixel * 2 + channel] = charon_float_to_half((float)value); break;
    case CharonPlanar16F: ((uint16_t *)row)[pixel] = charon_float_to_half((float)value); break;
    case CharonARGB16F: ((uint16_t *)row)[pixel * 4 + channel] = charon_float_to_half((float)value); break;
    case CharonXRGB2101010W: {
        // The ten-bit field is masked AFTER the round, so the round is on the value and not on the field: a
        // value of 1023.9 must become 1024 (which wraps to 0 in the field) rather than 1023, which is what a
        // truncating cast before the mask gave.
        uint32_t word = ((uint32_t *)row)[pixel], shift = channel * 10;
        word = (word & ~(0x3FFu << shift))
             | ((((uint32_t)CHARON_ROUND_HALF_UP(CharonSaturate(value, type))) & 0x3FFu) << shift);
        ((uint32_t *)row)[pixel] = word;
        break;
    }
    case CharonPlanarF: ((float *)row)[pixel] = (float)value; break;
    case CharonCbCrF: ((float *)row)[pixel * 2 + channel] = (float)value; break;
    case CharonARGBFFFF: ((float *)row)[pixel * 4 + channel] = (float)value; break;
    default: break;
    }
}

// The caller's backColor in the engine's own scale, one reader per storage the header's pixel types use.
// **These exist because reading a backColor as `sizeof(double) * channels` bytes is wrong for every one of
// them but the four-channel float form.** `Pixel_ARGB_16U` is four `uint16_t` and eight bytes, `Pixel_16U16U`
// is two of them and four bytes, `Pixel_88` is two bytes, and `Pixel_16U`, `Pixel_16S`, `Pixel_32U` and
// `Pixel_16F` are scalars, so the parameter is a POINTER and `(double)backColor` is the pointer's own value as
// a number. An earlier version of the four band files did both: it copied 32 bytes out of an eight-byte
// `Pixel_ARGB_16U` and out of a four-byte `Pixel_16U16U`, and it converted the pointer. Each element is read
// here as the type it is, and the half-precision forms go through the same conversion the samples do.
static inline void CharonShearBackU16(double *out, const uint16_t *values, unsigned channels)
{
    for (unsigned channel = 0; channel < channels; channel++)
        out[channel] = (double)values[channel];
}

static inline void CharonShearBackS16(double *out, const int16_t *values, unsigned channels)
{
    for (unsigned channel = 0; channel < channels; channel++)
        out[channel] = (double)values[channel];
}

static inline void CharonShearBackU8(double *out, const uint8_t *values, unsigned channels)
{
    for (unsigned channel = 0; channel < channels; channel++)
        out[channel] = (double)values[channel];
}

static inline void CharonShearBackF16(double *out, const uint16_t *values, unsigned channels)
{
    for (unsigned channel = 0; channel < channels; channel++)
        out[channel] = (double)charon_half_to_float(values[channel]);
}

// **The flag word, measured per shape over all thirty-two bits**, because the shears do not all take the same
// set and neither the header nor an earlier measurement says so. The three half-precision shapes -
// `ARGB16F`, `CbCr16F`, `Planar16F` - take seven bits and answer `kvImageUnknownFlagsBit` for the other
// twenty-five; **every other shape takes all thirty-two**, which is what a first pass over the family measured
// and what the header's silence suggests. A bit outside the set is refused rather than ignored.
//
// The seven are `kvImageBackgroundColorFill`, `kvImageEdgeExtend`, `kvImageDoNotTile`,
// `kvImageHighQualityResampling`, `kvImageGetTempBufferSize`, `kvImagePrintDiagnosticsToConsole` and
// `kvImageUseFP16Accumulator` - the mask is 0x11bc - and the three refused ones are
// `kvImageLeaveAlphaUnchanged` (0x1), `kvImageCopyInPlace` (0x2) and `kvImageTruncateKernel` (0x40).
static inline unsigned CharonShearFlags(enum CharonPixelType type)
{
    switch (type) {
    case CharonARGB16F: case CharonCbCr16F: case CharonPlanar16F:
        return (unsigned)(kvImageBackgroundColorFill | kvImageEdgeExtend | kvImageDoNotTile
                          | kvImageHighQualityResampling | kvImageGetTempBufferSize
                          | kvImagePrintDiagnosticsToConsole | kvImageUseFP16Accumulator);
    default:
        return 0xFFFFFFFFu;
    }
}

// The refusals, in the order the release makes them. Measured on the host's own shears, over a NULL buffer, a
// NULL filter, every bit of the flag word, and the region's two origins against the destination's two extents.
//
// **The NULL test is CharonChannelsIsNull's, reused rather than written again**: `src` and `dest` are declared
// `VIMAGE_NON_NULL(1,2)`, so an attributed parameter is assumed non-null inside the function and a plain
// `if (!src)` is folded away at -Os - there is no compare against zero anywhere in the object - while a
// volatile read is a memory access the optimizer has to honour. The four spellings and their disassembly are
// in CharonChannels.h's own comment, and that is where the measurement lives.
//
// **`filter` is NOT attributed** (`VIMAGE_NON_NULL(1,2)` names only the two buffers), so a plain NULL test
// survives at -Os. `ours` is NULL when the caller's object is not one of the measured filter shapes, which is
// what `CharonResampleFilterOf` answers, and the host answers `kvImageInvalidParameter` for that case.
//
// The cross extent is the one the release checks: `cross0 + destCross > srcCross` is
// `kvImageBufferSizeMismatch`, measured over three destination extents and both axes, and it is the ONLY shape
// condition - the destination's along extent is free, and so is the along offset, which a source nine wide
// accepts at twelve.
static inline vImage_Error CharonShearReady(const vImage_Buffer *src, const vImage_Buffer *dest,
                                            const CharonResampleFilter *ours, int horizontal,
                                            vImagePixelCount offsetX, vImagePixelCount offsetY)
{
    if (CharonChannelsIsNull(src) || CharonChannelsIsNull(dest))
        return kvImageNullPointerArgument;
    if (!ours || !ours->row)
        return kvImageInvalidParameter;
    vImagePixelCount cross0 = horizontal ? offsetY : offsetX;
    vImagePixelCount dstCross = horizontal ? dest->height : dest->width;
    vImagePixelCount srcCross = horizontal ? src->height : src->width;
    if (cross0 + dstCross > srcCross)
        return kvImageBufferSizeMismatch;
    return kvImageNoError;
}

// The shear. `horizontal` picks the axis; the two lines of the mapping are at the top of this file and each of
// them is there for a measurement the facts page records.
static inline vImage_Error CharonShearRun(const vImage_Buffer *src, const vImage_Buffer *dest,
                                          const CharonResampleFilter *filter, enum CharonPixelType type,
                                          int horizontal, double translate, double slope,
                                          vImagePixelCount offsetX, vImagePixelCount offsetY,
                                          const double *backColor, vImage_Flags flags)
{
    // The flags are read LAST, after the buffers, the filter and the region's shape: measured on a call that
    // breaks two rules at once, a bad flag beside an across offset of one answers the offset, and a NULL
    // destination beside a bad flag answers the NULL. So this refusal sits here rather than in
    // CharonShearReady, which has already answered the other three by the time the engine is reached.
    if (flags & ~CharonShearFlags(type))
        return kvImageUnknownFlagsBit;
    unsigned channels = CharonChannels(type);
    vImagePixelCount srcAlong = horizontal ? src->width : src->height;
    vImagePixelCount dstAlong = horizontal ? dest->width : dest->height;
    vImagePixelCount dstCross = horizontal ? dest->height : dest->width;
    vImagePixelCount along0 = horizontal ? offsetX : offsetY;
    vImagePixelCount cross0 = horizontal ? offsetY : offsetX;
    double reciprocal = filter->reciprocal;
    int extend = (flags & kvImageEdgeExtend) ? 1 : 0;

    // Every phase's own sum, read once for the call rather than once per destination sample. `phases` is at
    // most the writer's own 64, so this is a fixed array and not an allocation, and the divisor is the sum of
    // the row the port is about to use - which on 6.1.3 is not 16384 (CharonResampling.h).
    double rowSum[CharonResampleMaxPhases];
    for (unsigned phase = 0; phase < filter->phases; phase++)
        rowSum[phase] = CharonResampleRowSum(filter, phase);

    // The two axes are kept apart on purpose, because they are different and mixing them is what read past
    // the caller's buffer. `at` is the position ALONG the shear and is bounded by srcAlong - the width for
    // a horizontal shear, the HEIGHT for a vertical one. `row` is the position ACROSS the shear and is
    // bounded by srcCross, the other extent. The ADDRESS is the only place the two swap: it is always
    // `data + ROW * rowBytes + COL * pixelBytes`, with ROW the across value and the along value the other
    // way round according to the axis. Clamping the across value against srcCross and then multiplying it
    // by rowBytes is the bug AddressSanitizer named at CharonShear.h:225 - for the vertical shear srcCross
    // is the width, so a "row" clamped to srcCross - 1 was 8, and 8 * 36 is 288 bytes into a 180-byte image.
    //
    // `row` needs no clamp: CharonShearReady has refused every call where `cross0 + cross` could reach
    // srcCross, so for a call that gets here it is inside the picture by construction.
    const size_t pixelBytes = CharonBytesPerPixel(type);
#define CHARON_SHEAR_AT(img, along_, cross_) \
    ((uint8_t *)(img)->data + (size_t)(horizontal ? (cross_) : (along_)) * (img)->rowBytes \
     + (size_t)(horizontal ? (along_) : (cross_)) * pixelBytes)

    // The step, once per call: the release computes it beside the reciprocal and its saturation and never
    // recomputes it per sample (0x30413d48 on armv7, 0x1804a58dc on arm64).
    long long step = CharonResampleStep(filter);
    // The vertical's start, once per call, and the accumulator it runs from for the WHOLE destination: the
    // vertical's start carries no per-row term, so one accumulator serves every row and the along loop is
    // inside the row loop exactly as the release's is. The terms are the release's own, in its order -
    // `1 - recip`, times the destination's along extent, plus `recip*t`, plus `taps * -0.5`, plus `1.0` -
    // because at an inexact reciprocal any other grouping is the same expression and a different double, and a
    // different double at the conversion is a whole phase. The horizontal's is formed per row below, where its
    // slope term is.
    long long position = 0;
    if (!horizontal) {
        double oneMinusReciprocal = 1.0 - reciprocal;
        double scaled = (double)dstAlong * oneMinusReciprocal;
        scaled = scaled + reciprocal * translate;
        scaled = scaled + (double)filter->taps * -0.5;
        position = CharonResampleQ32((scaled + 1.0) * 4294967296.0);
    }

    for (vImagePixelCount cross = 0; cross < dstCross; cross++) {
        long sourceCross = (long)cross0 + (long)cross;
        // The horizontal's start carries the slope's cross term, so it is formed once per destination row; the
        // vertical's start carries none, so its accumulator runs straight through the whole destination, which
        // is why `position` is declared above the loops and only the horizontal resets it here. The terms are
        // the release's own, in its order - `1 - recip`, times the destination's extent, `+ recip*t`, `+
        // numTaps * -0.5`, `+ 1.0` - because at an inexact reciprocal any other grouping is the same
        // expression and a different double, and a different double at the conversion is a whole phase.
        if (horizontal) {
            double perRow = reciprocal * slope;
            double scaled = (double)((long)cross + 1 - (long)dstCross) * perRow;
            scaled = scaled - reciprocal * translate;
            scaled = scaled + (double)filter->taps * -0.5;
            position = CharonResampleQ32((scaled + 1.0) * 4294967296.0);
        } else if (slope != 0.0) {
            // **The vertical's slope term is NOT THE RELEASE'S, and this is the one term of the mapping that no
            // measurement of a release covers.** The 6.1.3 vertical worker reads its `shearSlope` at the top
            // and BRANCHES on it (0x30413d38): at zero it falls into the path this file implements, which has
            // no cross term at all, and at anything else it jumps to 0x304151e4, which spills its state and
            // CALLS rather than forming a start. That path is not read here, so the term below is macOS's own,
            // measured on the host by tests/backports/host/shear, carried across in the only units this
            // accumulator has: `slope * (cross + 0.5)` destination pixels is `... * reciprocal` source pixels,
            // which is where the host's own arrangement put it. It is kept rather than dropped because a shear
            // that ignored its slope would be a silent wrong answer for a parameter the header names; it is
            // stated here and in every shear row's reason because a reader is entitled to know which engine
            // this one term came from.
            double scaled = ((double)cross + 0.5) * slope * reciprocal;
            scaled = scaled + (double)dstAlong * (1.0 - reciprocal);
            scaled = scaled + reciprocal * translate;
            scaled = scaled + (double)filter->taps * -0.5;
            position = CharonResampleQ32((scaled + 1.0) * 4294967296.0);
        }
        for (vImagePixelCount along = 0; along < dstAlong; along++) {
            unsigned phase;
            long base;
            // The row and the tap come out of the accumulator, and the caller's offset along the shear is
            // added where the release adds it - to the row's base address, which is the FIRST tap, so the
            // centre this returns is `K0` above the first tap and `first` below it.
            CharonResamplePhase(filter, position, &phase, &base);
            base += (long)along0;
            const int16_t *row = filter->row + (size_t)phase * filter->width;
            long first = base - (long)filter->centre;
            double divisor = rowSum[phase];
            for (unsigned channel = 0; channel < channels; channel++) {
                // The accumulator is a double and not an integer, because three of the pixel types carry real
                // samples and a truncation would throw away their fractions. **For the integer types it is
                // still exact**: the weights are integers and a row of at most the writer's 64 phases holds
                // at most `int16Stride/2` of them, so the largest product is 32768 * 65535 and the largest sum
                // is under 2^40, every bit of it an integer a double holds.
                double accumulator = 0.0;
                for (unsigned k = 0; k < filter->width; k++) {
                    long at = first + (long)k;
                    long weight = row[k];
                    // A zero weight contributes nothing, so the tap is not read at all - which also means an
                    // out-of-picture tap under kvImageEdgeExtend cannot be pulled back to the edge for nothing.
                    if (!weight)
                        continue;
                    double value;
                    if (at < 0 || at >= (long)srcAlong) {
                        // kvImageEdgeExtend is the header's own "the edge pixels of the source are
                        // extended": the tap is pulled back to the edge and keeps its weight, where
                        // kvImageBackgroundColorFill substitutes the backColor instead.
                        if (!extend) {
                            value = backColor[channel];
                        } else {
                            at = at < 0 ? 0 : (srcAlong ? (long)srcAlong - 1 : 0);
                            value = CharonChannelAt(CHARON_SHEAR_AT(src, at, sourceCross), 0, channel, type);
                        }
                    } else {
                        value = CharonChannelAt(CHARON_SHEAR_AT(src, at, sourceCross), 0, channel, type);
                    }
                    accumulator += (double)weight * value;
                }
                // The divisor is the row's own sum. A row that sums to zero cannot come out of the release's
                // own writer - every row measured is within 5 of 16384 - so this arm is not a behaviour and is
                // here only so that a filter whose table has been overwritten answers a number rather than a
                // NaN. It is not a tolerance and it does not loosen anything else.
                CharonChannelPut(CHARON_SHEAR_AT(dest, along, cross), 0, channel,
                                 divisor != 0.0 ? accumulator / divisor : 0.0, type);
            }
            // The advance, after the sample and not before it: the release's first destination sample reads
            // the accumulator as it was started, and `adds`/`adcs` sit at the END of its sample body
            // (0x30414314 on armv7, behind the branch that leaves the body at 0x304141ce).
            position += step;
        }
    }
#undef CHARON_SHEAR_AT
    return kvImageNoError;
}