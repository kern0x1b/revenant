#import "CharonAVFAudio.h"
#import "CharonAVFAudioNew.h"
#import <objc/message.h>

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
- (instancetype)init
{
    return [AVAudioApplication sharedInstance];
}
#pragma clang diagnostic pop

- (BOOL)setInputMuted:(BOOL)muted error:(NSError **)outError
{
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
- (BOOL)setInputMuteStateChangeHandler:(BOOL (^)(BOOL))inputMuteHandler error:(NSError **)outError
{
    _charon_muteHandler = [inputMuteHandler copy];
    return YES;
}
#pragma clang diagnostic pop

- (AVAudioApplicationRecordPermission)recordPermission
{
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
    return AVAudioApplicationMicrophoneInjectionPermissionUndetermined;
}

+ (void)requestMicrophoneInjectionPermissionWithCompletionHandler:(void (^)(AVAudioApplicationMicrophoneInjectionPermission))response
{
    if (response != nil) {
        response(AVAudioApplicationMicrophoneInjectionPermissionUndetermined);
    }
}

@end
