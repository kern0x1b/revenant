#import "CharonAVCaptureDeviceDynamic26.h"
#import <objc/runtime.h>

static const char charon_simulated_aperture_key;

@implementation AVCaptureDevice (CharonCaptureDeviceDynamic26)

- (AVCaptureAspectRatio)dynamicAspectRatio
{
    return nil;
}

- (CMVideoDimensions)dynamicDimensions
{
    CMVideoDimensions dimensions;
    dimensions.width = 0;
    dimensions.height = 0;
    return dimensions;
}

- (void)setDynamicAspectRatio:(AVCaptureAspectRatio)dynamicAspectRatio
            completionHandler:(void (^)(CMTime syncTime, NSError *error))handler API_AVAILABLE(ios(26.0))
{
    [NSException raise:NSInvalidArgumentException
                format:@"*** -[AVCaptureDevice %@] Dynamic Aspect Ratio not supported by this device",
                       NSStringFromSelector(_cmd)];
}

- (void)setCameraLensSmudgeDetectionEnabled:(BOOL)cameraLensSmudgeDetectionEnabled
                           detectionInterval:(CMTime)detectionInterval API_AVAILABLE(ios(26.0))
{
    [NSException raise:NSInvalidArgumentException
                format:@"*** -[AVCaptureDevice %@] Not supported - use"
                       @" -activeFormat.isCameraLensSmudgeDetectionSupported",
                       NSStringFromSelector(_cmd)];
}

- (BOOL)isCameraLensSmudgeDetectionEnabled
{
    return NO;
}

- (CMTime)cameraLensSmudgeDetectionInterval
{
    return kCMTimeInvalid;
}

- (AVCaptureCameraLensSmudgeDetectionStatus)cameraLensSmudgeDetectionStatus
{
    return AVCaptureCameraLensSmudgeDetectionStatusDisabled;
}

@end

@implementation AVCaptureDeviceFormat (CharonCaptureDeviceFormatDynamic26)

- (BOOL)isCameraLensSmudgeDetectionSupported
{
    return NO;
}

- (float)defaultSimulatedAperture
{
    return 0.0f;
}

- (float)minSimulatedAperture
{
    return 0.0f;
}

- (float)maxSimulatedAperture
{
    return 0.0f;
}

- (NSArray<AVCaptureAspectRatio> *)supportedDynamicAspectRatios
{
    return [NSArray array];
}

@end

@implementation AVCaptureDeviceInput (CharonCaptureDeviceInputDynamic26)

- (float)simulatedAperture
{
    id stored = objc_getAssociatedObject(self, &charon_simulated_aperture_key);
    return stored ? [stored floatValue] : 0.0f;
}

- (void)setSimulatedAperture:(float)simulatedAperture API_AVAILABLE(ios(26.0))
{
    AVCaptureDevice *device = self.device;
    AVCaptureDeviceFormat *format = device ? device.activeFormat : nil;
    float minimum = format ? [(id)format minSimulatedAperture] : 0.0f;
    if (minimum > 0.0f) {
        objc_setAssociatedObject(self, &charon_simulated_aperture_key, @(simulatedAperture),
                                 OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        return;
    }
    [NSException raise:NSInvalidArgumentException
                format:@"*** -[AVCaptureDeviceInput %@] Not supported - the source device must have an"
                       @" activeFormat.minSimulatedAperture greater than 0.",
                       NSStringFromSelector(_cmd)];
}

@end
