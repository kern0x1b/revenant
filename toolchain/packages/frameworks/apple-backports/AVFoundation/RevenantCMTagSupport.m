#import "RevenantCMTagSupport.h"
#import <CoreMedia/CoreMedia.h>
#include <stdlib.h>
#include <string.h>

BOOL revenant_tag_equal(CMTag left, CMTag right)
{
    return left.category == right.category && left.dataType == right.dataType && left.value == right.value;
}

BOOL revenant_tag_is_less(CMTag left, CMTag right)
{
    if (left.category != right.category)
        return left.category < right.category;
    if (left.dataType != right.dataType)
        return left.dataType < right.dataType;
    return left.value < right.value;
}
BOOL revenant_tag_carries(const CMTag *held, CMItemCount heldCount, const CMTag *wanted, CMItemCount wantedCount)
{
    for (CMItemCount index = 0; index < wantedCount; index++) {
        BOOL seen = NO;
        for (CMItemCount other = 0; other < heldCount; other++)
            if (revenant_tag_equal(held[other], wanted[index])) {
                seen = YES;
                break;
            }
        if (!seen)
            return NO;
    }
    return YES;
}

@implementation RevenantCMTagCollection {
    CMTag *_tags;
    NSUInteger _count;
    NSUInteger _capacity;
}

@synthesize revenant_count = _count;

- (instancetype)revenant_initWithTags:(const CMTag *)tags count:(NSUInteger)count __attribute__((objc_method_family(init)))
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
            [self revenant_insert:tags[index]];
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

- (const CMTag *)revenant_tags
{
    return _tags;
}

- (NSUInteger)revenant_indexOfTag:(CMTag)tag
{
    NSUInteger low = 0, high = _count;
    while (low < high) {
        NSUInteger middle = low + (high - low) / 2;
        if (revenant_tag_is_less(_tags[middle], tag))
            low = middle + 1;
        else
            high = middle;
    }
    return low;
}

- (BOOL)revenant_contains:(CMTag)tag
{
    if (!CMTagIsValid(tag))
        return NO;
    NSUInteger at = [self revenant_indexOfTag:tag];
    return at < _count && revenant_tag_equal(_tags[at], tag);
}

- (BOOL)revenant_insert:(CMTag)tag
{
    if ([self revenant_contains:tag])
        return YES;
    if (_count == _capacity) {
        NSUInteger capacity = _capacity ? _capacity * 2 : 8;
        CMTag *tags = realloc(_tags, capacity * sizeof *tags);
        if (!tags)
            return NO;
        _tags = tags;
        _capacity = capacity;
    }
    NSUInteger at = [self revenant_indexOfTag:tag];
    memmove(_tags + at + 1, _tags + at, (_count - at) * sizeof *_tags);
    _tags[at] = tag;
    _count++;
    return YES;
}

- (BOOL)revenant_remove:(CMTag)tag
{
    NSUInteger at = [self revenant_indexOfTag:tag];
    if (at >= _count || !revenant_tag_equal(_tags[at], tag))
        return NO;
    memmove(_tags + at, _tags + at + 1, (_count - at - 1) * sizeof *_tags);
    _count--;
    return YES;
}

- (NSUInteger)revenant_removeCategory:(CMTagCategory)category
{
    CMTag probe = {category, kCMTagDataType_Invalid, 0};
    NSUInteger at = [self revenant_indexOfTag:probe], end = at;
    while (end < _count && _tags[end].category == category)
        end++;
    if (end > at) {
        memmove(_tags + at, _tags + end, (_count - end) * sizeof *_tags);
        _count -= end - at;
    }
    return end - at;
}

- (void)revenant_removeAll
{
    _count = 0;
}

- (NSUInteger)revenant_countOfCategory:(CMTagCategory)category
{
    CMTag probe = {category, kCMTagDataType_Invalid, 0};
    NSUInteger at = [self revenant_indexOfTag:probe], count = 0;
    while (at < _count && _tags[at].category == category) {
        count++;
        at++;
    }
    return count;
}

- (CMTag *)revenant_copyAllTags:(CMItemCount *)countOut
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

CMTag *revenant_copy_all_tags(CMTagCollectionRef collection, CMItemCount *countOut)
{
    RevenantCMTagCollection *mine = (__bridge RevenantCMTagCollection *)collection;
    if (!mine) {
        if (countOut)
            *countOut = 0;
        return NULL;
    }
    return [mine revenant_copyAllTags:countOut];
}
