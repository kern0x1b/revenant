#import <ReplayKit/ReplayKit.h>
#import "../CharonSayOnce.h"

// The screen recorder, as a device that cannot record answers. Nothing records, so no movie is written and nothing is
// recording. `available` answers NO until the recorder works (ruling 5): the host answers YES. The row is inert, not owed,
// because a NO is a safe reading here: an application that checks first finds a device that cannot record and starts none
// (registry/ReplayKit/recorder.json). Stopping a recording that never started answers -5829 on the calling thread, before the
// call returns, as the host does (facts/ReplayKit/RPScreenRecorder.md). The microphone and the camera are the flags the
// application sets; the camera has no preview, because no camera is turned on.
@implementation RPScreenRecorder

+ (RPScreenRecorder *)sharedRecorder
{
    static RPScreenRecorder *recorder;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        // The header makes -init unavailable, so the one instance is made with +new, which NSObject gives every class.
        recorder = [RPScreenRecorder new];
    });
    return recorder;
}

- (BOOL)isAvailable
{
    charon_say_once_for(@"ReplayKit.RPScreenRecorder.available",
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
