#import <AVFoundation/AVFoundation.h>
#import "check.h"

#pragma clang diagnostic ignored "-Wdeprecated-declarations"
#pragma clang diagnostic ignored "-Wunguarded-availability-new"

// The video stabilization modes of iOS 8 and the format's stabilization of iOS 7 over the release's
// switch (facts/AVFoundation/VideoStabilization.md). A daemon: the camera needs no permission on 6.1.3.

@interface AVCaptureDeviceFormat (CharonReleaseStabilization)
- (int)supportedStabilizationMethod;
@end

static NSString *raised(void (^block)(void))
{
    @try {
        block();
    } @catch (NSException *exception) {
        return [NSString stringWithFormat:@"%@: %@", exception.name, exception.reason];
    }
    return @"nothing";
}

static void check_formats(void)
{
    int formats = 0, agreeing = 0, methods[4] = {0};
    for (AVCaptureDevice *device in [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo]) {
        for (AVCaptureDeviceFormat *format in device.formats) {
            int method = [format supportedStabilizationMethod];
            CMVideoDimensions size = CMVideoFormatDescriptionGetDimensions(format.formatDescription);
            printf("format: position %d %dx%d max %.0f fps: supportedStabilizationMethod %d, supported %d, modes auto %d off %d standard %d cinematic %d extended %d\n",
                   (int)device.position, size.width, size.height, [format.videoSupportedFrameRateRanges.lastObject maxFrameRate], method,
                   format.videoStabilizationSupported, [format isVideoStabilizationModeSupported:AVCaptureVideoStabilizationModeAuto],
                   [format isVideoStabilizationModeSupported:AVCaptureVideoStabilizationModeOff],
                   [format isVideoStabilizationModeSupported:AVCaptureVideoStabilizationModeStandard],
                   [format isVideoStabilizationModeSupported:AVCaptureVideoStabilizationModeCinematic],
                   [format isVideoStabilizationModeSupported:AVCaptureVideoStabilizationModeCinematicExtended]);
            formats++;
            methods[method >= 0 && method < 3 ? method : 3]++;
            agreeing += format.videoStabilizationSupported == (method == 2) &&
                        [format isVideoStabilizationModeSupported:AVCaptureVideoStabilizationModeStandard] == format.videoStabilizationSupported &&
                        [format isVideoStabilizationModeSupported:AVCaptureVideoStabilizationModeAuto] &&
                        [format isVideoStabilizationModeSupported:AVCaptureVideoStabilizationModeOff] &&
                        ![format isVideoStabilizationModeSupported:AVCaptureVideoStabilizationModeCinematic];
        }
    }
    printf("methods: 0 x%d, 1 x%d, 2 x%d, other x%d\n", methods[0], methods[1], methods[2], methods[3]);
    CHECK(formats > 0, "the cameras list their formats");
    CHECK(methods[1] == 0 && methods[3] == 0, "the release's method answers 0 or 2 on every format, the two values 7.0 gives it");
    CHECK(agreeing == formats, "each format supports Standard exactly when the release's method answers 2, Off and Auto always, Cinematic never");
}

static void check_connection(void)
{
    AVCaptureDevice *camera = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    AVCaptureSession *session = [[AVCaptureSession alloc] init];
    AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:camera error:NULL];
    AVCaptureVideoDataOutput *output = [[AVCaptureVideoDataOutput alloc] init];
    CHECK(input && [session canAddInput:input], "the default camera is an input");
    [session addInput:input];
    [session addOutput:output];
    [session startRunning];
    [NSThread sleepForTimeInterval:2];
    AVCaptureConnection *connection = [output connectionWithMediaType:AVMediaTypeVideo];
    BOOL supported = connection.supportsVideoStabilization;
    BOOL formatSupported = camera.activeFormat.videoStabilizationSupported;
    printf("connection: supported %d, active format supports %d, enables %d, enabled %d\n", supported, formatSupported,
           connection.enablesVideoStabilizationWhenAvailable, connection.videoStabilizationEnabled);

    CHECK(connection.preferredVideoStabilizationMode == AVCaptureVideoStabilizationModeOff, "a new connection prefers Off");
    CHECK(connection.activeVideoStabilizationMode == AVCaptureVideoStabilizationModeOff, "and runs Off");

    NSString *outside = raised(^{ connection.preferredVideoStabilizationMode = (AVCaptureVideoStabilizationMode)3; });
    CHECK_EQUAL(outside, @"NSInvalidArgumentException: Supplied preferredVideoStabilizationMode (3) is outside of the range of AVCaptureVideoStabilizationMode.",
                "a mode past Cinematic raises as 8.0 does");
    CHECK(connection.preferredVideoStabilizationMode == AVCaptureVideoStabilizationModeOff, "and leaves the preferred mode");

    NSString *standard = raised(^{ connection.preferredVideoStabilizationMode = AVCaptureVideoStabilizationModeStandard; });
    [NSThread sleepForTimeInterval:2];
    printf("standard: raised %s, enables %d, enabled %d, active %d\n", standard.UTF8String, connection.enablesVideoStabilizationWhenAvailable,
           connection.videoStabilizationEnabled, (int)connection.activeVideoStabilizationMode);
    CHECK_EQUAL(standard, @"nothing", "Standard is taken whether or not the connection can stabilize");
    CHECK(connection.preferredVideoStabilizationMode == AVCaptureVideoStabilizationModeStandard, "the preferred mode reads back Standard");
    CHECK(connection.enablesVideoStabilizationWhenAvailable == (supported && formatSupported), "the release's switch is on exactly when the connection and its format can stabilize");
    CHECK(connection.activeVideoStabilizationMode == (connection.videoStabilizationEnabled ? AVCaptureVideoStabilizationModeStandard : AVCaptureVideoStabilizationModeOff),
          "the active mode is what the release says it runs");

    connection.preferredVideoStabilizationMode = AVCaptureVideoStabilizationModeCinematic;
    CHECK(connection.preferredVideoStabilizationMode == AVCaptureVideoStabilizationModeCinematic, "Cinematic reads back");
    CHECK(!connection.enablesVideoStabilizationWhenAvailable, "and runs nothing, the release having no Cinematic");

    connection.preferredVideoStabilizationMode = AVCaptureVideoStabilizationModeAuto;
    CHECK(connection.preferredVideoStabilizationMode == AVCaptureVideoStabilizationModeAuto, "Auto reads back");
    CHECK(connection.enablesVideoStabilizationWhenAvailable == (supported && formatSupported), "and runs Standard where the format has it");

    if (supported) {
        connection.enablesVideoStabilizationWhenAvailable = !connection.enablesVideoStabilizationWhenAvailable;
        CHECK(connection.preferredVideoStabilizationMode == (connection.enablesVideoStabilizationWhenAvailable ? AVCaptureVideoStabilizationModeStandard : AVCaptureVideoStabilizationModeOff),
              "after the old switch is set the preferred mode is what 8.0 makes of it");
    } else {
        NSString *release = raised(^{ connection.enablesVideoStabilizationWhenAvailable = YES; });
        printf("release switch on a connection that cannot stabilize: %s\n", release.UTF8String);
        CHECK([release hasPrefix:@"NSInvalidArgumentException: enablesVideoStabilizationWhenAvailable cannot be set"],
              "the release raises for its switch on a connection that cannot stabilize");
    }
    connection.preferredVideoStabilizationMode = AVCaptureVideoStabilizationModeOff;
    CHECK(!connection.enablesVideoStabilizationWhenAvailable && connection.preferredVideoStabilizationMode == AVCaptureVideoStabilizationModeOff, "Off turns the switch off");
    [session stopRunning];
}

int main(int argc, char **argv)
{
    @autoreleasepool {
        if (argc > 1)
            charon_log_to(@(argv[1]));
        check_formats();
        check_connection();
        printf("%d checks, %d failed\n", charon_checks, charon_failures);
    }
    return charon_failures;
}
