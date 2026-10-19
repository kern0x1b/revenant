#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
#import <CoreServices/CoreServices.h>
#import <dlfcn.h>
#import "check.h"

static void check_named(BOOL passed, NSString *name, NSString *detail)
{
    revenant_check(passed, [name UTF8String], detail);
}

static NSString *plain(void *value)
{
    if (!value) {
        return @"(not exported here)";
    }
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
        void *mine = dlsym(RTLD_DEFAULT, [@"revenantHost_" stringByAppendingString:name].UTF8String);
        void *theirs = dlsym(RTLD_DEFAULT, name.UTF8String);
        if (!theirs) {
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

    NSString *checksum = plain(dlsym(RTLD_DEFAULT, "revenantHost_NSPersistentStoreModelVersionChecksumKey"));
    check_named([checksum isEqualToString:@"NSStoreModelVersionChecksumKey"], @"and a name read on its own is the store's own text, not a spelling of the symbol",
                [NSString stringWithFormat:@"%@", checksum]);

    printf("checks=%d failures=%d\n", revenant_checks, revenant_failures);
    return revenant_failures == 0 ? 0 : 1;
}
