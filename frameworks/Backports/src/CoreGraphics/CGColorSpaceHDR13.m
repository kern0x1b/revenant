#include "../revenant_impl.h"
#import <CoreGraphics/CoreGraphics.h>

bool BACKPORT_IMPL(CGColorSpaceIsHDR)(CGColorSpaceRef space)
{
    return false;
}
