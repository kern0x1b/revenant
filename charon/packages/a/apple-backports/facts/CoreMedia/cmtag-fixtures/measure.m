#import <CoreMedia/CoreMedia.h>
#import <CoreMedia/CMTag.h>
#import <Foundation/Foundation.h>
#include <stdio.h>
static CMTag tag(CMTagCategory c, CMTagDataType d, uint64_t v){ CMTag m={c,d,v}; return m; }
static void show(const char *label, CMTag t)
{
    printf("%-40s %d/%u valid %d hash %lu\n", label, (int)t.category, (unsigned)t.dataType, CMTagIsValid(t), (unsigned long)CMTagHash(t));
}
int main(void){ setvbuf(stdout,NULL,_IONBF,0); @autoreleasepool {
    CMTag ostype = tag(kCMTagCategory_MediaType, kCMTagDataType_OSType, 'vide');
    CMTag sint = tag(kCMTagCategory_TrackID, kCMTagDataType_SInt64, 7);
    CMTag flags = tag(kCMTagCategory_PixelFormat, kCMTagDataType_Flags, 3);
    CMTag flt = tag(kCMTagCategory_TrackID, kCMTagDataType_Float64, 0x3FF8000000000000ULL);
    CMTag invalid = kCMTagInvalid;
    CMTag empty = tag(kCMTagCategory_Undefined, kCMTagDataType_Invalid, 0);
    show("ostype 'vide'", ostype); show("sint 7", sint); show("flags 3", flags);
    show("float 1.5", flt); show("kCMTagInvalid", invalid); show("empty", empty);
    printf("-- make\n");
    show("MakeWithOSTypeValue", CMTagMakeWithOSTypeValue(kCMTagCategory_MediaType, 'vide'));
    show("MakeWithSInt64Value", CMTagMakeWithSInt64Value(kCMTagCategory_TrackID, 7));
    show("MakeWithFlagsValue", CMTagMakeWithFlagsValue(kCMTagCategory_PixelFormat, 3));
    show("MakeWithFloat64Value", CMTagMakeWithFloat64Value(kCMTagCategory_TrackID, 1.5));
    show("MakeWithFloat64Value 0", CMTagMakeWithFloat64Value(kCMTagCategory_TrackID, 0.0));
    printf("-- equality and order\n");
    printf("equal ostype ostype %d, equal ostype sint %d\n", CMTagEqualToTag(ostype, ostype), CMTagEqualToTag(ostype, sint));
    printf("compare ostype/sint %ld ostype/flags %ld sint/ostype %ld\n",
           (long)CMTagCompare(ostype, sint), (long)CMTagCompare(ostype, flags), (long)CMTagCompare(sint, ostype));
    printf("compare invalid/empty %ld empty/invalid %ld\n", (long)CMTagCompare(invalid, empty), (long)CMTagCompare(empty, invalid));
    printf("category equal %d %d  value equal %d %d\n",
           CMTagCategoryEqualToTagCategory(ostype, ostype), CMTagCategoryEqualToTagCategory(ostype, sint),
           CMTagCategoryValueEqualToValue(ostype, ostype), CMTagCategoryValueEqualToValue(ostype, sint));
    printf("-- has and get\n");
    printf("has category %d %d, has ostype %d, has sint %d, has flags %d, has float %d\n",
           CMTagHasCategory(ostype, kCMTagCategory_MediaType), CMTagHasCategory(ostype, kCMTagCategory_TrackID),
           CMTagHasOSTypeValue(ostype), CMTagHasSInt64Value(sint), CMTagHasFlagsValue(flags), CMTagHasFloat64Value(flt));
    printf("get category %u get value %llu get dataType %u\n", (unsigned)CMTagGetCategory(ostype),
           (unsigned long long)CMTagGetValue(ostype), (unsigned)CMTagGetValueDataType(ostype));
    printf("get ostype %u get sint %lld get flags %u get float %g\n", (unsigned)CMTagGetOSTypeValue(ostype),
           (long long)CMTagGetSInt64Value(sint), (unsigned)CMTagGetFlagsValue(flags), CMTagGetFloat64Value(flt));
    printf("get ostype of a sint tag %u, get sint of an ostype tag %lld\n", (unsigned)CMTagGetOSTypeValue(sint), (long long)CMTagGetSInt64Value(ostype));
    printf("get value of invalid %llu get category of invalid %u\n", (unsigned long long)CMTagGetValue(invalid), (unsigned)CMTagGetCategory(invalid));
    printf("-- description\n");
    for (int which = 0; which < 5; which++) {
        CMTag t = which == 0 ? ostype : which == 1 ? sint : which == 2 ? flags : which == 3 ? flt : invalid;
        CFStringRef d = CMTagCopyDescription(NULL, t);
        char b[256] = {0};
        if (d) CFStringGetCString(d, b, sizeof b, kCFStringEncodingUTF8);
        printf("  %s\n", d ? b : "(null)");
    }
    printf("-- dictionary\n");
    for (int which = 0; which < 5; which++) {
        CMTag t = which == 0 ? ostype : which == 1 ? sint : which == 2 ? flags : which == 3 ? flt : invalid;
        CFDictionaryRef d = CMTagCopyAsDictionary(t, NULL);
        printf("  %s\n", d ? [[(__bridge NSDictionary *)d description] UTF8String] : "(null)");
        CMTag back = CMTagMakeFromDictionary(d);
        printf("    back %d/%u/%llu valid %d\n", (int)back.category, (unsigned)back.dataType, (unsigned long long)back.value, CMTagIsValid(back));
    }
    printf("  make from nothing %d\n", CMTagIsValid(CMTagMakeFromDictionary((CFDictionaryRef)@"not a dictionary")));
} return 0; }
