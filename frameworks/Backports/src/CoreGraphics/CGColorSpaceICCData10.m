#include "../revenant_impl.h"
#import <CoreGraphics/CoreGraphics.h>

CFDataRef BACKPORT_IMPL(CGColorSpaceCopyICCData)(CGColorSpaceRef space)
{
    return CGColorSpaceCopyICCProfile(space);
}
