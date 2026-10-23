#import <Foundation/Foundation.h>
#include <stdio.h>
#include "revenant/guest_memory.h"

int main(void)
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    NSMutableArray *array = [[NSMutableArray alloc] init];
    NSMutableDictionary *dictionary = [[NSMutableDictionary alloc] init];
    const unsigned count = 20000u;
    for (unsigned i = 0; i < count; ++i) {
        NSNumber *number = [[NSNumber alloc] initWithUnsignedInt:i];
        [array addObject:number];
        [dictionary setObject:number forKey:number];
        [number release];
    }
    unsigned sum = 0;
    for (unsigned i = 0; i < count; ++i) {
        sum += [[array objectAtIndex:i] unsignedIntValue];
        sum += [[dictionary objectForKey:[NSNumber numberWithUnsignedInt:i]] unsignedIntValue];
    }
    [dictionary release];
    [array release];
    [pool drain];
    revenant_guest_memory_t memory;
    revenant_guest_memory_read_self(&memory);
    printf("bench collections checksum=%u iterations=%u virtual=%llu resident=%llu peak=%llu peak_known=%d\n",
        sum, count, (unsigned long long)memory.virtual_bytes, (unsigned long long)memory.resident_bytes,
        (unsigned long long)memory.peak_resident_bytes, (int)memory.peak_known);
    return 0;
}
