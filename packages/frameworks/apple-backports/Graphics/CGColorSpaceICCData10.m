#import <CoreGraphics/CoreGraphics.h>

CFDataRef CGColorSpaceCopyICCData(CGColorSpaceRef space)
{
    return CGColorSpaceCopyICCProfile(space);
}
