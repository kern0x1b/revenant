#import "RevenantVideoToolbox.h"
#include <CoreFoundation/CoreFoundation.h>
#include <CoreMedia/CoreMedia.h>
#include <VideoToolbox/VTDecompressionSession.h>
#include <VideoToolbox/VTErrors.h>

OSStatus VTDecompressionSessionDecodeFrameWithOptions(
    VTDecompressionSessionRef CM_NONNULL session,
    CMSampleBufferRef CM_NONNULL sampleBuffer,
    VTDecodeFrameFlags decodeFlags,
    CFDictionaryRef CM_NULLABLE frameOptions,
    void * CM_NULLABLE sourceFrameRefCon,
    VTDecodeInfoFlags * CM_NULLABLE infoFlagsOut)
{
    (void)frameOptions;
    return VTDecompressionSessionDecodeFrame(session, sampleBuffer, decodeFlags, sourceFrameRefCon, infoFlagsOut);
}

OSStatus VTDecompressionSessionDecodeFrameWithOptionsAndOutputHandler(
    VTDecompressionSessionRef CM_NONNULL session,
    CMSampleBufferRef CM_NONNULL sampleBuffer,
    VTDecodeFrameFlags decodeFlags,
    CFDictionaryRef CM_NULLABLE frameOptions,
    VTDecodeInfoFlags * CM_NULLABLE infoFlagsOut,
    VTDecompressionOutputHandler CM_NONNULL outputHandler)
{
    (void)session;
    (void)sampleBuffer;
    (void)decodeFlags;
    (void)frameOptions;
    (void)outputHandler;
    return kVTParameterErr;
}
