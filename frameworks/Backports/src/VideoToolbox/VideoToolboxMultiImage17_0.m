#include "../revenant_impl.h"
#import "RevenantVideoToolbox.h"
#include <CoreFoundation/CoreFoundation.h>
#include <CoreMedia/CoreMedia.h>
#include <VideoToolbox/VTDecompressionSession.h>
#include <VideoToolbox/VTCompressionSession.h>
#include <VideoToolbox/VTErrors.h>

OSStatus BACKPORT_IMPL(VTDecompressionSessionSetMultiImageCallback)(
    VTDecompressionSessionRef CM_NONNULL decompressionSession,
    VTDecompressionOutputMultiImageCallback CM_NONNULL outputMultiImageCallback,
    void * CM_NULLABLE outputMultiImageRefcon)
{
    if (!decompressionSession || !outputMultiImageCallback)
        return kVTParameterErr;
    (void)outputMultiImageRefcon;
    return noErr;
}

OSStatus BACKPORT_IMPL(VTDecompressionSessionDecodeFrameWithMultiImageCapableOutputHandler)(
    VTDecompressionSessionRef CM_NONNULL session,
    CMSampleBufferRef CM_NONNULL sampleBuffer,
    VTDecodeFrameFlags decodeFlags,
    VTDecodeInfoFlags * CM_NULLABLE infoFlagsOut,
    VTDecompressionMultiImageCapableOutputHandler CM_NONNULL multiImageCapableOutputHandler)
{
    (void)session;
    (void)sampleBuffer;
    (void)decodeFlags;
    (void)multiImageCapableOutputHandler;
    return kVTParameterErr;
}

OSStatus BACKPORT_IMPL(VTCompressionSessionEncodeMultiImageFrame)(
    VTCompressionSessionRef CM_NONNULL session,
    CMTaggedBufferGroupRef CM_NONNULL taggedBufferGroup,
    CMTime presentationTimeStamp,
    CMTime duration,
    CFDictionaryRef CM_NULLABLE frameProperties,
    void * CM_NULLABLE sourceFrameRefcon,
    VTEncodeInfoFlags * CM_NULLABLE infoFlagsOut)
{
    if (!session || !taggedBufferGroup)
        return kVTParameterErr;
    (void)presentationTimeStamp;
    (void)duration;
    (void)frameProperties;
    (void)sourceFrameRefcon;
    if (infoFlagsOut)
        *infoFlagsOut = kVTEncodeInfo_FrameDropped;
    return noErr;
}

OSStatus BACKPORT_IMPL(VTCompressionSessionEncodeMultiImageFrameWithOutputHandler)(
    VTCompressionSessionRef CM_NONNULL session,
    CMTaggedBufferGroupRef CM_NONNULL taggedBufferGroup,
    CMTime presentationTimeStamp,
    CMTime duration,
    CFDictionaryRef CM_NULLABLE frameProperties,
    VTEncodeInfoFlags * CM_NULLABLE infoFlagsOut,
    VTCompressionOutputHandler CM_NONNULL outputHandler)
{
    if (!session || !taggedBufferGroup)
        return kVTParameterErr;
    (void)presentationTimeStamp;
    (void)duration;
    (void)frameProperties;
    (void)outputHandler;
    return kVTParameterErr;
}
