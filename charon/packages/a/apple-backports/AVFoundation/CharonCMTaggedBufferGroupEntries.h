// What the two objects of the tagged-buffer-group description share: the keys the description and the sample
// buffer carry the group under, and the way the group's entries travel inside the description. Each
// object includes it and holds its own copy, because the two are of different releases - the four
// functions of 18.0 in CMTaggedBufferGroupDescription17.m and the one of 26.0 in
// CMTaggedBufferGroupDescription26.m - and an object carries the API of one release.
#import <CoreMedia/CoreMedia.h>
#import <CoreFoundation/CoreFoundation.h>
#import <Foundation/Foundation.h>
#import "CharonCMTag26.h"
#import "CharonCMTagSupport.h"
#import "CharonCMTaggedBufferGroup26.h"

// The key the per-entry collections travel under, inside the description's extensions dictionary. It is
// the port's own: 26.2 gives no key for it, and the dictionary is ours to write into.
static NSString *const CharonEntriesKeyName = @"charon.taggedbuffergroup.entries";
// The attachment key the group travels under on the sample buffer.
static NSString *const CharonGroupKeyName = @"charon.taggedbuffergroup.group";

#define CharonEntriesKey ((__bridge CFStringRef)CharonEntriesKeyName)
#define CharonGroupKey ((__bridge CFStringRef)CharonGroupKeyName)

// 16.4's media type for a video format description, and the subtype the host's answers carry, measured as
// 1952606066 - 'tbgr', TaggedBufferGroup.
static const FourCharCode CharonTaggedBufferGroupSubtype = 'tbgr';

// The group's per-entry collections, in order, as the description carries them.
//
// NOT as an array of the collection objects. That was the first shape tried and 16.4 refuses it:
 // CMFormatDescriptionCreate answers kCMFormatDescriptionError_InvalidParameter (-12710) for an
// extensions dictionary holding bridged Objective-C values, while a NULL group - the same call with no
// such value in it - answers 0. The modern framework that took the measurement tolerates them, so the
// difference is the old platform's, and the port is the one that has to live with it.
//
// So the entries travel as CFData, which is what 16.4 will accept: for each collection in order, a
// CMItemCount and then that collection's tags as they sit in memory. A CMTag is three machine words and
// has no lifetime of its own, so copying its bytes is copying the whole of it, and the tags come back
// out of the port's own sorted storage in the same order they went in.
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

// The count and tags of entry `index` in a payload built by CharonCopyEntriesData, or NO if the payload
// does not hold that many entries.
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

// How many entries the payload holds, which is what the count comparison is really about: a group of two
// entries over a description of three has to answer false, and that is decided before any tag is read.
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
