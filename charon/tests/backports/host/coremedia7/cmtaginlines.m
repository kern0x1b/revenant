// CMTag's six header-carried inlines, measured against the host.
//
// There is no symbol to dlsym for an inline: the port's body only exists in a translation unit that
// includes the package's header, and the host's only in one that includes the real 26.2 header. So this
// one file is built twice - once per header - and run.sh compares what the two print. That is the only
// way to measure the port's own text, and it is what the three bodies that are the SDK's by necessity
// stand on: not a claim of independence, but the fact that both headers answer identically here.
#ifdef CHARON_CMTAG_PORT_HEADER
#import <Foundation/Foundation.h>
#import "CharonCMTag26.h"
#else
#import <CoreMedia/CoreMedia.h>
#import <CoreMedia/CMTag.h>
#endif
#import <Foundation/Foundation.h>
#include <stdio.h>


// One tag per data type, so CMTagIsValid is asked about all six; the two category extremes, so a
// signedness mistake in CMTagGetCategory or CMTagHasCategory shows up; and the value patterns that
// distinguish "uninterpreted" from "reinterpreted by data type": a float's bit pattern, both zeros, a
// NaN, an infinity, an SInt64's -1 and an unsigned all-ones. Built in main(), because mk() is a call and
// a file-scope initializer would need a constant expression.
static int make_tag(CMTag *tag, int category, unsigned dataType, unsigned long long value)
{
    tag->category = (CMTagCategory)category;
    tag->dataType = (CMTagDataType)dataType;
    tag->value = value;
    return 0;
}

#define TAGS 16

// The categories CMTagHasCategory is asked about: each tag's own, its neighbours, both zero and both
// extremes, so a comparison that ignored the sign or the width would answer differently.
#define PROBES 7

int main(void)
{
    // unsigned long long, not int: as an int table every one of these 64-bit patterns - the float bits,
    // both zeros, the NaN, the infinity, the unsigned all-ones - was truncated to 0, and the table then
    // said nothing the check could see. A value read that kept only the low half still passed.
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
        { 0, 0, 0x3FF8000000000000LL },   // a float's pattern with no data type
        { 1953653099, 0, 7 },              // an int64's value with no data type
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
