#ifdef REVENANT_CMTAG_PORT_HEADER
#import <Foundation/Foundation.h>
#import "RevenantCMTag26.h"
#else
#import <CoreMedia/CoreMedia.h>
#import <CoreMedia/CMTag.h>
#endif
#import <Foundation/Foundation.h>
#include <stdio.h>


static int make_tag(CMTag *tag, int category, unsigned dataType, unsigned long long value)
{
    tag->category = (CMTagCategory)category;
    tag->dataType = (CMTagDataType)dataType;
    tag->value = value;
    return 0;
}

#define TAGS 16

#define PROBES 7

int main(void)
{
    static const unsigned long long spec[TAGS][3] = {
        { 0, 0, 0 },
        { 0, 1, 0x20202020 },
        { 0, 2, 'vide' },
        { 1953653099, 3, 7 },
        { 2147483647, 3, (unsigned long long)-1 },
        { 1953653099, 4, 0x3FF8000000000000LL },
        { 1953653099, 4, 0xBFE0000000000000LL },
        { 1953653099, 4, 0x0000000000000000LL },
        { 1953653099, 4, 0x8000000000000000LL },
        { 1953653099, 4, 0x7FF8000000000000LL },
        { 1953653099, 4, 0x7FF0000000000000LL },
        { 1885960294, 5, 3 },
        { (unsigned long long)(long long)-2147483647, 5, (unsigned long long)-1 },
        { (unsigned long long)(long long)-1, 5, 0 },
        { 0, 0, 0x3FF8000000000000LL },
        { 1953653099, 0, 7 },
    };
    static const CMTagCategory probes[PROBES] = {
        (CMTagCategory)0,
        (CMTagCategory)1,
        (CMTagCategory)-1,
        (CMTagCategory)2147483647,
        (CMTagCategory)-2147483647,
        (CMTagCategory)1953653099,
        (CMTagCategory)1885960294,
    };
    CMTag tags[TAGS];
    unsigned long checks = 0;
    unsigned i, j, p;

    for (i = 0; i < TAGS; i++)
        make_tag(&tags[i], (int)spec[i][0], (unsigned)spec[i][1], spec[i][2]);

    for (i = 0; i < TAGS; i++) {
        printf("tag %2u valid %d category %d type %u value %llu\n",
            i, (int)CMTagIsValid(tags[i]), (int)CMTagGetCategory(tags[i]),
            (unsigned)CMTagGetValueDataType(tags[i]),
            (unsigned long long)CMTagGetValue(tags[i]));
        checks += 3;
    }
    for (i = 0; i < TAGS; i++) {
        for (p = 0; p < PROBES; p++) {
            printf("hasCategory %2u %d %d\n", i, (int)probes[p],
                (int)CMTagHasCategory(tags[i], probes[p]));
            checks++;
        }
        for (j = 0; j < TAGS; j++) {
            printf("categories %2u %2u %d\n", i, j,
                (int)CMTagCategoryEqualToTagCategory(tags[i], tags[j]));
            printf("categoryValue %2u %2u %d\n", i, j,
                (int)CMTagCategoryValueEqualToValue(tags[i], tags[j]));
            checks += 2;
        }
    }
    printf("checks %lu\n", checks);
    return 0;
}
