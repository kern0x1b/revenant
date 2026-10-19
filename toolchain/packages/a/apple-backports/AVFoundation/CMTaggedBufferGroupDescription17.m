#import <CoreMedia/CoreMedia.h>
#import <CoreFoundation/CoreFoundation.h>
#import "RevenantCMTag26.h"
#import "RevenantCMTagSupport.h"
#import "RevenantCMTaggedBufferGroup26.h"
#import <Foundation/Foundation.h>

#import "RevenantCMTaggedBufferGroupEntries.h"

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
    CFDataRef recorded = (CFDataRef)CFDictionaryGetValue(extensions, RevenantEntriesKey);
    if (!recorded)
        return false;

    RevenantCMTaggedBufferGroup *group = (__bridge RevenantCMTaggedBufferGroup *)taggedBufferGroup;
    NSArray *collections = group.revenant_collections;
    if ((CFIndex)collections.count != RevenantEntriesDataCount(recorded))
        return false;

    for (CFIndex index = 0; index < (CFIndex)collections.count; index++) {
        CMItemCount theirCount = 0;
        const CMTag *theirTags = NULL;
        if (!RevenantEntriesDataAtIndex(recorded, index, &theirCount, &theirTags))
            return false;
        RevenantCMTagCollection *mine = (RevenantCMTagCollection *)collections[index];
        if ((CMItemCount)mine.revenant_count != theirCount)
            return false;
        const CMTag *myTags = mine.revenant_tags;
        for (NSUInteger tag = 0; tag < mine.revenant_count; tag++) {
            if (!revenant_tag_equal(myTags[tag], theirTags[tag]))
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

    CMSetAttachment(sampleBuffer, RevenantGroupKey, taggedBufferGroup, kCMAttachmentMode_ShouldNotPropagate);
    *sBufOut = sampleBuffer;
    return noErr;
}

CMTaggedBufferGroupRef CM_NULLABLE CMSampleBufferGetTaggedBufferGroup(CMSampleBufferRef CM_NONNULL sbuf)
{
    if (!sbuf)
        return NULL;
    return (CMTaggedBufferGroupRef)CMGetAttachment(sbuf, RevenantGroupKey, NULL);
}
