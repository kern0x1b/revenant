#import "CharonAVFAudio.h"
#import "CharonAVFAudioNew.h"

// AVAudioSessionCapability and AVAudioSessionPortExtensionBluetoothMicrophone of iOS 26.
//
// Both describe a facility of the audio route, and the whole question this port can answer honestly
// is whether the release has one. A capability answers its two questions as a device without the
// facility does: not supported, not enabled - the shape the header gives, and the shape a program
// that checks before using a facility on an old device already handles.
//
// What the release actually holds is read, not assumed: iOS 6.1.3's armv7 cache exports no
// AVAudioSession port-extension API, and its route is an AVAudioSessionRouteDescription of port types
// it names itself (the built-in microphone, the receiver, the headphones). A Bluetooth microphone of
// the kind these two classes describe - a far-field capture device or one that records at high
// quality over Bluetooth - is a hardware accessory this release's route has no way to name, so
// neither capability is supported.

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

// Nothing on this release can turn the capability on, so a supported one is enabled and an
// unsupported one is not; there is no third answer to give and no setter to misreport one with.
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
