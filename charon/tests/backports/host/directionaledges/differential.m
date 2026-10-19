#import <UIKit/UIKit.h>
#import "directionaledges-cases.h"

extern const NSDirectionalEdgeInsets CharonHostNSDirectionalEdgeInsetsZero;
extern NSString *CharonHostNSStringFromDirectionalEdgeInsets(NSDirectionalEdgeInsets);
extern NSDirectionalEdgeInsets CharonHostNSDirectionalEdgeInsetsFromString(NSString *);
void host_attach_prefixed(const char *prefix);

int main(int argc, char **argv)
{
    @autoreleasepool {
        if (argc < 2) {
            fprintf(stderr, "usage: %s expectations.json\n", argv[0]);
            return 2;
        }
        host_attach_prefixed("charonHost_");

        DirectionalEdgesRecorder *system = [DirectionalEdgesRecorder new];
        DirectionalEdgesImplementation systemImplementation = {
            .prefix = @"", .zero = &NSDirectionalEdgeInsetsZero,
            .string = NSStringFromDirectionalEdgeInsets, .parse = NSDirectionalEdgeInsetsFromString};
        directionaledges_run(systemImplementation, system);

        DirectionalEdgesRecorder *ours = [DirectionalEdgesRecorder new];
        DirectionalEdgesImplementation ourImplementation = {
            .prefix = @"charonHost_", .zero = &CharonHostNSDirectionalEdgeInsetsZero,
            .string = CharonHostNSStringFromDirectionalEdgeInsets, .parse = CharonHostNSDirectionalEdgeInsetsFromString};
        directionaledges_run(ourImplementation, ours);

        int failures = 0;
        for (NSString *name in [system.records.allKeys sortedArrayUsingSelector:@selector(compare:)]) {
            NSString *expected = system.records[name], *found = ours.records[name];
            if ([expected isEqual:found]) {
                printf("ok   %s: %s\n", name.UTF8String, expected.UTF8String);
            } else {
                failures++;
                printf("FAIL %s: the system answers %s, the backport answers %s\n", name.UTF8String, expected.UTF8String, (found ?: @"(nothing)").UTF8String);
            }
        }
        if (failures == 0) {
            NSData *json = [NSJSONSerialization dataWithJSONObject:system.records options:NSJSONWritingSortedKeys error:NULL];
            [json writeToFile:@(argv[1]) atomically:YES];
        }
        printf("%d of %lu checks failed\n", failures, (unsigned long)system.records.count);
        return failures > 0;
    }
}
