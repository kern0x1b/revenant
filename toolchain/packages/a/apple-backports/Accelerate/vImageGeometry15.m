#import <Accelerate/Accelerate.h>
#include "CharonGeometry.h"

#pragma clang diagnostic ignored "-Wunguarded-availability-new"
#pragma clang diagnostic ignored "-Wpointer-bool-conversion"
#pragma clang diagnostic ignored "-Wnonnull"

vImage_Error vImageRotate90_ARGB16F(const vImage_Buffer *src, const vImage_Buffer *dest, uint8_t rotationConstant,
                                    const Pixel_ARGB_16F backColor, vImage_Flags flags)
{
    vImage_Error ready = charon_turn_ready(src, dest, rotationConstant);
    if (ready != kvImageNoError)
        return ready;
    return charon_turn_run(src, dest, rotationConstant, backColor, 8, flags);
}

vImage_Error vImageRotate90_CbCr16F(const vImage_Buffer *src, const vImage_Buffer *dest, uint8_t rotationConstant,
                                    const Pixel_16F16F backColor, vImage_Flags flags)
{
    vImage_Error ready = charon_turn_ready(src, dest, rotationConstant);
    if (ready != kvImageNoError)
        return ready;
    return charon_turn_run(src, dest, rotationConstant, backColor, 4, flags);
}

vImage_Error vImageRotate90_Planar16F(const vImage_Buffer *src, const vImage_Buffer *dest, uint8_t rotationConstant,
                                      const Pixel_16F backColor, vImage_Flags flags)
{
    vImage_Error ready = charon_turn_ready(src, dest, rotationConstant);
    if (ready != kvImageNoError)
        return ready;
    return charon_turn_run(src, dest, rotationConstant, &backColor, 2, flags);
}
