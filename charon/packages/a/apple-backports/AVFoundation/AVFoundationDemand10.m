#import <AVFoundation/AVFoundation.h>
#import <objc/runtime.h>

// AVFoundation's 10.0 surface, the five rows DEMAND-AVFoundation-10.tsv measured CRASH-ON-USE
// against 6.1.3. ONE OBJECT for 10.0 only. Three of the five - automaticallyWaitsToMinimizeStalling,
// -playImmediatelyAtRate: and -initWithOutputSettings: - are AVFoundation100.m's, which carried them
// first; this file carries the two capture members nothing else defines.

#pragma mark - AVCaptureDeviceFormat.supportedColorSpaces

// 6.1.3's capture stack has no color space selection of any kind - every format it reports captures
// in sRGB, which is what the release's own AVCaptureColorSpace enumeration calls
// AVCaptureColorSpace_sRGB (0). There being exactly one, and no way for a format to answer otherwise,
// is the real state of 6.1.3's camera stack, not a placeholder.

@implementation AVCaptureDeviceFormat (CharonSupportedColorSpaces10)

- (NSArray<NSNumber *> *)supportedColorSpaces
{
    return @[@(AVCaptureColorSpace_sRGB)];
}

@end

#pragma mark - AVCaptureSession.automaticallyConfiguresCaptureDeviceForWideColor

// Stored and real as a flag; it has nothing to act on. Wide color capture needs a format whose
// supportedColorSpaces carries more than sRGB, which -[AVCaptureDeviceFormat supportedColorSpaces]
// above never answers on this hardware (no iPad 2 or iPhone 4S camera ever reports a wide-color
// format), so there is never a format for this flag to switch the session to.

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
