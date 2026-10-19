#import "CharonCallKit.h"
#import <AVFoundation/AVAudioSession.h>

@implementation CharonCallAudio {
    NSUInteger _connected;
}

+ (instancetype)shared
{
    static CharonCallAudio *shared;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        shared = [[CharonCallAudio alloc] init];
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
    [provider charon_audioSessionActivated:session];
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
    [provider charon_audioSessionDeactivated:session];
}

@end
