#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import "check.h"

#pragma clang diagnostic ignored "-Wdeprecated-declarations"

CFDataRef revenant_host_CGColorSpaceCopyICCData(CGColorSpaceRef space);
bool revenant_host_CGColorSpaceUsesExtendedRange(CGColorSpaceRef space);
bool revenant_host_CGColorSpaceIsHDR(CGColorSpaceRef space);
bool revenant_host_CGColorSpaceUsesITUR_2100TF(CGColorSpaceRef space);
bool revenant_host_CGColorSpaceIsHLGBased(CGColorSpaceRef space);
bool revenant_host_CGColorSpaceIsPQBased(CGColorSpaceRef space);

static void check_spaces(void)
{
    CFStringRef names[] = {kCGColorSpaceGenericRGB, kCGColorSpaceGenericGray, kCGColorSpaceGenericCMYK};
    for (int i = 0; i < 3; i++) {
        CGColorSpaceRef space = CGColorSpaceCreateWithName(names[i]);
        CHECK(revenant_host_CGColorSpaceUsesExtendedRange(space) == CGColorSpaceUsesExtendedRange(space), "the extended range answer of a generic space is the system's");
        CHECK(revenant_host_CGColorSpaceIsHDR(space) == CGColorSpaceIsHDR(space), "the HDR answer of a generic space is the system's");
        CHECK(revenant_host_CGColorSpaceUsesITUR_2100TF(space) == CGColorSpaceUsesITUR_2100TF(space), "the 2100 transfer function answer is the system's");
        CHECK(revenant_host_CGColorSpaceIsHLGBased(space) == CGColorSpaceIsHLGBased(space), "the HLG answer is the system's");
        CHECK(revenant_host_CGColorSpaceIsPQBased(space) == CGColorSpaceIsPQBased(space), "the PQ answer is the system's");
        CFDataRef ours = revenant_host_CGColorSpaceCopyICCData(space), theirs = CGColorSpaceCopyICCData(space);
        CHECK((ours == NULL) == (theirs == NULL) && (!ours || CFEqual(ours, theirs)), "the ICC data of a generic space is the system's");
        if (ours) CFRelease(ours);
        if (theirs) CFRelease(theirs);
        CGColorSpaceRelease(space);
    }
}

int main(int argc, char **argv)
{
    @autoreleasepool {
        if (argc > 1)
            revenant_log_to(@(argv[1]));
        check_spaces();
        printf("%d checks, %d failed\n", revenant_checks, revenant_failures);
    }
    return revenant_failures;
}
