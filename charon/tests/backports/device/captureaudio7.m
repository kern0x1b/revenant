#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import "check.h"

// What a capture session of 6.1.3 does with the application's audio session (facts/AVFoundation/CaptureZoomAudioSession.md):
// the application sets Playback, which cannot record, and a capture of the microphone still delivers audio. Then
// the port's AVCaptureSession+ApplicationAudioSession7.m, built in, answers as that measurement says.

static BOOL wait_until(BOOL (^done)(void), NSTimeInterval seconds)
{
    NSDate *limit = [NSDate dateWithTimeIntervalSinceNow:seconds];
    while (!done() && [limit timeIntervalSinceNow] > 0)
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
    return done();
}

@interface CharonAudioFrames : NSObject <AVCaptureAudioDataOutputSampleBufferDelegate>
@property (atomic) int buffers;
@end
@implementation CharonAudioFrames
- (void)captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sample fromConnection:(AVCaptureConnection *)connection
{
    self.buffers++;
}
@end

static void state(const char *when)
{
    AVAudioSession *session = [AVAudioSession sharedInstance];
    printf("measure %s: category %s options %lu mode %s input available %d\n", when, session.category.UTF8String, (unsigned long)session.categoryOptions,
           session.mode.UTF8String, session.inputAvailable);
}

int main(int argc, char **argv)
{
    @autoreleasepool {
        if (argc > 1)
            charon_log_to([NSString stringWithUTF8String:argv[1]]);
        __block int interruptions = 0;
        [[NSNotificationCenter defaultCenter] addObserverForName:AVAudioSessionInterruptionNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
            interruptions++;
            printf("measure interruption %s\n", note.userInfo.description.UTF8String);
        }];
        NSError *error = nil;
        [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback withOptions:AVAudioSessionCategoryOptionMixWithOthers error:&error];
        [[AVAudioSession sharedInstance] setActive:YES error:&error];
        state("before capture (Playback, mix)");
        AVCaptureSession *capture = [[AVCaptureSession alloc] init];
        AVCaptureDeviceInput *mic = [AVCaptureDeviceInput deviceInputWithDevice:[AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio] error:&error];
        printf("measure microphone input %p %s\n", mic, error.description.UTF8String ?: "");
        if (mic)
            [capture addInput:mic];
        AVCaptureAudioDataOutput *output = [[AVCaptureAudioDataOutput alloc] init];
        CharonAudioFrames *frames = [[CharonAudioFrames alloc] init];
        [output setSampleBufferDelegate:frames queue:dispatch_queue_create("audio", NULL)];
        [capture addOutput:output];
        [capture startRunning];
        CHECK(wait_until(^BOOL { return frames.buffers > 5; }, 8), "audio arrives from the capture session");
        printf("measure buffers %d running %d\n", frames.buffers, capture.running);
        state("while capturing");
        [capture stopRunning];
        wait_until(^BOOL { return NO; }, 1);
        state("after capture");
        printf("measure interruptions %d\n", interruptions);
        // The port: the session answers what 6.1.3 did above, and asking for more leaves it so.
        CHECK(!capture.usesApplicationAudioSession && !capture.automaticallyConfiguresApplicationAudioSession, "the capture session uses and configures no application session");
        capture.usesApplicationAudioSession = YES;
        capture.automaticallyConfiguresApplicationAudioSession = YES;
        CHECK(!capture.usesApplicationAudioSession && !capture.automaticallyConfiguresApplicationAudioSession, "asking for it leaves both NO");
        printf("checks=%d failures=%d\n", charon_checks, charon_failures);
    }
    return charon_failures;
}
