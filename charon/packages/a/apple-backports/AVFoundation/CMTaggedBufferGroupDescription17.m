#import <CoreMedia/CoreMedia.h>
#import <CoreFoundation/CoreFoundation.h>
#import "CharonCMTag26.h"
#import "CharonCMTagSupport.h"
#import "CharonCMTaggedBufferGroup26.h"
#import <Foundation/Foundation.h>

#import "CharonCMTaggedBufferGroupEntries.h"

OSStatus CMTaggedBufferGroupFormatDescriptionCreateForTaggedBufferGroup(
    CFAllocatorRef CM_NULLABLE allocator, CMTaggedBufferGroupRef CM_NONNULL taggedBufferGroup,
    CMTaggedBufferGroupFormatDescriptionRef CM_NULLABLE * CM_NONNULL formatDescriptionOut)
{
    return CMTaggedBufferGroupFormatDescriptionCreateForTaggedBufferGroupWithExtensions(
        allocator, taggedBufferGroup, NULL, formatDescriptionOut);
}

Boolean CMTaggedBufferGroupFormatDescriptionMatchesTaggedBufferGroup(
    CMTaggedBufferGroupFormatDescriptionRef CM_NONNULL desc,
    CMTaggedBufferGroupRef CM_NONNULL taggedBufferGroup)
{
    if (!desc || !taggedBufferGroup)
        return false;

    CFDictionaryRef extensions = CMFormatDescriptionGetExtensions(desc);
    if (!extensions)
        return false;
    CFDataRef recorded = (CFDataRef)CFDictionaryGetValue(extensions, CharonEntriesKey);
    if (!recorded)
        return false;

    CharonCMTaggedBufferGroup *group = (__bridge CharonCMTaggedBufferGroup *)taggedBufferGroup;
    NSArray *collections = group.charon_collections;
    if ((CFIndex)collections.count != CharonEntriesDataCount(recorded))
        return false;

    for (CFIndex index = 0; index < (CFIndex)collections.count; index++) {
        CMItemCount theirCount = 0;
        const CMTag *theirTags = NULL;
        if (!CharonEntriesDataAtIndex(recorded, index, &theirCount, &theirTags))
            return false;
        CharonCMTagCollection *mine = (CharonCMTagCollection *)collections[index];
        if ((CMItemCount)mine.charon_count != theirCount)
            return false;
        const CMTag *myTags = mine.charon_tags;
        for (NSUInteger tag = 0; tag < mine.charon_count; tag++) {
            if (!charon_tag_equal(myTags[tag], theirTags[tag]))
                return false;
        }
    }
    return true;
}

OSStatus CMSampleBufferCreateForTaggedBufferGroup(
    CFAllocatorRef CM_NULLABLE allocator, CMTaggedBufferGroupRef CM_NONNULL taggedBufferGroup,
    CMTime sbufPTS, CMTime sbufDuration,
    CMTaggedBufferGroupFormatDescriptionRef CM_NONNULL formatDescription,
    CMSampleBufferRef CM_NULLABLE * CM_NONNULL sBufOut)
{
    if (!sBufOut)
        return kCMFormatDescriptionError_InvalidParameter;

    CMBlockBufferRef backing = NULL;
    OSStatus status = CMBlockBufferCreateEmpty(kCFAllocatorDefault, 0, kCMBlockBufferAssureMemoryNowFlag,
                                               &backing);
    if (status)
        return status;

    CMSampleTimingInfo timing = { sbufDuration, sbufPTS, kCMTimeInvalid, kCMTimeInvalid };
    const size_t sizes[1] = { 0 };
    CMSampleBufferRef sampleBuffer = NULL;
    status = CMSampleBufferCreate(allocator, backing, true, NULL, NULL, formatDescription,
                                  1, 1, &timing, 1, sizes, &sampleBuffer);
    CFRelease(backing);
    if (status)
        return status;

    CMSetAttachment(sampleBuffer, CharonGroupKey, taggedBufferGroup, kCMAttachmentMode_ShouldNotPropagate);
    *sBufOut = sampleBuffer;
    return noErr;
}

CMTaggedBufferGroupRef CM_NULLABLE CMSampleBufferGetTaggedBufferGroup(CMSampleBufferRef CM_NONNULL sbuf)
{
    if (!sbuf)
        return NULL;
    return (CMTaggedBufferGroupRef)CMGetAttachment(sbuf, CharonGroupKey, NULL);
}
