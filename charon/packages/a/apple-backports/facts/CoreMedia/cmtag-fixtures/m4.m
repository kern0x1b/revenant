#import <CoreMedia/CoreMedia.h>
#import <CoreMedia/CMTag.h>
#import <Foundation/Foundation.h>
#include <stdio.h>
static CMTag tag(CMTagCategory c, CMTagDataType d, uint64_t v){ CMTag m={c,d,v}; return m; }
static void bytes(const char *label, CFStringRef text)
{
    if (!text) { printf("%-28s (null)\n", label); return; }
    const char *utf8 = CFStringGetCStringPtr(text, kCFStringEncodingUTF8);
    printf("%-28s %2ld bytes:", label, (long)CFStringGetLength(text));
    if (!utf8) { printf(" (not UTF8)"); } else
        for (const char *p = utf8; *p; p++) printf(" %02x", (unsigned char)*p);
    printf("\n");
}
int main(void){ setvbuf(stdout,NULL,_IONBF,0); @autoreleasepool {
    printf("-- (1) the descriptions, as bytes\n");
    CMTag invalid = kCMTagInvalid;
    bytes("invalid", CMTagCopyDescription(NULL, invalid));
    bytes("invalid again", CMTagCopyDescription(NULL, tag(0, 0, 0)));
    bytes("'mdia' no data type", CMTagCopyDescription(NULL, tag(0x6d646961, 0, 0)));
    bytes("0 category OSType", CMTagCopyDescription(NULL, tag(0, 5, 0)));
    bytes("'vide'", CMTagCopyDescription(NULL, tag(0x6d646961, 5, 0x76696465)));
    bytes("'trak' int64 7", CMTagCopyDescription(NULL, tag(0x7472616b, 2, 7)));
    bytes("'zzzz' flags 3", CMTagCopyDescription(NULL, tag(0x7a7a7a7a, 7, 3)));
    bytes("'trak' float 1.5", CMTagCopyDescription(NULL, tag(0x7472616b, 3, 0x3FF8000000000000ULL)));
    printf("\n-- (2) the compare order, one field at a time\n");
    const CMTagCategory cats[] = {0, 1, 0x6d646961, 0x70697866, 0x7472616b, 0x7a7a7a7a, 0xffffffff};
    const CMTagDataType types[] = {0, 2, 3, 5, 7};
    printf("  categories, value 0, type 5: ");
    for (size_t i = 0; i < 7; i++) printf("%ld ", (long)CMTagCompare(tag(cats[i], 5, 0), tag(0x6d646961, 5, 0)));
    printf("\n  data types, category 'trak', value 0: ");
    for (size_t i = 0; i < 5; i++) printf("%ld ", (long)CMTagCompare(tag(0x7472616b, types[i], 0), tag(0x7472616b, 5, 0)));
    printf("\n  values, category 'trak', type 2: ");
    const uint64_t values[] = {0, 1, 2, 3, 255, 256, 0xffffffff, 0x100000000ULL, 0xffffffffffffffffULL};
    for (size_t i = 0; i < 9; i++) printf("%ld ", (long)CMTagCompare(tag(0x7472616b, 2, values[i]), tag(0x7472616b, 2, 7)));
    printf("\n  invalid against each category, type 5, value 0: ");
    for (size_t i = 0; i < 7; i++) printf("%ld ", (long)CMTagCompare(invalid, tag(cats[i], 5, 0)));
    printf("\n  each category against invalid: ");
    for (size_t i = 0; i < 7; i++) printf("%ld ", (long)CMTagCompare(tag(cats[i], 5, 0), invalid));
    printf("\n");
} return 0; }
