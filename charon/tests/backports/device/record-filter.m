#import <AVFoundation/AVFoundation.h>
#import <CoreImage/CoreImage.h>
#import <QuartzCore/QuartzCore.h>
#import <UIKit/UIKit.h>
#include <dlfcn.h>
#import "check.h"

#pragma clang diagnostic ignored "-Wdeprecated-declarations"
#pragma clang diagnostic ignored "-Wunguarded-availability-new"

static NSString *image_of(const void *address)
{
    Dl_info info;
    return dladdr(address, &info) ? @(info.dli_fname).lastPathComponent : @"?";
}

static NSString *raised(void (^block)(void))
{
    @try {
        block();
    } @catch (NSException *exception) {
        return exception.name;
    }
    return @"nothing";
}

static void check_record_permission(void)
{
    AVAudioSession *session = [AVAudioSession sharedInstance];
    CHECK(session.recordPermission == AVAudioSessionRecordPermissionGranted, "the record permission is granted");
    CHECK_EQUAL(image_of((const void *)[session methodForSelector:@selector(recordPermission)]), @"libAVFoundationBackports.dylib", "and comes from the backports");
    dispatch_semaphore_t done = dispatch_semaphore_create(0);
    __block BOOL granted = NO, onMain = YES;
    __block int calls = 0;
    [session requestRecordPermission:^(BOOL result) {
        granted = result;
        onMain = [NSThread isMainThread];
        calls++;
        dispatch_semaphore_signal(done);
    }];
    CHECK(dispatch_semaphore_wait(done, dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC)) == 0, "the request answers");
    CHECK(granted && !onMain && calls == 1, "once, with YES, off the main thread");
}

static void check_image_filter(void)
{
    CIImage *base = [CIImage imageWithColor:[CIColor colorWithRed:1 green:0 blue:0]];
    CIImage *input = [base imageByCroppingToRect:CGRectMake(0, 0, 64, 64)];
    CHECK_EQUAL(image_of((const void *)[input methodForSelector:@selector(imageByApplyingFilter:withInputParameters:)]), @"libGraphicsBackports.dylib", "the method comes from the backports");
    CIImage *blurred = [input imageByApplyingFilter:@"CIGaussianBlur" withInputParameters:@{@"inputRadius": @5}];
    CIFilter *direct = [CIFilter filterWithName:@"CIGaussianBlur"];
    [direct setDefaults];
    [direct setValue:input forKey:kCIInputImageKey];
    [direct setValue:@5 forKey:@"inputRadius"];
    CGRect wanted = direct.outputImage.extent;
    CHECK(blurred != nil && CGRectEqualToRect(blurred.extent, wanted), "a blur with parameters is the image a filter made by hand gives");
    printf("blur extent %s from 64 by 64, radius 5\n", NSStringFromCGRect(blurred.extent).UTF8String);
    CIImage *defaults = [input imageByApplyingFilter:@"CIGaussianBlur" withInputParameters:nil];
    CIFilter *plain = [CIFilter filterWithName:@"CIGaussianBlur"];
    [plain setValue:input forKey:kCIInputImageKey];
    CHECK(defaults != nil && CGRectEqualToRect(defaults.extent, plain.outputImage.extent), "with no parameters the filter has its defaults");
    CHECK([input imageByApplyingFilter:@"CINoSuchFilter" withInputParameters:@{}] == nil, "a filter that does not exist gives nil");
    CHECK_EQUAL(raised(^{ [input imageByApplyingFilter:@"CIGaussianBlur" withInputParameters:@{@"inputBogus": @1}]; }), NSUndefinedKeyException, "a key the filter does not have raises the exception of key-value coding");
    CIImage *other = [[CIImage imageWithColor:[CIColor colorWithRed:0 green:1 blue:0]] imageByCroppingToRect:CGRectMake(0, 0, 32, 32)];
    CIImage *replaced = [input imageByApplyingFilter:@"CIGaussianBlur" withInputParameters:@{@"inputRadius": @2, kCIInputImageKey: other}];
    CIFilter *byHand = [CIFilter filterWithName:@"CIGaussianBlur"];
    [byHand setValue:other forKey:kCIInputImageKey];
    [byHand setValue:@2 forKey:@"inputRadius"];
    CHECK(CGRectEqualToRect(replaced.extent, byHand.outputImage.extent), "an input image in the parameters replaces this image");
    CIImage *sepia = [input imageByApplyingFilter:@"CISepiaTone" withInputParameters:@{kCIInputIntensityKey: @0.5}];
    CHECK(sepia != nil && CGRectEqualToRect(sepia.extent, input.extent), "a filter that keeps the extent keeps it");
    CIImage *simple = [input imageByApplyingFilter:@"CISepiaTone"];
    CHECK(simple != nil && CGRectEqualToRect(simple.extent, input.extent), "the variant with no parameters does the same");
    NSString *wrong = raised(^{ [input imageByApplyingFilter:@"CIGaussianBlur" withInputParameters:@{@"inputRadius": @"wrong"}]; });
    printf("a string as a radius: %s\n", wrong.UTF8String);
}

int main(int argc, char **argv)
{
    @autoreleasepool {
        if (argc > 1)
            charon_log_to(@(argv[1]));
        check_record_permission();
        check_image_filter();
        printf("%d checks, %d failures\n", charon_checks, charon_failures);
        return charon_failures;
    }
}
