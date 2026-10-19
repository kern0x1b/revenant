#import <GameController/GameController.h>
#include <dlfcn.h>
#import "check.h"

#pragma clang diagnostic ignored "-Wunguarded-availability-new"
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

static NSMutableArray *elsewhere;
static NSMutableArray *different;
static int strings, codes, floats;

static void where(const void *address, const char *name)
{
    Dl_info info;
    if (!dladdr(address, &info) || strcmp(strrchr(info.dli_fname, '/') + 1, "libGameControllerBackports.dylib"))
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
#define NAME_CODE(name, value) \
        do { where(&name, #name); codes++; if ((long)name != (long)(value)) [different addObject:@(#name)]; } while (0);
#define NAME_FLOAT(name, value) \
        do { where(&name, #name); floats++; if (name != (value)) [different addObject:@(#name)]; } while (0);
#include "gamecontroller-names.h"
        CHECK(strings == 187, "there are 187 string names");
        CHECK(codes == 134, "there are 134 key codes");
        CHECK(floats == 1, "and the infinite duration of a haptic");
        CHECK(elsewhere.count == 0, "every name comes from the backports");
        if (elsewhere.count)
            printf("  elsewhere: %s\n", [elsewhere componentsJoinedByString:@" "].UTF8String);
        CHECK(different.count == 0, "every name has the value the host gives it");
        if (different.count)
            printf("  different: %s\n", [different componentsJoinedByString:@" "].UTF8String);
        CHECK_EQUAL(GCInputButtonA, @"Button A", "the button A of a profile is named as the header says");
        CHECK(GCKeyCodeKeyA == 4 && GCKeyCodeKeyZ == 29, "the key codes are those of the keyboard usage page");
        CHECK(GCHapticDurationInfinite == 1000000.0f, "the infinite haptic duration");
        printf("%d checks, %d failed\n", charon_checks, charon_failures);
    }
    return charon_failures;
}
