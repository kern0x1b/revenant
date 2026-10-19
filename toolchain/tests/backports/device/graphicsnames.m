#import <CoreImage/CoreImage.h>
#import <MobileCoreServices/MobileCoreServices.h>
#include <dlfcn.h>
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
        CHECK_EQUAL(image_of((void *)&kCIInputAngleKey), @"libGraphicsBackports.dylib", "kCIInputAngleKey comes from the backports");
        CHECK_EQUAL(kCIInputAngleKey, @"inputAngle", "the angle key");
        CHECK_EQUAL(kCIInputRadiusKey, @"inputRadius", "the radius key");
        CHECK_EQUAL(image_of((void *)&kUTTypeScalableVectorGraphics), @"libGraphicsBackports.dylib", "kUTTypeScalableVectorGraphics comes from the backports");
        CHECK_EQUAL((__bridge NSString *)kUTTypeScalableVectorGraphics, @"public.svg-image", "the SVG identifier");
        CIFilter *blur = [CIFilter filterWithName:@"CIGaussianBlur"];
        CHECK(blur != nil, "the release has the Gaussian blur");
        CHECK([[blur inputKeys] containsObject:kCIInputRadiusKey], "the blur reads its radius under the radius key");
        CHECK([[blur inputKeys] containsObject:kCIInputImageKey], "and its image under the image key of the release");
        CIFilter *straighten = [CIFilter filterWithName:@"CIStraightenFilter"];
        CHECK(straighten != nil && [[straighten inputKeys] containsObject:kCIInputAngleKey], "the straighten filter reads its angle under the angle key");
        printf("%d checks, %d failed\n", charon_checks, charon_failures);
    }
    return charon_failures;
}
