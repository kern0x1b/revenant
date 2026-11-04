#include "../revenant_impl.h"
#import "RevenantVideoToolbox.h"
#include <CoreFoundation/CoreFoundation.h>
#include <CoreMedia/CoreMedia.h>
#include <CoreVideo/CoreVideo.h>
#include <VideoToolbox/VTErrors.h>

const VTHDRPerFrameMetadataGenerationHDRFormatType
    BACKPORT_IMPL(kVTHDRPerFrameMetadataGenerationHDRFormatType_DolbyVision) = CFSTR("DolbyVision");

CFTypeID BACKPORT_IMPL(VTHDRPerFrameMetadataGenerationSessionGetTypeID)(void)
{
    static CFTypeID type;
    if (!type)
        type = CFUUIDGetTypeID();
    return type;
}

OSStatus BACKPORT_IMPL(VTHDRPerFrameMetadataGenerationSessionCreate)(
    CFAllocatorRef CM_NULLABLE allocator,
    float framesPerSecond,
    CFDictionaryRef CM_NULLABLE options,
    VTHDRPerFrameMetadataGenerationSessionRef CM_NULLABLE * CM_NONNULL
        hdrPerFrameMetadataGenerationSessionOut)
{
    if (framesPerSecond <= 0.0f)
        return kVTParameterErr;
    if (!hdrPerFrameMetadataGenerationSessionOut)
        return kVTParameterErr;
    *hdrPerFrameMetadataGenerationSessionOut = NULL;
    return kVTVideoEncoderNotAvailableNowErr;
}

OSStatus BACKPORT_IMPL(VTHDRPerFrameMetadataGenerationSessionAttachMetadata)(
    VTHDRPerFrameMetadataGenerationSessionRef hdrPerFrameMetadataGenerationSession,
    CVPixelBufferRef pixelBuffer,
    Boolean sceneChange)
{
    if (!hdrPerFrameMetadataGenerationSession)
        return kVTInvalidSessionErr;
    if (!pixelBuffer)
        return kVTParameterErr;
    return kVTVideoEncoderNotAvailableNowErr;
}
