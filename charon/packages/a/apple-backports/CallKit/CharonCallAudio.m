#import "CharonCallKit.h"
#import <AVFoundation/AVAudioSession.h>

// CallKit does not configure an application's audio: the application sets its
// own category and mode while it performs the answer or start action, and the
// system activates the session for it and says so. That is the whole of the
// contract, and the whole of what is done here - iOS 6 has AVAudioSession,
// with the category, the mode and -setActive:withOptions:error: the contract
// needs.
//
// The session is activated when a call of the provider first connects and
// deactivated when the provider's last call has gone, in that order, so an
// application that starts its audio in didActivateAudioSession: and stops it
// in didDeactivateAudioSession: is called exactly as the release calls it.

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
