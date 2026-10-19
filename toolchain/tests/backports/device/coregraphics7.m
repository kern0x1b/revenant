#import <CoreGraphics/CoreGraphics.h>
#include <dlfcn.h>
#import "check.h"
#import "coregraphics7-cases.h"

static const char *expectations[][2] = {
#include "coregraphics7-expectations.h"
};

#pragma clang diagnostic ignored "-Wdeprecated-declarations"
#pragma clang diagnostic ignored "-Wunguarded-availability-new"

static NSString *image_of(void *symbol)
{
    Dl_info info;
    return dladdr(symbol, &info) ? @(info.dli_fname).lastPathComponent : @"?";
}

static void check_spaces(void)
{
    CHECK_EQUAL(image_of((void *)CGColorSpaceCopyICCData), @"libGraphicsBackports.dylib", "CGColorSpaceCopyICCData comes from the backports");
    CHECK_EQUAL(image_of((void *)CGColorSpaceUsesExtendedRange), @"libGraphicsBackports.dylib", "CGColorSpaceUsesExtendedRange comes from the backports");
    CHECK_EQUAL(image_of((void *)CGColorSpaceIsHDR), @"libGraphicsBackports.dylib", "CGColorSpaceIsHDR comes from the backports");
    CHECK_EQUAL(image_of((void *)CGColorSpaceCreateWithName), @"CoreGraphics", "CGColorSpaceCreateWithName is the release's");
    CFStringRef names[] = {kCGColorSpaceGenericRGB, kCGColorSpaceGenericGray, kCGColorSpaceGenericCMYK};
    for (int i = 0; i < 3; i++) {
        CGColorSpaceRef space = CGColorSpaceCreateWithName(names[i]);
        CHECK(space != NULL, "a generic space is made");
        CHECK(!CGColorSpaceUsesExtendedRange(space), "no space of this release uses an extended range");
        CHECK(!CGColorSpaceIsHDR(space) && !CGColorSpaceUsesITUR_2100TF(space) && !CGColorSpaceIsHLGBased(space) && !CGColorSpaceIsPQBased(space), "no space of this release is HDR, HLG or PQ");
        CFDataRef data = CGColorSpaceCopyICCData(space), profile = CGColorSpaceCopyICCProfile(space);
        CHECK((data == NULL) == (profile == NULL) && (!data || CFEqual(data, profile)), "the ICC data is the ICC profile of the release");
        if (data) CFRelease(data);
        if (profile) CFRelease(profile);
        CGColorSpaceRelease(space);
    }
    CGColorSpaceRef none = NULL;
    CHECK(!CGColorSpaceUsesExtendedRange(none) && !CGColorSpaceIsHDR(none), "a NULL space answers NO");
    CHECK(CGColorSpaceCreateWithName(kCGColorSpaceSRGB) == NULL, "the release makes no sRGB space by name, as recorded in its facts");
    CGColorSpaceRef device = CGColorSpaceCreateDeviceRGB();
    CHECK(device != NULL, "the device RGB space is made");
    CGColorSpaceRelease(device);
}

static BOOL agrees(NSString *actual, NSString *expected)
{
    if (!actual || !expected)
        return NO;
    NSRegularExpression *number = [NSRegularExpression regularExpressionWithPattern:@"-?[0-9]+\\.[0-9]+" options:0 error:NULL];
    NSString *skeleton_a = [number stringByReplacingMatchesInString:actual options:0 range:NSMakeRange(0, actual.length) withTemplate:@"#"];
    NSString *skeleton_e = [number stringByReplacingMatchesInString:expected options:0 range:NSMakeRange(0, expected.length) withTemplate:@"#"];
    if (![skeleton_a isEqualToString:skeleton_e])
        return NO;
    NSArray *a = [number matchesInString:actual options:0 range:NSMakeRange(0, actual.length)];
    NSArray *e = [number matchesInString:expected options:0 range:NSMakeRange(0, expected.length)];
    if (a.count != e.count)
        return NO;
    for (NSUInteger i = 0; i < a.count; i++) {
        double x = [[actual substringWithRange:[a[i] range]] doubleValue], y = [[expected substringWithRange:[e[i] range]] doubleValue];
        if (fabs(x - y) > 2e-3)
            return NO;
    }
    return YES;
}

int main(int argc, char **argv)
{
    @autoreleasepool {
        if (argc > 1)
            charon_log_to(@(argv[1]));
        NSMutableDictionary *expected = [NSMutableDictionary dictionary];
        for (size_t i = 0; i < sizeof(expectations) / sizeof(*expectations); i++)
            expected[@(expectations[i][0])] = @(expectations[i][1]);
        __block int compared = 0;
        charon_cg7_cases(^(NSString *name, NSString *value) {
            compared++;
            charon_check(agrees(value, expected[name]), [name UTF8String], [NSString stringWithFormat:@"%@ != %@", value, expected[name]]);
        });
        CHECK(compared == (int)expected.count, "every recorded answer was compared");
        check_spaces();
        printf("%d checks, %d failed\n", charon_checks, charon_failures);
    }
    return charon_failures;
}
