#import <AVFoundation/AVFoundation.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

@implementation AVCaptureSession (RevenantApplicationAudioSession)

static void revenant_say_once(void)
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
        revenant_say_once();
}

- (BOOL)automaticallyConfiguresApplicationAudioSession
{
    return NO;
}

- (void)setAutomaticallyConfiguresApplicationAudioSession:(BOOL)configures
{
    if (configures)
        revenant_say_once();
}

@end
