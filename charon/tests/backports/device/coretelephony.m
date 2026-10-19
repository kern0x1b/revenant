#import <CoreTelephony/CTTelephonyNetworkInfo.h>
#include <dlfcn.h>
#import <objc/runtime.h>
#import "check.h"

#pragma clang diagnostic ignored "-Wdeprecated-declarations"
#pragma clang diagnostic ignored "-Wunguarded-availability-new"

static NSString *image_of(void *symbol)
{
    Dl_info info;
    return dladdr(symbol, &info) ? @(info.dli_fname).lastPathComponent : @"?";
}

int main(int argc, char **argv)
{
    @autoreleasepool {
        if (argc > 1)
            charon_log_to(@(argv[1]));
        NSArray *names = @[CTRadioAccessTechnologyGPRS, CTRadioAccessTechnologyEdge, CTRadioAccessTechnologyWCDMA, CTRadioAccessTechnologyHSDPA, CTRadioAccessTechnologyHSUPA, CTRadioAccessTechnologyCDMA1x, CTRadioAccessTechnologyCDMAEVDORev0, CTRadioAccessTechnologyCDMAEVDORevA, CTRadioAccessTechnologyCDMAEVDORevB, CTRadioAccessTechnologyeHRPD, CTRadioAccessTechnologyLTE];
        CHECK_EQUAL(image_of((void *)&CTRadioAccessTechnologyWCDMA), @"libCoreTelephonyBackports.dylib", "the WCDMA name comes from the backports");
        NSArray *expected = @[@"CTRadioAccessTechnologyGPRS", @"CTRadioAccessTechnologyEdge", @"CTRadioAccessTechnologyWCDMA", @"CTRadioAccessTechnologyHSDPA", @"CTRadioAccessTechnologyHSUPA", @"CTRadioAccessTechnologyCDMA1x", @"CTRadioAccessTechnologyCDMAEVDORev0", @"CTRadioAccessTechnologyCDMAEVDORevA", @"CTRadioAccessTechnologyCDMAEVDORevB", @"CTRadioAccessTechnologyeHRPD", @"CTRadioAccessTechnologyLTE"];
        CHECK_EQUAL(names, expected, "each name is its own string");
        CHECK_EQUAL(CTRadioAccessTechnologyDidChangeNotification, @"CTRadioAccessTechnologyDidChangeNotification", "the notification name");
        CTTelephonyNetworkInfo *info = [[CTTelephonyNetworkInfo alloc] init];
        CHECK([info respondsToSelector:@selector(currentRadioAccessTechnology)], "the property answers");
        NSString *technology = info.currentRadioAccessTechnology;
        printf("technology: %s\n", technology ? [technology UTF8String] : "nil");
        CHECK(technology == nil || [names containsObject:technology], "the technology is nil or one of the eleven names");
        SEL private = sel_registerName("radioAccessTechnology");
        if (![info respondsToSelector:private])
            CHECK(technology == nil, "a release with no private technology class answers nil");
        printf("%d checks, %d failed\n", charon_checks, charon_failures);
    }
    return charon_failures;
}
