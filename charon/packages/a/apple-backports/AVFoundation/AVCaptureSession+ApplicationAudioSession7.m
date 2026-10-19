#import <AVFoundation/AVFoundation.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

// 6.1.3's capture session records through an audio session of its own: measured on an iPad 2, it
// delivers microphone buffers while the application's session is Playback, a category that cannot
// record, and leaves that category, its options and its mode as they were, with no interruption. So
// it neither uses nor configures the application's session, which is what both properties answer.
// The release cannot be made to record through the application's session, so asking for it is
// refused where it can be seen - the property keeps answering NO - and said once in the log.

@implementation AVCaptureSession (CharonApplicationAudioSession)

static void charon_say_once(void)
{
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSLog(@"AVCaptureSession on iOS 6 records through an audio session of its own; usesApplicationAudioSession and "
              @"automaticallyConfiguresApplicationAudioSession stay NO");
    });
}

- (BOOL)usesApplicationAudioSession
{
    return NO;
}

- (void)setUsesApplicationAudioSession:(BOOL)uses
{
    if (uses)
        charon_say_once();
}

- (BOOL)automaticallyConfiguresApplicationAudioSession
{
    return NO;
}

- (void)setAutomaticallyConfiguresApplicationAudioSession:(BOOL)configures
{
    if (configures)
        charon_say_once();
}

@end
