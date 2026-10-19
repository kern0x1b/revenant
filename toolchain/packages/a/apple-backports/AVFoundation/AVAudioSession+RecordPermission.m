#import <AVFoundation/AVFoundation.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

@implementation AVAudioSession (CharonRecordPermission)

- (AVAudioSessionRecordPermission)recordPermission
{
    return AVAudioSessionRecordPermissionGranted;
}

- (void)requestRecordPermission:(void (^)(BOOL granted))response
{
    void (^kept)(BOOL) = [response copy];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        if (kept)
            kept(YES);
    });
}

@end
