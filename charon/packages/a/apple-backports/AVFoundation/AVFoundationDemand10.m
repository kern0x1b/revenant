#import <AVFoundation/AVFoundation.h>
#import <objc/runtime.h>

#pragma mark - AVCaptureDeviceFormat.supportedColorSpaces

@implementation AVCaptureDeviceFormat (CharonSupportedColorSpaces10)

- (NSArray<NSNumber *> *)supportedColorSpaces
{
    return @[@(AVCaptureColorSpace_sRGB)];
}

@end

#pragma mark - AVCaptureSession.automaticallyConfiguresCaptureDeviceForWideColor

static const char charon_wideColorKey;

@implementation AVCaptureSession (CharonWideColor10)

- (BOOL)automaticallyConfiguresCaptureDeviceForWideColor
{
    NSNumber *stored = objc_getAssociatedObject(self, &charon_wideColorKey);
    return stored ? stored.boolValue : YES;
}

- (void)setAutomaticallyConfiguresCaptureDeviceForWideColor:(BOOL)automaticallyConfiguresCaptureDeviceForWideColor
{
    objc_setAssociatedObject(self, &charon_wideColorKey, @(automaticallyConfiguresCaptureDeviceForWideColor), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
