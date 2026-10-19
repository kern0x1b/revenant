#import <Accelerate/Accelerate.h>
#import <Foundation/Foundation.h>   // BOOL, which the 4.3 include chain does not reach on its own
#include "CharonYpCbCr.h"

#pragma clang diagnostic ignored "-Wunguarded-availability-new"
#pragma clang diagnostic ignored "-Wpointer-bool-conversion"
#pragma clang diagnostic ignored "-Wnonnull"

// The Y'CbCr conversions of vImage, iOS 8.0: the whole of Conversion.h's thirty-four entry points, the
// 4:2:2, 4:4:4, 4:2:0, 10-bit v410 and v210, 16-bit v216 and y416 shapes, both directions, and the two
// generators that build the conversion each of them takes. The arithmetic is CharonYpCbCr.h's, which
// says where the header's per-pixel text puts it and why.
//
// Everything here is the port's own. The armv7 cache of iOS 6.1.3 exports 235 vImage names and not one
// kvImage matrix among them, so none of this calls into the release: each conversion is a loop over
// buffers with the header's coefficients in it, and the host differential compares every byte of the
// result against macOS's own vImage.

static const vImage_YpCbCrToARGBMatrix charon_ypcbcr_601_4 = {1.0f, 1.40199995f, -0.714136302f, -0.344136298f, 1.77199996f};
static const vImage_YpCbCrToARGBMatrix charon_ypcbcr_709_2 = {1.0f, 1.57480001f, -0.46812427f, -0.187324271f, 1.8556f};
static const vImage_ARGBToYpCbCrMatrix charon_argb_601_4 = {0.298999995f, 0.587000012f, 0.114f, -0.168735892f, -0.331264108f, 0.5f, -0.418687582f, -0.0813124105f};
static const vImage_ARGBToYpCbCrMatrix charon_argb_709_2 = {0.212599993f, 0.715200007f, 0.0722000003f, -0.114572108f, -0.385427892f, 0.5f, -0.454152912f, -0.0458470918f};

const vImage_YpCbCrToARGBMatrix *kvImage_YpCbCrToARGBMatrix_ITU_R_601_4 = &charon_ypcbcr_601_4;
const vImage_YpCbCrToARGBMatrix *kvImage_YpCbCrToARGBMatrix_ITU_R_709_2 = &charon_ypcbcr_709_2;
const vImage_ARGBToYpCbCrMatrix *kvImage_ARGBToYpCbCrMatrix_ITU_R_601_4 = &charon_argb_601_4;
const vImage_ARGBToYpCbCrMatrix *kvImage_ARGBToYpCbCrMatrix_ITU_R_709_2 = &charon_argb_709_2;

static const vImage_Flags charon_vimage_conversion_flags = kvImageDoNotTile | kvImagePrintDiagnosticsToConsole;
static const vImage_Flags charon_vimage_generate_flags = kvImagePrintDiagnosticsToConsole;

// Which of the thirteen Y'CbCr types the header's own table in the two generators pairs with which of
// the three ARGB types, read straight off it: the columns are RGB8, RGB16Q12 and RGB16, the rows the
// Y'CbCr types grouped by bit depth. The 12- and 14-bit rows of that table name no format this header
// declares, so nothing answers for them.
static BOOL charon_yuv_supports(vImageYpCbCrType yuv, vImageARGBType argb)
{
    switch (yuv) {
    case kvImage422CbYpCrYp8:
    case kvImage422CbYpCrYp8_AA8:
    case kvImage422YpCbYpCr8:
    case kvImage420Yp8_Cb8_Cr8:
    case kvImage420Yp8_CbCr8:
    case kvImage444AYpCbCr8:
    case kvImage444CbYpCrA8:
    case kvImage444CrYpCb8:
    case kvImage444CrYpCb10:
    case kvImage422CrYpCbYpCbYpCbYpCrYpCrYp10:
        return argb == kvImageARGB8888 || argb == kvImageARGB16Q12;
    case kvImage422CbYpCrYp16:
    case kvImage444AYpCbCr16:
        return argb == kvImageARGB8888 || argb == kvImageARGB16U;
    default:
        return NO;
    }
}

vImage_Error vImageConvert_YpCbCrToARGB_GenerateConversion(const vImage_YpCbCrToARGBMatrix *matrix,
                                                           const vImage_YpCbCrPixelRange *pixelRange,
                                                           vImage_YpCbCrToARGB *outInfo,
                                                           vImageYpCbCrType inYpCbCrType,
                                                           vImageARGBType outARGBType,
                                                           vImage_Flags flags)
{
    if (flags & ~charon_vimage_generate_flags)
        return kvImageUnknownFlagsBit;
    if (!matrix || !pixelRange || !outInfo)
        return kvImageNullPointerArgument;
    float full = charon_argb_scale(outARGBType);
    if (full == 0.0f || !charon_yuv_supports(inYpCbCrType, outARGBType))
        return kvImageUnsupportedConversion;
    int32_t yRange = pixelRange->YpRangeMax - pixelRange->Yp_bias;
    int32_t cRange = pixelRange->CbCrRangeMax - pixelRange->CbCr_bias;
    if (yRange == 0 || cRange == 0)
        return kvImageInvalidParameter;
    CharonToARGB found = {
        .magic = CharonYpCbCrToARGBMagic,
        .Yp = matrix->Yp,
        .Cr_R = matrix->Cr_R,
        .Cr_G = matrix->Cr_G,
        .Cb_G = matrix->Cb_G,
        .Cb_B = matrix->Cb_B,
        .yScale = full / (float)yRange,
        .cScale = full / (2.0f * (float)cRange),
        .Yp_bias = (float)pixelRange->Yp_bias,
        .CbCr_bias = (float)pixelRange->CbCr_bias,
        .YpMin = (float)pixelRange->YpMin,
        .YpMax = (float)pixelRange->YpMax,
        .CbCrMin = (float)pixelRange->CbCrMin,
        .CbCrMax = (float)pixelRange->CbCrMax
    };
    memset(outInfo, 0, sizeof *outInfo);
    memcpy(outInfo, &found, sizeof found);
    return kvImageNoError;
}

vImage_Error vImageConvert_ARGBToYpCbCr_GenerateConversion(const vImage_ARGBToYpCbCrMatrix *matrix,
                                                           const vImage_YpCbCrPixelRange *pixelRange,
                                                           vImage_ARGBToYpCbCr *outInfo,
                                                           vImageARGBType inARGBType,
                                                           vImageYpCbCrType outYpCbCrType,
                                                           vImage_Flags flags)
{
    if (flags & ~charon_vimage_generate_flags)
        return kvImageUnknownFlagsBit;
    if (!matrix || !pixelRange || !outInfo)
        return kvImageNullPointerArgument;
    float full = charon_argb_scale(inARGBType);
    if (full == 0.0f || !charon_yuv_supports(outYpCbCrType, inARGBType))
        return kvImageUnsupportedConversion;
    int32_t yRange = pixelRange->YpRangeMax - pixelRange->Yp_bias;
    int32_t cRange = pixelRange->CbCrRangeMax - pixelRange->CbCr_bias;
    if (yRange == 0 || cRange == 0)
        return kvImageInvalidParameter;
    CharonToYpCbCr found = {
        .magic = CharonARGBToYpCbCrMagic,
        .R_Yp = matrix->R_Yp,
        .G_Yp = matrix->G_Yp,
        .B_Yp = matrix->B_Yp,
        .R_Cb = matrix->R_Cb,
        .G_Cb = matrix->G_Cb,
        .B_Cb_R_Cr = matrix->B_Cb_R_Cr,
        .G_Cr = matrix->G_Cr,
        .B_Cr = matrix->B_Cr,
        .yScale = (float)yRange / full,
        .cScale = 2.0f * (float)cRange / full,
        .Yp_bias = (float)pixelRange->Yp_bias,
        .CbCr_bias = (float)pixelRange->CbCr_bias,
        .YpMin = (float)pixelRange->YpMin,
        .YpMax = (float)pixelRange->YpMax,
        .CbCrMin = (float)pixelRange->CbCrMin,
        .CbCrMax = (float)pixelRange->CbCrMax
    };
    memset(outInfo, 0, sizeof *outInfo);
    memcpy(outInfo, &found, sizeof found);
    return kvImageNoError;
}

// ---------------------------------------------------------------------------------------------
// The layouts. Which of the thirteen Y'CbCr shapes a buffer holds is not a parameter of any of the
// thirty-two conversions - the name says it - so the port keeps it as a number its own loops read, and
// the two directions share one table of it. A source and a destination of one name are the same layout
// read the other way round, which is what lets one pair of loops serve both.
//
//   across     luma samples that share one chroma sample, left to right
//   down       luma samples that share one chroma sample, top to bottom
//   group      luma samples one unit of the layout holds, which is the width the shape divides by
//   alphaWords words the shape's own alpha channel takes, where only y416's is sixteen bit wide
// ---------------------------------------------------------------------------------------------

enum {
    CharonYUV422YpCbYpCr8,   // Y0 Cb Y1 Cr, four bytes to two pixels
    CharonYUV422CbYpCrYp8,   // Cb Y0 Cr Y1
    CharonYUV444AYpCbCr8,    // A Y Cb Cr
    CharonYUV444CbYpCrA8,    // Cb Y Cr A
    CharonYUV444CrYpCb8,     // Cr Y Cb
    CharonYUV444AYpCbCr16,   // A Y Cb Cr, four 16-bit words to one pixel
    CharonYUV422CbYpCrYp16,  // Cb Y0 Cr Y1, four 16-bit words to two pixels
    CharonYUV444CrYpCb10,    // v410: one word to one pixel, Cb in bits 0-9, Yp in 10-19, Cr in 20-29
    CharonYUV422v210         // four words to six pixels
};

typedef struct CharonYUVLayout {
    unsigned across;
    unsigned down;
    unsigned group;
    unsigned alphaWords;
} CharonYUVLayout;

// `rows` is one for every shape: a v210 unit is SIX samples of ONE row and not a block of two rows, which
// the header's own pseudo-code says - it reads six pixels and writes six - and the system agrees: over a
// four-row buffer whose four units each carry their own values, row 1 comes back as row 1's unit and not
// as row 0's again. An earlier version of this file divided the row by six, which made every row of a
// short picture the first row's, and the differential now holds the two to each other over the whole of
// the shape.
static const CharonYUVLayout charon_yuv_layouts[] = {
    [CharonYUV422YpCbYpCr8]  = {2, 1, 2, 1},
    [CharonYUV422CbYpCrYp8]  = {2, 1, 2, 1},
    [CharonYUV444AYpCbCr8]   = {1, 1, 1, 1},
    [CharonYUV444CbYpCrA8]   = {1, 1, 1, 1},
    [CharonYUV444CrYpCb8]    = {1, 1, 1, 1},
    [CharonYUV444AYpCbCr16]  = {1, 1, 1, 2},
    [CharonYUV422CbYpCrYp16] = {2, 1, 2, 1},
    [CharonYUV444CrYpCb10]   = {1, 1, 1, 1},
    [CharonYUV422v210]       = {2, 1, 6, 1}
};

// The v410 word, read off the header's own diagram: the three ten-bit channels in bits 0-9, 10-19 and
// 20-29, two bits of each byte unused, the top two of the word unused. Splitting and joining them that
// way is the only reading of the diagram that gives a picture back the picture it came from, which is
// what the host differential checks over every one of the 1024 three of them.
static inline void charon_v410_split(uint32_t pixel, float *Yp, float *Cb, float *Cr)
{
    *Cb = (float)(pixel & 0x3FFu);
    *Yp = (float)((pixel >> 10) & 0x3FFu);
    *Cr = (float)((pixel >> 20) & 0x3FFu);
}

static inline uint32_t charon_v410_join(uint32_t Yp, uint32_t Cb, uint32_t Cr)
{
    return ((Cr & 0x3FFu) << 20) | ((Yp & 0x3FFu) << 10) | (Cb & 0x3FFu);
}

// The v210 group, the header's four diagrams: Cb0, Y0 and Cr0; Y1, Cb1 and Y2; Cr1, Y3 and Cb2; Y4, Cr2
// and Y5 - six luma and three of each chroma in sixteen words, each channel in bits 0-9, 10-19 or 20-29
// of its word.
static inline void charon_v210_split(const uint32_t *words, float *Yp, float *Cb, float *Cr)
{
    Cb[0] = (float)(words[0] & 0x3FFu);
    Yp[0] = (float)((words[0] >> 10) & 0x3FFu);
    Cr[0] = (float)((words[0] >> 20) & 0x3FFu);
    Yp[1] = (float)(words[1] & 0x3FFu);
    Cb[1] = (float)((words[1] >> 10) & 0x3FFu);
    Yp[2] = (float)((words[1] >> 20) & 0x3FFu);
    Cr[1] = (float)(words[2] & 0x3FFu);
    Yp[3] = (float)((words[2] >> 10) & 0x3FFu);
    Cb[2] = (float)((words[2] >> 20) & 0x3FFu);
    Yp[4] = (float)(words[3] & 0x3FFu);
    Cr[2] = (float)((words[3] >> 10) & 0x3FFu);
    Yp[5] = (float)((words[3] >> 20) & 0x3FFu);
}

// The same four words the other way round. Its arguments are the graded integers, not floats: an
// earlier version of this took a float array and was handed a uint32_t array through a cast, so the
// integers' bit patterns were read as floats and every chroma of a Q12 source came out wrong.
static inline void charon_v210_join(uint32_t *words, const uint32_t *Yp, const uint32_t *Cb, const uint32_t *Cr)
{
    words[0] = charon_v410_join(Yp[0], Cb[0], Cr[0]);
    words[1] = charon_v410_join(Yp[2], Cb[1], Yp[1]);
    words[2] = charon_v410_join(Yp[3], Cr[1], Cb[2]);
    words[3] = charon_v410_join(Yp[5], Yp[4], Cr[2]);
}

// ---------------------------------------------------------------------------------------------
// Y'CbCr to ARGB
// ---------------------------------------------------------------------------------------------

// One luma sample's Yp, Cb, Cr and alpha, read out of a source of the given layout. The chroma comes from
// the sample the layout shares: for 4:2:2 the pair to the left, for 4:4:4 the pixel itself, and for v210
// the six-pixel unit it belongs to.
static void charon_yuv_read(int layout, const uint8_t *row, vImagePixelCount column, uint32_t alpha,
                            BOOL hasAlphaArgument, float *Yp, float *Cb, float *Cr, uint32_t *A)
{
    switch (layout) {
    case CharonYUV422YpCbYpCr8: {
        vImagePixelCount pair = (column / 2) * 4;
        *Yp = (float)row[pair + (column & 1 ? 2 : 0)];
        *Cb = (float)row[pair + 1];
        *Cr = (float)row[pair + 3];
        *A = hasAlphaArgument ? alpha : 255;
        break;
    }
    case CharonYUV422CbYpCrYp8: {
        vImagePixelCount pair = (column / 2) * 4;
        *Cb = (float)row[pair];
        *Yp = (float)row[pair + (column & 1 ? 3 : 1)];
        *Cr = (float)row[pair + 2];
        *A = hasAlphaArgument ? alpha : 255;
        break;
    }
    case CharonYUV444AYpCbCr8:
        *A = row[column * 4];
        *Yp = (float)row[column * 4 + 1];
        *Cb = (float)row[column * 4 + 2];
        *Cr = (float)row[column * 4 + 3];
        break;
    case CharonYUV444CbYpCrA8:
        *Cb = (float)row[column * 4];
        *Yp = (float)row[column * 4 + 1];
        *Cr = (float)row[column * 4 + 2];
        *A = row[column * 4 + 3];
        break;
    case CharonYUV444CrYpCb8:
        *Cr = (float)row[column * 3];
        *Yp = (float)row[column * 3 + 1];
        *Cb = (float)row[column * 3 + 2];
        *A = hasAlphaArgument ? alpha : 255;
        break;
    case CharonYUV444AYpCbCr16: {
        const uint16_t *wide = (const uint16_t *)(const void *)row + column * 4;
        *A = wide[0];
        *Yp = (float)wide[1];
        *Cb = (float)wide[2];
        *Cr = (float)wide[3];
        break;
    }
    case CharonYUV422CbYpCrYp16: {
        const uint16_t *wide = (const uint16_t *)(const void *)row + (column / 2) * 4;
        *Cb = (float)wide[0];
        *Yp = (float)wide[column & 1 ? 3 : 1];
        *Cr = (float)wide[2];
        *A = hasAlphaArgument ? alpha : 65535;
        break;
    }
    case CharonYUV444CrYpCb10: {
        charon_v410_split(*(const uint32_t *)(const void *)(row + column * 4), Yp, Cb, Cr);
        *A = hasAlphaArgument ? alpha : 0;
        break;
    }
    case CharonYUV422v210: {
        // A unit is six pixels of forty-eight bytes, so the unit is at column / 6 of the row and the index
        // inside it is the column modulo six: reading the arrays at the column itself walks off the end of
        // all three from the seventh column on, and reading the unit at the row's start makes every
        // sixth column the first unit's.
        float yp[6], cb[3], cr[3];
        unsigned at = (unsigned)column % 6u;
        charon_v210_split((const uint32_t *)(const void *)(row + (column / 6) * 48), yp, cb, cr);
        *Yp = yp[at];
        *Cb = cb[at / 2u];
        *Cr = cr[at / 2u];
        *A = hasAlphaArgument ? alpha : 0;
        break;
    }
    default:
        *Yp = *Cb = *Cr = 0.0f;
        *A = hasAlphaArgument ? alpha : 255;
        break;
    }
}

// The store, in the destination's own width: the header's four ARGB channels go through the permutation
// map on the way out, and the alpha the caller gave is the fourth of the four the map may name.
static void charon_argb_store8(const CharonToARGB *conversion, float Yp, float Cb, float Cr, uint32_t A,
                               const uint8_t *permuteMap, uint8_t *out)
{
    float red, green, blue;
    charon_argb_of(conversion, Yp, Cb, Cr, &red, &green, &blue);
    uint8_t argb[4] = {(uint8_t)A, (uint8_t)charon_grade(red, 255.0f), (uint8_t)charon_grade(green, 255.0f),
                       (uint8_t)charon_grade(blue, 255.0f)};
    out[0] = argb[permuteMap[0]];
    out[1] = argb[permuteMap[1]];
    out[2] = argb[permuteMap[2]];
    out[3] = argb[permuteMap[3]];
}

static void charon_argb_store16(const CharonToARGB *conversion, float Yp, float Cb, float Cr, uint32_t A,
                                const uint8_t *permuteMap, uint16_t *out, float full)
{
    float red, green, blue;
    charon_argb_of(conversion, Yp, Cb, Cr, &red, &green, &blue);
    uint32_t argb[4] = {A, charon_grade(red, full), charon_grade(green, full), charon_grade(blue, full)};
    out[0] = (uint16_t)argb[permuteMap[0]];
    out[1] = (uint16_t)argb[permuteMap[1]];
    out[2] = (uint16_t)argb[permuteMap[2]];
    out[3] = (uint16_t)argb[permuteMap[3]];
}

// The whole of the interleaved direction, from one layout to one destination width. The header's return
// list for every one of these is the same three: no error, an unknown flag, and a destination larger
// than the source.
static vImage_Error charon_yuv_to_argb(int layout, float destFull, const vImage_Buffer *src,
                                       const vImage_Buffer *dest, const vImage_YpCbCrToARGB *info,
                                       const uint8_t *permuteMap, uint32_t alpha, BOOL hasAlphaArgument,
                                       const vImage_Buffer *srcA)
{
    static const uint8_t identity[4] = {0, 1, 2, 3};
    if (!src || !dest || !info)
        return kvImageNullPointerArgument;
    const CharonToARGB *conversion = charon_to_argb(info);
    if (!conversion)
        return kvImageNullPointerArgument;
    if (!permuteMap)
        permuteMap = identity;
    else if (!charon_permutation(permuteMap))
        return kvImageInvalidParameter;
    if (src->width < dest->width || src->height < dest->height)
        return kvImageRoiLargerThanInputBuffer;
    const CharonYUVLayout *shape = &charon_yuv_layouts[layout];
    if (shape->group > 1 && dest->width % shape->group)
        return kvImageRoiLargerThanInputBuffer;
    vImagePixelCount width = dest->width, height = dest->height;
    for (vImagePixelCount row = 0; row < height; row++) {
        const uint8_t *in = (const uint8_t *)src->data + row * src->rowBytes;
        const uint8_t *alphaRow = srcA ? (const uint8_t *)srcA->data + row * srcA->rowBytes : NULL;
        uint8_t *out8 = (uint8_t *)dest->data + row * dest->rowBytes;
        uint16_t *out16 = (uint16_t *)(void *)out8;
        for (vImagePixelCount column = 0; column < width; column++) {
            float Yp, Cb, Cr;
            uint32_t A = 0;
            charon_yuv_read(layout, in, column, alpha, hasAlphaArgument, &Yp, &Cb, &Cr, &A);
            if (alphaRow)
                A = alphaRow[column];
            // A shape whose own alpha is sixteen bit wide and an eight-bit destination narrow it the way
            // Conversion.h narrows a sixteen-bit channel to eight: (bits * 255 + 32767) / 65535. Measured
            // over seventeen values, and it is a rounding rule and not a shift: 255 gives 1 and 511 gives 2,
            // where a shift gives 0 and 1. A sixteen-bit destination takes the value as it stands.
            if (shape->alphaWords == 2 && destFull == 255.0f)
                A = (A * 255u + 32767u) / 65535u;
            if (destFull == 255.0f) {
                charon_argb_store8(conversion, Yp, Cb, Cr, A, permuteMap, out8 + column * 4);
            } else {
                charon_argb_store16(conversion, Yp, Cb, Cr, A, permuteMap, out16 + column * 4, destFull);
            }
        }
    }
    return kvImageNoError;
}

#define CharonYUVToARGB(name, layout, full, hasAlpha)                                                         \
    vImage_Error name(const vImage_Buffer *src, const vImage_Buffer *dest, const vImage_YpCbCrToARGB *info,     \
                      const uint8_t permuteMap[4], const uint8_t alpha, vImage_Flags flags)                     \
    {                                                                                                          \
        if (flags & ~charon_vimage_conversion_flags)                                                           \
            return kvImageUnknownFlagsBit;                                                                     \
        return charon_yuv_to_argb(layout, full, src, dest, info, permuteMap, (uint32_t)alpha, hasAlpha, NULL);   \
    }

// Four of the eleven interleaved Y'CbCr-to-ARGB conversions take no alpha argument at all: the shape
// carries one, and the header declares them without the parameter. They are the same call with the
// fixed alpha out of it, so they get the same macro with a different head.
#define CharonYUVToARGBNoAlpha(name, layout, full)                                                            \
    vImage_Error name(const vImage_Buffer *src, const vImage_Buffer *dest, const vImage_YpCbCrToARGB *info,     \
                      const uint8_t permuteMap[4], vImage_Flags flags)                                         \
    {                                                                                                          \
        if (flags & ~charon_vimage_conversion_flags)                                                           \
            return kvImageUnknownFlagsBit;                                                                     \
        return charon_yuv_to_argb(layout, full, src, dest, info, permuteMap, 0, NO, NULL);                      \
    }

CharonYUVToARGB(vImageConvert_422YpCbYpCr8ToARGB8888, CharonYUV422YpCbYpCr8, 255.0f, YES)
CharonYUVToARGB(vImageConvert_422CbYpCrYp8ToARGB8888, CharonYUV422CbYpCrYp8, 255.0f, YES)
CharonYUVToARGB(vImageConvert_444CrYpCb8ToARGB8888, CharonYUV444CrYpCb8, 255.0f, YES)
CharonYUVToARGB(vImageConvert_422CbYpCrYp16ToARGB8888, CharonYUV422CbYpCrYp16, 255.0f, YES)
CharonYUVToARGB(vImageConvert_444CrYpCb10ToARGB8888, CharonYUV444CrYpCb10, 255.0f, YES)
CharonYUVToARGBNoAlpha(vImageConvert_444AYpCbCr8ToARGB8888, CharonYUV444AYpCbCr8, 255.0f)
CharonYUVToARGBNoAlpha(vImageConvert_444CbYpCrA8ToARGB8888, CharonYUV444CbYpCrA8, 255.0f)
CharonYUVToARGBNoAlpha(vImageConvert_444AYpCbCr16ToARGB8888, CharonYUV444AYpCbCr16, 255.0f)

#undef CharonYUVToARGB
#undef CharonYUVToARGBNoAlpha

vImage_Error vImageConvert_444AYpCbCr16ToARGB16U(const vImage_Buffer *src, const vImage_Buffer *dest,
                                                  const vImage_YpCbCrToARGB *info, const uint8_t permuteMap[4],
                                                  vImage_Flags flags)
{
    if (flags & ~charon_vimage_conversion_flags)
        return kvImageUnknownFlagsBit;
    return charon_yuv_to_argb(CharonYUV444AYpCbCr16, 65535.0f, src, dest, info, permuteMap, 0, NO, NULL);
}

vImage_Error vImageConvert_422CbYpCrYp16ToARGB16U(const vImage_Buffer *src, const vImage_Buffer *dest,
                                                  const vImage_YpCbCrToARGB *info, const uint8_t permuteMap[4],
                                                  const uint16_t alpha, vImage_Flags flags)
{
    if (flags & ~charon_vimage_conversion_flags)
        return kvImageUnknownFlagsBit;
    return charon_yuv_to_argb(CharonYUV422CbYpCrYp16, 65535.0f, src, dest, info, permuteMap, alpha, YES, NULL);
}

vImage_Error vImageConvert_444CrYpCb10ToARGB16Q12(const vImage_Buffer *src, const vImage_Buffer *dest,
                                                   const vImage_YpCbCrToARGB *info, const uint8_t permuteMap[4],
                                                   const Pixel_16Q12 alpha, vImage_Flags flags)
{
    if (flags & ~charon_vimage_conversion_flags)
        return kvImageUnknownFlagsBit;
    return charon_yuv_to_argb(CharonYUV444CrYpCb10, 4096.0f, src, dest, info, permuteMap, alpha, YES, NULL);
}

// The unit of this shape is six pixels of one row, so a destination whose width is not a whole number of
// units asks for luma the source has not got: the header's own pseudo-code reads six pixels and writes
// six, and a width of five has no sixth. Measured on the system over a four-row buffer: row 1 is its own
// unit, so nothing carries over from row 0.
vImage_Error vImageConvert_422CrYpCbYpCbYpCbYpCrYpCrYp10ToARGB8888(const vImage_Buffer *src,
                                                                     const vImage_Buffer *dest,
                                                                     const vImage_YpCbCrToARGB *info,
                                                                     const uint8_t permuteMap[4],
                                                                     const uint8_t alpha, vImage_Flags flags)
{
    if (flags & ~charon_vimage_conversion_flags)
        return kvImageUnknownFlagsBit;
    return charon_yuv_to_argb(CharonYUV422v210, 255.0f, src, dest, info, permuteMap, alpha, YES, NULL);
}

vImage_Error vImageConvert_422CrYpCbYpCbYpCbYpCrYpCrYp10ToARGB16Q12(const vImage_Buffer *src,
                                                                      const vImage_Buffer *dest,
                                                                      const vImage_YpCbCrToARGB *info,
                                                                      const uint8_t permuteMap[4],
                                                                      const Pixel_16Q12 alpha, vImage_Flags flags)
{
    if (flags & ~charon_vimage_conversion_flags)
        return kvImageUnknownFlagsBit;
    return charon_yuv_to_argb(CharonYUV422v210, 4096.0f, src, dest, info, permuteMap, alpha, YES, NULL);
}

vImage_Error vImageConvert_422CbYpCrYp8_AA8ToARGB8888(const vImage_Buffer *src, const vImage_Buffer *srcA,
                                                      const vImage_Buffer *dest, const vImage_YpCbCrToARGB *info,
                                                      const uint8_t permuteMap[4], vImage_Flags flags)
{
    if (flags & ~charon_vimage_conversion_flags)
        return kvImageUnknownFlagsBit;
    if (!srcA)
        return kvImageNullPointerArgument;
    // One alpha byte to a pixel, measured: a plane of eight bytes over an eight-pixel row of ten, twenty,
    // thirty ... puts 10, 20, 30 ... into the eight pixels' alpha channels one for one, and a plane
    // narrower than the image is refused with kvImageRoiLargerThanInputBuffer. The header's own
    // pseudo-code writes two alpha bytes and then advances by two, which is a plane half as wide - so
    // the header's text and the system's behaviour disagree here, and the port follows the system, which
    // is the one a caller of the system has to match. facts/Accelerate/vImageYpCbCr.md records it.
    if (srcA->width < src->width || srcA->height < src->height)
        return kvImageRoiLargerThanInputBuffer;
    return charon_yuv_to_argb(CharonYUV422CbYpCrYp8, 255.0f, src, dest, info, permuteMap, 0, NO, srcA);
}

// The 4:2:0 shapes, the only two of the thirteen with no interleaved form: one luma plane and either
// two chroma planes or one. The chroma of a two by two block is the mean of the block's four pixels,
// which is what the header's pseudo-code adds up and divides by four; a block at the right or bottom
// edge of an odd-sized picture averages the pixels it has.
static vImage_Error charon_420_to_argb(const vImage_Buffer *srcYp, const vImage_Buffer *srcCb,
                                       const vImage_Buffer *srcCr, const vImage_Buffer *srcCbCr,
                                       const vImage_Buffer *dest, const vImage_YpCbCrToARGB *info,
                                       const uint8_t *permuteMap, uint8_t alpha, vImage_Flags flags)
{
    static const uint8_t identity[4] = {0, 1, 2, 3};
    if (flags & ~charon_vimage_conversion_flags)
        return kvImageUnknownFlagsBit;
    const CharonToARGB *conversion = charon_to_argb(info);
    if (!srcYp || !dest || !conversion)
        return kvImageNullPointerArgument;
    if (!permuteMap)
        permuteMap = identity;
    else if (!charon_permutation(permuteMap))
        return kvImageInvalidParameter;
    vImagePixelCount width = dest->width, height = dest->height;
    if (srcYp->width < width || srcYp->height < height)
        return kvImageRoiLargerThanInputBuffer;
    vImagePixelCount chromaWidth = (width + 1) / 2, chromaHeight = (height + 1) / 2;
    if (srcCbCr) {
        if (srcCbCr->width < chromaWidth || srcCbCr->height < chromaHeight)
            return kvImageRoiLargerThanInputBuffer;
    } else {
        if (!srcCb || !srcCr)
            return kvImageNullPointerArgument;
        if (srcCb->width < chromaWidth || srcCb->height < chromaHeight
            || srcCr->width < chromaWidth || srcCr->height < chromaHeight)
            return kvImageRoiLargerThanInputBuffer;
    }
    for (vImagePixelCount row = 0; row < height; row++) {
        const uint8_t *luma = (const uint8_t *)srcYp->data + row * srcYp->rowBytes;
        uint8_t *out = (uint8_t *)dest->data + row * dest->rowBytes;
        vImagePixelCount chromaRow = row / 2;
        const uint8_t *cbcr = srcCbCr ? (const uint8_t *)srcCbCr->data + chromaRow * srcCbCr->rowBytes : NULL;
        const uint8_t *cbRow = srcCb ? (const uint8_t *)srcCb->data + chromaRow * srcCb->rowBytes : NULL;
        const uint8_t *crRow = srcCr ? (const uint8_t *)srcCr->data + chromaRow * srcCr->rowBytes : NULL;
        for (vImagePixelCount column = 0; column < width; column++) {
            vImagePixelCount chromaColumn = column / 2;
            float cb = cbcr ? (float)cbcr[chromaColumn * 2] : (float)cbRow[chromaColumn];
            float cr = cbcr ? (float)cbcr[chromaColumn * 2 + 1] : (float)crRow[chromaColumn];
            charon_argb_store8(conversion, (float)luma[column], cb, cr, alpha, permuteMap, out + column * 4);
        }
    }
    return kvImageNoError;
}

vImage_Error vImageConvert_420Yp8_CbCr8ToARGB8888(const vImage_Buffer *srcYp, const vImage_Buffer *srcCbCr,
                                                  const vImage_Buffer *dest, const vImage_YpCbCrToARGB *info,
                                                  const uint8_t permuteMap[4], const uint8_t alpha,
                                                  vImage_Flags flags)
{
    return charon_420_to_argb(srcYp, NULL, NULL, srcCbCr, dest, info, permuteMap, alpha, flags);
}

vImage_Error vImageConvert_420Yp8_Cb8_Cr8ToARGB8888(const vImage_Buffer *srcYp, const vImage_Buffer *srcCb,
                                                    const vImage_Buffer *srcCr, const vImage_Buffer *dest,
                                                    const vImage_YpCbCrToARGB *info, const uint8_t permuteMap[4],
                                                    const uint8_t alpha, vImage_Flags flags)
{
    return charon_420_to_argb(srcYp, srcCb, srcCr, NULL, dest, info, permuteMap, alpha, flags);
}

// ---------------------------------------------------------------------------------------------
// ARGB to Y'CbCr
// ---------------------------------------------------------------------------------------------

// One source pixel's red, green and blue, at the source's own full scale - 255 for an eight-bit pixel,
// 65535 for a sixteen-bit one, 4096 for a Q12 one. The scale itself is already folded into the two
// scales of the conversion the generator built, so the sample is used as it stands.
static void charon_rgb_read(int words, const vImage_Buffer *src, vImagePixelCount row, vImagePixelCount column,
                            const uint8_t *permuteMap, float *rgb)
{
    const uint8_t *in = (const uint8_t *)src->data + row * src->rowBytes;
    if (words == 1) {
        rgb[0] = (float)in[column * 4 + permuteMap[1]];
        rgb[1] = (float)in[column * 4 + permuteMap[2]];
        rgb[2] = (float)in[column * 4 + permuteMap[3]];
    } else {
        const uint16_t *wide = (const uint16_t *)(const void *)in + column * 4;
        rgb[0] = (float)wide[permuteMap[1]];
        rgb[1] = (float)wide[permuteMap[2]];
        rgb[2] = (float)wide[permuteMap[3]];
    }
}

// The luma of one pixel, which every layout writes for every pixel.
static uint32_t charon_luma_of(const CharonToYpCbCr *conversion, const float *rgb)
{
    float Yp, Cb, Cr;
    charon_ypcbcr_of(conversion, rgb[0], rgb[1], rgb[2], &Yp, &Cb, &Cr);
    return charon_encode(Yp, conversion->YpMin, conversion->YpMax);
}

// The chroma of the block a pixel starts, the header's rule: the sum over the block's pixels of the
// same three dot products, divided by the number of them. A block at the right or bottom edge of an
// odd-sized picture has fewer, and the header's own pseudo-code adds up what it has. What is summed is
// the raw dot product, before the scale and the bias, which is what the header's own text adds up -
// CharonYpCbCr.h says why the two must not be confused.
static void charon_chroma_of(const CharonToYpCbCr *conversion, int words, const vImage_Buffer *src,
                             vImagePixelCount width, vImagePixelCount height, vImagePixelCount row,
                             vImagePixelCount column, unsigned across, unsigned down, const uint8_t *permuteMap,
                             uint32_t *Cb, uint32_t *Cr)
{
    float blue = 0.0f, red = 0.0f;
    unsigned counted = 0;
    for (vImagePixelCount step = 0; step < (vImagePixelCount)down; step++) {
        if (row + step >= height)
            continue;
        for (vImagePixelCount other = 0; other < (vImagePixelCount)across; other++) {
            if (column + other >= width)
                continue;
            float rgb[3], one, two;
            charon_rgb_read(words, src, row + step, column + other, permuteMap, rgb);
            charon_ypcbcr_chroma_of(conversion, rgb[0], rgb[1], rgb[2], &one, &two);
            blue += one;
            red += two;
            counted++;
        }
    }
    if (counted == 0)
        counted = 1;
    *Cb = charon_encode(conversion->CbCr_bias + blue * conversion->cScale / (float)counted, conversion->CbCrMin,
                        conversion->CbCrMax);
    *Cr = charon_encode(conversion->CbCr_bias + red * conversion->cScale / (float)counted, conversion->CbCrMin,
                        conversion->CbCrMax);
}

// One source pixel's alpha, at the source's own full scale, which is the fourth of the four the
// permutation map may name.
static uint32_t charon_alpha_of(int words, const vImage_Buffer *src, vImagePixelCount row, vImagePixelCount column,
                                const uint8_t *permuteMap)
{
    const uint8_t *in = (const uint8_t *)src->data + row * src->rowBytes;
    if (words == 1)
        return in[column * 4 + permuteMap[0]];
    return ((const uint16_t *)(const void *)in)[column * 4 + permuteMap[0]];
}

// The eight interleaved layouts, one pair of loops. Every one of them writes a luma for every pixel and,
// where the layout subsamples the chroma, a chroma for every sample; where a pixel's alpha belongs in
// the destination it goes there in the same pass, which is what the header's pseudo-code for
// ARGB8888To422CbYpCrYp8_AA8 does - the alpha plane is written as the luma planes are.
static vImage_Error charon_argb_to_yuv(int layout, int words, const vImage_Buffer *src, const vImage_Buffer *dest,
                                       const vImage_ARGBToYpCbCr *info, const uint8_t *permuteMap,
                                       const vImage_Buffer *destA)
{
    static const uint8_t identity[4] = {0, 1, 2, 3};
    if (!src || !dest || !info)
        return kvImageNullPointerArgument;
    const CharonToYpCbCr *conversion = charon_to_ypcbcr(info);
    if (!conversion)
        return kvImageNullPointerArgument;
    if (!permuteMap)
        permuteMap = identity;
    else if (!charon_permutation(permuteMap))
        return kvImageInvalidParameter;
    const CharonYUVLayout *shape = &charon_yuv_layouts[layout];
    vImagePixelCount width = dest->width, height = dest->height;
    if (src->width < width || src->height < height)
        return kvImageRoiLargerThanInputBuffer;
    // The same rule as the A8 shape's own alpha plane, measured on the system: at least as wide as the
    // image, and one byte to a pixel.
    if (destA && (destA->width < width || destA->height < height))
        return kvImageRoiLargerThanInputBuffer;
    for (vImagePixelCount row = 0; row < height; row++) {
        uint8_t *out = (uint8_t *)dest->data + row * dest->rowBytes;
        uint16_t *wide = (uint16_t *)(void *)out;
        for (vImagePixelCount column = 0; column < width; column++) {
            float rgb[3];
            charon_rgb_read(words, src, row, column, permuteMap, rgb);
            uint32_t luma = charon_luma_of(conversion, rgb);
            uint32_t Cb = 0, Cr = 0;
            int starts = (column % shape->across) == 0;
            if (starts)
                charon_chroma_of(conversion, words, src, width, height, row, column, shape->across, shape->down,
                                 permuteMap, &Cb, &Cr);
            switch (layout) {
            case CharonYUV422YpCbYpCr8: {
                vImagePixelCount pair = (column / 2) * 4;
                out[pair + (column & 1 ? 2 : 0)] = (uint8_t)luma;
                if (starts) {
                    out[pair + 1] = (uint8_t)Cb;
                    out[pair + 3] = (uint8_t)Cr;
                }
                break;
            }
            case CharonYUV422CbYpCrYp8: {
                vImagePixelCount pair = (column / 2) * 4;
                out[pair + (column & 1 ? 3 : 1)] = (uint8_t)luma;
                if (starts) {
                    out[pair] = (uint8_t)Cb;
                    out[pair + 2] = (uint8_t)Cr;
                }
                break;
            }
            case CharonYUV444AYpCbCr8:
                out[column * 4] = (uint8_t)charon_alpha_of(words, src, row, column, permuteMap);
                out[column * 4 + 1] = (uint8_t)luma;
                out[column * 4 + 2] = (uint8_t)Cb;
                out[column * 4 + 3] = (uint8_t)Cr;
                break;
            case CharonYUV444CbYpCrA8:
                out[column * 4] = (uint8_t)Cb;
                out[column * 4 + 1] = (uint8_t)luma;
                out[column * 4 + 2] = (uint8_t)Cr;
                out[column * 4 + 3] = (uint8_t)charon_alpha_of(words, src, row, column, permuteMap);
                break;
            case CharonYUV444CrYpCb8:
                out[column * 3] = (uint8_t)Cr;
                out[column * 3 + 1] = (uint8_t)luma;
                out[column * 3 + 2] = (uint8_t)Cb;
                break;
            case CharonYUV444AYpCbCr16: {
                // An eight-bit source's alpha widened into the sixteen-bit shape by 257, which is the
                // reverse of the narrowing above and what the system does: 32 becomes 8224, 128 becomes
                // 32896 and 255 becomes 65535.
                uint32_t source = charon_alpha_of(words, src, row, column, permuteMap);
                wide[column * 4] = (uint16_t)(words == 1 ? source * 257u : source);
                wide[column * 4 + 1] = (uint16_t)luma;
                wide[column * 4 + 2] = (uint16_t)Cb;
                wide[column * 4 + 3] = (uint16_t)Cr;
                break;
            }
            case CharonYUV422CbYpCrYp16: {
                uint16_t *pair = wide + (column / 2) * 4;
                pair[column & 1 ? 3 : 1] = (uint16_t)luma;
                if (starts) {
                    pair[0] = (uint16_t)Cb;
                    pair[2] = (uint16_t)Cr;
                }
                break;
            }
            default:
                break;
            }
        }
        // One alpha byte to a pixel, the same rule the A8 shape's own source plane follows and the same
        // one the system was measured on: eight input alphas of 30 to 37 come back as eight plane bytes
        // of 30 to 37, in order.
        if (destA) {
            uint8_t *alphaRow = (uint8_t *)destA->data + row * destA->rowBytes;
            for (vImagePixelCount column = 0; column < width; column++)
                alphaRow[column] = (uint8_t)charon_alpha_of(words, src, row, column, permuteMap);
        }
    }
    return kvImageNoError;
}

#define CharonARGBToYUV(name, layout, words)                                                                  \
    vImage_Error name(const vImage_Buffer *src, const vImage_Buffer *dest, const vImage_ARGBToYpCbCr *info,     \
                      const uint8_t permuteMap[4], vImage_Flags flags)                                         \
    {                                                                                                          \
        if (flags & ~charon_vimage_conversion_flags)                                                           \
            return kvImageUnknownFlagsBit;                                                                     \
        return charon_argb_to_yuv(layout, words, src, dest, info, permuteMap, NULL);                           \
    }

CharonARGBToYUV(vImageConvert_ARGB8888To422YpCbYpCr8, CharonYUV422YpCbYpCr8, 1)
CharonARGBToYUV(vImageConvert_ARGB8888To422CbYpCrYp8, CharonYUV422CbYpCrYp8, 1)
CharonARGBToYUV(vImageConvert_ARGB8888To444AYpCbCr8, CharonYUV444AYpCbCr8, 1)
CharonARGBToYUV(vImageConvert_ARGB8888To444CbYpCrA8, CharonYUV444CbYpCrA8, 1)
CharonARGBToYUV(vImageConvert_ARGB8888To444CrYpCb8, CharonYUV444CrYpCb8, 1)
CharonARGBToYUV(vImageConvert_ARGB8888To444AYpCbCr16, CharonYUV444AYpCbCr16, 1)
CharonARGBToYUV(vImageConvert_ARGB8888To422CbYpCrYp16, CharonYUV422CbYpCrYp16, 1)

#undef CharonARGBToYUV

vImage_Error vImageConvert_ARGB16UTo444AYpCbCr16(const vImage_Buffer *src, const vImage_Buffer *dest,
                                                  const vImage_ARGBToYpCbCr *info, const uint8_t permuteMap[4],
                                                  vImage_Flags flags)
{
    if (flags & ~charon_vimage_conversion_flags)
        return kvImageUnknownFlagsBit;
    return charon_argb_to_yuv(CharonYUV444AYpCbCr16, 2, src, dest, info, permuteMap, NULL);
}

vImage_Error vImageConvert_ARGB16UTo422CbYpCrYp16(const vImage_Buffer *src, const vImage_Buffer *dest,
                                                  const vImage_ARGBToYpCbCr *info, const uint8_t permuteMap[4],
                                                  vImage_Flags flags)
{
    if (flags & ~charon_vimage_conversion_flags)
        return kvImageUnknownFlagsBit;
    return charon_argb_to_yuv(CharonYUV422CbYpCrYp16, 2, src, dest, info, permuteMap, NULL);
}

vImage_Error vImageConvert_ARGB8888To422CbYpCrYp8_AA8(const vImage_Buffer *src, const vImage_Buffer *dest,
                                                      const vImage_Buffer *destA, const vImage_ARGBToYpCbCr *info,
                                                      const uint8_t permuteMap[4], vImage_Flags flags)
{
    if (flags & ~charon_vimage_conversion_flags)
        return kvImageUnknownFlagsBit;
    if (!destA)
        return kvImageNullPointerArgument;
    return charon_argb_to_yuv(CharonYUV422CbYpCrYp8, 1, src, dest, info, permuteMap, destA);
}

// The two 10-bit shapes are the same word layout as the others and the same dot products, but each
// pixel's three channels share one word, so they are written a pixel at a time rather than a channel at
// a time: v410 packs them, v210 gathers six pixels and three of each chroma into sixteen words.
static vImage_Error charon_argb_to_v410(int words, const vImage_Buffer *src, const vImage_Buffer *dest,
                                        const vImage_ARGBToYpCbCr *info, const uint8_t *permuteMap)
{
    static const uint8_t identity[4] = {0, 1, 2, 3};
    if (!src || !dest || !info)
        return kvImageNullPointerArgument;
    const CharonToYpCbCr *conversion = charon_to_ypcbcr(info);
    if (!conversion)
        return kvImageNullPointerArgument;
    if (!permuteMap)
        permuteMap = identity;
    else if (!charon_permutation(permuteMap))
        return kvImageInvalidParameter;
    vImagePixelCount width = dest->width, height = dest->height;
    if (src->width < width || src->height < height)
        return kvImageRoiLargerThanInputBuffer;
    for (vImagePixelCount row = 0; row < height; row++) {
        uint32_t *out = (uint32_t *)(void *)((uint8_t *)dest->data + row * dest->rowBytes);
        for (vImagePixelCount column = 0; column < width; column++) {
            float rgb[3], Yp, Cb, Cr;
            charon_rgb_read(words, src, row, column, permuteMap, rgb);
            charon_ypcbcr_of(conversion, rgb[0], rgb[1], rgb[2], &Yp, &Cb, &Cr);
            out[column] = charon_v410_join(charon_encode(Yp, conversion->YpMin, conversion->YpMax),
                                           charon_encode(Cb, conversion->CbCrMin, conversion->CbCrMax),
                                           charon_encode(Cr, conversion->CbCrMin, conversion->CbCrMax));
        }
    }
    return kvImageNoError;
}

vImage_Error vImageConvert_ARGB8888To444CrYpCb10(const vImage_Buffer *src, const vImage_Buffer *dest,
                                                 const vImage_ARGBToYpCbCr *info, const uint8_t permuteMap[4],
                                                 vImage_Flags flags)
{
    if (flags & ~charon_vimage_conversion_flags)
        return kvImageUnknownFlagsBit;
    return charon_argb_to_v410(1, src, dest, info, permuteMap);
}

vImage_Error vImageConvert_ARGB16Q12To444CrYpCb10(const vImage_Buffer *src, const vImage_Buffer *dest,
                                                  const vImage_ARGBToYpCbCr *info, const uint8_t permuteMap[4],
                                                  vImage_Flags flags)
{
    if (flags & ~charon_vimage_conversion_flags)
        return kvImageUnknownFlagsBit;
    return charon_argb_to_v410(3, src, dest, info, permuteMap);
}

static vImage_Error charon_argb_to_v210(int words, const vImage_Buffer *src, const vImage_Buffer *dest,
                                        const vImage_ARGBToYpCbCr *info, const uint8_t *permuteMap)
{
    static const uint8_t identity[4] = {0, 1, 2, 3};
    if (!src || !dest || !info)
        return kvImageNullPointerArgument;
    const CharonToYpCbCr *conversion = charon_to_ypcbcr(info);
    if (!conversion)
        return kvImageNullPointerArgument;
    if (!permuteMap)
        permuteMap = identity;
    else if (!charon_permutation(permuteMap))
        return kvImageInvalidParameter;
    vImagePixelCount width = dest->width, height = dest->height;
    if (src->width < width || src->height < height)
        return kvImageRoiLargerThanInputBuffer;
    if (width % 6)
        return kvImageRoiLargerThanInputBuffer;
    for (vImagePixelCount row = 0; row < height; row++) {
        uint32_t *out = (uint32_t *)(void *)((uint8_t *)dest->data + row * dest->rowBytes);
        for (vImagePixelCount column = 0; column < width; column += 6) {
            uint32_t Yp[6], Cb[3], Cr[3];
            for (vImagePixelCount index = 0; index < 6; index++) {
                float rgb[3];
                charon_rgb_read(words, src, row, column + index, permuteMap, rgb);
                Yp[index] = charon_encode(charon_ypcbcr_luma_of(conversion, rgb[0], rgb[1], rgb[2]),
                                          conversion->YpMin, conversion->YpMax);
            }
            for (vImagePixelCount index = 0; index < 3; index++) {
                // The header's own pseudo-code: Cb0 is the mean of pixels 0 and 1 of THIS row, Cb1 that
                // of 2 and 3, Cb2 that of 4 and 5. The chroma of a v210 unit is not shared with the row
                // below it.
                charon_chroma_of(conversion, words, src, width, height, row, column + index * 2, 2, 1, permuteMap,
                                 &Cb[index], &Cr[index]);
            }
            charon_v210_join(out + (column / 6) * 4, Yp, Cb, Cr);
        }
    }
    return kvImageNoError;
}

vImage_Error vImageConvert_ARGB8888To422CrYpCbYpCbYpCbYpCrYpCrYp10(const vImage_Buffer *src,
                                                                     const vImage_Buffer *dest,
                                                                     const vImage_ARGBToYpCbCr *info,
                                                                     const uint8_t permuteMap[4], vImage_Flags flags)
{
    if (flags & ~charon_vimage_conversion_flags)
        return kvImageUnknownFlagsBit;
    return charon_argb_to_v210(1, src, dest, info, permuteMap);
}

vImage_Error vImageConvert_ARGB16Q12To422CrYpCbYpCbYpCbYpCrYpCrYp10(const vImage_Buffer *src,
                                                                      const vImage_Buffer *dest,
                                                                      const vImage_ARGBToYpCbCr *info,
                                                                      const uint8_t permuteMap[4], vImage_Flags flags)
{
    if (flags & ~charon_vimage_conversion_flags)
        return kvImageUnknownFlagsBit;
    return charon_argb_to_v210(3, src, dest, info, permuteMap);
}

// The 4:2:0 shapes again, the other way round: the luma plane is written for every pixel and the chroma
// planes for every two by two block, whose chroma is the mean of the four pixels' own.
static vImage_Error charon_argb_to_420(const vImage_Buffer *src, const vImage_Buffer *destYp,
                                       const vImage_Buffer *destCb, const vImage_Buffer *destCr,
                                       const vImage_Buffer *destCbCr, const vImage_ARGBToYpCbCr *info,
                                       const uint8_t *permuteMap, vImage_Flags flags)
{
    static const uint8_t identity[4] = {0, 1, 2, 3};
    if (flags & ~charon_vimage_conversion_flags)
        return kvImageUnknownFlagsBit;
    const CharonToYpCbCr *conversion = charon_to_ypcbcr(info);
    if (!src || !destYp || !conversion)
        return kvImageNullPointerArgument;
    if (!permuteMap)
        permuteMap = identity;
    else if (!charon_permutation(permuteMap))
        return kvImageInvalidParameter;
    vImagePixelCount width = destYp->width, height = destYp->height;
    if (src->width < width || src->height < height)
        return kvImageRoiLargerThanInputBuffer;
    vImagePixelCount chromaWidth = (width + 1) / 2, chromaHeight = (height + 1) / 2;
    if (destCbCr) {
        if (destCbCr->width < chromaWidth || destCbCr->height < chromaHeight)
            return kvImageRoiLargerThanInputBuffer;
    } else {
        if (!destCb || !destCr)
            return kvImageNullPointerArgument;
        if (destCb->width < chromaWidth || destCb->height < chromaHeight
            || destCr->width < chromaWidth || destCr->height < chromaHeight)
            return kvImageRoiLargerThanInputBuffer;
    }
    for (vImagePixelCount row = 0; row < height; row++) {
        const uint8_t *in = (const uint8_t *)src->data + row * src->rowBytes;
        uint8_t *luma = (uint8_t *)destYp->data + row * destYp->rowBytes;
        for (vImagePixelCount column = 0; column < width; column++) {
            const uint8_t *pixel = in + column * 4;
            float red = (float)pixel[permuteMap[1]], green = (float)pixel[permuteMap[2]],
                  blue = (float)pixel[permuteMap[3]];
            luma[column] = (uint8_t)charon_luma_of(conversion, (float[3]){red, green, blue});
        }
    }
    for (vImagePixelCount row = 0; row < chromaHeight; row++) {
        uint8_t *cbcr = destCbCr ? (uint8_t *)destCbCr->data + row * destCbCr->rowBytes : NULL;
        uint8_t *cbRow = destCb ? (uint8_t *)destCb->data + row * destCb->rowBytes : NULL;
        uint8_t *crRow = destCr ? (uint8_t *)destCr->data + row * destCr->rowBytes : NULL;
        for (vImagePixelCount column = 0; column < chromaWidth; column++) {
            uint32_t Cb, Cr;
            charon_chroma_of(conversion, 1, src, width, height, row * 2, column * 2, 2, 2, permuteMap, &Cb, &Cr);
            if (cbcr) {
                cbcr[column * 2] = (uint8_t)Cb;
                cbcr[column * 2 + 1] = (uint8_t)Cr;
            } else {
                cbRow[column] = (uint8_t)Cb;
                crRow[column] = (uint8_t)Cr;
            }
        }
    }
    return kvImageNoError;
}

vImage_Error vImageConvert_ARGB8888To420Yp8_CbCr8(const vImage_Buffer *src, const vImage_Buffer *destYp,
                                                  const vImage_Buffer *destCbCr, const vImage_ARGBToYpCbCr *info,
                                                  const uint8_t permuteMap[4], vImage_Flags flags)
{
    return charon_argb_to_420(src, destYp, NULL, NULL, destCbCr, info, permuteMap, flags);
}

vImage_Error vImageConvert_ARGB8888To420Yp8_Cb8_Cr8(const vImage_Buffer *src, const vImage_Buffer *destYp,
                                                    const vImage_Buffer *destCb, const vImage_Buffer *destCr,
                                                    const vImage_ARGBToYpCbCr *info, const uint8_t permuteMap[4],
                                                    vImage_Flags flags)
{
    return charon_argb_to_420(src, destYp, destCb, destCr, NULL, info, permuteMap, flags);
}

vImage_Error vImageExtractChannel_ARGB8888(const vImage_Buffer *src, const vImage_Buffer *dest, long channelIndex,
                                           vImage_Flags flags)
{
    static const vImage_Flags charon_channel_flags = kvImageDoNotTile | kvImageGetTempBufferSize
                                                     | kvImagePrintDiagnosticsToConsole;
    if (flags & ~charon_channel_flags)
        return kvImageUnknownFlagsBit;
    if (flags & kvImageGetTempBufferSize)
        return 0;
    if (!src || !dest)
        return kvImageNullPointerArgument;
    if (channelIndex < 0 || channelIndex > 3)
        return kvImageInvalidParameter;
    if (src->width < dest->width || src->height < dest->height)
        return kvImageRoiLargerThanInputBuffer;
    for (vImagePixelCount row = 0; row < dest->height; row++) {
        const uint8_t *in = (const uint8_t *)src->data + row * src->rowBytes;
        uint8_t *out = (uint8_t *)dest->data + row * dest->rowBytes;
        for (vImagePixelCount column = 0; column < dest->width; column++)
            out[column] = in[column * 4 + (size_t)channelIndex];
    }
    return kvImageNoError;
}
