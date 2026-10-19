#import <CoreMedia/CoreMedia.h>
#import <CoreMedia/CMTag.h>
#import <Foundation/Foundation.h>
#include <stdio.h>
static CMTag tag(CMTagCategory c, CMTagDataType d, uint64_t v){ CMTag m={c,d,v}; return m; }
int main(void){ setvbuf(stdout,NULL,_IONBF,0); @autoreleasepool {
    // The union of every tag the measurements used: the differential's set, the m4 category/dataType
    // sweep and the m5 value sweep. The values are written into the table, so nothing downstream ever
    // restates them - two hand-maintained copies of the same data is what made the last derivation a
    // clean-looking zero over the wrong pairs.
    CMTag t[] = {
        tag(0, 0, 0), tag(0, 5, 0), tag(0, 2, (uint64_t)-1), tag(1, 5, 0),
        tag(0x6d646961, 0, 0), tag(0x6d646961, 5, 0x76696465), tag(0x7472616b, 2, 7),
        tag(0x7472616b, 3, 0x3FF8000000000000ULL), tag(0x70697866, 7, 3), tag(0x7a7a7a7a, 7, 3),
        tag(0xffffffff, 5, 0), tag(0x6d646961, 2, 7), tag(0x6d646961, 5, 0), tag(0x2147483647, 2, 0xFFFFFFFFFFFFFFFFULL),
        tag(0x73766970, 5, 0x6c667274),
        // and the values whose ordering decides how the value is compared: negatives of each width, the
        // two zeroes, and the three doubles whose order is the host's to decide
        tag(0x7472616b, 3, 0xBFE0000000000000ULL),                 // -0.5
        tag(0x7472616b, 2, (uint64_t)-1),                           // int64 -1
        tag(0x7472616b, 3, 0x8000000000000000ULL),                 // -0.0
        tag(0x7472616b, 3, 0x0000000000000000ULL),                 // +0.0
        tag(0x7472616b, 3, 0x7FF0000000000000ULL),                 // +Inf
        tag(0x7472616b, 3, 0xFFF0000000000000ULL),                 // -Inf
        tag(0x7472616b, 3, 0x7FF8000000000000ULL),                 // NaN
        tag(0x7472616b, 3, 0xFFF8000000000000ULL),                 // -NaN
    };
    size_t count = sizeof t / sizeof *t;
    printf("# index category dataType value\n");
    for (size_t a = 0; a < count; a++)
        printf("T %zu %u %u %llu\n", a, (unsigned)t[a].category, (unsigned)t[a].dataType,
               (unsigned long long)t[a].value);
    printf("# a b host\n");
    for (size_t a = 0; a < count; a++)
        for (size_t b = a + 1; b < count; b++)
            printf("%zu %zu %ld\n", a, b, (long)CMTagCompare(t[a], t[b]));
    printf("# hash samples\n");
    for (size_t a = 0; a < count; a++)
        printf("H %zu %lu\n", a, (unsigned long)CMTagHash(t[a]));
} return 0; }
