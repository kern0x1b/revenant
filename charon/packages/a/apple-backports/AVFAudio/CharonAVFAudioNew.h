#import <AVFAudio/AVFAudio.h>

// The three AVFAudio classes this port carries that the SDK the package is compiled against does not
// declare. The build resolves charon@iphoneos-sdk to 16.4 - build-gate.lua names it, and every log
// line of a gate says `sdk=16.4` - so an API that arrived after 16.4 has no @interface here, and an
// @implementation written without one is a root class: `[super init]` is an error and `[Class alloc]`
// is undeclared. That is not a guess, it is what the 6.1.3 gate said:
//
//   AVAudioSessionCapability26.m: error: 'AVAudioSessionCapability' cannot use 'super' because it
//   is a root class
//   AVAudioSessionCapability26.m: error: no known class method for selector 'alloc'
//
// So the declarations below are transcribed from SDK 26.2, and every one of them is checked against
// the 16.4 SDK for absence first, so that the day the build SDK moves past them this header can go
// away instead of shadowing the real one. Nothing here changes a member's spelling or type: these are
// the same declarations, in the same files, at the paths named.
//
//   AVAudioApplication.h                          AVAudioApplication, iOS 17.0
//   AVAudioSessionRoute.h                         AVAudioSessionCapability, iOS 26.0
//   AVAudioSessionRoute.h                         AVAudioSessionPortExtensionBluetoothMicrophone, iOS 26.0
//
// The class of each is NSObject, which is what those headers declare and what the 16.4 SDK's
// foundation is.

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, AVAudioApplicationRecordPermission) {
    AVAudioApplicationRecordPermissionUndetermined = 'undt',
    AVAudioApplicationRecordPermissionDenied = 'deny',
    AVAudioApplicationRecordPermissionGranted = 'grnt',
};

typedef NS_ENUM(NSInteger, AVAudioApplicationMicrophoneInjectionPermission) {
    AVAudioApplicationMicrophoneInjectionPermissionServiceDisabled = 'srds',
    AVAudioApplicationMicrophoneInjectionPermissionUndetermined = 'undt',
    AVAudioApplicationMicrophoneInjectionPermissionDenied = 'deny',
    AVAudioApplicationMicrophoneInjectionPermissionGranted = 'grnt',
};

@interface AVAudioApplication : NSObject
@property (class, readonly) AVAudioApplication *sharedInstance;
- (instancetype)init NS_UNAVAILABLE;
- (BOOL)setInputMuted:(BOOL)muted error:(NSError **)outError;
@property (readonly, nonatomic, getter=isInputMuted) BOOL inputMuted;
- (BOOL)setInputMuteStateChangeHandler:(BOOL (^_Nullable)(BOOL inputShouldBeMuted))inputMuteHandler error:(NSError **)outError;
@property (readonly) AVAudioApplicationRecordPermission recordPermission;
+ (void)requestRecordPermissionWithCompletionHandler:(void (^)(BOOL granted))response;
@property (readonly) AVAudioApplicationMicrophoneInjectionPermission microphoneInjectionPermission;
+ (void)requestMicrophoneInjectionPermissionWithCompletionHandler:(void (^)(AVAudioApplicationMicrophoneInjectionPermission permission))response;
@end

// AVAudioEnvironmentNode.listenerHeadTrackingEnabled is iOS 18.0 and the build SDK is 16.4, so the
// declaration is here for the same reason the three classes below are: without it the member has no
// @interface here and an @implementation written against it is a root class. The 26.2 header declares
// it `@property (nonatomic) BOOL listenerHeadTrackingEnabled;` on AVAudioEnvironmentNode, which is
// declared there as `AVAudioEnvironmentNode : AVAudioNode <AVAudioMixing>` - the same superclass and
// the same protocol the 16.4 header declares, so the member is declared in a category on it.
@interface AVAudioEnvironmentNode (CharonHeadTracking)
@property (nonatomic) BOOL listenerHeadTrackingEnabled;
@end

@interface AVAudioSessionCapability : NSObject
@property (readonly, nonatomic, getter=isSupported) BOOL supported;
@property (readonly, nonatomic, getter=isEnabled) BOOL enabled;
@end

@interface AVAudioSessionPortExtensionBluetoothMicrophone : NSObject
@property (readonly, strong, nonatomic, nonnull) AVAudioSessionCapability *highQualityRecording;
@property (readonly, strong, nonatomic, nonnull) AVAudioSessionCapability *farFieldCapture;
@end

NS_ASSUME_NONNULL_END
