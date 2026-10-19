#import "CharonCMTaggedBufferGroup26.h"
#import "CharonCMTagSupport.h"
#import <CoreMedia/CoreMedia.h>
#import <CoreFoundation/CoreFoundation.h>
#import <objc/runtime.h>
#import <stdlib.h>
#import <string.h>

@implementation CharonCMTaggedBufferGroup {
    CMTag *_tags;
    CMItemCount *_offsets;
    NSUInteger _entries;
}

@synthesize charon_collections = _charon_collections;
@synthesize charon_buffers = _charon_buffers;

- (instancetype)charon_initWithCollections:(NSArray *)collections buffers:(NSArray *)buffers
{
    self = [super init];
    if (!self)
        return nil;
    _charon_collections = [collections copy];
    _charon_buffers = [buffers copy];
    _entries = _charon_collections.count;
    if (_entries) {
        _offsets = calloc(_entries + 1, sizeof *_offsets);
        for (NSUInteger index = 0; index < _entries; index++) {
            CMItemCount held = 0;
            CMTag *run = charon_copy_all_tags((CMTagCollectionRef)(__bridge void *)[collections objectAtIndex:index], &held);
            size_t room = (size_t)(_offsets[index] + held) * sizeof *_tags;
            CMTag *grown = realloc(_tags, room ? room : 1);
            if (!grown) {
                free(run);
                return nil;
            }
            _tags = grown;
            if (held)
                memcpy(_tags + _offsets[index], run, (size_t)held * sizeof *run);
            _offsets[index + 1] = _offsets[index] + held;
            free(run);
        }
    }
    return self;
}

- (void)dealloc
{
    free(_tags);
    _tags = NULL;
    free(_offsets);
    _offsets = NULL;
    _entries = 0;
}

- (const CMTag *)charon_tags
{
    return _tags;
}

- (CMItemCount)charon_tagCount
{
    CMItemCount total = 0;
    for (NSUInteger index = 0; index < _entries; index++)
        total += _offsets[index];
    return total;
}

- (CMItemCount)charon_tagOffsetAtIndex:(NSInteger)index
{
    if (index < 0 || index >= (NSInteger)_entries)
        return -1;
    return _offsets[index];
}

- (NSInteger)charon_count
{
    return (NSInteger)MIN(_entries, _charon_buffers.count);
}

- (CMTagCollectionRef)charon_collectionAtIndex:(NSInteger)index
{
    if (index < 0 || index >= (NSInteger)_entries)
        return NULL;
    return (__bridge CMTagCollectionRef)_charon_collections[(NSUInteger)index];
}

- (CVBufferRef)charon_bufferAtIndex:(NSInteger)index
{
    if (index < 0 || index >= (NSInteger)_charon_buffers.count)
        return NULL;
    return (__bridge CVBufferRef)_charon_buffers[(NSUInteger)index];
}

- (CVBufferRef)charon_bufferForTags:(const CMTag *)tags count:(CMItemCount)count index:(NSInteger *)index
{
    if (!tags || !count)
        return NULL;
    const CMTag *all = [self charon_tags];
    if (!all)
        return NULL;
    NSInteger found = -1, seen = 0;
    for (NSInteger entry = 0; entry < [self charon_count]; entry++) {
        CMItemCount at = _offsets[entry], held = _offsets[entry + 1] - _offsets[entry];
        if (charon_tag_carries(all + at, held, tags, count)) {
            found = entry;
            seen++;
        }
    }
    if (seen != 1)
        return NULL;
    if (index)
        *index = found;
    return [self charon_bufferAtIndex:found];
}

- (NSInteger)charon_matchesForTags:(const CMTag *)tags count:(CMItemCount)count
{
    const CMTag *all = [self charon_tags];
    NSInteger matches = 0;
    for (NSInteger entry = 0; entry < [self charon_count]; entry++) {
        CMItemCount at = _offsets[entry], held = _offsets[entry + 1] - at;
        if (charon_tag_carries(all ? all + at : NULL, held, tags, count))
            matches++;
    }
    return matches;
}

@end

static CMTaggedBufferGroupRef charon_from(CharonCMTaggedBufferGroup *group)
{
    return (__bridge_retained CMTaggedBufferGroupRef)group;
}

static CharonCMTaggedBufferGroup *charon_to(CMTaggedBufferGroupRef group)
{
    return (__bridge CharonCMTaggedBufferGroup *)group;
}

static CMTag *charon_copy_tags(CMTagCollectionRef collection, CMItemCount *countOut)
{
    return charon_copy_all_tags(collection, countOut);
}

#define charon_param_err ((OSStatus)-15780)

CFTypeID CMTaggedBufferGroupGetTypeID(void)
{
    return (CFTypeID)objc_getClass("CharonCMTaggedBufferGroup");
}

OSStatus CMTaggedBufferGroupCreate(CFAllocatorRef allocator, CFArrayRef tagCollections, CFArrayRef buffers, CMTaggedBufferGroupRef *out)
{
    (void)allocator;
    if (!tagCollections || !buffers || !out)
        return charon_param_err;
    *out = NULL;
    CFIndex collections = CFArrayGetCount(tagCollections), count = CFArrayGetCount(buffers);
    if (collections != count)
        return charon_param_err;
    NSMutableArray *made = [NSMutableArray arrayWithCapacity:(NSUInteger)count];
    NSMutableArray *held = [NSMutableArray arrayWithCapacity:(NSUInteger)count];
    for (CFIndex index = 0; index < count; index++) {
        CFTypeRef collection = CFArrayGetValueAtIndex(tagCollections, index);
        CFTypeRef buffer = CFArrayGetValueAtIndex(buffers, index);
        if (collection)
            [made addObject:(__bridge id)collection];
        if (buffer)
            [held addObject:(__bridge id)buffer];
    }
    *out = charon_from([[CharonCMTaggedBufferGroup alloc] charon_initWithCollections:made buffers:held]);
    return *out ? 0 : -15782;
}

OSStatus CMTaggedBufferGroupCreateCombined(CFAllocatorRef allocator, CFArrayRef groups, CMTaggedBufferGroupRef *out)
{
    (void)allocator;
    if (!groups || !out)
        return charon_param_err;
    *out = NULL;
    NSMutableArray *collections = [NSMutableArray array], *buffers = [NSMutableArray array];
    for (CFIndex index = 0; index < CFArrayGetCount(groups); index++) {
        CharonCMTaggedBufferGroup *one = charon_to((CMTaggedBufferGroupRef)CFArrayGetValueAtIndex(groups, index));
        if (!one)
            continue;
        [collections addObjectsFromArray:one.charon_collections];
        [buffers addObjectsFromArray:one.charon_buffers];
    }
    *out = charon_from([[CharonCMTaggedBufferGroup alloc] charon_initWithCollections:collections buffers:buffers]);
    return *out ? 0 : -15782;
}

CMItemCount CMTaggedBufferGroupGetCount(CMTaggedBufferGroupRef group)
{
    return (CMItemCount)[charon_to(group) charon_count];
}

CMTagCollectionRef CMTaggedBufferGroupGetTagCollectionAtIndex(CMTaggedBufferGroupRef group, CFIndex index)
{
    return [charon_to(group) charon_collectionAtIndex:index];
}

CVPixelBufferRef CMTaggedBufferGroupGetCVPixelBufferAtIndex(CMTaggedBufferGroupRef group, CFIndex index)
{
    CVBufferRef buffer = [charon_to(group) charon_bufferAtIndex:index];
    return buffer && CFGetTypeID(buffer) == CVPixelBufferGetTypeID() ? (CVPixelBufferRef)buffer : NULL;
}

CMSampleBufferRef CMTaggedBufferGroupGetCMSampleBufferAtIndex(CMTaggedBufferGroupRef group, CFIndex index)
{
    CVBufferRef buffer = [charon_to(group) charon_bufferAtIndex:index];
    return buffer && CFGetTypeID(buffer) == CMSampleBufferGetTypeID() ? (CMSampleBufferRef)buffer : NULL;
}

CVPixelBufferRef CMTaggedBufferGroupGetCVPixelBufferForTag(CMTaggedBufferGroupRef group, CMTag tag, CFIndex *indexOut)
{
    NSInteger index = 0;
    CVBufferRef found = [charon_to(group) charon_bufferForTags:&tag count:1 index:&index];
    if (!found)
        return NULL;
    if (indexOut)
        *indexOut = (CFIndex)index;
    return CFGetTypeID(found) == CVPixelBufferGetTypeID() ? (CVPixelBufferRef)found : NULL;
}

CMSampleBufferRef CMTaggedBufferGroupGetCMSampleBufferForTag(CMTaggedBufferGroupRef group, CMTag tag, CFIndex *indexOut)
{
    NSInteger index = 0;
    CVBufferRef found = [charon_to(group) charon_bufferForTags:&tag count:1 index:&index];
    if (!found)
        return NULL;
    if (indexOut)
        *indexOut = (CFIndex)index;
    return CFGetTypeID(found) == CMSampleBufferGetTypeID() ? (CMSampleBufferRef)found : NULL;
}

CVPixelBufferRef CMTaggedBufferGroupGetCVPixelBufferForTagCollection(CMTaggedBufferGroupRef group, CMTagCollectionRef tagCollection, CFIndex *indexOut)
{
    CMItemCount count = 0;
    CMTag *tags = charon_copy_tags(tagCollection, &count);
    if (!tags)
        return NULL;
    NSInteger index = 0;
    CVBufferRef found = [charon_to(group) charon_bufferForTags:tags count:count index:&index];
    free(tags);
    if (!found)
        return NULL;
    if (indexOut)
        *indexOut = (CFIndex)index;
    return CFGetTypeID(found) == CVPixelBufferGetTypeID() ? (CVPixelBufferRef)found : NULL;
}

CMSampleBufferRef CMTaggedBufferGroupGetCMSampleBufferForTagCollection(CMTaggedBufferGroupRef group, CMTagCollectionRef tagCollection, CFIndex *indexOut)
{
    CMItemCount count = 0;
    CMTag *tags = charon_copy_tags(tagCollection, &count);
    if (!tags)
        return NULL;
    NSInteger index = 0;
    CVBufferRef found = [charon_to(group) charon_bufferForTags:tags count:count index:&index];
    free(tags);
    if (!found)
        return NULL;
    if (indexOut)
        *indexOut = (CFIndex)index;
    return CFGetTypeID(found) == CMSampleBufferGetTypeID() ? (CMSampleBufferRef)found : NULL;
}

CMItemCount CMTaggedBufferGroupGetNumberOfMatchesForTagCollection(CMTaggedBufferGroupRef group, CMTagCollectionRef tagCollection)
{
    CMItemCount count = 0;
    CMTag *tags = charon_copy_tags(tagCollection, &count);
    CMItemCount matches = (CMItemCount)[charon_to(group) charon_matchesForTags:tags count:count];
    free(tags);
    return matches;
}
