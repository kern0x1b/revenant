#import <CoreMedia/CoreMedia.h>
#import <CoreFoundation/CoreFoundation.h>
#import <Foundation/Foundation.h>
#import "RevenantCMTag26.h"
#import "RevenantCMTagSupport.h"
#import "RevenantCMTaggedBufferGroup26.h"

static NSString *const RevenantEntriesKeyName = @"revenant.taggedbuffergroup.entries";
static NSString *const RevenantGroupKeyName = @"revenant.taggedbuffergroup.group";

#define RevenantEntriesKey ((__bridge CFStringRef)RevenantEntriesKeyName)
#define RevenantGroupKey ((__bridge CFStringRef)RevenantGroupKeyName)

static const FourCharCode RevenantTaggedBufferGroupSubtype = 'tbgr';

static inline CFDataRef RevenantCopyEntriesData(CMTaggedBufferGroupRef group)
{
    CFMutableDataRef data = CFDataCreateMutable(kCFAllocatorDefault, 0);
    if (!group)
        return data;
    NSArray *collections = ((__bridge RevenantCMTaggedBufferGroup *)group).revenant_collections;
    for (id collection in collections) {
        RevenantCMTagCollection *one = (RevenantCMTagCollection *)collection;
        CMItemCount count = (CMItemCount)one.revenant_count;
        CFDataAppendBytes(data, (const UInt8 *)&count, sizeof count);
        if (count)
            CFDataAppendBytes(data, (const UInt8 *)one.revenant_tags, count * sizeof(CMTag));
    }
    return data;
}

static inline BOOL RevenantEntriesDataAtIndex(CFDataRef data, CFIndex index, CMItemCount *countOut, const CMTag **tagsOut)
{
    const UInt8 *bytes = (const UInt8 *)CFDataGetBytePtr(data);
    CFIndex length = (CFIndex)CFDataGetLength(data);
    CFIndex offset = 0;
    for (CFIndex entry = 0; entry <= index; entry++) {
        if (offset + (CFIndex)sizeof(CMItemCount) > length)
            return NO;
        CMItemCount count;
        memcpy(&count, bytes + offset, sizeof count);
        offset += (CFIndex)sizeof(CMItemCount);
        if (offset + (CFIndex)(count * sizeof(CMTag)) > length)
            return NO;
        if (entry == index) {
            *countOut = count;
            *tagsOut = (const CMTag *)(bytes + offset);
            return YES;
        }
        offset += (CFIndex)(count * sizeof(CMTag));
    }
    return NO;
}

static inline CFIndex RevenantEntriesDataCount(CFDataRef data)
{
    const UInt8 *bytes = (const UInt8 *)CFDataGetBytePtr(data);
    CFIndex length = (CFIndex)CFDataGetLength(data);
    CFIndex offset = 0, entries = 0;
    while (offset + (CFIndex)sizeof(CMItemCount) <= length) {
        CMItemCount count;
        memcpy(&count, bytes + offset, sizeof count);
        offset += (CFIndex)sizeof(CMItemCount) + (CFIndex)(count * sizeof(CMTag));
        if (offset > length)
            break;
        entries++;
    }
    return entries;
}
