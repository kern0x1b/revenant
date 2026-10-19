// The quarter turns of vImage at 7.0: vImageRotate90_ARGB16U and vImageRotate90_ARGB16S.
//
// The mapping and the loop are CharonGeometry.h's, measured over eight shapes both destination ways; this
// file is the two shapes of it that arrived at 7.0. Nothing in a quarter turn resamples, so the loop moves
// bytes: a destination pixel is one source pixel, copied, or the backColor where the source does not reach.

#import <Accelerate/Accelerate.h>
#include "CharonGeometry.h"

#pragma clang diagnostic ignored "-Wunguarded-availability-new"
#pragma clang diagnostic ignored "-Wpointer-bool-conversion"
#pragma clang diagnostic ignored "-Wnonnull"

vImage_Error vImageRotate90_ARGB16U(const vImage_Buffer *src, const vImage_Buffer *dest, uint8_t rotationConstant,
                                    const Pixel_ARGB_16U backColor, vImage_Flags flags)
{
    vImage_Error ready = charon_turn_ready(src, dest, rotationConstant);
    if (ready != kvImageNoError)
        return ready;
    return charon_turn_run(src, dest, rotationConstant, backColor, 8, flags);
}

vImage_Error vImageRotate90_ARGB16S(const vImage_Buffer *src, const vImage_Buffer *dest, uint8_t rotationConstant,
                                    const Pixel_ARGB_16S backColor, vImage_Flags flags)
{
    vImage_Error ready = charon_turn_ready(src, dest, rotationConstant);
    if (ready != kvImageNoError)
        return ready;
    return charon_turn_run(src, dest, rotationConstant, backColor, 8, flags);
}
