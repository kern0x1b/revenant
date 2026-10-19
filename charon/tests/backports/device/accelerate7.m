#import <Accelerate/Accelerate.h>
#include <dlfcn.h>
#import "check.h"
#import "accelerate7-cases.h"

#pragma clang diagnostic ignored "-Wunguarded-availability-new"

static const char *expectations[][2] = {
#include "accelerate7-expectations.h"
};

static BOOL agrees(NSString *actual, NSString *expected, int tolerance)
{
    if (!actual || !expected)
        return NO;
    if ([actual isEqualToString:expected])
        return YES;
    NSArray *a = [actual componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@",|"]];
    NSArray *e = [expected componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@",|"]];
    if (a.count != e.count)
        return NO;
    for (NSUInteger i = 0; i < a.count; i++) {
        if (abs([a[i] intValue] - [e[i] intValue]) > tolerance)
            return NO;
    }
    return YES;
}

int main(int argc, char **argv)
{
    @autoreleasepool {
        if (argc > 1)
            charon_log_to(@(argv[1]));
        Dl_info info;
        CHECK(dladdr((void *)vImageBuffer_InitWithCGImage, &info) != 0 && [@(info.dli_fname).lastPathComponent isEqualToString:@"libAccelerateBackports.dylib"], "vImageBuffer_InitWithCGImage comes from the backports");
        NSMutableDictionary *expected = [NSMutableDictionary dictionary];
        for (size_t i = 0; i < sizeof(expectations) / sizeof(*expectations); i++)
            expected[@(expectations[i][0])] = @(expectations[i][1]);
        __block int compared = 0;
        charon_vimage_cases(^(NSString *name, NSString *value) {
            compared++;
            int tolerance = ([name hasSuffix:@"pixels"] || [name hasSuffix:@" image"]) ? 1 : 0;
            charon_check(agrees(value, expected[name], tolerance), [name UTF8String], [NSString stringWithFormat:@"%@ != %@", value, expected[name]]);
        });
        CHECK(compared == (int)expected.count, "every recorded answer was compared");
        vImage_Buffer buffer = {0};
        CHECK(vImageBuffer_Init(&buffer, 10, 10, 32, kvImageNoFlags) == kvImageNoError, "a buffer is made");
        CHECK(buffer.rowBytes >= 40 && buffer.rowBytes % 16 == 0 && (uintptr_t)buffer.data % 16 == 0, "its row is a multiple of 16 bytes that holds the pixels and its data is aligned");
        free(buffer.data);
        printf("%d checks, %d failed\n", charon_checks, charon_failures);
    }
    return charon_failures;
}
