#import "CharonVideoToolbox.h"
#include <CoreFoundation/CoreFoundation.h>
#include <CoreMedia/CoreMedia.h>
#include <CoreVideo/CoreVideo.h>
#include <VideoToolbox/VTCompressionSession.h>
#include <VideoToolbox/VTDecompressionSession.h>
#include <VideoToolbox/VTErrors.h>

OSStatus VTCompressionSessionEncodeFrameWithOutputHandler(
    VTCompressionSessionRef session, CVImageBufferRef imageBuffer, CMTime presentationTimeStamp,
    CMTime duration, CFDictionaryRef CM_NULLABLE frameProperties,
    VTEncodeInfoFlags * CM_NULLABLE infoFlagsOut, VTCompressionOutputHandler outputHandler)
{
    (void)session; (void)imageBuffer; (void)presentationTimeStamp; (void)duration;
    (void)frameProperties; (void)infoFlagsOut; (void)outputHandler;
    return kVTVideoEncoderNotAvailableNowErr;
}

OSStatus VTDecompressionSessionDecodeFrameWithOutputHandler(
    VTDecompressionSessionRef session, CMSampleBufferRef sampleBuffer, VTDecodeFrameFlags decodeFlags,
    VTDecodeInfoFlags * CM_NULLABLE infoFlagsOut, VTDecompressionOutputHandler outputHandler)
{
    (void)session; (void)sampleBuffer; (void)decodeFlags; (void)infoFlagsOut; (void)outputHandler;
    return kVTVideoDecoderNotAvailableNowErr;
}
