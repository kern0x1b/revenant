#include "../revenant_impl.h"
#import <CoreGraphics/CoreGraphics.h>

bool BACKPORT_IMPL(CGColorSpaceUsesExtendedRange)(CGColorSpaceRef space)
{
    return false;
}
