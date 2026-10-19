#import <AVFoundation/AVFoundation.h>
#import <objc/runtime.h>

#pragma mark - AVCaptureDeviceFormat.supportedColorSpaces

@implementation AVCaptureDeviceFormat (RevenantSupportedColorSpaces10)

- (NSArray<NSNumber *> *)supportedColorSpaces
{
    return @[@(AVCaptureColorSpace_sRGB)];
}

@end

#pragma mark - AVCaptureSession.automaticallyConfiguresCaptureDeviceForWideColor

static const char revenant_wideColorKey;

@implementation AVCaptureSession (RevenantWideColor10)

- (BOOL)automaticallyConfiguresCaptureDeviceForWideColor
{
    NSNumber *stored = objc_getAssociatedObject(self, &revenant_wideColorKey);
    return stored ? stored.boolValue : YES;
}

- (void)setAutomaticallyConfiguresCaptureDeviceForWideColor:(BOOL)automaticallyConfiguresCaptureDeviceForWideColor
{
    objc_setAssociatedObject(self, &revenant_wideColorKey, @(automaticallyConfiguresCaptureDeviceForWideColor), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
