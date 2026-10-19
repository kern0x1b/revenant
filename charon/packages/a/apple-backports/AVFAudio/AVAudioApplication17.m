#import "CharonAVFAudio.h"
#import "CharonAVFAudioNew.h"
#import <objc/message.h>

// AVAudioApplication of iOS 17 and the continuity-microphone port type that came with it.
//
// The one thing this class has to get right is the record permission, because a caller that reads it
// is deciding whether to show a prompt. iOS 6's AVAudioSession has no permission API at all - the
// first is iOS 7 - so where this process has loaded the AVFAudio backports, which carry that API,
// the answer is taken from it by message send (the class is looked up, so a process that has not
// loaded them is not made to fail for it); where it has not, the honest answer for a release that
// cannot report a permission is Undetermined, and a request asks. An application that reads the
// permission first and falls back to asking therefore behaves as it does on iOS 17, and one that
// needs the answer without asking is told Undetermined, which is what iOS 17 says for an application
// that has not asked. facts/AVFAudio/AVAudioApplication.md has the whole account.

// AVAudioApplicationRecordPermission, the three answers of iOS 17, in the header's own numbering.
NSString * const AVAudioApplicationMuteStateKey = @"AVAudioApplicationMuteStateKey";
NSString * const AVAudioApplicationInputMuteStateChangeNotification = @"AVAudioApplicationInputMuteStateChangeNotification";
NSString * const AVAudioSessionPortContinuityMicrophone = @"ContinuityMicrophone";

@implementation AVAudioApplication {
    BOOL _charon_inputMuted;
    BOOL (^_charon_muteHandler)(BOOL);
}

+ (AVAudioApplication *)sharedInstance
{
    static AVAudioApplication *shared;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        shared = [[self alloc] init];
    });
    return shared;
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-designated-initializers"
// The header marks -init NS_UNAVAILABLE and the application object is the shared one, so the only
// object of this class an application ever names is +sharedInstance. -init is in the corpus, so it is
// answered, and it answers the shared instance rather than a second one: two AVAudioApplication
// objects would each keep their own mute state, which is not a thing this API has.
- (instancetype)init
{
    return [AVAudioApplication sharedInstance];
}
#pragma clang diagnostic pop

- (BOOL)setInputMuted:(BOOL)muted error:(NSError **)outError
{
    // The mute state is the release's own reading of the hardware switch, and only this process can
    // change it here. Setting the state it already holds changes nothing, and says so rather than
    // reporting a change that did not happen; a state that did change posts the notification the
    // header names and calls the handler with the new state.
    if (muted == _charon_inputMuted) {
        if (outError) {
            *outError = [NSError errorWithDomain:@"AVAudioApplicationErrorDomain" code:1 userInfo:nil];
        }
        return NO;
    }
    _charon_inputMuted = muted;
    if (_charon_muteHandler) {
        _charon_muteHandler(muted);
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:AVAudioApplicationInputMuteStateChangeNotification object:self
                                                      userInfo:@{AVAudioApplicationMuteStateKey: @(muted ? 1 : 0)}];
    return YES;
}

- (BOOL)isInputMuted
{
    return _charon_inputMuted;
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunguarded-availability"
// macOS-only in the 26.2 header, and in the corpus because the corpus is the whole SDK surface. The
// handler is kept, because keeping it is what the iOS 17 API is: a process that sets one is told
// when the state changes. Nothing on this release changes the state on its own, so the handler is
// called only for a change this process made through -setInputMuted:error:.
- (BOOL)setInputMuteStateChangeHandler:(BOOL (^)(BOOL))inputMuteHandler error:(NSError **)outError
{
    _charon_muteHandler = [inputMuteHandler copy];
    return YES;
}
#pragma clang diagnostic pop

- (AVAudioApplicationRecordPermission)recordPermission
{
    // The permission is the release's own where this process has an AVAudioSession that reports one,
    // which is the backported AVFAudio library's category. NSClassFromString keeps the dependency
    // dynamic in the only direction that matters: a process that never loaded it is not made to fail
    // over a class it does not have.
    Class session = NSClassFromString(@"AVAudioSession");
    SEL selector = NSSelectorFromString(@"recordPermission");
    if (session != Nil && [session respondsToSelector:selector]) {
        id value = ((id (*)(id, SEL))objc_msgSend)((id)[session sharedInstance], selector);
        if ([value isKindOfClass:[NSString class]]) {
            NSInteger raw = [value integerValue];
            if (raw == 2) return AVAudioApplicationRecordPermissionDenied;
            if (raw == 1) return AVAudioApplicationRecordPermissionGranted;
        }
    }
    return AVAudioApplicationRecordPermissionUndetermined;
}

+ (void)requestRecordPermissionWithCompletionHandler:(void (^)(BOOL))response
{
    if (response == nil) {
        return;
    }
    // Where the process has the release's own record permission, the request is that one. Otherwise
    // this release has no permission to ask about and the answer is NO, the answer a device without a
    // microphone permission record gives.
    Class session = NSClassFromString(@"AVAudioSession");
    SEL request = NSSelectorFromString(@"requestRecordPermission:");
    if (session != Nil && [session respondsToSelector:request]) {
        void (^handler)(BOOL) = ^(BOOL granted) { response(granted); };
        ((void (*)(id, SEL, id))objc_msgSend)((id)[session sharedInstance], request, handler);
        return;
    }
    response(NO);
}

- (AVAudioApplicationMicrophoneInjectionPermission)microphoneInjectionPermission
{
    // Injecting audio into the record path is a facility of the audio server of a release that has
    // one. iOS 6.1.3 has no such facility and no C API that reports it, so the permission is the
    // documented one for a session that cannot inject: undetermined, and a request answers it.
    return AVAudioApplicationMicrophoneInjectionPermissionUndetermined;
}

+ (void)requestMicrophoneInjectionPermissionWithCompletionHandler:(void (^)(AVAudioApplicationMicrophoneInjectionPermission))response
{
    if (response != nil) {
        response(AVAudioApplicationMicrophoneInjectionPermissionUndetermined);
    }
}

@end
