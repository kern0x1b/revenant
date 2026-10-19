#import <CoreMedia/CoreMedia.h>
#import <CoreMedia/CMTag.h>
#import <Foundation/Foundation.h>
#include <stdio.h>
static CMTag tag(CMTagCategory c, CMTagDataType d, uint64_t v){ CMTag m={c,d,v}; return m; }
int main(void){ setvbuf(stdout,NULL,_IONBF,0); @autoreleasepool {
    // the one measurement that settles whether the value is a text sort: single digits and two digits
    const uint64_t values[] = {0,1,2,3,4,5,6,7,8,9,10,11,19,20,21,99,100};
    printf("  values against each other, category 'trak' type 2, as 0/1/2:\n   ");
    for (size_t i = 0; i < 17; i++) printf(" %2llu", (unsigned long long)values[i]);
    printf("\n");
    for (size_t a = 0; a < 17; a++) {
        printf("  %2llu:", (unsigned long long)values[a]);
        for (size_t b = 0; b < 17; b++) printf(" %2ld", (long)CMTagCompare(tag(0x7472616b,2,values[a]), tag(0x7472616b,2,values[b])));
        printf("\n");
    }
} return 0; }
