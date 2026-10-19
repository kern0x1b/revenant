#import "CharonCMTagSupport.h"
#import <CoreMedia/CoreMedia.h>
#include <stdlib.h>
#include <string.h>

// The comparison rules CMTagCollection and CMTaggedBufferGroup both need, in one place.
//
// A C function shared between two backport objects is the trap in charon/AGENTS.md: the band machinery
// keys an object on the API it exports, so an object calling another's public function links a
// dependency between two objects that are dropped independently. Everything here is charon_-prefixed and
// therefore not an API symbol, so the object that compiles this file exports nothing of it and both
// CMTagCollection17.m and CMTaggedBufferGroup17.m can use it without either calling the other.

BOOL charon_tag_equal(CMTag left, CMTag right)
{
    return left.category == right.category && left.dataType == right.dataType && left.value == right.value;
}

BOOL charon_tag_is_less(CMTag left, CMTag right)
{
    if (left.category != right.category)
        return left.category < right.category;
    if (left.dataType != right.dataType)
        return left.dataType < right.dataType;
    return left.value < right.value;
}
// The rule the host's own ContainsSpecifiedTags and the group's six lookups both use: every one of the
// wanted tags is carried. The empty set is carried by everything, and neither argument is dereferenced
// when it is NULL.
BOOL charon_tag_carries(const CMTag *held, CMItemCount heldCount, const CMTag *wanted, CMItemCount wantedCount)
{
    for (CMItemCount index = 0; index < wantedCount; index++) {
        BOOL seen = NO;
        for (CMItemCount other = 0; other < heldCount; other++)
            if (charon_tag_equal(held[other], wanted[index])) {
                seen = YES;
                break;
            }
        if (!seen)
            return NO;
    }
    return YES;
}

// The collection's class and its sorted array, moved here from CMTagCollection17.m so that another
// object can read a collection's tags without calling that object's API.

@implementation CharonCMTagCollection {
    CMTag *_tags;
    NSUInteger _count;
    NSUInteger _capacity;
}

@synthesize charon_count = _count;

- (instancetype)charon_initWithTags:(const CMTag *)tags count:(NSUInteger)count __attribute__((objc_method_family(init)))
{
    self = [super init];
    if (!self)
        return nil;
    if (count) {
        _tags = malloc(count * sizeof *_tags);
        if (!_tags)
            return nil;
        _capacity = count;
        for (NSUInteger index = 0; index < count; index++)
            [self charon_insert:tags[index]];
    }
    return self;
}

- (void)dealloc
{
    free(_tags);
    _tags = NULL;
    _count = 0;
    _capacity = 0;
}

- (const CMTag *)charon_tags
{
    return _tags;
}

// The index of the first tag not less than the one asked for, and whether that is the tag itself.
- (NSUInteger)charon_indexOfTag:(CMTag)tag
{
    NSUInteger low = 0, high = _count;
    while (low < high) {
        NSUInteger middle = low + (high - low) / 2;
        if (charon_tag_is_less(_tags[middle], tag))
            low = middle + 1;
        else
            high = middle;
    }
    return low;
}

- (BOOL)charon_contains:(CMTag)tag
{
    if (!CMTagIsValid(tag))
        return NO;
    NSUInteger at = [self charon_indexOfTag:tag];
    return at < _count && charon_tag_equal(_tags[at], tag);
}

- (BOOL)charon_insert:(CMTag)tag
{
    if ([self charon_contains:tag])
        return YES;
    if (_count == _capacity) {
        NSUInteger capacity = _capacity ? _capacity * 2 : 8;
        CMTag *tags = realloc(_tags, capacity * sizeof *tags);
        if (!tags)
            return NO;
        _tags = tags;
        _capacity = capacity;
    }
    NSUInteger at = [self charon_indexOfTag:tag];
    memmove(_tags + at + 1, _tags + at, (_count - at) * sizeof *_tags);
    _tags[at] = tag;
    _count++;
    return YES;
}

- (BOOL)charon_remove:(CMTag)tag
{
    NSUInteger at = [self charon_indexOfTag:tag];
    if (at >= _count || !charon_tag_equal(_tags[at], tag))
        return NO;
    memmove(_tags + at, _tags + at + 1, (_count - at - 1) * sizeof *_tags);
    _count--;
    return YES;
}

- (NSUInteger)charon_removeCategory:(CMTagCategory)category
{
    CMTag probe = {category, kCMTagDataType_Invalid, 0};
    NSUInteger at = [self charon_indexOfTag:probe], end = at;
    while (end < _count && _tags[end].category == category)
        end++;
    if (end > at) {
        memmove(_tags + at, _tags + end, (_count - end) * sizeof *_tags);
        _count -= end - at;
    }
    return end - at;
}

- (void)charon_removeAll
{
    _count = 0;
}

- (NSUInteger)charon_countOfCategory:(CMTagCategory)category
{
    CMTag probe = {category, kCMTagDataType_Invalid, 0};
    NSUInteger at = [self charon_indexOfTag:probe], count = 0;
    while (at < _count && _tags[at].category == category) {
        count++;
        at++;
    }
    return count;
}

- (CMTag *)charon_copyAllTags:(CMItemCount *)countOut
{
    CMTag *copy = _count ? malloc(_count * sizeof *copy) : NULL;
    if (_count && !copy)
        return NULL;
    if (_count)
        memcpy(copy, _tags, _count * sizeof *copy);
    if (countOut)
        *countOut = (CMItemCount)_count;
    return copy;
}
@end

// The class method that hands a collection's tags to another object, in the helper so the group never
// calls CMTagCollection17.o's API. The caller frees the array.
CMTag *charon_copy_all_tags(CMTagCollectionRef collection, CMItemCount *countOut)
{
    CharonCMTagCollection *mine = (__bridge CharonCMTagCollection *)collection;
    if (!mine) {
        if (countOut)
            *countOut = 0;
        return NULL;
    }
    return [mine charon_copyAllTags:countOut];
}
