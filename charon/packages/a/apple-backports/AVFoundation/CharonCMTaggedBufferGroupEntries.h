#import <CoreMedia/CoreMedia.h>
#import <CoreFoundation/CoreFoundation.h>
#import <Foundation/Foundation.h>
#import "CharonCMTag26.h"
#import "CharonCMTagSupport.h"
#import "CharonCMTaggedBufferGroup26.h"

static NSString *const CharonEntriesKeyName = @"charon.taggedbuffergroup.entries";
static NSString *const CharonGroupKeyName = @"charon.taggedbuffergroup.group";

#define CharonEntriesKey ((__bridge CFStringRef)CharonEntriesKeyName)
#define CharonGroupKey ((__bridge CFStringRef)CharonGroupKeyName)

static const FourCharCode CharonTaggedBufferGroupSubtype = 'tbgr';

static inline CFDataRef CharonCopyEntriesData(CMTaggedBufferGroupRef group)
{
    CFMutableDataRef data = CFDataCreateMutable(kCFAllocatorDefault, 0);
    if (!group)
        return data;
    NSArray *collections = ((__bridge CharonCMTaggedBufferGroup *)group).charon_collections;
    for (id collection in collections) {
        CharonCMTagCollection *one = (CharonCMTagCollection *)collection;
        CMItemCount count = (CMItemCount)one.charon_count;
        CFDataAppendBytes(data, (const UInt8 *)&count, sizeof count);
        if (count)
            CFDataAppendBytes(data, (const UInt8 *)one.charon_tags, count * sizeof(CMTag));
    }
    return data;
}

static inline BOOL CharonEntriesDataAtIndex(CFDataRef data, CFIndex index, CMItemCount *countOut, const CMTag **tagsOut)
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

static inline CFIndex CharonEntriesDataCount(CFDataRef data)
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
