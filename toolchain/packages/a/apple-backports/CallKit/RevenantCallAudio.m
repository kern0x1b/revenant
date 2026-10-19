#import "RevenantCallKit.h"
#import <AVFoundation/AVAudioSession.h>

@implementation RevenantCallAudio {
    NSUInteger _connected;
}

+ (instancetype)shared
{
    static RevenantCallAudio *shared;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        shared = [[RevenantCallAudio alloc] init];
    });
    return shared;
}

- (AVAudioSession *)session
{
    Class cls = NSClassFromString(@"AVAudioSession");
    return cls ? (AVAudioSession *)[cls sharedInstance] : nil;
}

- (void)callConnectedFor:(CXProvider *)provider
{
    BOOL first;
    @synchronized (self) {
        first = _connected == 0;
        _connected++;
    }
    if (!first)
        return;
    AVAudioSession *session = [self session];
    if (!session)
        return;
    [session setActive:YES error:NULL];
    [provider revenant_audioSessionActivated:session];
}

- (void)callEndedFor:(CXProvider *)provider
{
    BOOL last;
    @synchronized (self) {
        if (_connected == 0)
            return;
        _connected--;
        last = _connected == 0;
    }
    if (!last)
        return;
    AVAudioSession *session = [self session];
    if (!session)
        return;
    [session setActive:NO withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation error:NULL];
    [provider revenant_audioSessionDeactivated:session];
}

@end
