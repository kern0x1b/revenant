#import <Foundation/Foundation.h>
#import <IOSurface/IOSurfaceObjC.h>
#import <dlfcn.h>
#import "check.h"

// The port's IOSurface property keys against the host's own IOSurface, which exports every one of
// them. Each value was read out of the arm64e shared cache of iOS 18.0 through the symbol; this asks
// the running system for the same keys and compares, so a key mistyped between the cache and the
// source is a failure here rather than a key no surface answers to.

static void check_named(BOOL passed, NSString *name, NSString *detail)
{
    charon_check(passed, [name UTF8String], detail);
}

static NSString *plain(void *value)
{
    if (!value) {
        return @"(not exported here)";
    }
    // dlsym gives the address of the variable, which holds the NSString *.
    NSString *string = *(NSString * __unsafe_unretained *)value;
    return string ? [string description] : @"(nil)";
}

int main(int argc, char **argv)
{
    setvbuf(stdout, NULL, _IOLBF, 0);
    NSString *list = [NSString stringWithContentsOfFile:@(argv[1]) encoding:NSUTF8StringEncoding error:nil];
    NSMutableArray<NSString *> *names = [NSMutableArray array];
    for (NSString *line in [list componentsSeparatedByString:@"\n"]) {
        if ([line hasPrefix:@"IOSurface"] || [line hasPrefix:@"kIOSurface"]) {
            [names addObject:line];
        }
    }
    check_named(names.count == 33, @"the list holds the 33 keys the corpus names", [NSString stringWithFormat:@"%lu", (unsigned long)names.count]);

    NSUInteger agreed = 0, absent = 0, differed = 0, missingHere = 0;
    for (NSString *name in names) {
        void *mine = dlsym(RTLD_DEFAULT, [@"charonHost_" stringByAppendingString:name].UTF8String);
        void *theirs = dlsym(RTLD_DEFAULT, name.UTF8String);
        if (!theirs) {
            absent++;
            printf("absent %s\n", [name UTF8String]);
            continue;
        }
        if (!mine) {
            missingHere++;
            printf("FAIL the port carries no %s\n", [name UTF8String]);
            continue;
        }
        NSString *a = plain(mine), *b = plain(theirs);
        if ([a isEqualToString:b]) {
            agreed++;
        } else {
            differed++;
            printf("FAIL %s: port %@, host %@\n", [name UTF8String], a, b);
        }
    }
    check_named(agreed + differed + absent == names.count, @"every key of the list was read on both sides",
                [NSString stringWithFormat:@"%lu agreed, %lu differed, %lu absent from the host, %lu not carried",
                 (unsigned long)agreed, (unsigned long)differed, (unsigned long)absent, (unsigned long)missingHere]);
    check_named(differed == 0, @"every value the port carries is the one the host's IOSurface has",
                [NSString stringWithFormat:@"%lu of %lu differ", (unsigned long)differed, (unsigned long)names.count]);
    check_named(missingHere == 0, @"and the port carries every key of the list",
                [NSString stringWithFormat:@"%lu are not carried", (unsigned long)missingHere]);
    printf("agreed %lu, differed %lu, the host has no such key %lu\n", (unsigned long)agreed, (unsigned long)differed, (unsigned long)absent);

    NSString *bytes = plain(dlsym(RTLD_DEFAULT, "charonHost_IOSurfacePropertyKeyBytesPerRow"));
    check_named([bytes isEqualToString:@"IOSurfaceBytesPerRow"], @"and a key read on its own is the surface's own text, not a spelling of the symbol",
                [NSString stringWithFormat:@"%@", bytes]);

    printf("checks=%d failures=%d\n", charon_checks, charon_failures);
    return charon_failures == 0 ? 0 : 1;
}
