#import <Accelerate/Accelerate.h>
#include "RevenantGeometry.h"

#pragma clang diagnostic ignored "-Wunguarded-availability-new"
#pragma clang diagnostic ignored "-Wpointer-bool-conversion"
#pragma clang diagnostic ignored "-Wnonnull"

vImage_Error vImageRotate90_ARGB16U(const vImage_Buffer *src, const vImage_Buffer *dest, uint8_t rotationConstant,
                                    const Pixel_ARGB_16U backColor, vImage_Flags flags)
{
    vImage_Error ready = revenant_turn_ready(src, dest, rotationConstant);
    if (ready != kvImageNoError)
        return ready;
    return revenant_turn_run(src, dest, rotationConstant, backColor, 8, flags);
}

vImage_Error vImageRotate90_ARGB16S(const vImage_Buffer *src, const vImage_Buffer *dest, uint8_t rotationConstant,
                                    const Pixel_ARGB_16S backColor, vImage_Flags flags)
{
    vImage_Error ready = revenant_turn_ready(src, dest, rotationConstant);
    if (ready != kvImageNoError)
        return ready;
    return revenant_turn_run(src, dest, rotationConstant, backColor, 8, flags);
}
