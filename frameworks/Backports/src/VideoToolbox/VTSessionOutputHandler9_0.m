#import "RevenantVideoToolbox.h"
#include <CoreFoundation/CoreFoundation.h>
#include <CoreMedia/CoreMedia.h>
#include <CoreVideo/CoreVideo.h>
#include <VideoToolbox/VTCompressionSession.h>
#include <VideoToolbox/VTDecompressionSession.h>
#include <VideoToolbox/VTErrors.h>

#import "VTDecompressionSessionHEVC.h"
#import "VTSystem.h"

OSStatus VTCompressionSessionEncodeFrameWithOutputHandler(
    VTCompressionSessionRef session, CVImageBufferRef imageBuffer, CMTime presentationTimeStamp,
    CMTime duration, CFDictionaryRef CM_NULLABLE frameProperties,
    VTEncodeInfoFlags * CM_NULLABLE infoFlagsOut, VTCompressionOutputHandler outputHandler)
{
    (void)session; (void)imageBuffer; (void)presentationTimeStamp; (void)duration;
    (void)frameProperties; (void)infoFlagsOut; (void)outputHandler;
    return kVTVideoEncoderNotAvailableNowErr;
}

typedef OSStatus (*RevenantVTDecodeWithHandlerFunction)(VTDecompressionSessionRef, CMSampleBufferRef, VTDecodeFrameFlags, VTDecodeInfoFlags *, VTDecompressionOutputHandler);

OSStatus VTDecompressionSessionDecodeFrameWithOutputHandler(
    VTDecompressionSessionRef session, CMSampleBufferRef sampleBuffer, VTDecodeFrameFlags decodeFlags,
    VTDecodeInfoFlags * CM_NULLABLE infoFlagsOut, VTDecompressionOutputHandler outputHandler)
{
    if (RevenantVTSoftwareSessionOwns(session)) {
        if (!outputHandler)
            return kVTParameterErr;
        return RevenantVTSoftwareSessionDecode(session, sampleBuffer, decodeFlags, NULL, infoFlagsOut, ^(void *sourceFrameRefCon, OSStatus status, VTDecodeInfoFlags infoFlags, CVImageBufferRef imageBuffer, CMTime presentationTimeStamp, CMTime presentationDuration) {
            (void)sourceFrameRefCon;
            outputHandler(status, infoFlags, imageBuffer, presentationTimeStamp, presentationDuration);
        });
    }
    RevenantVTDecodeWithHandlerFunction decode = (RevenantVTDecodeWithHandlerFunction)RevenantVTSystemSymbol("VTDecompressionSessionDecodeFrameWithOutputHandler");
    return decode ? decode(session, sampleBuffer, decodeFlags, infoFlagsOut, outputHandler) : kVTVideoDecoderNotAvailableNowErr;
}
