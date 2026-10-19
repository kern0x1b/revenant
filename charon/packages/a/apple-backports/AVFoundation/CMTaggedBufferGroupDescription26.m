// CMTaggedBufferGroupFormatDescriptionCreateForTaggedBufferGroupWithExtensions, of 26.0. It is its own object
// because the other four functions of the description are of 18.0: see CMTaggedBufferGroupDescription17.m,
// whose header comment says what the description is and how it was measured.
#import "CharonCMTaggedBufferGroupEntries.h"

OSStatus CMTaggedBufferGroupFormatDescriptionCreateForTaggedBufferGroupWithExtensions(
    CFAllocatorRef CM_NULLABLE allocator, CMTaggedBufferGroupRef CM_NONNULL taggedBufferGroup,
    CFDictionaryRef CM_NULLABLE extensions,
    CMTaggedBufferGroupFormatDescriptionRef CM_NULLABLE * CM_NONNULL formatDescriptionOut)
{
    if (!formatDescriptionOut)
        return kCMFormatDescriptionError_InvalidParameter;

    // The caller's extensions keep their own keys, and ours is added alongside them rather than over
    // them, so a caller can read back what it passed. With a NULL dictionary this is just our key.
    CFMutableDictionaryRef payload = NULL;
    if (extensions)
        payload = CFDictionaryCreateMutableCopy(kCFAllocatorDefault, 0, extensions);
    else
        payload = CFDictionaryCreateMutable(kCFAllocatorDefault, 0, &kCFTypeDictionaryKeyCallBacks,
                                            &kCFTypeDictionaryValueCallBacks);

    // A NULL group is not a failure: the host answers 0 and hands back a real description that matches
    // nothing, and the reason is visible here - there are no entries to record. The array is empty, not
    // absent, so the description is a description of nothing rather than of an unknown.
    CFDataRef entries = CharonCopyEntriesData(taggedBufferGroup);
    CFDictionarySetValue(payload, CharonEntriesKey, entries);
    CFRelease(entries);

    CMFormatDescriptionRef description = NULL;
    OSStatus status = CMFormatDescriptionCreate(allocator, kCMMediaType_Video, CharonTaggedBufferGroupSubtype,
                                                payload, &description);
    CFRelease(payload);
    if (status)
        return status;
    *formatDescriptionOut = description;
    return noErr;
}
