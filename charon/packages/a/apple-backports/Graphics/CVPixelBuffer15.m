// The creation-attribute reader iOS 15 added, built on the one the release itself carries.
//
// iOS 6.1.3 exports CVPixelBufferGetAttributes, and iOS 4.3 does too; the header of iOS 16.4 no
// longer declares it, so it is declared here as the private entry point it is. That function is the
// release's own dictionary of the attributes its pixel buffer was created with, which is what
// CVPixelBufferCopyCreationAttributes answers, so the answer is the release's and not this file's.
//
// The iOS 15 header marks the result CV_NONNULL and CV_RETURNS_RETAINED: the caller releases it, and
// never sees NULL. A buffer whose own dictionary the release declines to produce still gets the
// empty dictionary that is the truth about it, because there is no second answer to give.
#import <CoreVideo/CoreVideo.h>
#import <CoreFoundation/CoreFoundation.h>

// The release's own function, declared here because no SDK header declares it. It hands back the
// dictionary the release owns, which is why the copy below is what carries the ownership.
extern CFDictionaryRef CVPixelBufferGetAttributes(CVPixelBufferRef pixelBuffer);

CFDictionaryRef CVPixelBufferCopyCreationAttributes(CVPixelBufferRef pixelBuffer)
{
    CFDictionaryRef found = CVPixelBufferGetAttributes(pixelBuffer);
    if (!found) return CFDictionaryCreate(kCFAllocatorDefault, NULL, NULL, 0, NULL, NULL);
    return CFDictionaryCreateCopy(kCFAllocatorDefault, found);
}
