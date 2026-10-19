#import <UIKit/UIKit.h>
#include <stdio.h>

typedef id (*PlainFn)(id, SEL);
typedef NSInteger (*IntGetFn)(id, SEL);
typedef void (*IntSetFn)(id, SEL, NSInteger);
typedef NSUInteger (*UIntGetFn)(id, SEL);
typedef void (*UIntSetFn)(id, SEL, NSUInteger);

static void report(const char *side, const char *check, NSString *value)
{
    printf("%s\t%s\t%s\n", side, check, value ? [value UTF8String] : "nil");
}

static NSString *yes_no(BOOL answer)
{
    return answer ? @"yes" : @"no";
}

static void run(const char *side, Class cls)
{
    report(side, "search-superclass", NSStringFromClass([cls superclass]));

    SEL initSel = NSSelectorFromString(@"init");
    id allocated = [cls alloc];
    id first = ((PlainFn)[allocated methodForSelector:initSel])(allocated, initSel);
    allocated = [cls alloc];
    id second = ((PlainFn)[allocated methodForSelector:initSel])(allocated, initSel);

    SEL wordGet = NSSelectorFromString(@"wordMatchMethod");
    SEL compareGet = NSSelectorFromString(@"stringCompareOptions");
    report(side, "default-word-match", [NSString stringWithFormat:@"%ld", (long)((IntGetFn)[first methodForSelector:wordGet])(first, wordGet)]);
    report(side, "default-compare-options", [NSString stringWithFormat:@"%lu", (unsigned long)((UIntGetFn)[first methodForSelector:compareGet])(first, compareGet)]);

    report(side, "equal-to-equal-defaults", yes_no([first isEqual:second]));
    report(side, "equal-to-nil", yes_no([first isEqual:nil]));
    report(side, "equal-to-string", yes_no([first isEqual:@"options"]));
    report(side, "equal-to-self", yes_no([first isEqual:first]));
    report(side, "hash-equal-defaults", yes_no([first hash] == [second hash]));

    SEL wordSet = NSSelectorFromString(@"setWordMatchMethod:");
    if ([first respondsToSelector:wordSet]) {
        ((IntSetFn)[first methodForSelector:wordSet])(first, wordSet, 2);
        report(side, "wordmatch-setter", [NSString stringWithFormat:@"%ld", (long)((IntGetFn)[first methodForSelector:wordGet])(first, wordGet)]);
    } else {
        report(side, "wordmatch-setter", @"no setter");
    }
    SEL compareSet = NSSelectorFromString(@"setStringCompareOptions:");
    if ([second respondsToSelector:compareSet]) {
        ((UIntSetFn)[second methodForSelector:compareSet])(second, compareSet, 1);
        report(side, "compare-setter", [NSString stringWithFormat:@"%lu", (unsigned long)((UIntGetFn)[second methodForSelector:compareGet])(second, compareGet)]);
    } else {
        report(side, "compare-setter", @"no setter");
    }
}

int main(void)
{
    @autoreleasepool {
        setvbuf(stdout, NULL, _IONBF, 0);
        run("host", NSClassFromString(@"UITextSearchOptions"));
        run("port", [UITextSearchOptions class]);
    }
    return 0;
}
