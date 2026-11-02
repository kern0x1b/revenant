#import "RevenantScale.h"

vImage_Error vImageScale_Planar16U(const vImage_Buffer *src, const vImage_Buffer *dest, void *tempBuffer, vImage_Flags flags)
{
    return RevenantScaleRun16(src, dest, 1, flags);
}
