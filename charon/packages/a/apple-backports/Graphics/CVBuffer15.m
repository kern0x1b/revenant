// The attachment readers iOS 15 added, built on the ones the release itself carries.
//
// iOS 6.1.3 and iOS 4.3 both export CVBufferGetAttachment and CVBufferGetAttachments (measured on
// the armv7 shared cache of each through the export trie: 204 and 178 CoreVideo exports), and
// neither carries a single CVBuffer*Copy* or CVBufferHas* name. Each function here is the release's
// own reader with the ownership the iOS 15 header documents put on top of it, so the answer comes
// from the release's attachment store and not from this file.
#import <CoreVideo/CoreVideo.h>
#import <CoreFoundation/CoreFoundation.h>

// The iOS 15 header marks this CV_RETURNS_RETAINED and the caller releases what it gets. The
// release's reader hands back a dictionary it owns, so the copy is what carries the ownership.
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
    // A CF object has no generic copy, so the copy is made of the type the release stored: the types
    // an attachment of an image buffer is a string, a data, a dictionary or an array, and a retain
    // of anything else, which is what the release's own retain count then protects.
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
