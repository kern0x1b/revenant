#import <Foundation/Foundation.h>
#include <stdio.h>
#include "revenant/guest_memory.h"

@interface Node : NSObject {
    unsigned value_;
}
- (id)initWithValue:(unsigned)value;
- (unsigned)value;
@end

@implementation Node
- (id)initWithValue:(unsigned)value
{
    self = [super init];
    if (self) {
        value_ = value;
    }
    return self;
}

- (unsigned)value
{
    return value_;
}
@end

int main(void)
{
    unsigned sum = 0;
    for (unsigned i = 0; i < 200000u; ++i) {
        Node *node = [[Node alloc] initWithValue:i];
        for (unsigned j = 0; j < 8u; ++j) {
            sum += [node value];
        }
        [node release];
    }
    printf("bench-entry symbol=Node.initWithValue address=%p\n", (void *)[Node instanceMethodForSelector:@selector(initWithValue:)]);
    printf("bench-entry symbol=Node.value address=%p\n", (void *)[Node instanceMethodForSelector:@selector(value)]);
    revenant_guest_memory_t memory;
    revenant_guest_memory_read_self(&memory);
    printf("bench alloc checksum=%u iterations=200000 virtual=%llu resident=%llu peak=%llu peak_known=%d\n",
        sum, (unsigned long long)memory.virtual_bytes, (unsigned long long)memory.resident_bytes,
        (unsigned long long)memory.peak_resident_bytes, (int)memory.peak_known);
    return 0;
}
