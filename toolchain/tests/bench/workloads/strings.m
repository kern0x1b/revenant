#import <Foundation/Foundation.h>
#include <stdio.h>
#include "revenant/guest_memory.h"

int main(void)
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    const unsigned count = 20000u;
    NSMutableString *text = [[NSMutableString alloc] init];
    for (unsigned i = 0; i < count; ++i) {
        [text appendFormat:@"%u,", i];
    }
    NSString *summary = [NSString stringWithFormat:@"%@:%u", text, (unsigned)[text length]];
    unsigned sum = (unsigned)[summary length];
    for (unsigned i = 0; i < 2000u; ++i) {
        NSString *piece = [NSString stringWithFormat:@"item-%u", i];
        sum += (unsigned)[[piece uppercaseString] length];
    }
    [text release];
    [pool drain];
    revenant_guest_memory_t memory;
    revenant_guest_memory_read_self(&memory);
    printf("bench strings checksum=%u iterations=%u virtual=%llu resident=%llu peak=%llu peak_known=%d\n",
        sum, count, (unsigned long long)memory.virtual_bytes, (unsigned long long)memory.resident_bytes,
        (unsigned long long)memory.peak_resident_bytes, (int)memory.peak_known);
    return 0;
}
