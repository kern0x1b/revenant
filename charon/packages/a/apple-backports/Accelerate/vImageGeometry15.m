// The quarter turns of vImage at 15.0: the three half-precision shapes - vImageRotate90_ARGB16F over four
// channels, vImageRotate90_CbCr16F over two, vImageRotate90_Planar16F over one.
//
// The mapping and the loop are CharonGeometry.h's, and the half-precision shapes need nothing out of
// CharonVImageFixed.h: a quarter turn copies a pixel rather than computing one, so there is no half to be
// converted at all and the sixteen bits of a channel move as sixteen bits. That header is in the tree for
// the *other* half-precision work in this family, where a value is computed and does have to be rounded to
// the nearest half.
//
// kvImageUseFP16Accumulator is accepted on these three, as the header says, and changes nothing here: it
// is documented as making the *internal filtering* use half-precision arithmetic, and a quarter turn has no
// filtering. Saying so is better than silently ignoring a flag a caller set.

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
