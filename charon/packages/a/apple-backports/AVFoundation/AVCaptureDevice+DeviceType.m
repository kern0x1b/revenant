#import "CharonAVCapture.h"


@implementation AVCaptureDevice (CharonDeviceType)

- (AVCaptureDeviceType)deviceType
{
    BOOL video = [self hasMediaType:AVMediaTypeVideo], audio = [self hasMediaType:AVMediaTypeAudio];
    if (video && !audio)
        return AVCaptureDeviceTypeBuiltInWideAngleCamera;
    if (audio && !video)
        return AVCaptureDeviceTypeBuiltInMicrophone;
    return @"";
}

+ (AVCaptureDevice *)defaultDeviceWithDeviceType:(AVCaptureDeviceType)deviceType mediaType:(AVMediaType)mediaType position:(AVCaptureDevicePosition)position
{
    if (self != [AVCaptureDevice class])
        return nil;
    if (!deviceType)
        [NSException raise:NSInvalidArgumentException format:@"*** +[%@ %@] The deviceType cannot be nil", NSStringFromClass(self), NSStringFromSelector(_cmd)];
    return [charon_capture_devices(@[deviceType], mediaType, position) firstObject];
}

@end
