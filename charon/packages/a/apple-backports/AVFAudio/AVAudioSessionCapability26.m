#import "CharonAVFAudio.h"
#import "CharonAVFAudioNew.h"

@implementation AVAudioSessionCapability {
    BOOL _charon_supported;
}

- (instancetype)initWithCharonSupported:(BOOL)supported
{
    if ((self = [super init])) {
        _charon_supported = supported;
    }
    return self;
}

- (BOOL)isSupported
{
    return _charon_supported;
}

- (BOOL)isEnabled
{
    return _charon_supported;
}

@end

@implementation AVAudioSessionPortExtensionBluetoothMicrophone {
    AVAudioSessionCapability *_charon_highQualityRecording;
    AVAudioSessionCapability *_charon_farFieldCapture;
}

- (instancetype)init
{
    if ((self = [super init])) {
        _charon_highQualityRecording = [[AVAudioSessionCapability alloc] initWithCharonSupported:NO];
        _charon_farFieldCapture = [[AVAudioSessionCapability alloc] initWithCharonSupported:NO];
    }
    return self;
}

- (AVAudioSessionCapability *)highQualityRecording
{
    return _charon_highQualityRecording;
}

- (AVAudioSessionCapability *)farFieldCapture
{
    return _charon_farFieldCapture;
}

@end
