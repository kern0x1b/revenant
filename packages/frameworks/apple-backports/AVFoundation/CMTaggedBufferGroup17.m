#import "RevenantCMTaggedBufferGroup26.h"
#import "RevenantCMTagSupport.h"
#import <CoreMedia/CoreMedia.h>
#import <CoreFoundation/CoreFoundation.h>
#import <objc/runtime.h>
#import <stdlib.h>
#import <string.h>

@implementation RevenantCMTaggedBufferGroup {
    CMTag *_tags;
    CMItemCount *_offsets;
    NSUInteger _entries;
}

@synthesize revenant_collections = _revenant_collections;
@synthesize revenant_buffers = _revenant_buffers;

- (instancetype)revenant_initWithCollections:(NSArray *)collections buffers:(NSArray *)buffers
{
    self = [super init];
    if (!self)
        return nil;
    _revenant_collections = [collections copy];
    _revenant_buffers = [buffers copy];
    _entries = _revenant_collections.count;
    if (_entries) {
        _offsets = calloc(_entries + 1, sizeof *_offsets);
        for (NSUInteger index = 0; index < _entries; index++) {
            CMItemCount held = 0;
            CMTag *run = revenant_copy_all_tags((CMTagCollectionRef)(__bridge void *)[collections objectAtIndex:index], &held);
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

- (const CMTag *)revenant_tags
{
    return _tags;
}

- (CMItemCount)revenant_tagCount
{
    CMItemCount total = 0;
    for (NSUInteger index = 0; index < _entries; index++)
        total += _offsets[index];
    return total;
}

- (CMItemCount)revenant_tagOffsetAtIndex:(NSInteger)index
{
    if (index < 0 || index >= (NSInteger)_entries)
        return -1;
    return _offsets[index];
}

- (NSInteger)revenant_count
{
    return (NSInteger)MIN(_entries, _revenant_buffers.count);
}

- (CMTagCollectionRef)revenant_collectionAtIndex:(NSInteger)index
{
    if (index < 0 || index >= (NSInteger)_entries)
        return NULL;
    return (__bridge CMTagCollectionRef)_revenant_collections[(NSUInteger)index];
}

- (CVBufferRef)revenant_bufferAtIndex:(NSInteger)index
{
    if (index < 0 || index >= (NSInteger)_revenant_buffers.count)
        return NULL;
    return (__bridge CVBufferRef)_revenant_buffers[(NSUInteger)index];
}

- (CVBufferRef)revenant_bufferForTags:(const CMTag *)tags count:(CMItemCount)count index:(NSInteger *)index
{
    if (!tags || !count)
        return NULL;
    const CMTag *all = [self revenant_tags];
    if (!all)
        return NULL;
    NSInteger found = -1, seen = 0;
    for (NSInteger entry = 0; entry < [self revenant_count]; entry++) {
        CMItemCount at = _offsets[entry], held = _offsets[entry + 1] - _offsets[entry];
        if (revenant_tag_carries(all + at, held, tags, count)) {
            found = entry;
            seen++;
        }
    }
    if (seen != 1)
        return NULL;
    if (index)
        *index = found;
    return [self revenant_bufferAtIndex:found];
}

- (NSInteger)revenant_matchesForTags:(const CMTag *)tags count:(CMItemCount)count
{
    const CMTag *all = [self revenant_tags];
    NSInteger matches = 0;
    for (NSInteger entry = 0; entry < [self revenant_count]; entry++) {
        CMItemCount at = _offsets[entry], held = _offsets[entry + 1] - at;
        if (revenant_tag_carries(all ? all + at : NULL, held, tags, count))
            matches++;
    }
    return matches;
}

@end

static CMTaggedBufferGroupRef revenant_from(RevenantCMTaggedBufferGroup *group)
{
    return (__bridge_retained CMTaggedBufferGroupRef)group;
}

static RevenantCMTaggedBufferGroup *revenant_to(CMTaggedBufferGroupRef group)
{
    return (__bridge RevenantCMTaggedBufferGroup *)group;
}

static CMTag *revenant_copy_tags(CMTagCollectionRef collection, CMItemCount *countOut)
{
    return revenant_copy_all_tags(collection, countOut);
}

#define revenant_param_err ((OSStatus)-15780)

CFTypeID CMTaggedBufferGroupGetTypeID(void)
{
    return (CFTypeID)objc_getClass("RevenantCMTaggedBufferGroup");
}

OSStatus CMTaggedBufferGroupCreate(CFAllocatorRef allocator, CFArrayRef tagCollections, CFArrayRef buffers, CMTaggedBufferGroupRef *out)
{
    (void)allocator;
    if (!tagCollections || !buffers || !out)
        return revenant_param_err;
    *out = NULL;
    CFIndex collections = CFArrayGetCount(tagCollections), count = CFArrayGetCount(buffers);
    if (collections != count)
        return revenant_param_err;
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
    *out = revenant_from([[RevenantCMTaggedBufferGroup alloc] revenant_initWithCollections:made buffers:held]);
    return *out ? 0 : -15782;
}

OSStatus CMTaggedBufferGroupCreateCombined(CFAllocatorRef allocator, CFArrayRef groups, CMTaggedBufferGroupRef *out)
{
    (void)allocator;
    if (!groups || !out)
        return revenant_param_err;
    *out = NULL;
    NSMutableArray *collections = [NSMutableArray array], *buffers = [NSMutableArray array];
    for (CFIndex index = 0; index < CFArrayGetCount(groups); index++) {
        RevenantCMTaggedBufferGroup *one = revenant_to((CMTaggedBufferGroupRef)CFArrayGetValueAtIndex(groups, index));
        if (!one)
            continue;
        [collections addObjectsFromArray:one.revenant_collections];
        [buffers addObjectsFromArray:one.revenant_buffers];
    }
    *out = revenant_from([[RevenantCMTaggedBufferGroup alloc] revenant_initWithCollections:collections buffers:buffers]);
    return *out ? 0 : -15782;
}

CMItemCount CMTaggedBufferGroupGetCount(CMTaggedBufferGroupRef group)
{
    return (CMItemCount)[revenant_to(group) revenant_count];
}

CMTagCollectionRef CMTaggedBufferGroupGetTagCollectionAtIndex(CMTaggedBufferGroupRef group, CFIndex index)
{
    return [revenant_to(group) revenant_collectionAtIndex:index];
}

CVPixelBufferRef CMTaggedBufferGroupGetCVPixelBufferAtIndex(CMTaggedBufferGroupRef group, CFIndex index)
{
    CVBufferRef buffer = [revenant_to(group) revenant_bufferAtIndex:index];
    return buffer && CFGetTypeID(buffer) == CVPixelBufferGetTypeID() ? (CVPixelBufferRef)buffer : NULL;
}

CMSampleBufferRef CMTaggedBufferGroupGetCMSampleBufferAtIndex(CMTaggedBufferGroupRef group, CFIndex index)
{
    CVBufferRef buffer = [revenant_to(group) revenant_bufferAtIndex:index];
    return buffer && CFGetTypeID(buffer) == CMSampleBufferGetTypeID() ? (CMSampleBufferRef)buffer : NULL;
}

CVPixelBufferRef CMTaggedBufferGroupGetCVPixelBufferForTag(CMTaggedBufferGroupRef group, CMTag tag, CFIndex *indexOut)
{
    NSInteger index = 0;
    CVBufferRef found = [revenant_to(group) revenant_bufferForTags:&tag count:1 index:&index];
    if (!found)
        return NULL;
    if (indexOut)
        *indexOut = (CFIndex)index;
    return CFGetTypeID(found) == CVPixelBufferGetTypeID() ? (CVPixelBufferRef)found : NULL;
}

CMSampleBufferRef CMTaggedBufferGroupGetCMSampleBufferForTag(CMTaggedBufferGroupRef group, CMTag tag, CFIndex *indexOut)
{
    NSInteger index = 0;
    CVBufferRef found = [revenant_to(group) revenant_bufferForTags:&tag count:1 index:&index];
    if (!found)
        return NULL;
    if (indexOut)
        *indexOut = (CFIndex)index;
    return CFGetTypeID(found) == CMSampleBufferGetTypeID() ? (CMSampleBufferRef)found : NULL;
}

CVPixelBufferRef CMTaggedBufferGroupGetCVPixelBufferForTagCollection(CMTaggedBufferGroupRef group, CMTagCollectionRef tagCollection, CFIndex *indexOut)
{
    CMItemCount count = 0;
    CMTag *tags = revenant_copy_tags(tagCollection, &count);
    if (!tags)
        return NULL;
    NSInteger index = 0;
    CVBufferRef found = [revenant_to(group) revenant_bufferForTags:tags count:count index:&index];
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
    CMTag *tags = revenant_copy_tags(tagCollection, &count);
    if (!tags)
        return NULL;
    NSInteger index = 0;
    CVBufferRef found = [revenant_to(group) revenant_bufferForTags:tags count:count index:&index];
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
    CMTag *tags = revenant_copy_tags(tagCollection, &count);
    CMItemCount matches = (CMItemCount)[revenant_to(group) revenant_matchesForTags:tags count:count];
    free(tags);
    return matches;
}
