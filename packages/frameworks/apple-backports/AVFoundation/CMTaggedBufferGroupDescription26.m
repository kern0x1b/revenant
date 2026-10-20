#import "RevenantCMTaggedBufferGroupEntries.h"

OSStatus CMTaggedBufferGroupFormatDescriptionCreateForTaggedBufferGroupWithExtensions(
    CFAllocatorRef CM_NULLABLE allocator, CMTaggedBufferGroupRef CM_NONNULL taggedBufferGroup,
    CFDictionaryRef CM_NULLABLE extensions,
    CMTaggedBufferGroupFormatDescriptionRef CM_NULLABLE * CM_NONNULL formatDescriptionOut)
{
    if (!formatDescriptionOut)
        return kCMFormatDescriptionError_InvalidParameter;

    CFMutableDictionaryRef payload = NULL;
    if (extensions)
        payload = CFDictionaryCreateMutableCopy(kCFAllocatorDefault, 0, extensions);
    else
        payload = CFDictionaryCreateMutable(kCFAllocatorDefault, 0, &kCFTypeDictionaryKeyCallBacks,
                                            &kCFTypeDictionaryValueCallBacks);

    CFDataRef entries = RevenantCopyEntriesData(taggedBufferGroup);
    CFDictionarySetValue(payload, RevenantEntriesKey, entries);
    CFRelease(entries);

    CMFormatDescriptionRef description = NULL;
    OSStatus status = CMFormatDescriptionCreate(allocator, kCMMediaType_Video, RevenantTaggedBufferGroupSubtype,
                                                payload, &description);
    CFRelease(payload);
    if (status)
        return status;
    *formatDescriptionOut = description;
    return noErr;
}
