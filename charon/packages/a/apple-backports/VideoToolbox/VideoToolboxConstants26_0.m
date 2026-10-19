#import <Foundation/Foundation.h>
#import <CoreMedia/CoreMedia.h>
#import <VideoToolbox/VideoToolbox.h>

// The string constants VideoToolbox's first held export of which is iOS 26.0. Where the values
// come from, and why a value is not the constant's own name: the head of
// VideoToolboxConstants7_0.m. An object carries the API of one release.

const CFStringRef kVTCameraCalibrationExtrinsicOriginSource_StereoCameraSystemBaseline = CFSTR("StereoCameraSystemBaseline");
const CFStringRef kVTCameraCalibrationLensAlgorithmKind_ParametricLens = CFSTR("ParametricLens");
const CFStringRef kVTCameraCalibrationLensDomain_Color = CFSTR("Color");
const CFStringRef kVTCameraCalibrationLensRole_Left = CFSTR("Left");
const CFStringRef kVTCameraCalibrationLensRole_Mono = CFSTR("Mono");
const CFStringRef kVTCameraCalibrationLensRole_Right = CFSTR("Right");
const CFStringRef kVTCompressionPreset_Balanced = CFSTR("Balanced");
const CFStringRef kVTCompressionPreset_HighQuality = CFSTR("HighQuality");
const CFStringRef kVTCompressionPreset_HighSpeed = CFSTR("HighSpeed");
const CFStringRef kVTCompressionPreset_VideoConferencing = CFSTR("VideoConferencing");
const CFStringRef kVTCompressionPropertyCameraCalibrationKey_ExtrinsicOrientationQuaternion = CFSTR("ExtrinsicOrientationQuaternion");
const CFStringRef kVTCompressionPropertyCameraCalibrationKey_ExtrinsicOriginSource = CFSTR("ExtrinsicOriginSource");
const CFStringRef kVTCompressionPropertyCameraCalibrationKey_IntrinsicMatrix = CFSTR("IntrinsicMatrix");
const CFStringRef kVTCompressionPropertyCameraCalibrationKey_IntrinsicMatrixProjectionOffset = CFSTR("IntrinsicMatrixProjectionOffset");
const CFStringRef kVTCompressionPropertyCameraCalibrationKey_IntrinsicMatrixReferenceDimensions = CFSTR("IntrinsicMatrixReferenceDimensions");
const CFStringRef kVTCompressionPropertyCameraCalibrationKey_LensAlgorithmKind = CFSTR("LensAlgorithmKind");
const CFStringRef kVTCompressionPropertyCameraCalibrationKey_LensDistortions = CFSTR("LensDistortions");
const CFStringRef kVTCompressionPropertyCameraCalibrationKey_LensDomain = CFSTR("LensDomain");
const CFStringRef kVTCompressionPropertyCameraCalibrationKey_LensFrameAdjustmentsPolynomialX = CFSTR("LensFrameAdjustmentsPolynomialX");
const CFStringRef kVTCompressionPropertyCameraCalibrationKey_LensFrameAdjustmentsPolynomialY = CFSTR("LensFrameAdjustmentsPolynomialY");
const CFStringRef kVTCompressionPropertyCameraCalibrationKey_LensIdentifier = CFSTR("LensIdentifier");
const CFStringRef kVTCompressionPropertyCameraCalibrationKey_LensRole = CFSTR("LensRole");
const CFStringRef kVTCompressionPropertyCameraCalibrationKey_RadialAngleLimit = CFSTR("RadialAngleLimit");
const CFStringRef kVTCompressionPropertyKey_CameraCalibrationDataLensCollection = CFSTR("CameraCalibrationDataLensCollection");
const CFStringRef kVTCompressionPropertyKey_SupportedPresetDictionaries = CFSTR("SupportedPresetDictionaries");
const CFStringRef kVTCompressionPropertyKey_VBVBufferDuration = CFSTR("VBVBufferDuration");
const CFStringRef kVTCompressionPropertyKey_VBVInitialDelayPercentage = CFSTR("VBVInitialDelayPercentage");
const CFStringRef kVTCompressionPropertyKey_VBVMaxBitRate = CFSTR("VBVMaxBitRate");
const CFStringRef kVTCompressionPropertyKey_VariableBitRate = CFSTR("VariableBitRate");
const CFStringRef kVTDecodeFrameOptionKey_ContentAnalyzerCropRectangle = CFSTR("ContentAnalyzerCropRectangle");
const CFStringRef kVTDecodeFrameOptionKey_ContentAnalyzerRotation = CFSTR("ContentAnalyzerRotation");
const CFStringRef kVTHDRMetadataInsertionMode_RequestSDRRangePreservation = CFSTR("HDRMetadataInsertionMode_RequestSDRRangePreservation");
const CFStringRef kVTHeroEye_Left = CFSTR("Left");
const CFStringRef kVTHeroEye_Right = CFSTR("Right");
const CFStringRef kVTMotionEstimationSessionCreationOption_UseMultiPassSearch = CFSTR("UseMultiPassSearch");
const CFStringRef kVTProjectionKind_Equirectangular = CFSTR("Equirectangular");
const CFStringRef kVTProjectionKind_HalfEquirectangular = CFSTR("HalfEquirectangular");
const CFStringRef kVTProjectionKind_ParametricImmersive = CFSTR("ParametricImmersive");
const CFStringRef kVTProjectionKind_Rectilinear = CFSTR("Rectilinear");
const CFStringRef kVTViewPackingKind_OverUnder = CFSTR("OverUnder");
const CFStringRef kVTViewPackingKind_SideBySide = CFSTR("SideBySide");
