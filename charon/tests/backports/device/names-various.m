#import <AVFoundation/AVFoundation.h>
#import <CoreImage/CoreImage.h>
#import <CoreText/CoreText.h>
#import <MapKit/MapKit.h>
#import <MobileCoreServices/MobileCoreServices.h>
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
    if (!dladdr(address, &info) || (strcmp(strrchr(info.dli_fname, '/') + 1, "libAVFoundationBackports.dylib") && strcmp(strrchr(info.dli_fname, '/') + 1, "libGraphicsBackports.dylib")))
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
#include "names-various.h"
        CHECK(strings == 37, "there are 37 names");
        CHECK(elsewhere.count == 0, "every name comes from the backports");
        if (elsewhere.count)
            printf("  elsewhere: %s\n", [elsewhere componentsJoinedByString:@" "].UTF8String);
        CHECK(different.count == 0, "every name has the text the iOS 12 cache holds");
        if (different.count)
            printf("  different: %s\n", [different componentsJoinedByString:@" "].UTF8String);
        AVCaptureSession *session = [[AVCaptureSession alloc] init];
        CHECK(![session canSetSessionPreset:AVCaptureSessionPresetInputPriority] && ![session canSetSessionPreset:AVCaptureSessionPreset3840x2160], "no session accepts the input priority or the 4K preset");
        AVCaptureMetadataOutput *output = [[AVCaptureMetadataOutput alloc] init];
        CHECK(![output.availableMetadataObjectTypes containsObject:AVMetadataObjectTypeQRCode], "the metadata output does not list the QR code among its available types");
        printf("%d checks, %d failures\n", charon_checks, charon_failures);
        return charon_failures;
    }
}
