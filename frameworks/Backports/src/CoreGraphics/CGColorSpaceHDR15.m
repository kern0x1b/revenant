#include "../revenant_impl.h"
#import <CoreGraphics/CoreGraphics.h>

bool BACKPORT_IMPL(CGColorSpaceIsHLGBased)(CGColorSpaceRef space)
{
    return false;
}

bool BACKPORT_IMPL(CGColorSpaceIsPQBased)(CGColorSpaceRef space)
{
    return false;
}
