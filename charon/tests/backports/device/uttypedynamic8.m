#import <Foundation/Foundation.h>
#import <MobileCoreServices/MobileCoreServices.h>
#import "check.h"

// UTTypeIsDynamic and UTTypeIsDeclared of iOS 8 against the release's own declarations
// (facts/MobileCoreServices/UTTypeDynamic.md). Built with packages/a/apple-backports/UIKit/UTTypeDynamic8.m
// compiled in: 6.1.3 exports neither function.

int main(int argc, char **argv)
{
    @autoreleasepool {
        if (argc > 1)
            charon_log_to([NSString stringWithUTF8String:argv[1]]);
        NSArray *declared = @[@"public.jpeg", @"public.JPEG", @"public.png", @"public.data", @"public.item", @"com.apple.quicktime-movie", @"public.mpeg-4", @"com.adobe.pdf"];
        for (NSString *identifier in declared) {
            char label[128];
            snprintf(label, sizeof label, "%s is declared and not dynamic", identifier.UTF8String);
            CHECK(UTTypeIsDeclared((__bridge CFStringRef)identifier) && !UTTypeIsDynamic((__bridge CFStringRef)identifier), label);
        }
        NSArray *undeclared = @[@"com.example.undeclared", @"", @"dyn.ah62d4rv4ge80e5pe"];
        for (NSString *identifier in undeclared) {
            char label[128];
            snprintf(label, sizeof label, "'%s' is not declared", identifier.UTF8String);
            CHECK(!UTTypeIsDeclared((__bridge CFStringRef)identifier), label);
        }
        CFStringRef made = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, CFSTR("zzqq"), NULL);
        printf("measure the release's identifier for .zzqq: %s\n", [(__bridge NSString *)made UTF8String]);
        CHECK(UTTypeIsDynamic(made), "the release's identifier for an unknown extension is dynamic");
        CHECK(!UTTypeIsDeclared(made), "and not declared");
        CFStringRef jpeg = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, CFSTR("jpg"), NULL);
        CHECK(!UTTypeIsDynamic(jpeg) && UTTypeIsDeclared(jpeg), "the release's identifier for .jpg is declared");
        CHECK(!UTTypeIsDeclared(NULL) && !UTTypeIsDynamic(NULL), "NULL is neither");
        printf("checks=%d failures=%d\n", charon_checks, charon_failures);
    }
    return charon_failures ? 1 : 0;
}
