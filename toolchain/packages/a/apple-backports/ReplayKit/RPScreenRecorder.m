#import <ReplayKit/ReplayKit.h>
#import "../RevenantSayOnce.h"

@implementation RPScreenRecorder

+ (RPScreenRecorder *)sharedRecorder
{
    static RPScreenRecorder *recorder;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        recorder = [RPScreenRecorder new];
    });
    return recorder;
}

- (BOOL)isAvailable
{
    revenant_say_once_for(@"ReplayKit.RPScreenRecorder.available",
                       @"ReplayKit: RPScreenRecorder.available answers NO: this device cannot record the screen yet, so an application "
                       @"that checks first starts no recording. The host answers YES.");
    return NO;
}

- (BOOL)isRecording
{
    return NO;
}

- (RPCameraPosition)cameraPosition
{
    return _cameraPosition ? _cameraPosition : RPCameraPositionFront;
}

- (UIView *)cameraPreviewView
{
    return nil;
}

- (void)stopRecordingWithHandler:(void (^)(RPPreviewViewController *, NSError *))handler
{
    NSError *error = [NSError errorWithDomain:RPRecordingErrorDomain code:RPRecordingErrorAttemptToStopNonRecording userInfo:nil];
    handler(nil, error);
}

- (void)discardRecordingWithHandler:(void (^)(void))handler
{
}

@end
