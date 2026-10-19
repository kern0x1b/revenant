// The channel moves of vImage: permute, extract, overwrite. One engine, and the three pixel widths.
//
// **These are data movements and nothing else**, which is why the loops below are written over bytes and
// never look at a value: there is no rounding to get wrong, no channel to clamp and no half to be
// converted, so a pixel is `channels` runs of `bytes` and a destination pixel's run `i` is the source's run
// the map names. The width is a parameter and nothing else differs between an 8-bit RGB triple, a 16-bit
// four-channel word and a 32-bit FFFF word. (Conversion.h says the same of the copy: a channel move carries
// signed 16-bit integers and half-precision floats through unchanged, "of any endianness".)
//
// In place is the case the loops have to survive: every one of these functions is documented to work with
// `src->data == dest->data`, so a permute reads a whole source pixel into local storage before it writes
// any of it back. Writing run 0 before reading run 1 would be correct only for a map that leaves run 0
// alone, and the map `3,2,1,0` - ARGB to BGRA, the one the header names - is in the corpus.
//
// The name carries a Charon prefix because the gate does not weigh a symbol of the port's own against a
// release or ask the registry about it (modules/apple/backports.lua, internal_symbol) - the same reason
// CharonGeometry.h's, CharonResampling.h's and CharonVImageFixed.h's do. Everything here is `static
// inline`, so no object file that includes this exports a name of its own.

#pragma once

#import <Accelerate/Accelerate.h>
#include <string.h>

// The widest pixel this engine moves: four channels of four bytes (an FFFF word). Every local below is
// sized from it rather than from the caller's arguments, so a caller cannot overflow one by asking for a
// wider pixel than the header names.
#define CHARON_CHANNELS_MAX_CHANNELS 4
#define CHARON_CHANNELS_MAX_BYTES 4

// **The NULL test, in the one spelling the optimizer keeps.** Every function of this family has its buffers
// declared with `VIMAGE_NON_NULL`, and an attributed parameter is assumed non-null *inside* the function: at
// -Os for armv7 with the package line, `if (!src) ...` on such a parameter is folded away completely - there
// is no compare against zero anywhere in the object - and clang says so at the front end ("nonnull parameter
// 'src' will evaluate to 'true' on first encounter"). The object the bands link would then carry no refusal
// at all, and the release makes one: measured, the host answers kvImageNullPointerArgument for a NULL source,
// a NULL destination and a NULL map, and answers nothing at all (its process ends on a signal) for four
// others.
//
// Four spellings were built at -Os and read in the disassembly:
//
//   if (!pointer)                              the compare is gone
//   the same test inside a __attribute__((noinline)) helper    gone - LLVM infers nonnull from the call site
//   the same test on a one-element array the parameter is stored into    gone
//   the same test on a volatile copy of the parameter            **there**
//
// because the attribute is an assumption about a value and a volatile read is a memory access the optimizer
// has to honour. No pragma is involved, and none can be: `-Wnonnull` and `-Wpointer-bool-conversion` are
// warnings, so suppressing them would silence the warning that names the folded test without bringing it
// back.
static inline int CharonChannelsIsNull(const void *pointer)
{
    const void *volatile checked = pointer;
    return checked == NULL;
}

// One row of a permute. `insert` is NULL for a plain permute and the inserted pixel otherwise: a channel
// whose copyMask bit is SET takes the inserted value. The mask is the header's - 0x8 alpha, 0x4 red, 0x2
// green, 0x1 blue - tested from the top bit down, and the sense is the header's too: Conversion.h's own
// pseudocode is `if (mask & copyMask) result[i] = backgroundColor[i]` with `mask = 0x8` shifted right each
// channel, and the parameter's own comment says "Copy backgroundColor into 0x8 -- alpha". An earlier
// version of this header took the bit as "keep the source's", which is the sense the *overwrite with a
// pixel* uses and the opposite of this one.
static inline void CharonChannelsPermuteRow(const uint8_t *srcRow, uint8_t *destRow, vImagePixelCount width,
                                            const uint8_t *map, int channels, int bytes, const uint8_t *insert,
                                            uint8_t copyMask)
{
    for (vImagePixelCount x = 0; x < width; x++) {
        uint8_t source[CHARON_CHANNELS_MAX_CHANNELS * CHARON_CHANNELS_MAX_BYTES];
        uint8_t result[CHARON_CHANNELS_MAX_CHANNELS * CHARON_CHANNELS_MAX_BYTES];
        size_t pixel = (size_t)channels * bytes;
        // The whole source pixel first, so a map that moves a run backwards cannot read a run this loop
        // has already written - which is what makes `src->data == dest->data` work.
        memcpy(source, srcRow + (size_t)x * pixel, pixel);
        for (int channel = 0; channel < channels; channel++) {
            const uint8_t *from = source + (size_t)map[channel] * bytes;
            uint8_t *to = result + (size_t)channel * bytes;
            if (insert && (copyMask & (uint8_t)(0x8 >> channel)))
                memcpy(to, insert + (size_t)channel * bytes, (size_t)bytes);
            else
                memcpy(to, from, (size_t)bytes);
        }
        memcpy(destRow + (size_t)x * pixel, result, pixel);
    }
}

// One row of an extract: the run `channelIndex` of every source pixel, into a one channel destination.
static inline void CharonChannelsExtractRow(const uint8_t *srcRow, uint8_t *destRow, vImagePixelCount width,
                                            long channelIndex, int channels, int bytes)
{
    for (vImagePixelCount x = 0; x < width; x++)
        memcpy(destRow + (size_t)x * bytes,
               srcRow + ((size_t)x * (size_t)channels + (size_t)channelIndex) * (size_t)bytes, (size_t)bytes);
}

// One row of a fill: the same value in every pixel of a one channel destination.
static inline void CharonChannelsFillRow(uint8_t *destRow, vImagePixelCount width, const uint8_t *value, int bytes)
{
    for (vImagePixelCount x = 0; x < width; x++)
        memcpy(destRow + (size_t)x * bytes, value, (size_t)bytes);
}

// One row of an overwrite-with-pixel: each channel of every destination pixel is either the source's own or
// the given pixel's, decided by the copyMask bit for that channel - **and the bit is set for the pixel, not
// for the source**, which is what the host answers and what the parameter's own comment says ("Copy plane
// into 0x8 -- alpha"). Measured over all sixteen masks: with copyMask 0 the host conserves every run of the
// source, and with copyMask 0x8 it writes the pixel's alpha and conserves the rest
// (tests/backports/host/vimagechannels). Conversion.h's own words point the other way - `destRow[x] =
// (srcRow[x] & mask) | the_pixel` with the mask "0xFFFF where the pixels should be conserved" - and reading
// it that way puts the two functions of this family on opposite senses, which the host does not do. This is
// the run at a time rather than the header's word at a time, because a channel taken from the source and a
// channel taken from the pixel never share a word.
//
// The source pixel is read whole before anything is written, for the same in-place reason as the permute.
static inline void CharonChannelsOverwritePixelRow(const uint8_t *srcRow, uint8_t *destRow, vImagePixelCount width,
                                                   const uint8_t *pixel, int channels, int bytes, uint8_t copyMask)
{
    for (vImagePixelCount x = 0; x < width; x++) {
        uint8_t source[CHARON_CHANNELS_MAX_CHANNELS * CHARON_CHANNELS_MAX_BYTES];
        size_t run = (size_t)channels * bytes;
        memcpy(source, srcRow + (size_t)x * run, run);
        for (int channel = 0; channel < channels; channel++) {
            uint8_t *to = destRow + (size_t)x * run + (size_t)channel * bytes;
            if (copyMask & (uint8_t)(0x8 >> channel))
                memcpy(to, pixel + (size_t)channel * bytes, (size_t)bytes);
            else
                memcpy(to, source + (size_t)channel * bytes, (size_t)bytes);
        }
    }
}