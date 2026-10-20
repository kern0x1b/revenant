#import "RevenantAVFAudio.h"

@implementation AVAudioSessionCapability {
    BOOL _revenant_supported;
}

- (instancetype)initWithRevenantSupported:(BOOL)supported
{
    if ((self = [super init])) {
        _revenant_supported = supported;
    }
    return self;
}

- (BOOL)isSupported
{
    return _revenant_supported;
}

- (BOOL)isEnabled
{
    return _revenant_supported;
}

@end

@implementation AVAudioSessionPortExtensionBluetoothMicrophone {
    AVAudioSessionCapability *_revenant_highQualityRecording;
    AVAudioSessionCapability *_revenant_farFieldCapture;
}

- (instancetype)init
{
    if ((self = [super init])) {
        _revenant_highQualityRecording = [[AVAudioSessionCapability alloc] initWithRevenantSupported:NO];
        _revenant_farFieldCapture = [[AVAudioSessionCapability alloc] initWithRevenantSupported:NO];
    }
    return self;
}

- (AVAudioSessionCapability *)highQualityRecording
{
    return _revenant_highQualityRecording;
}

- (AVAudioSessionCapability *)farFieldCapture
{
    return _revenant_farFieldCapture;
}

@end
