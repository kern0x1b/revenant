#import <Foundation/Foundation.h>
#import "keyedarchive11-cases.h"

void host_attach_prefixed(const char *prefix);

int main(int argc, char **argv)
{
    @autoreleasepool {
        if (argc < 2) {
            fprintf(stderr, "usage: %s expectations.json\n", argv[0]);
            return 2;
        }
        host_attach_prefixed("");

        KeyedArchive11Recorder *system = [KeyedArchive11Recorder new];
        keyedarchive11_run(@"", system);
        KeyedArchive11Recorder *ours = [KeyedArchive11Recorder new];
        keyedarchive11_run(@"charonHost_", ours);

        int failures = 0;
        for (NSString *name in [system.records.allKeys sortedArrayUsingSelector:@selector(compare:)]) {
            NSString *expected = system.records[name];
            NSString *found = ours.records[name];
            if ([expected isEqual:found]) {
                printf("ok   %s: %s\n", name.UTF8String, expected.UTF8String);
            } else {
                failures++;
                printf("FAIL %s: the system answers %s, the backport answers %s\n",
                       name.UTF8String, expected.UTF8String, (found ?: @"(nothing)").UTF8String);
            }
        }
        for (NSString *name in ours.records)
            if (!system.records[name])
                printf("note %s: only the backport records it\n", name.UTF8String);

        if (failures == 0) {
            NSData *json = [NSJSONSerialization dataWithJSONObject:system.records options:NSJSONWritingSortedKeys error:NULL];
            [json writeToFile:@(argv[1]) atomically:YES];
        }
        printf("%d of %lu checks failed\n", failures, (unsigned long)system.records.count);
        return failures > 0;
    }
}
