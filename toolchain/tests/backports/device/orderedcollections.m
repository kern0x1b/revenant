#import <Foundation/Foundation.h>
#include <dlfcn.h>
#import "check.h"
#import "orderedcollections-cases.h"
#import "orderedcollections-expectations.h"

int main(void)
{
    @autoreleasepool {
        Dl_info info;
        CHECK(dladdr((__bridge const void *)[NSOrderedCollectionDifference class], &info) && !strcmp(strrchr(info.dli_fname, '/') + 1, "libFoundationBackports.dylib"),
              "NSOrderedCollectionDifference comes from the backports library");
        CHECK(dladdr((__bridge const void *)[NSOrderedCollectionChange class], &info) && !strcmp(strrchr(info.dli_fname, '/') + 1, "libFoundationBackports.dylib"),
              "NSOrderedCollectionChange comes from the backports library");
        CHECK(sizeof oc_expectations / sizeof oc_expectations[0] == OC_CASE_COUNT, "there is one recorded fingerprint for every case");
        size_t wrong = 0;
        for (size_t index = 0; index < OC_CASE_COUNT; index++) {
            NSString *answer = oc_answer(index);
            if (oc_hash(answer) != oc_expectations[index]) {
                wrong++;
                if (wrong <= 5) {
                    charon_check(NO, [NSString stringWithFormat:@"case %zu answers as the system does", index].UTF8String, answer);
                }
            }
        }
        CHECK(wrong == 0, "all recorded cases answer as the system does");

        NSArray *before = @[@"a", @"b", @"c", @"d"], *after = @[@"b", @"x", @"d", @"a", @"c"];
        NSOrderedCollectionDifference *difference = [after differenceFromArray:before];
        CHECK(difference.hasChanges && difference.insertions.count == 3 && difference.removals.count == 2, "a difference has its insertions and removals");
        CHECK_EQUAL([before arrayByApplyingDifference:difference], after, "applying the difference to the old array gives the new");
        CHECK_EQUAL([after arrayByApplyingDifference:difference.inverseDifference], before, "the inverse takes the new back to the old");
        CHECK([[before differenceFromArray:before] hasChanges] == NO, "equal arrays have no difference");
        CHECK([before arrayByApplyingDifference:[[NSOrderedCollectionDifference alloc] initWithChanges:@[[NSOrderedCollectionChange changeWithObject:@"z" type:NSCollectionChangeInsert index:9]]]] == nil, "an insertion past the end applies to nothing");
        NSMutableArray *array = [before mutableCopy];
        [array applyDifference:difference];
        CHECK_EQUAL(array, after, "a mutable array applies a difference to itself");
        NSMutableOrderedSet *set = [NSMutableOrderedSet orderedSetWithArray:before];
        [set applyDifference:[[NSOrderedSet orderedSetWithArray:after] differenceFromOrderedSet:[NSOrderedSet orderedSetWithArray:before]]];
        CHECK_EQUAL([set array], after, "a mutable ordered set does as well");
        printf("checks=%d failures=%d\n", charon_checks, charon_failures);
        return charon_failures;
    }
}
