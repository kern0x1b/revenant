// AVCaptureDeviceDynamic26.m - the thirteen members of iOS 26's dynamic aspect ratio, camera lens smudge
// detection and simulated aperture, in one object.
//
// THREE FEATURES, ONE HARDWARE QUESTION, and the header answers it for each of them in the same shape: a
// device whose sensor cannot do it reports the absent case, and this release's sensor cannot do any of the
// three.
//
//   Dynamic aspect ratio (:2718-2736). A device whose sensor can change shape mid-stream lists what it can be
//   in -supportedDynamicAspectRatios, and the two read-only members are DERIVED from that list by the header:
//   The header (:2722) starts it at the first AVCaptureAspectRatio of the format's list, and gives nil for an empty list.
//   The header (:2728) gives an empty list a size of {0,0}. So with no list there is no aspect ratio (nil) and no
//   output size ({0, 0}) - which is what the host answers too (measured), for the same reason: its camera's
//   list is empty.
//   Camera lens smudge detection (:3862-3895). The header's own defaults are the answer where the feature is
//   absent: the header's default for -isCameraLensSmudgeDetectionEnabled is false (:3871), its default interval is kCMTimeInvalid (:3877),
//   and the status enum's first value means the detection is not enabled (:3881) - which is the case, because
//   -setCameraLensSmudgeDetectionEnabled:detectionInterval: refuses (below) and -isCameraLensSmudgeDetectionSupported
//   is NO for every format.
//   Simulated aperture (:3894-3905 on the format, :443-452 on the input). The header gives a non-zero value only where the device
//   can run the shallow depth-of-field effect, and 0 where it cannot change the simulated aperture, so all three are 0,
//   which is what the host answers for all seven of its formats (measured). The input's own setter refuses unless the format's minSimulatedAperture is non-zero (:450).
//
// A SIMULATED APERTURE IS PART OF CINEMATIC VIDEO, and that is why the three aperture rows are here and the
// three Cinematic Video rows are in AVCaptureDeviceCinematicVideo26.m even though 26.2 declares both halves in
// the same category: the feature renders a depth of field out of two lenses, this port has one.
//
// THE TWO REFUSALS, with Apple's own reason for each, measured on this host:
//
//   -setCameraLensSmudgeDetectionEnabled:detectionInterval:
//     *** -[AVCaptureDALDevice setCameraLensSmudgeDetectionEnabled:detectionInterval:] Not supported - use
//     -activeFormat.isCameraLensSmudgeDetectionSupported
//     The header's rule is the same, naming the same member: "AVCaptureDevice throws an NSInvalidArgumentException
//     if the AVCaptureDeviceFormat/cameraLensSmudgeDetectionSupported property on the current active format
//     returns false" (:3866). The tail after the class name is what the port raises verbatim; the class is not
//     copied, because AVCaptureDALDevice is a private class of Apple's device-access layer while these methods
//     belong to AVCaptureDevice.
//
//   -setDynamicAspectRatio:completionHandler:
//     *** -[AVCaptureDALDevice setDynamicAspectRatio:completionHandler:] Dynamic Aspect Ratio not supported by
//     this device
//     The header's rule: the method throws NSInvalidArgumentException for a dynamicAspectRatio that is not in the
//     device's activeFormat list of supportedDynamicAspectRatios (:2735), and
//     the list is empty, so every value is one that is not in it.
//
//   -setSimulatedAperture: (the setter of AVCaptureDeviceInput.simulatedAperture)
//     *** -[AVCaptureDeviceInput setSimulatedAperture:] Not supported - the source device must have an
//     activeFormat.minSimulatedAperture greater than 0.
//     Apple's own text again, and here the class in the prefix IS the port's own class.
//
// TWO ROWS HAVE NO HOST VALUE, and both are recorded as such rather than compared:
//   -[AVCaptureDeviceFormat isCameraLensSmudgeDetectionSupported] raises on this host for EVERY one of its
//   seven formats (measured: NSInvalidArgumentException, "-[__NSCFType mediaType]: unrecognized selector sent
//   to instance", raised inside Apple's own -figCaptureSourceVideoFormat), so there is no host value to put
//   in a table; and AVCaptureAspectRatio's five constants are code+lift rows of their own and are not carried,
//   which is why the supported-ratios array this port answers is empty and nothing a caller can name is in it.
#import "CharonAVCaptureDeviceDynamic26.h"
#import <objc/runtime.h>

// The aperture the caller last set on an input. The value is only ever the format's own 0 here - every other
// value is refused - and an associated object is the only place a category can keep one: the class belongs to
// the release and a category cannot add an ivar to it.
static const char charon_simulated_aperture_key;

@implementation AVCaptureDevice (CharonCaptureDeviceDynamic26)

- (AVCaptureAspectRatio)dynamicAspectRatio
{
    return nil;
}

- (CMVideoDimensions)dynamicDimensions
{
    // A CMVideoDimensions is a plain struct of two ints: { 0, 0 } is the header's own value for the
    // absent case, written out because the 16.4 SDK's CoreMedia has no CMVideoDimensionsMake.
    CMVideoDimensions dimensions;
    dimensions.width = 0;
    dimensions.height = 0;
    return dimensions;
}

- (void)setDynamicAspectRatio:(AVCaptureAspectRatio)dynamicAspectRatio
            completionHandler:(void (^)(CMTime syncTime, NSError *error))handler API_AVAILABLE(ios(26.0))
{
    // The header's rule (:2735) and Apple's own reason for it, measured. A completion handler is never called:
    // the call refused before any pipeline work could start, and Apple's own does not call it either.
    [NSException raise:NSInvalidArgumentException
                format:@"*** -[AVCaptureDevice %@] Dynamic Aspect Ratio not supported by this device",
                       NSStringFromSelector(_cmd)];
}

- (void)setCameraLensSmudgeDetectionEnabled:(BOOL)cameraLensSmudgeDetectionEnabled
                           detectionInterval:(CMTime)detectionInterval API_AVAILABLE(ios(26.0))
{
    // The header's rule (:3866) and Apple's own reason for it, measured, with the tail after the class name
    // verbatim. -activeFormat.isCameraLensSmudgeDetectionSupported is NO for every format on this port, which
    // is the member this refusal is about.
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
    // "Indicates that the detection is not enabled" (AVCaptureDevice.h:3881), which is the case: the setter
    // above refuses every value and the format's support flag is NO.
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
    // The header's own rule (:450): "you may only set this property if AVCaptureDevice/activeFormat/
    // minSimulatedAperture returns a non-zero value, otherwise an NSInvalidArgumentException is thrown", and
    // with Apple's own reason for it, measured on this host. The format's minimum is the port's own member, so
    // the refusal is that rule read through it rather than a written-down refusal.
    AVCaptureDevice *device = self.device;
    AVCaptureDeviceFormat *format = device ? device.activeFormat : nil;
    // Asked through an id, for the reason AVCaptureDeviceCinematicVideo26.m gives: the declaration lives in
    // this header, which the host harness does not compile its copy against.
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
