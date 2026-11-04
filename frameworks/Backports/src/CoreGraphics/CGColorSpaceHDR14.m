#include "../revenant_impl.h"
#import <CoreGraphics/CoreGraphics.h>

bool BACKPORT_IMPL(CGColorSpaceUsesITUR_2100TF)(CGColorSpaceRef space)
{
    if (!space)
        return false;
    if (@available(iOS 14.0, *)) {
        CFStringRef name = CGColorSpaceCopyName(space);
        bool uses = name && (CFEqual(name, kCGColorSpaceITUR_2100_PQ) || CFEqual(name, kCGColorSpaceITUR_2100_HLG));
        if (name)
            CFRelease(name);
        return uses;
    }
    return false;
}
