#import <AVFoundation/AVFoundation.h>
#include <dlfcn.h>
#import <objc/runtime.h>
#import "check.h"

#pragma clang diagnostic ignored "-Wunguarded-availability-new"

static NSString *image_of_method(Class cls, SEL selector)
{
    Dl_info info;
    IMP implementation = class_getMethodImplementation(object_getClass(cls), selector);
    return dladdr((void *)implementation, &info) ? @(info.dli_fname).lastPathComponent : @"?";
}

int main(int argc, char **argv)
{
    @autoreleasepool {
        if (argc > 1)
            charon_log_to(@(argv[1]));
        CHECK_EQUAL(image_of_method([AVCaptureDevice class], @selector(authorizationStatusForMediaType:)), @"libAVFoundationBackports.dylib", "the status comes from the backports");
        AVAuthorizationStatus audio = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeAudio];
        AVAuthorizationStatus video = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
        CHECK(audio == AVAuthorizationStatusAuthorized, "the microphone is authorized: the release asks nobody");
        CHECK(video == AVAuthorizationStatusAuthorized || video == AVAuthorizationStatusRestricted, "the camera is authorized, or restricted when the device restricts it");
        printf("audio %d video %d\n", (int)audio, (int)video);
        BOOL raised = NO;
        NSString *reason = nil;
        @try {
            [AVCaptureDevice authorizationStatusForMediaType:@"muxx"];
        } @catch (NSException *exception) {
            raised = [exception.name isEqualToString:NSInvalidArgumentException];
            reason = exception.reason;
        }
        CHECK(raised, "another media type raises an invalid argument exception");
        CHECK([reason rangeOfString:@"The passed media type 'muxx' is not supported"].location != NSNotFound, "the reason names the media type");
        CHECK([reason hasPrefix:@"*** +[AVCaptureDevice authorizationStatusForMediaType:]"], "the reason names the class method");
        dispatch_semaphore_t done = dispatch_semaphore_create(0);
        __block BOOL granted = NO, onMain = YES;
        __block int calls = 0;
        [AVCaptureDevice requestAccessForMediaType:AVMediaTypeAudio completionHandler:^(BOOL yes) {
            granted = yes;
            onMain = [NSThread isMainThread];
            calls++;
            dispatch_semaphore_signal(done);
        }];
        CHECK(dispatch_semaphore_wait(done, dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC)) == 0, "the handler is called");
        CHECK(granted, "the microphone is granted");
        CHECK(!onMain, "off the main thread");
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.2]];
        CHECK(calls == 1, "once");
        raised = NO;
        @try {
            [AVCaptureDevice requestAccessForMediaType:@"text" completionHandler:^(BOOL yes) {}];
        } @catch (NSException *exception) {
            raised = [exception.name isEqualToString:NSInvalidArgumentException];
        }
        CHECK(raised, "a request for another media type raises too");
        printf("%d checks, %d failed\n", charon_checks, charon_failures);
    }
    return charon_failures;
}
