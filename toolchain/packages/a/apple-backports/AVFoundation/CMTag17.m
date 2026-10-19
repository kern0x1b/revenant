#import "CharonCMTag26.h"
#import "CharonCMTagSupport.h"
#import <CoreMedia/CoreMedia.h>
#import <CoreFoundation/CoreFoundation.h>
#include <string.h>

CMTag CMTagMakeWithOSTypeValue( CMTagCategory category, FourCharCode value )
{
    CMTag tag = {category, kCMTagDataType_OSType, (uint32_t)value};
    return tag;
}

CMTag CMTagMakeWithSInt64Value( CMTagCategory category, int64_t value )
{
    CMTag tag = {category, kCMTagDataType_SInt64, (uint64_t)value};
    return tag;
}

CMTag CMTagMakeWithFlagsValue( CMTagCategory category, uint64_t value )
{
    CMTag tag = {category, kCMTagDataType_Flags, value};
    return tag;
}

CMTag CMTagMakeWithFloat64Value( CMTagCategory category, double value )
{
    uint64_t bits;
    memcpy(&bits, &value, sizeof bits);
    CMTag tag = {category, kCMTagDataType_Float64, bits};
    return tag;
}

CMTagDataType CMTagGetValueDataType( CMTag tag )
{
    return tag.dataType;
}

FourCharCode CMTagGetOSTypeValue( CMTag tag )
{
    return (FourCharCode)(uint32_t)tag.value;
}

int64_t CMTagGetSInt64Value( CMTag tag )
{
    return (int64_t)tag.value;
}

uint64_t CMTagGetFlagsValue( CMTag tag )
{
    return tag.value;
}

double CMTagGetFloat64Value( CMTag tag )
{
    double value;
    uint64_t bits = tag.value;
    memcpy(&value, &bits, sizeof value);
    return value;
}

Boolean CMTagEqualToTag( CMTag tag1, CMTag tag2 )
{
    return charon_tag_equal(tag1, tag2);
}

Boolean CMTagHasOSTypeValue( CMTag tag )
{
    return tag.dataType == kCMTagDataType_OSType;
}

Boolean CMTagHasSInt64Value( CMTag tag )
{
    return tag.dataType == kCMTagDataType_SInt64;
}

Boolean CMTagHasFlagsValue( CMTag tag )
{
    return tag.dataType == kCMTagDataType_Flags;
}

Boolean CMTagHasFloat64Value( CMTag tag )
{
    return tag.dataType == kCMTagDataType_Float64;
}

static BOOL charon_tag_is_nan( CMTag tag )
{
    if ( tag.dataType != kCMTagDataType_Float64 )
        return NO;
    double number;
    uint64_t bits = tag.value;
    memcpy(&number, &bits, sizeof number);
    return number != number;
}

CFComparisonResult CMTagCompare( CMTag tag1, CMTag tag2 )
{
    int32_t left = (int32_t)tag1.category, right = (int32_t)tag2.category;
    if ( left != right )
        return left < right ? kCFCompareLessThan : kCFCompareGreaterThan;
    if ( tag1.dataType != tag2.dataType )
        return tag1.dataType < tag2.dataType ? kCFCompareLessThan : kCFCompareGreaterThan;
    if ( charon_tag_is_nan( tag1 ) || charon_tag_is_nan( tag2 ) )
        return kCFCompareEqualTo;
    if ( tag1.dataType == kCMTagDataType_Float64 ) {
        double one, two;
        uint64_t lowBits = tag1.value, highBits = tag2.value;
        memcpy(&one, &lowBits, sizeof one);
        memcpy(&two, &highBits, sizeof two);
        if ( one == 0.0 )
            one = 0.0;
        if ( two == 0.0 )
            two = 0.0;
        if ( one != two )
            return one < two ? kCFCompareLessThan : kCFCompareGreaterThan;
        return kCFCompareEqualTo;
    }
    if ( tag1.value != tag2.value )
        return tag1.value < tag2.value ? kCFCompareLessThan : kCFCompareGreaterThan;
    return kCFCompareEqualTo;
}

CFHashCode CMTagHash( CMTag tag )
{
    CFMutableStringRef text = CFStringCreateMutable(NULL, 0);
    char buffer[32];
    snprintf(buffer, sizeof buffer, "%d%u%llu", (int)tag.category, (unsigned)tag.dataType, (unsigned long long)tag.value);
    CFStringAppendCString(text, buffer, kCFStringEncodingASCII);
    CFHashCode hash = CFHash(text);
    CFRelease(text);
    return hash;
}

CFDictionaryRef CMTagCopyAsDictionary( CMTag tag, CFAllocatorRef allocator )
{
    unsigned category = (unsigned)tag.category;
    unsigned dataType = (unsigned)tag.dataType;
    uint64_t value = tag.value;
    CFNumberRef numbers[] = {
        CFNumberCreate(allocator, kCFNumberSInt32Type, &category),
        CFNumberCreate(allocator, kCFNumberSInt32Type, &dataType),
        CFNumberCreate(allocator, kCFNumberSInt64Type, &value),
    };
    const void *keys[] = {kCMTagCategoryKey, kCMTagDataTypeKey, kCMTagValueKey};
    const void *values[] = {numbers[0], numbers[1], numbers[2]};
    CFDictionaryRef out = CFDictionaryCreate(allocator, keys, values, 3, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    for (size_t index = 0; index < 3; index++)
        if (numbers[index])
            CFRelease(numbers[index]);
    return out;
}

CMTag CMTagMakeFromDictionary( CFDictionaryRef dict )
{
    if (!dict || CFGetTypeID(dict) != CFDictionaryGetTypeID())
        return kCMTagInvalid;
    unsigned category = 0, dataType = 0;
    uint64_t value = 0;
    const void *wanted[] = {kCMTagCategoryKey, kCMTagDataTypeKey, kCMTagValueKey};
    unsigned *shorts[] = {&category, &dataType};
    uint64_t *wide = &value;
    for (int index = 0; index < 3; index++) {
        CFTypeRef held = CFDictionaryGetValue(dict, wanted[index]);
        if (!held || CFGetTypeID(held) != CFNumberGetTypeID())
            return kCMTagInvalid;
        if (index < 2) {
            if (!CFNumberGetValue((CFNumberRef)held, kCFNumberSInt32Type, (void **)shorts[index]))
                return kCMTagInvalid;
        } else if (!CFNumberGetValue((CFNumberRef)held, kCFNumberSInt64Type, (void **)wide)) {
            return kCMTagInvalid;
        }
    }
    CMTag tag = {(CMTagCategory)category, (CMTagDataType)dataType, value};
    return tag;
}

static NSString *charon_category_text(CMTagCategory category)
{
    unsigned char bytes[4];
    for (int index = 0; index < 4; index++)
        bytes[index] = (unsigned char)((category >> (24 - index * 8)) & 0xFF);
    CFIndex length = 0;
    while (length < 4 && bytes[length])
        length++;
    return (__bridge NSString *)CFStringCreateWithBytes(NULL, bytes, (CFIndex)length, kCFStringEncodingMacRoman, false);
}

static NSString *charon_value_text(CMTag tag)
{
    switch (tag.dataType) {
    case kCMTagDataType_OSType:
        return [NSString stringWithFormat:@"'%@'", charon_category_text((CMTagCategory)(uint32_t)tag.value)];
    case kCMTagDataType_Flags:
        return [NSString stringWithFormat:@"0x%llx", (unsigned long long)tag.value];
    case kCMTagDataType_Float64: {
        double number;
        uint64_t bits = tag.value;
        memcpy(&number, &bits, sizeof number);
        return [NSString stringWithFormat:@"%.2f", number];
    }
    default:
        return [NSString stringWithFormat:@"%lld", (long long)tag.value];
    }
}

static NSString *charon_type_text(CMTagDataType type)
{
    switch (type) {
    case kCMTagDataType_OSType: return @"OSType";
    case kCMTagDataType_Flags: return @"flags";
    case kCMTagDataType_Float64: return @"Flt64";
    default: return @"int64";
    }
}

CFStringRef CMTagCopyDescription( CFAllocatorRef allocator, CMTag tag )
{
    (void)allocator;
    NSString *text;
    if (!CMTagIsValid(tag))
        text = [NSString stringWithFormat:@"{category:'%@'{INVALID}", charon_category_text(tag.category)];
    else
        text = [NSString stringWithFormat:@"{category:'%@' value:%@ <%@>}", charon_category_text(tag.category),
                                        charon_value_text(tag), charon_type_text(tag.dataType)];
    return (__bridge_retained CFStringRef)text;
}
