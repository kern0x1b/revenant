#import <AVFAudio/AVFAudio.h>

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

@interface AVAudioEnvironmentNode (RevenantHeadTracking)
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
