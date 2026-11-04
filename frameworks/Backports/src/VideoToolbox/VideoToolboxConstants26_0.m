#include "../revenant_impl.h"
#import <Foundation/Foundation.h>
#import <CoreMedia/CoreMedia.h>
#import <VideoToolbox/VideoToolbox.h>

const CFStringRef BACKPORT_IMPL(kVTCameraCalibrationExtrinsicOriginSource_StereoCameraSystemBaseline) = CFSTR("StereoCameraSystemBaseline");
const CFStringRef BACKPORT_IMPL(kVTCameraCalibrationLensAlgorithmKind_ParametricLens) = CFSTR("ParametricLens");
const CFStringRef BACKPORT_IMPL(kVTCameraCalibrationLensDomain_Color) = CFSTR("Color");
const CFStringRef BACKPORT_IMPL(kVTCameraCalibrationLensRole_Left) = CFSTR("Left");
const CFStringRef BACKPORT_IMPL(kVTCameraCalibrationLensRole_Mono) = CFSTR("Mono");
const CFStringRef BACKPORT_IMPL(kVTCameraCalibrationLensRole_Right) = CFSTR("Right");
const CFStringRef BACKPORT_IMPL(kVTCompressionPreset_Balanced) = CFSTR("Balanced");
const CFStringRef BACKPORT_IMPL(kVTCompressionPreset_HighQuality) = CFSTR("HighQuality");
const CFStringRef BACKPORT_IMPL(kVTCompressionPreset_HighSpeed) = CFSTR("HighSpeed");
const CFStringRef BACKPORT_IMPL(kVTCompressionPreset_VideoConferencing) = CFSTR("VideoConferencing");
const CFStringRef BACKPORT_IMPL(kVTCompressionPropertyCameraCalibrationKey_ExtrinsicOrientationQuaternion) = CFSTR("ExtrinsicOrientationQuaternion");
const CFStringRef BACKPORT_IMPL(kVTCompressionPropertyCameraCalibrationKey_ExtrinsicOriginSource) = CFSTR("ExtrinsicOriginSource");
const CFStringRef BACKPORT_IMPL(kVTCompressionPropertyCameraCalibrationKey_IntrinsicMatrix) = CFSTR("IntrinsicMatrix");
const CFStringRef BACKPORT_IMPL(kVTCompressionPropertyCameraCalibrationKey_IntrinsicMatrixProjectionOffset) = CFSTR("IntrinsicMatrixProjectionOffset");
const CFStringRef BACKPORT_IMPL(kVTCompressionPropertyCameraCalibrationKey_IntrinsicMatrixReferenceDimensions) = CFSTR("IntrinsicMatrixReferenceDimensions");
const CFStringRef BACKPORT_IMPL(kVTCompressionPropertyCameraCalibrationKey_LensAlgorithmKind) = CFSTR("LensAlgorithmKind");
const CFStringRef BACKPORT_IMPL(kVTCompressionPropertyCameraCalibrationKey_LensDistortions) = CFSTR("LensDistortions");
const CFStringRef BACKPORT_IMPL(kVTCompressionPropertyCameraCalibrationKey_LensDomain) = CFSTR("LensDomain");
const CFStringRef BACKPORT_IMPL(kVTCompressionPropertyCameraCalibrationKey_LensFrameAdjustmentsPolynomialX) = CFSTR("LensFrameAdjustmentsPolynomialX");
const CFStringRef BACKPORT_IMPL(kVTCompressionPropertyCameraCalibrationKey_LensFrameAdjustmentsPolynomialY) = CFSTR("LensFrameAdjustmentsPolynomialY");
const CFStringRef BACKPORT_IMPL(kVTCompressionPropertyCameraCalibrationKey_LensIdentifier) = CFSTR("LensIdentifier");
const CFStringRef BACKPORT_IMPL(kVTCompressionPropertyCameraCalibrationKey_LensRole) = CFSTR("LensRole");
const CFStringRef BACKPORT_IMPL(kVTCompressionPropertyCameraCalibrationKey_RadialAngleLimit) = CFSTR("RadialAngleLimit");
const CFStringRef BACKPORT_IMPL(kVTCompressionPropertyKey_CameraCalibrationDataLensCollection) = CFSTR("CameraCalibrationDataLensCollection");
const CFStringRef BACKPORT_IMPL(kVTCompressionPropertyKey_SupportedPresetDictionaries) = CFSTR("SupportedPresetDictionaries");
const CFStringRef BACKPORT_IMPL(kVTCompressionPropertyKey_VBVBufferDuration) = CFSTR("VBVBufferDuration");
const CFStringRef BACKPORT_IMPL(kVTCompressionPropertyKey_VBVInitialDelayPercentage) = CFSTR("VBVInitialDelayPercentage");
const CFStringRef BACKPORT_IMPL(kVTCompressionPropertyKey_VBVMaxBitRate) = CFSTR("VBVMaxBitRate");
const CFStringRef BACKPORT_IMPL(kVTCompressionPropertyKey_VariableBitRate) = CFSTR("VariableBitRate");
const CFStringRef BACKPORT_IMPL(kVTDecodeFrameOptionKey_ContentAnalyzerCropRectangle) = CFSTR("ContentAnalyzerCropRectangle");
const CFStringRef BACKPORT_IMPL(kVTDecodeFrameOptionKey_ContentAnalyzerRotation) = CFSTR("ContentAnalyzerRotation");
const CFStringRef BACKPORT_IMPL(kVTHDRMetadataInsertionMode_RequestSDRRangePreservation) = CFSTR("HDRMetadataInsertionMode_RequestSDRRangePreservation");
const CFStringRef BACKPORT_IMPL(kVTHeroEye_Left) = CFSTR("Left");
const CFStringRef BACKPORT_IMPL(kVTHeroEye_Right) = CFSTR("Right");
const CFStringRef BACKPORT_IMPL(kVTMotionEstimationSessionCreationOption_UseMultiPassSearch) = CFSTR("UseMultiPassSearch");
const CFStringRef BACKPORT_IMPL(kVTProjectionKind_Equirectangular) = CFSTR("Equirectangular");
const CFStringRef BACKPORT_IMPL(kVTProjectionKind_HalfEquirectangular) = CFSTR("HalfEquirectangular");
const CFStringRef BACKPORT_IMPL(kVTProjectionKind_ParametricImmersive) = CFSTR("ParametricImmersive");
const CFStringRef BACKPORT_IMPL(kVTProjectionKind_Rectilinear) = CFSTR("Rectilinear");
const CFStringRef BACKPORT_IMPL(kVTViewPackingKind_OverUnder) = CFSTR("OverUnder");
const CFStringRef BACKPORT_IMPL(kVTViewPackingKind_SideBySide) = CFSTR("SideBySide");
