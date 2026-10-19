#import <CoreVideo/CoreVideo.h>
#import <CoreFoundation/CoreFoundation.h>

CFDictionaryRef CVBufferCopyAttachments(CVBufferRef buffer, CVAttachmentMode attachmentMode)
{
    CFDictionaryRef found = CVBufferGetAttachments(buffer, attachmentMode);
    return found ? CFDictionaryCreateCopy(kCFAllocatorDefault, found) : NULL;
}

CFTypeRef CVBufferCopyAttachment(CVBufferRef buffer, CFStringRef key, CVAttachmentMode *attachmentMode)
{
    CVAttachmentMode foundMode = kCVAttachmentMode_ShouldNotPropagate;
    CFTypeRef found = CVBufferGetAttachment(buffer, key, &foundMode);
    if (attachmentMode) *attachmentMode = foundMode;
    if (!found) return NULL;
    CFTypeID type = CFGetTypeID(found);
    if (type == CFStringGetTypeID()) return CFStringCreateCopy(kCFAllocatorDefault, (CFStringRef)found);
    if (type == CFDataGetTypeID()) return CFDataCreateCopy(kCFAllocatorDefault, (CFDataRef)found);
    if (type == CFDictionaryGetTypeID()) return CFDictionaryCreateCopy(kCFAllocatorDefault, (CFDictionaryRef)found);
    if (type == CFArrayGetTypeID()) return CFArrayCreateCopy(kCFAllocatorDefault, (CFArrayRef)found);
    return CFRetain(found);
}

Boolean CVBufferHasAttachment(CVBufferRef buffer, CFStringRef key)
{
    return CVBufferGetAttachment(buffer, key, NULL) != NULL ? true : false;
}
