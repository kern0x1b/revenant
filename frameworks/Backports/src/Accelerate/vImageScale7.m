#import "RevenantScale.h"

vImage_Error vImageScale_ARGB16U(const vImage_Buffer *src, const vImage_Buffer *dest, void *tempBuffer, vImage_Flags flags)
{
    return RevenantScaleRun16(src, dest, 4, flags);
}
