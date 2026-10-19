#import "CharonCMTagSupport.h"
#import "CharonCMTag26.h"
#import <objc/runtime.h>
#include <stdlib.h>
#include <string.h>

static void charon_insert_all(CharonCMTagCollection *into, CharonCMTagCollection *from);

const CMTag kCMTagInvalid = {kCMTagCategory_Undefined, kCMTagDataType_Invalid, 0};

const CFStringRef kCMTagCategoryKey = CFSTR("category");
const CFStringRef kCMTagValueKey = CFSTR("value");
const CFStringRef kCMTagDataTypeKey = CFSTR("flags");

CFTypeID CMTagCollectionGetTypeID(void)
{
    return (CFTypeID)objc_getClass("CharonCMTagCollection");
}

static CMTagCollectionRef charon_from(CharonCMTagCollection *collection)
{
    return (__bridge_retained CMTagCollectionRef)collection;
}

static CMMutableTagCollectionRef charon_mutable_from(CharonCMTagCollection *collection)
{
    return (CMMutableTagCollectionRef)(__bridge_retained CMTagCollectionRef)collection;
}

static CharonCMTagCollection *charon_to(CMTagCollectionRef collection)
{
    return (__bridge CharonCMTagCollection *)collection;
}

OSStatus CMTagCollectionCreate(CFAllocatorRef allocator, const CMTag *tags, CMItemCount tagCount, CMTagCollectionRef *newCollectionOut)
{
    (void)allocator;
    if (!newCollectionOut || (!tags && tagCount))
        return kCMTagCollectionError_ParamErr;
    *newCollectionOut = NULL;
    CharonCMTagCollection *collection = [[CharonCMTagCollection alloc] charon_initWithTags:tags count:(NSUInteger)tagCount];
    if (!collection)
        return kCMTagCollectionError_AllocationFailed;
    *newCollectionOut = charon_from(collection);
    return noErr;
}

OSStatus CMTagCollectionCreateMutable(CFAllocatorRef allocator, CFIndex capacity, CMMutableTagCollectionRef *newMutableCollectionOut)
{
    (void)allocator;
    (void)capacity;
    if (!newMutableCollectionOut)
        return kCMTagCollectionError_ParamErr;
    *newMutableCollectionOut = charon_mutable_from([[CharonCMTagCollection alloc] charon_initWithTags:NULL count:0]);
    return *newMutableCollectionOut ? noErr : kCMTagCollectionError_AllocationFailed;
}

OSStatus CMTagCollectionCreateCopy(CMTagCollectionRef tagCollection, CFAllocatorRef allocator, CMTagCollectionRef *newCollectionCopyOut)
{
    CharonCMTagCollection *source = charon_to(tagCollection);
    return CMTagCollectionCreate(allocator, source ? source.charon_tags : NULL, (CMItemCount)(source ? source.charon_count : 0), newCollectionCopyOut);
}

OSStatus CMTagCollectionCreateMutableCopy(CMTagCollectionRef tagCollection, CFAllocatorRef allocator, CMMutableTagCollectionRef *newMutableCollectionCopyOut)
{
    CharonCMTagCollection *source = charon_to(tagCollection);
    if (!newMutableCollectionCopyOut)
        return kCMTagCollectionError_ParamErr;
    CMMutableTagCollectionRef out = NULL;
    OSStatus status = CMTagCollectionCreateMutable(allocator, (CFIndex)(source ? source.charon_count : 0), &out);
    if (status)
        return status;
    charon_insert_all(charon_to((CMTagCollectionRef)out), source);
    *newMutableCollectionCopyOut = out;
    return noErr;
}

static NSString *charon_category_name(CMTagCategory category)
{
    return [NSString stringWithFormat:@"%c%c%c%c", (char)(category >> 24), (char)(category >> 16), (char)(category >> 8), (char)category];
}

static NSString *charon_tag_value(CMTag tag)
{
    switch (tag.dataType) {
    case kCMTagDataType_OSType:
        return [NSString stringWithFormat:@"'%@'", charon_category_name((CMTagCategory)(uint32_t)tag.value)];
    case kCMTagDataType_Flags:
        return [NSString stringWithFormat:@"0x%llx", (unsigned long long)tag.value];
    case kCMTagDataType_Float64: {
        double number;
        memcpy(&number, &tag.value, sizeof number);
        return [NSString stringWithFormat:@"%.2f", number];
    }
    default:
        return [NSString stringWithFormat:@"%lld", (long long)tag.value];
    }
}

static NSString *charon_tag_type(CMTagDataType type)
{
    switch (type) {
    case kCMTagDataType_OSType: return @"OSType";
    case kCMTagDataType_Flags: return @"flags";
    case kCMTagDataType_Float64: return @"Flt64";
    default: return @"int64";
    }
}

CFStringRef CMTagCollectionCopyDescription(CFAllocatorRef allocator, CMTagCollectionRef tagCollection)
{
    (void)allocator;
    CharonCMTagCollection *collection = charon_to(tagCollection);
    if (!collection)
        return NULL;
    const CMTag *tags = [collection charon_tags];
    NSMutableString *built = [NSMutableString stringWithString:@"CMTagCollection{\n"];
    for (NSUInteger index = 0; index < collection.charon_count; index++)
        [built appendFormat:@"{category:'%@' value:%@ <%@>}\n", charon_category_name(tags[index].category),
                              charon_tag_value(tags[index]), charon_tag_type(tags[index].dataType)];
    [built appendString:@"}"];
    return (__bridge_retained CFStringRef)built;
}

CMItemCount CMTagCollectionGetCount(CMTagCollectionRef tagCollection)
{
    CharonCMTagCollection *collection = charon_to(tagCollection);
    return (CMItemCount)(collection ? collection.charon_count : 0);
}

Boolean CMTagCollectionIsEmpty(CMTagCollectionRef tagCollection)
{
    return CMTagCollectionGetCount(tagCollection) == 0;
}

Boolean CMTagCollectionContainsTag(CMTagCollectionRef tagCollection, CMTag tag)
{
    CharonCMTagCollection *collection = charon_to(tagCollection);
    return collection ? [collection charon_contains:tag] : false;
}

CMItemCount CMTagCollectionGetCountOfCategory(CMTagCollectionRef tagCollection, CMTagCategory category)
{
    CharonCMTagCollection *collection = charon_to(tagCollection);
    return (CMItemCount)(collection ? [collection charon_countOfCategory:category] : 0);
}

Boolean CMTagCollectionContainsCategory(CMTagCollectionRef tagCollection, CMTagCategory category)
{
    if (category == kCMTagCategory_Undefined)
        return true;
    return CMTagCollectionGetCountOfCategory(tagCollection, category) != 0;
}

Boolean CMTagCollectionContainsTagsOfCollection(CMTagCollectionRef tagCollection, CMTagCollectionRef inputCollection)
{
    CharonCMTagCollection *collection = charon_to((CMTagCollectionRef)tagCollection), *input = charon_to(inputCollection);
    if (!collection || !input)
        return false;
    const CMTag *tags = input.charon_tags;
    for (NSUInteger index = 0; index < input.charon_count; index++)
        if (![collection charon_contains:tags[index]])
            return false;
    return true;
}

Boolean CMTagCollectionContainsSpecifiedTags(CMTagCollectionRef tagCollection, const CMTag *containedTags, CMItemCount containedTagCount)
{
    CharonCMTagCollection *collection = charon_to(tagCollection);
    if (!collection || (!containedTags && containedTagCount))
        return false;
    for (CMItemCount index = 0; index < containedTagCount; index++)
        if (![collection charon_contains:containedTags[index]])
            return false;
    return true;
}

OSStatus CMTagCollectionGetTags(CMTagCollectionRef tagCollection, CMTag *tagBuffer, CMItemCount tagBufferCount,
                                CMItemCount *numberOfTagsCopied)
{
    CharonCMTagCollection *collection = charon_to(tagCollection);
    if (!collection || (!tagBuffer && tagBufferCount))
        return kCMTagCollectionError_ParamErr;
    const CMTag *tags = [collection charon_tags];
    CMItemCount written = 0;
    for (NSUInteger index = 0; index < collection.charon_count && written < tagBufferCount; index++)
        tagBuffer[written++] = tags[index];
    if (numberOfTagsCopied)
        *numberOfTagsCopied = written;
    return written == collection.charon_count ? noErr : kCMTagCollectionError_ExhaustedBufferSize;
}

OSStatus CMTagCollectionGetTagsWithCategory(CMTagCollectionRef tagCollection, CMTagCategory category, CMTag *tagBuffer,
                                           CMItemCount tagBufferCount, CMItemCount *numberOfTagsCopied)
{
    CharonCMTagCollection *collection = charon_to(tagCollection);
    if (!collection || (!tagBuffer && tagBufferCount))
        return kCMTagCollectionError_ParamErr;
    const CMTag *tags = [collection charon_tags];
    CMItemCount written = 0;
    CMItemCount matched = 0;
    for (NSUInteger index = 0; index < collection.charon_count; index++)
        if (tags[index].category == category)
            matched++;
    for (NSUInteger index = 0; index < collection.charon_count && written < tagBufferCount; index++)
        if (tags[index].category == category)
            tagBuffer[written++] = tags[index];
    if (numberOfTagsCopied)
        *numberOfTagsCopied = written;
    return written == matched ? noErr : kCMTagCollectionError_ExhaustedBufferSize;
}

CMItemCount CMTagCollectionCountTagsWithFilterFunction(CMTagCollectionRef tagCollection,
                                                       CMTagCollectionTagFilterFunction filterApplier, void *context)
{
    CharonCMTagCollection *collection = charon_to(tagCollection);
    if (!collection || !filterApplier)
        return 0;
    const CMTag *tags = [collection charon_tags];
    CMItemCount count = 0;
    for (NSUInteger index = 0; index < collection.charon_count; index++)
        if (filterApplier(tags[index], context))
            count++;
    return count;
}

OSStatus CMTagCollectionGetTagsWithFilterFunction(CMTagCollectionRef tagCollection, CMTag *tagBuffer, CMItemCount tagBufferCount,
                                                 CMItemCount *numberOfTagsCopied, CMTagCollectionTagFilterFunction filter, void *context)
{
    CharonCMTagCollection *collection = charon_to(tagCollection);
    if (!collection || !filter || (!tagBuffer && tagBufferCount))
        return kCMTagCollectionError_ParamErr;
    const CMTag *tags = [collection charon_tags];
    CMItemCount written = 0;
    CMItemCount matched = 0;
    for (NSUInteger index = 0; index < collection.charon_count; index++)
        if (filter(tags[index], context))
            matched++;
    for (NSUInteger index = 0; index < collection.charon_count && written < tagBufferCount; index++)
        if (filter(tags[index], context))
            tagBuffer[written++] = tags[index];
    if (numberOfTagsCopied)
        *numberOfTagsCopied = written;
    return written == matched ? noErr : kCMTagCollectionError_ExhaustedBufferSize;
}

OSStatus CMTagCollectionAddTag(CMMutableTagCollectionRef tagCollection, CMTag tag)
{
    CharonCMTagCollection *collection = charon_to((CMTagCollectionRef)tagCollection);
    if (!collection)
        return kCMTagCollectionError_ParamErr;
    return [collection charon_insert:tag] ? noErr : kCMTagCollectionError_AllocationFailed;
}

OSStatus CMTagCollectionRemoveTag(CMMutableTagCollectionRef tagCollection, CMTag tag)
{
    CharonCMTagCollection *collection = charon_to((CMTagCollectionRef)tagCollection);
    if (!collection)
        return kCMTagCollectionError_ParamErr;
    return [collection charon_remove:tag] ? noErr : kCMTagCollectionError_TagNotFound;
}

OSStatus CMTagCollectionRemoveAllTagsOfCategory(CMMutableTagCollectionRef tagCollection, CMTagCategory category)
{
    CharonCMTagCollection *collection = charon_to((CMTagCollectionRef)tagCollection);
    if (!collection)
        return kCMTagCollectionError_ParamErr;
    [collection charon_removeCategory:category];
    return noErr;
}

OSStatus CMTagCollectionRemoveAllTags(CMMutableTagCollectionRef tagCollection)
{
    CharonCMTagCollection *collection = charon_to((CMTagCollectionRef)tagCollection);
    if (!collection)
        return kCMTagCollectionError_ParamErr;
    [collection charon_removeAll];
    return noErr;
}

OSStatus CMTagCollectionAddTagsFromCollection(CMMutableTagCollectionRef tagCollection, CMTagCollectionRef inputCollection)
{
    CharonCMTagCollection *collection = charon_to((CMTagCollectionRef)tagCollection), *input = charon_to(inputCollection);
    if (!collection || !input)
        return kCMTagCollectionError_ParamErr;
    const CMTag *tags = input.charon_tags;
    for (NSUInteger index = 0; index < input.charon_count; index++)
        if (![collection charon_insert:tags[index]])
            return kCMTagCollectionError_AllocationFailed;
    return noErr;
}

OSStatus CMTagCollectionAddTagsFromArray(CMMutableTagCollectionRef tagCollection, CMTag *tags, CMItemCount tagCount)
{
    CharonCMTagCollection *collection = charon_to((CMTagCollectionRef)tagCollection);
    if (!collection || (!tags && tagCount))
        return kCMTagCollectionError_ParamErr;
    for (CMItemCount index = 0; index < tagCount; index++)
        if (![collection charon_insert:tags[index]])
            return kCMTagCollectionError_AllocationFailed;
    return noErr;
}

static void charon_insert_all(CharonCMTagCollection *into, CharonCMTagCollection *from)
{
    if (!into || !from)
        return;
    const CMTag *tags = [from charon_tags];
    for (NSUInteger index = 0; index < from.charon_count; index++)
        [into charon_insert:tags[index]];
}

OSStatus CMTagCollectionCreateDifference(CMTagCollectionRef tagCollectionMinuend, CMTagCollectionRef tagCollectionSubtrahend, CMTagCollectionRef *tagCollectionOut)
{
    CharonCMTagCollection *minuend = charon_to(tagCollectionMinuend), *subtrahend = charon_to(tagCollectionSubtrahend);
    if (!tagCollectionOut)
        return kCMTagCollectionError_ParamErr;
    CMTagCollectionRef out = NULL;
    OSStatus status = CMTagCollectionCreateMutable(kCFAllocatorDefault, 0, (CMMutableTagCollectionRef *)&out);
    if (status)
        return status;
    CharonCMTagCollection *result = charon_to(out);
    const CMTag *tags = minuend ? [minuend charon_tags] : NULL;
    for (NSUInteger index = 0; minuend && index < minuend.charon_count; index++)
        if (!subtrahend || ![subtrahend charon_contains:tags[index]])
            [result charon_insert:tags[index]];
    *tagCollectionOut = out;
    return noErr;
}

OSStatus CMTagCollectionCreateExclusiveOr(CMTagCollectionRef tagCollection1, CMTagCollectionRef tagCollection2, CMTagCollectionRef *tagCollectionOut)
{
    CharonCMTagCollection *first = charon_to(tagCollection1), *second = charon_to(tagCollection2);
    if (!tagCollectionOut)
        return kCMTagCollectionError_ParamErr;
    CMTagCollectionRef out = NULL;
    OSStatus status = CMTagCollectionCreateMutable(kCFAllocatorDefault, 0, (CMMutableTagCollectionRef *)&out);
    if (status)
        return status;
    CharonCMTagCollection *result = charon_to(out);
    const CMTag *left = first ? [first charon_tags] : NULL;
    for (NSUInteger index = 0; first && index < first.charon_count; index++)
        if (!second || ![second charon_contains:left[index]])
            [result charon_insert:left[index]];
    const CMTag *right = second ? [second charon_tags] : NULL;
    for (NSUInteger index = 0; second && index < second.charon_count; index++)
        if (!first || ![first charon_contains:right[index]])
            [result charon_insert:right[index]];
    *tagCollectionOut = out;
    return noErr;
}


OSStatus CMTagCollectionCreateUnion(CMTagCollectionRef tagCollection1, CMTagCollectionRef tagCollection2, CMTagCollectionRef *tagCollectionOut)
{
    CMTagCollectionRef out = NULL;
    OSStatus status = CMTagCollectionCreateMutableCopy(tagCollection1, NULL, (CMMutableTagCollectionRef *)&out);
    if (status)
        return status;
    charon_insert_all(charon_to(out), charon_to(tagCollection2));
    *tagCollectionOut = out;
    return noErr;
}

OSStatus CMTagCollectionCreateIntersection(CMTagCollectionRef tagCollection1, CMTagCollectionRef tagCollection2, CMTagCollectionRef *tagCollectionOut)
{
    CharonCMTagCollection *first = charon_to(tagCollection1), *second = charon_to(tagCollection2);
    if (!tagCollectionOut)
        return kCMTagCollectionError_ParamErr;
    CMTagCollectionRef out = NULL;
    OSStatus status = CMTagCollectionCreateMutable(kCFAllocatorDefault, 0, (CMMutableTagCollectionRef *)&out);
    if (status)
        return status;
    CharonCMTagCollection *result = charon_to(out);
    const CMTag *tags = first ? [first charon_tags] : NULL;
    for (NSUInteger index = 0; first && index < first.charon_count; index++)
        if (second && [second charon_contains:tags[index]])
            [result charon_insert:tags[index]];
    *tagCollectionOut = out;
    return noErr;
}

OSStatus CMTagCollectionCopyTagsOfCategories(CFAllocatorRef allocator, CMTagCollectionRef tagCollection, const CMTagCategory *categories,
                                             CMItemCount categoriesCount, CMTagCollectionRef *newCollectionOut)
{
    (void)allocator;
    CharonCMTagCollection *collection = charon_to(tagCollection);
    if (!collection || !categories || !newCollectionOut || !categoriesCount)
        return kCMTagCollectionError_ParamErr;
    CMTagCollectionRef out = NULL;
    OSStatus status = CMTagCollectionCreateMutable(kCFAllocatorDefault, 0, (CMMutableTagCollectionRef *)&out);
    if (status)
        return status;
    const CMTag *tags = [collection charon_tags];
    for (CMItemCount index = 0; index < categoriesCount; index++)
        for (NSUInteger one = 0; one < collection.charon_count; one++)
            if (tags[one].category == categories[index])
                [charon_to(out) charon_insert:tags[one]];
    *newCollectionOut = out;
    return noErr;
}

void CMTagCollectionApply(CMTagCollectionRef tagCollection, CMTagCollectionApplierFunction applier, void *context)
{
    CharonCMTagCollection *collection = charon_to(tagCollection);
    if (!collection || !applier)
        return;
    const CMTag *tags = [collection charon_tags];
    for (NSUInteger index = 0; index < collection.charon_count; index++)
        applier(tags[index], context);
}

CMTag CMTagCollectionApplyUntil(CMTagCollectionRef tagCollection, CMTagCollectionTagFilterFunction filter, void *context)
{
    CharonCMTagCollection *collection = charon_to(tagCollection);
    if (!collection || !filter)
        return kCMTagInvalid;
    const CMTag *tags = [collection charon_tags];
    for (NSUInteger index = 0; index < collection.charon_count; index++)
        if (filter(tags[index], context))
            return tags[index];
    return kCMTagInvalid;
}

CFDictionaryRef CMTagCollectionCopyAsDictionary(CMTagCollectionRef tagCollection, CFAllocatorRef allocator)
{
    (void)allocator;
    CharonCMTagCollection *collection = charon_to(tagCollection);
    if (!collection)
        return NULL;
    const CMTag *tags = [collection charon_tags];
    CFMutableArrayRef list = CFArrayCreateMutable(allocator, collection.charon_count, &kCFTypeArrayCallBacks);
    for (NSUInteger index = 0; index < collection.charon_count; index++) {
        CFNumberRef category = CFNumberCreate(allocator, kCFNumberSInt32Type, &(int){(int)tags[index].category});
        CFNumberRef value = CFNumberCreate(allocator, kCFNumberSInt32Type, &(int){(int)tags[index].value});
        CFNumberRef flags = CFNumberCreate(allocator, kCFNumberSInt32Type, &(int){(int)tags[index].dataType});
        const void *keys[] = {kCMTagCategoryKey, kCMTagValueKey, kCMTagDataTypeKey};
        const void *values[] = {category, value, flags};
        CFDictionaryRef entry = CFDictionaryCreate(allocator, keys, values, 3, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
        CFArrayAppendValue(list, entry);
        CFRelease(entry);
        CFRelease(category);
        CFRelease(value);
        CFRelease(flags);
    }
    const void *keys[] = {CFSTR("tags")};
    const void *values[] = {list};
    CFDictionaryRef out = CFDictionaryCreate(allocator, keys, values, 1, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    CFRelease(list);
    return out;
}

OSStatus CMTagCollectionCreateFromDictionary(CFDictionaryRef dict, CFAllocatorRef allocator, CMTagCollectionRef *newCollectionOut)
{
    if (!dict || !newCollectionOut)
        return kCMTagCollectionError_ParamErr;
    CMTagCollectionRef out = NULL;
    OSStatus status = CMTagCollectionCreateMutable(kCFAllocatorDefault, 0, (CMMutableTagCollectionRef *)&out);
    if (status)
        return status;
    CFArrayRef list = CFDictionaryGetValue(dict, CFSTR("tags"));
    if (list && CFGetTypeID(list) == CFArrayGetTypeID()) {
        CFIndex count = CFArrayGetCount(list);
        for (CFIndex index = 0; index < count; index++) {
            CFDictionaryRef entry = CFArrayGetValueAtIndex(list, index);
            if (!entry || CFGetTypeID(entry) != CFDictionaryGetTypeID())
                continue;
            int category = 0, value = 0, flags = 0;
            CFNumberGetValue(CFDictionaryGetValue(entry, kCMTagCategoryKey), kCFNumberIntType, &category);
            CFNumberGetValue(CFDictionaryGetValue(entry, kCMTagValueKey), kCFNumberIntType, &value);
            CFNumberGetValue(CFDictionaryGetValue(entry, kCMTagDataTypeKey), kCFNumberIntType, &flags);
            CMTag tag = {(CMTagCategory)category, (CMTagDataType)flags, (uint32_t)value};
            [charon_to(out) charon_insert:tag];
        }
    }
    (void)allocator;
    *newCollectionOut = out;
    return noErr;
}

#define charon_data_tag 16
#define charon_data_header 44

static void charon_data_put32(uint8_t *at, uint32_t value)
{
    at[0] = (uint8_t)(value >> 24);
    at[1] = (uint8_t)(value >> 16);
    at[2] = (uint8_t)(value >> 8);
    at[3] = (uint8_t)value;
}

static uint32_t charon_data_get32(const uint8_t *at)
{
    return ((uint32_t)at[0] << 24) | ((uint32_t)at[1] << 16) | ((uint32_t)at[2] << 8) | at[3];
}

static void charon_data_category(uint8_t *at, CMTagCategory category)
{
    at[0] = (uint8_t)(category >> 24);
    at[1] = (uint8_t)(category >> 16);
    at[2] = (uint8_t)(category >> 8);
    at[3] = (uint8_t)category;
}

CFDataRef CMTagCollectionCopyAsData(CMTagCollectionRef tagCollection, CFAllocatorRef allocator)
{
    CharonCMTagCollection *collection = charon_to(tagCollection);
    if (!collection)
        return NULL;
    const CMTag *tags = [collection charon_tags];
    size_t length = charon_data_header + (size_t)collection.charon_count * charon_data_tag;
    uint8_t *bytes = calloc(length, 1);
    if (!bytes)
        return NULL;
    charon_data_put32(bytes, (uint32_t)length);
    memcpy(bytes + 4, "tgco", 4);
    charon_data_put32(bytes + 8, 20);
    memcpy(bytes + 12, "tgin", 4);
    charon_data_put32(bytes + 16, 0);
    memcpy(bytes + 20, "tag coll", 8);
    charon_data_put32(bytes + 28, (uint32_t)(charon_data_tag * (collection.charon_count + 1)));
    memcpy(bytes + 32, "tgli", 4);
    charon_data_put32(bytes + 36, 0);
    charon_data_put32(bytes + 40, (uint32_t)collection.charon_count);
    for (NSUInteger index = 0; index < collection.charon_count; index++) {
        uint8_t *at = bytes + charon_data_header + index * charon_data_tag;
        charon_data_category(at, tags[index].category);
        charon_data_put32(at + 4, tags[index].dataType);
        for (int byte = 0; byte < 8; byte++)
            at[8 + byte] = (uint8_t)(tags[index].value >> (56 - 8 * byte));
    }
    CFDataRef data = CFDataCreate(allocator, bytes, (CFIndex)length);
    free(bytes);
    return data;
}

OSStatus CMTagCollectionCreateFromData(CFDataRef data, CFAllocatorRef allocator, CMTagCollectionRef *newCollectionOut)
{
    (void)allocator;
    if (!data || !newCollectionOut)
        return kCMTagCollectionError_ParamErr;
    *newCollectionOut = NULL;
    const uint8_t *bytes = CFDataGetBytePtr(data);
    size_t length = (size_t)CFDataGetLength(data);
    if (length < 8)
        return kCMTagCollectionError_ParamErr;
    if (length < charon_data_header)
        return (OSStatus)-12894;
    uint32_t count = charon_data_get32(bytes + 40);
    if (charon_data_get32(bytes) != length || charon_data_get32(bytes + 8) != 20)
        return (OSStatus)-12894;
    if (length != charon_data_header + (size_t)count * charon_data_tag)
        return kCMTagCollectionError_InvalidTagCollectionData;
    if (charon_data_get32(bytes + 28) != charon_data_tag * (count + 1))
        return (OSStatus)-12894;
    if (charon_data_get32(bytes + 16) || charon_data_get32(bytes + 36))
        return kCMTagCollectionError_InvalidTagCollectionDataVersion;
    if (memcmp(bytes + 20, "tag coll", 8))
        return kCMTagCollectionError_InvalidTagCollectionData;
    CMTagCollectionRef out = NULL;
    OSStatus status = CMTagCollectionCreateMutable(kCFAllocatorDefault, (CFIndex)count, (CMMutableTagCollectionRef *)&out);
    if (status)
        return status;
    for (uint32_t index = 0; index < count; index++) {
        const uint8_t *at = bytes + charon_data_header + (size_t)index * charon_data_tag;
        uint64_t value = 0;
        for (int byte = 0; byte < 8; byte++)
            value = (value << 8) | at[8 + byte];
        CMTagCategory category = (CMTagCategory)charon_data_get32(at);
        CMTag tag = {category, (CMTagDataType)charon_data_get32(at + 4), value};
        [charon_to(out) charon_insert:tag];
    }
    *newCollectionOut = out;
    return noErr;
}
