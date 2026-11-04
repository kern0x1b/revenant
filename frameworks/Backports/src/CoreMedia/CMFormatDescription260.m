#include "../revenant_impl.h"
#import <CoreMedia/CoreMedia.h>
#include <CoreVideo/CoreVideo.h>

const CFStringRef BACKPORT_IMPL(kCMFormatDescriptionCameraCalibrationExtrinsicOriginSource_StereoCameraSystemBaseline) = CFSTR("StereoCameraSystemBaseline");
const CFStringRef BACKPORT_IMPL(kCMFormatDescriptionCameraCalibrationLensAlgorithmKind_ParametricLens) = CFSTR("ParametricLens");
const CFStringRef BACKPORT_IMPL(kCMFormatDescriptionCameraCalibrationLensDomain_Color) = CFSTR("Color");
const CFStringRef BACKPORT_IMPL(kCMFormatDescriptionCameraCalibrationLensRole_Left) = CFSTR("Left");
const CFStringRef BACKPORT_IMPL(kCMFormatDescriptionCameraCalibrationLensRole_Mono) = CFSTR("Mono");
const CFStringRef BACKPORT_IMPL(kCMFormatDescriptionCameraCalibrationLensRole_Right) = CFSTR("Right");
const CFStringRef BACKPORT_IMPL(kCMFormatDescriptionCameraCalibration_ExtrinsicOrientationQuaternion) = CFSTR("ExtrinsicOrientationQuaternion");
const CFStringRef BACKPORT_IMPL(kCMFormatDescriptionCameraCalibration_ExtrinsicOriginSource) = CFSTR("ExtrinsicOriginSource");
const CFStringRef BACKPORT_IMPL(kCMFormatDescriptionCameraCalibration_IntrinsicMatrix) = CFSTR("IntrinsicMatrix");
const CFStringRef BACKPORT_IMPL(kCMFormatDescriptionCameraCalibration_IntrinsicMatrixProjectionOffset) = CFSTR("IntrinsicMatrixProjectionOffset");
const CFStringRef BACKPORT_IMPL(kCMFormatDescriptionCameraCalibration_IntrinsicMatrixReferenceDimensions) = CFSTR("IntrinsicMatrixReferenceDimensions");
const CFStringRef BACKPORT_IMPL(kCMFormatDescriptionCameraCalibration_LensAlgorithmKind) = CFSTR("LensAlgorithmKind");
const CFStringRef BACKPORT_IMPL(kCMFormatDescriptionCameraCalibration_LensDistortions) = CFSTR("LensDistortions");
const CFStringRef BACKPORT_IMPL(kCMFormatDescriptionCameraCalibration_LensDomain) = CFSTR("LensDomain");
const CFStringRef BACKPORT_IMPL(kCMFormatDescriptionCameraCalibration_LensFrameAdjustmentsPolynomialX) = CFSTR("LensFrameAdjustmentsPolynomialX");
const CFStringRef BACKPORT_IMPL(kCMFormatDescriptionCameraCalibration_LensFrameAdjustmentsPolynomialY) = CFSTR("LensFrameAdjustmentsPolynomialY");
const CFStringRef BACKPORT_IMPL(kCMFormatDescriptionCameraCalibration_LensIdentifier) = CFSTR("LensIdentifier");
const CFStringRef BACKPORT_IMPL(kCMFormatDescriptionCameraCalibration_LensRole) = CFSTR("LensRole");
const CFStringRef BACKPORT_IMPL(kCMFormatDescriptionCameraCalibration_RadialAngleLimit) = CFSTR("RadialAngleLimit");
const CFStringRef BACKPORT_IMPL(kCMFormatDescriptionExtension_CameraCalibrationDataLensCollection) = CFSTR("CameraCalibrationDataLensCollection");
const CFStringRef BACKPORT_IMPL(kCMFormatDescriptionExtension_ConvertedFromExternalSphericalTags) = CFSTR("ConvertedFromExternalSphericalTags");
const CFStringRef BACKPORT_IMPL(kCMFormatDescriptionProjectionKind_AppleImmersiveVideo) = CFSTR("AppleImmersiveVideo");
const CFStringRef BACKPORT_IMPL(kCMFormatDescriptionProjectionKind_ParametricImmersive) = CFSTR("ParametricImmersive");
