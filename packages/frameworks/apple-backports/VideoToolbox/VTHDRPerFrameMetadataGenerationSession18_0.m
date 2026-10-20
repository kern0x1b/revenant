#import "RevenantVideoToolbox.h"
#include <CoreFoundation/CoreFoundation.h>
#include <CoreMedia/CoreMedia.h>
#include <CoreVideo/CoreVideo.h>
#include <VideoToolbox/VTErrors.h>

const VTHDRPerFrameMetadataGenerationHDRFormatType
    kVTHDRPerFrameMetadataGenerationHDRFormatType_DolbyVision = CFSTR("DolbyVision");

CFTypeID VTHDRPerFrameMetadataGenerationSessionGetTypeID(void)
{
    static CFTypeID type;
    if (!type)
        type = CFUUIDGetTypeID();
    return type;
}

OSStatus VTHDRPerFrameMetadataGenerationSessionCreate(
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

OSStatus VTHDRPerFrameMetadataGenerationSessionAttachMetadata(
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
