#import <Foundation/Foundation.h>
#include <dispatch/dispatch.h>
#include <unistd.h>
#import "check.h"

// The owner thread enumerates the keys of each table while other threads drop the keys and values: a read of every entry's
// key, which the port's contract (facts) does not promise to survive before 5.0. A probe of the first round of this work,
// kept in the tree for what the facts say of it (5.1.1 clean, 4.3 SIGSEGV within 1.1 guest seconds; on the host the port before
// the __weak read ended in SIGSEGV 3 of 3); differential.m's enumeration_checks is the test that holds it now.
// Built and run by probes.sh (MAPTABLE6_PROBES=1 adds it to emulate/xmake.lua).
@interface NSMapTable (H)
+ (instancetype)charonHost_weakToStrongObjectsMapTable;
+ (instancetype)charonHost_strongToWeakObjectsMapTable;
+ (instancetype)charonHost_weakToWeakObjectsMapTable;
@end

int main(void)
{
    const char *names[] = {"weakToStrong", "strongToWeak", "weakToWeak"};
    NSMapTable *(^makers[])(void) = {
        ^{ return [NSMapTable charonHost_weakToStrongObjectsMapTable]; },
        ^{ return [NSMapTable charonHost_strongToWeakObjectsMapTable]; },
        ^{ return [NSMapTable charonHost_weakToWeakObjectsMapTable]; },
    };
    for (int m = 0; m < 3; m++) {
        NSMapTable *table = makers[m]();
        dispatch_queue_t queue = dispatch_queue_create("enum.release", DISPATCH_QUEUE_CONCURRENT);
        dispatch_group_t group = dispatch_group_create();
        long seen = 0;
        for (long i = 0; i < 100000; i++) {
            @autoreleasepool {
                NSObject *key = [NSObject new], *value = [NSObject new];
                [table setObject:value forKey:key];
                dispatch_group_async(group, queue, ^{ (void)key; (void)value; usleep(i % 3); });
                if (i % 16 == 0)
                    for (id each in [table keyEnumerator]) {
                        seen++;
                        (void)[each hash];
                    }
            }
        }
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        printf("%s: enumerated %ld keys, count %lu\n", names[m], seen, (unsigned long)[table count]);
        fflush(stdout);
        CHECK_EQUAL(@([table count]), @0, names[m]);
    }
    printf("%d checks, %d failures\n", charon_checks, charon_failures);
    return charon_failures ? 1 : 0;
}
