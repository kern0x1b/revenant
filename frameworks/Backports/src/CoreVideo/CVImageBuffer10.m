#include "../revenant_impl.h"
#import <CoreVideo/CoreVideo.h>
#import <CoreGraphics/CoreGraphics.h>
#import <CoreFoundation/CoreFoundation.h>

CGColorSpaceRef BACKPORT_IMPL(CVImageBufferCreateColorSpaceFromAttachments)(CFDictionaryRef attachments)
{
    if (!attachments) return NULL;
    CFTypeRef profile = CFDictionaryGetValue(attachments, kCVImageBufferICCProfileKey);
    if (!profile || CFGetTypeID(profile) != CFDataGetTypeID()) return NULL;
    return CGColorSpaceCreateWithICCData((CFDataRef)profile);
}
