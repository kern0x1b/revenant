#include "../revenant_impl.h"
#import <CoreVideo/CoreVideo.h>
#import <CoreFoundation/CoreFoundation.h>

extern CFDictionaryRef CVPixelBufferGetAttributes(CVPixelBufferRef pixelBuffer);

CFDictionaryRef BACKPORT_IMPL(CVPixelBufferCopyCreationAttributes)(CVPixelBufferRef pixelBuffer)
{
    CFDictionaryRef found = CVPixelBufferGetAttributes(pixelBuffer);
    if (!found) return CFDictionaryCreate(kCFAllocatorDefault, NULL, NULL, 0, NULL, NULL);
    return CFDictionaryCreateCopy(kCFAllocatorDefault, found);
}
