#include "../revenant_impl.h"
#import <CoreVideo/CoreVideo.h>
#import <CoreFoundation/CoreFoundation.h>

Boolean BACKPORT_IMPL(CVIsCompressedPixelFormatAvailable)(OSType pixelFormatType)
{
    (void)pixelFormatType;
    return false;
}
