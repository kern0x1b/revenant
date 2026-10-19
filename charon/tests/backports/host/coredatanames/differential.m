#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
#import <CoreServices/CoreServices.h>
#import <dlfcn.h>
#import "check.h"

// The port's kUTType names against the host's own CoreServices, which exports every one of them. Each
// value was read out of the arm64e shared cache of iOS 18.0 through the symbol; this asks the running
// system for the same names and compares, so a value mistyped between the cache and the source is a
// failure here rather than a uniform type identifier no file would ever match.
//
// The names come from names.txt, which is the corpus's own list, so a name the source does not carry
// is a failure and not a skip.

static void check_named(BOOL passed, NSString *name, NSString *detail)
{
    charon_check(passed, [name UTF8String], detail);
}

static NSString *plain(void *value)
{
    if (!value) {
        return @"(not exported here)";
    }
    // dlsym gives the address of the variable, which holds the CFStringRef.
    CFStringRef string = *(CFStringRef __unsafe_unretained *)value;
    if (!string) {
        return @"(nil)";
    }
    return string ? (__bridge NSString *)string : @"(not a string)";
}

int main(int argc, char **argv)
{
    setvbuf(stdout, NULL, _IOLBF, 0);
    NSString *list = [NSString stringWithContentsOfFile:@(argv[1]) encoding:NSUTF8StringEncoding error:nil];
    NSMutableArray<NSString *> *names = [NSMutableArray array];
    for (NSString *line in [list componentsSeparatedByString:@"\n"]) {
        if ([line hasPrefix:@"NS"]) {
            [names addObject:line];
        }
    }
    check_named(names.count == 21, @"the list holds the 21 names this band carries", [NSString stringWithFormat:@"%lu", (unsigned long)names.count]);

    NSUInteger agreed = 0, absent = 0, differed = 0, missingHere = 0;
    for (NSString *name in names) {
        void *mine = dlsym(RTLD_DEFAULT, [@"charonHost_" stringByAppendingString:name].UTF8String);
        void *theirs = dlsym(RTLD_DEFAULT, name.UTF8String);
        if (!theirs) {
            // The host's CoreData keeps several of these to itself and exports no such name, which is
            // the same answer iOS 6.1.3 gives; the value is then checked against the reading in the
            // cache below rather than against a second source.
            absent++;
            continue;
        }
        if (!mine) {
            missingHere++;
            printf("FAIL the port carries no %s\n", [name UTF8String]); fflush(stdout);
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
    check_named(agreed + differed + absent == names.count, @"every name of the list was read",
                [NSString stringWithFormat:@"%lu agreed with the host, %lu differed, %lu the host exports no such name, %lu not carried",
                 (unsigned long)agreed, (unsigned long)differed, (unsigned long)absent, (unsigned long)missingHere]);
    check_named(differed == 0, @"and every name the host does export, the port carries the same value for",
                [NSString stringWithFormat:@"%lu of %lu differ", (unsigned long)differed, (unsigned long)agreed]);
    check_named(agreed > 0, @"which is at least one of them, or the comparison says nothing",
                @"the host exported none of them, so nothing was compared");
    check_named(missingHere == 0, @"and the port carries every name of the list",
                [NSString stringWithFormat:@"%lu are not carried", (unsigned long)missingHere]);
    printf("agreed %lu, differed %lu, the host has no such name %lu\n", (unsigned long)agreed, (unsigned long)differed, (unsigned long)absent);

    NSString *checksum = plain(dlsym(RTLD_DEFAULT, "charonHost_NSPersistentStoreModelVersionChecksumKey"));
    check_named([checksum isEqualToString:@"NSStoreModelVersionChecksumKey"], @"and a name read on its own is the store's own text, not a spelling of the symbol",
                [NSString stringWithFormat:@"%@", checksum]);

    printf("checks=%d failures=%d\n", charon_checks, charon_failures);
    return charon_failures == 0 ? 0 : 1;
}
