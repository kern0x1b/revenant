#import <Foundation/Foundation.h>
#import <CoreMedia/CoreMedia.h>
#import <VideoToolbox/VideoToolbox.h>

// The string constants VideoToolbox's first held export of which is iOS 18.0. Where the values
// come from, and why a value is not the constant's own name: the head of
// VideoToolboxConstants7_0.m. An object carries the API of one release.

const CFStringRef kVTCompressionPropertyKey_CalculateMeanSquaredError = CFSTR("CalculateMeanSquaredError");
const CFStringRef kVTCompressionPropertyKey_HasLeftStereoEyeView = CFSTR("HasLeftStereoEyeView");
const CFStringRef kVTCompressionPropertyKey_HasRightStereoEyeView = CFSTR("HasRightStereoEyeView");
const CFStringRef kVTCompressionPropertyKey_HeroEye = CFSTR("HeroEye");
const CFStringRef kVTCompressionPropertyKey_HorizontalDisparityAdjustment = CFSTR("HorizontalDisparityAdjustment");
const CFStringRef kVTCompressionPropertyKey_MVHEVCLeftAndRightViewIDs = CFSTR("MVHEVCLeftAndRightViewIDs");
const CFStringRef kVTCompressionPropertyKey_MVHEVCVideoLayerIDs = CFSTR("MVHEVCVideoLayerIDs");
const CFStringRef kVTCompressionPropertyKey_MVHEVCViewIDs = CFSTR("MVHEVCViewIDs");
const CFStringRef kVTCompressionPropertyKey_MaximumRealTimeFrameRate = CFSTR("MaximumRealTimeFrameRate");
const CFStringRef kVTCompressionPropertyKey_ProjectionKind = CFSTR("ProjectionKind");
const CFStringRef kVTCompressionPropertyKey_RecommendedParallelizedSubdivisionMinimumDuration = CFSTR("RecommendedParallelizedSubdivisionMinimumDuration");
const CFStringRef kVTCompressionPropertyKey_RecommendedParallelizedSubdivisionMinimumFrameCount = CFSTR("RecommendedParallelizedSubdivisionMinimumFrameCount");
const CFStringRef kVTCompressionPropertyKey_StereoCameraBaseline = CFSTR("StereoCameraBaseline");
const CFStringRef kVTCompressionPropertyKey_ViewPackingKind = CFSTR("ViewPackingKind");
const CFStringRef kVTDecompressionPropertyKey_AllowBitstreamToChangeFrameDimensions = CFSTR("AllowBitstreamToChangeFrameDimensions");
const CFStringRef kVTDecompressionPropertyKey_GeneratePerFrameHDRDisplayMetadata = CFSTR("GeneratePerFrameHDRDisplayMetadata");
const CFStringRef kVTDecompressionPropertyKey_RequestedMVHEVCVideoLayerIDs = CFSTR("RequestedMVHEVCVideoLayerIDs");
const CFStringRef kVTHDRPerFrameMetadataGenerationOptionsKey_HDRFormats = CFSTR("HDRFormats");
const CFStringRef kVTMotionEstimationSessionCreationOption_Label = CFSTR("Label");
const CFStringRef kVTMotionEstimationSessionCreationOption_MotionVectorSize = CFSTR("MotionVectorSize");
const CFStringRef kVTSampleAttachmentQualityMetricsKey_ChromaBlueMeanSquaredError = CFSTR("ChromaBlueMeanSquaredError");
const CFStringRef kVTSampleAttachmentQualityMetricsKey_ChromaRedMeanSquaredError = CFSTR("ChromaRedMeanSquaredError");
const CFStringRef kVTSampleAttachmentQualityMetricsKey_LumaMeanSquaredError = CFSTR("LumaMeanSquaredError");
