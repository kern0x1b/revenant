#import <AVFoundation/AVFoundation.h>
#import <CoreTelephony/CTTelephonyNetworkInfo.h>
#import <CoreVideo/CoreVideo.h>
#import <ImageIO/ImageIO.h>
#import <QuartzCore/QuartzCore.h>
#import <Security/Security.h>
#include <dlfcn.h>
#import "check.h"

#pragma clang diagnostic ignored "-Wunguarded-availability-new"
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

static NSMutableArray *elsewhere;
static NSMutableArray *different;
static int strings;

static void where(const void *address, const char *name)
{
    Dl_info info;
    if (!dladdr(address, &info) || !strstr(strrchr(info.dli_fname, '/') + 1, "Backports.dylib"))
        [elsewhere addObject:@(name)];
}

int main(int argc, char **argv)
{
    @autoreleasepool {
        if (argc > 1)
            charon_log_to(@(argv[1]));
        elsewhere = [NSMutableArray array];
        different = [NSMutableArray array];
#define NAME_STRING(name, value) \
        do { where(&name, #name); strings++; if (![(NSString *)name isEqualToString:value]) [different addObject:@(#name)]; } while (0);
#define NAME_CFSTRING(name, value) \
        do { where(&name, #name); strings++; if (![(__bridge NSString *)name isEqualToString:value]) [different addObject:@(#name)]; } while (0);
#include "names-more.h"
        CHECK(strings == 836, "there are 836 names");
        CHECK(elsewhere.count == 0, "every name comes from a backports library");
        if (elsewhere.count)
            printf("  elsewhere: %s\n", [elsewhere componentsJoinedByString:@" "].UTF8String);
        CHECK(different.count == 0, "every name has the text the iOS 12 cache holds");
        if (different.count)
            printf("  different: %s\n", [different componentsJoinedByString:@" "].UTF8String);
        CHECK_EQUAL(AVVideoCodecTypeHEVC, @"hvc1", "the HEVC codec type is the string the release names it by");
        printf("%d checks, %d failures\n", charon_checks, charon_failures);
        return charon_failures;
    }
}
