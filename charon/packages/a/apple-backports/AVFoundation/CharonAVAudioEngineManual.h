#import <AVFAudio/AVAudioTypes.h>
#import <AudioToolbox/AudioToolbox.h>

typedef NS_ENUM(NSInteger, AVAudioEngineManualRenderingStatus) {
    AVAudioEngineManualRenderingStatusError = -1,
    AVAudioEngineManualRenderingStatusSuccess = 0,
    AVAudioEngineManualRenderingStatusInsufficientDataFromInputNode = 1,
    AVAudioEngineManualRenderingStatusCannotDoInCurrentContext = 2,
};

typedef NS_ENUM(NSInteger, AVAudioEngineManualRenderingMode) {
    AVAudioEngineManualRenderingModeOffline = 0,
    AVAudioEngineManualRenderingModeRealtime = 1,
};

typedef AVAudioEngineManualRenderingStatus (^AVAudioEngineManualRenderingBlock)(AVAudioFrameCount numberOfFrames,
                                                                                AudioBufferList *outBuffer,
                                                                                OSStatus * _Nullable outError);
