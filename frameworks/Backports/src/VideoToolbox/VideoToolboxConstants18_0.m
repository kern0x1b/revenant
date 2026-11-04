#include "../revenant_impl.h"
#import <Foundation/Foundation.h>
#import <CoreMedia/CoreMedia.h>
#import <VideoToolbox/VideoToolbox.h>

const CFStringRef BACKPORT_IMPL(kVTCompressionPropertyKey_CalculateMeanSquaredError) = CFSTR("CalculateMeanSquaredError");
const CFStringRef BACKPORT_IMPL(kVTCompressionPropertyKey_HasLeftStereoEyeView) = CFSTR("HasLeftStereoEyeView");
const CFStringRef BACKPORT_IMPL(kVTCompressionPropertyKey_HasRightStereoEyeView) = CFSTR("HasRightStereoEyeView");
const CFStringRef BACKPORT_IMPL(kVTCompressionPropertyKey_HeroEye) = CFSTR("HeroEye");
const CFStringRef BACKPORT_IMPL(kVTCompressionPropertyKey_HorizontalDisparityAdjustment) = CFSTR("HorizontalDisparityAdjustment");
const CFStringRef BACKPORT_IMPL(kVTCompressionPropertyKey_MVHEVCLeftAndRightViewIDs) = CFSTR("MVHEVCLeftAndRightViewIDs");
const CFStringRef BACKPORT_IMPL(kVTCompressionPropertyKey_MVHEVCVideoLayerIDs) = CFSTR("MVHEVCVideoLayerIDs");
const CFStringRef BACKPORT_IMPL(kVTCompressionPropertyKey_MVHEVCViewIDs) = CFSTR("MVHEVCViewIDs");
const CFStringRef BACKPORT_IMPL(kVTCompressionPropertyKey_MaximumRealTimeFrameRate) = CFSTR("MaximumRealTimeFrameRate");
const CFStringRef BACKPORT_IMPL(kVTCompressionPropertyKey_ProjectionKind) = CFSTR("ProjectionKind");
const CFStringRef BACKPORT_IMPL(kVTCompressionPropertyKey_RecommendedParallelizedSubdivisionMinimumDuration) = CFSTR("RecommendedParallelizedSubdivisionMinimumDuration");
const CFStringRef BACKPORT_IMPL(kVTCompressionPropertyKey_RecommendedParallelizedSubdivisionMinimumFrameCount) = CFSTR("RecommendedParallelizedSubdivisionMinimumFrameCount");
const CFStringRef BACKPORT_IMPL(kVTCompressionPropertyKey_StereoCameraBaseline) = CFSTR("StereoCameraBaseline");
const CFStringRef BACKPORT_IMPL(kVTCompressionPropertyKey_ViewPackingKind) = CFSTR("ViewPackingKind");
const CFStringRef BACKPORT_IMPL(kVTDecompressionPropertyKey_AllowBitstreamToChangeFrameDimensions) = CFSTR("AllowBitstreamToChangeFrameDimensions");
const CFStringRef BACKPORT_IMPL(kVTDecompressionPropertyKey_GeneratePerFrameHDRDisplayMetadata) = CFSTR("GeneratePerFrameHDRDisplayMetadata");
const CFStringRef BACKPORT_IMPL(kVTDecompressionPropertyKey_RequestedMVHEVCVideoLayerIDs) = CFSTR("RequestedMVHEVCVideoLayerIDs");
const CFStringRef BACKPORT_IMPL(kVTHDRPerFrameMetadataGenerationOptionsKey_HDRFormats) = CFSTR("HDRFormats");
const CFStringRef BACKPORT_IMPL(kVTMotionEstimationSessionCreationOption_Label) = CFSTR("Label");
const CFStringRef BACKPORT_IMPL(kVTMotionEstimationSessionCreationOption_MotionVectorSize) = CFSTR("MotionVectorSize");
const CFStringRef BACKPORT_IMPL(kVTSampleAttachmentQualityMetricsKey_ChromaBlueMeanSquaredError) = CFSTR("ChromaBlueMeanSquaredError");
const CFStringRef BACKPORT_IMPL(kVTSampleAttachmentQualityMetricsKey_ChromaRedMeanSquaredError) = CFSTR("ChromaRedMeanSquaredError");
const CFStringRef BACKPORT_IMPL(kVTSampleAttachmentQualityMetricsKey_LumaMeanSquaredError) = CFSTR("LumaMeanSquaredError");
