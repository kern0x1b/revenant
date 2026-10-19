#import <Foundation/Foundation.h>
#import <Contacts/Contacts.h>
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
    NSString *string = *(NSString * __unsafe_unretained *)value;
    return string ? [string description] : @"(nil)";
}

int main(int argc, char **argv)
{
    setvbuf(stdout, NULL, _IOLBF, 0);
    NSString *list = [NSString stringWithContentsOfFile:@(argv[1]) encoding:NSUTF8StringEncoding error:nil];
    NSMutableArray<NSString *> *names = [NSMutableArray array];
    for (NSString *line in [list componentsSeparatedByString:@"\n"]) {
        if ([line hasPrefix:@"CNLabel"]) {
            [names addObject:line];
        }
    }
    revenant_check(names.count == 207, @"the list holds the 207 names the corpus names", [NSString stringWithFormat:@"%lu", (unsigned long)names.count]);

    NSUInteger agreed = 0, absent = 0, differed = 0, missingHere = 0;
    for (NSString *name in names) {
        NSString *renamed = [@"revenantHost_" stringByAppendingString:name];
        void *found = dlsym(RTLD_DEFAULT, [renamed UTF8String]);
        void *theirs = dlsym(RTLD_DEFAULT, [name UTF8String]);
        if (!theirs) {
            absent++;
            printf("absent %s\n", [name UTF8String]);
            continue;
        }
        if (!found) {
            missingHere++;
            printf("FAIL the port carries no %s\n", [name UTF8String]);
            continue;
        }
        NSString *mine_ = plain(found);
        NSString *host_ = plain(theirs);
        if ([mine_ isEqualToString:host_]) {
            agreed++;
        } else {
            differed++;
            printf("FAIL %s: port %@, host %@\n", [name UTF8String], mine_, host_);
        }
    }
    check_named(agreed + differed + absent == names.count, @"every name of the list was read on both sides",
                [NSString stringWithFormat:@"%lu agreed, %lu differed, %lu absent from the host, %lu not carried",
                 (unsigned long)agreed, (unsigned long)differed, (unsigned long)absent, (unsigned long)missingHere]);
    check_named(differed == 0, @"every value the port carries is the value the host's own Contacts has",
                [NSString stringWithFormat:@"%lu of %lu differ", (unsigned long)differed, (unsigned long)names.count]);
    check_named(missingHere == 0, @"and the port carries every name of the list",
                [NSString stringWithFormat:@"%lu are not carried", (unsigned long)missingHere]);
    printf("agreed %lu, differed %lu, the host has no such name %lu\n", (unsigned long)agreed, (unsigned long)differed, (unsigned long)absent);

    NSString *aunt = plain(dlsym(RTLD_DEFAULT, "revenantHost_CNLabelContactRelationAunt"));
    check_named([aunt isEqualToString:@"_$!<Aunt>!$_"], @"and a name read on its own is the release's own token, not a spelling of the symbol",
                [NSString stringWithFormat:@"%@", aunt]);

    printf("checks=%d failures=%d\n", revenant_checks, revenant_failures);
    return revenant_failures == 0 ? 0 : 1;
}
