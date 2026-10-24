#import <Foundation/Foundation.h>
#include <dlfcn.h>
#include <stdio.h>
#include "revenant/guest_memory.h"

@interface Counter : NSObject
- (unsigned)bump:(unsigned)value;
@end

@implementation Counter
- (unsigned)bump:(unsigned)value
{
    return value * 3u + 1u;
}
@end

int main(void)
{
    Counter *counter = [[Counter alloc] init];
    unsigned sum = 0;
    for (unsigned i = 0; i < 1000000u; ++i) {
        sum += [counter bump:i];
    }
    printf("bench-entry symbol=objc_msgSend address=%p\n", dlsym(RTLD_DEFAULT, "objc_msgSend"));
    printf("bench-entry symbol=Counter.bump address=%p\n", (void *)[Counter instanceMethodForSelector:@selector(bump:)]);
    [counter release];
    revenant_guest_memory_t memory;
    revenant_guest_memory_read_self(&memory);
    printf("bench msgsend checksum=%u iterations=1000000 virtual=%llu resident=%llu peak=%llu peak_known=%d\n",
        sum, (unsigned long long)memory.virtual_bytes, (unsigned long long)memory.resident_bytes,
        (unsigned long long)memory.peak_resident_bytes, (int)memory.peak_known);
    return 0;
}
