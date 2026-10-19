#import <Foundation/Foundation.h>
#include <sys/xattr.h>
#include <unistd.h>
#import "check.h"

extern id CharonHostcharon_resource_value(NSString *path, NSString *key);

static uint64_t state = 0x7E50C0ull;

static uint32_t next(void)
{
    state = state * 6364136223846793005ull + 1442695040888963407ull;
    return (uint32_t)(state >> 33);
}

int main(int argc, char **argv)
{
    @autoreleasepool {
        NSFileManager *manager = [NSFileManager defaultManager];
        NSString *base = [NSTemporaryDirectory() stringByAppendingPathComponent:@"f14-keys"];
        [manager removeItemAtPath:base error:NULL];
        [manager createDirectoryAtPath:base withIntermediateDirectories:YES attributes:nil error:NULL];
        NSArray *keys = @[NSURLMayShareFileContentKey, NSURLMayHaveExtendedAttributesKey, NSURLIsPurgeableKey, NSURLIsSparseKey, NSURLVolumeSupportsFileProtectionKey];
        NSUInteger cases = argc > 1 ? (NSUInteger)atoi(argv[1]) : 400, wrong = 0;
        NSMutableArray *samples = [NSMutableArray array];
        for (NSUInteger index = 0; index < cases; index++) {
            NSString *path = [base stringByAppendingPathComponent:[NSString stringWithFormat:@"item%lu", (unsigned long)index]];
            switch (next() % 6) {
            case 0: [@"hello" writeToFile:path atomically:NO encoding:NSUTF8StringEncoding error:NULL]; break;
            case 1: {
                FILE *file = fopen(path.UTF8String, "w");
                fseek(file, (long)(1 + next() % 200) * 1024 * 1024, SEEK_SET);
                fputc('x', file);
                fclose(file);
                break;
            }
            case 2:
                [@"x" writeToFile:path atomically:NO encoding:NSUTF8StringEncoding error:NULL];
                setxattr(path.UTF8String, "user.test", "1", 1, 0, 0);
                break;
            case 3: [manager createDirectoryAtPath:path withIntermediateDirectories:NO attributes:nil error:NULL]; break;
            case 4: symlink("/etc/hosts", path.UTF8String); break;
            default: [[NSData data] writeToFile:path atomically:NO]; break;
            }
            NSURL *URL = [NSURL fileURLWithPath:path];
            for (NSString *key in keys) {
                id theirs = nil;
                [URL getResourceValue:&theirs forKey:key error:NULL];
                id ours = CharonHostcharon_resource_value(path, key);
                if (!(ours == theirs || [ours isEqual:theirs])) {
                    wrong++;
                    if (samples.count < 8)
                        [samples addObject:[NSString stringWithFormat:@"%@ %@: port %@ system %@", path.lastPathComponent, key, ours, theirs]];
                }
            }
        }
        for (NSString *sample in samples)
            printf("  %s\n", sample.UTF8String);
        [manager removeItemAtPath:base error:NULL];
        charon_check(wrong == 0, "the values of the new resource keys are the system's for files, folders and links", [NSString stringWithFormat:@"%lu differ", (unsigned long)wrong]);
    }
    printf("checks=%d failures=%d\n", charon_checks, charon_failures);
    return charon_failures;
}
