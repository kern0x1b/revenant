#import "CharonVideoToolbox.h"
#include <CoreFoundation/CoreFoundation.h>
#include <CoreMedia/CoreMedia.h>
#include <CoreVideo/CoreVideo.h>
#include <VideoToolbox/VTCompressionSession.h>
#include <VideoToolbox/VTDecompressionSession.h>
#include <VideoToolbox/VTErrors.h>

// Two entry points that exist to hand the caller a frame through a block, and what they honestly answer
// on a release whose sessions are the 6.1.3 ones.
//
// They answer with a status and they do NO work. That is the whole of this file, and it is the answer
// rather than a refusal of the idea:
//
//   - VTCompressionSession.h on VTCompressionSessionEncodeFrameWithOutputHandler, and
//     VTDecompressionSession.h on VTDecompressionSessionDecodeFrameWithOutputHandler, both say the methods are
//     refused on sessions made with a VTCompressionOutputCallback or a VTDecompressionOutputCallbackRecord. So the caller
//     creates the session with a NULL callback and passes a block per call instead.
//
//   - The callback is fixed at VTCompressionSessionCreate / VTDecompressionSessionCreate time and NO API
//     CHANGES IT AFTERWARDS. Measured over the release's own symbol table, from
//     `xmake l tools/corpus/dump-cache.lua $HOME/.charon/dyld/6.1.3/dyld_shared_cache_armv7`, 2026-10-03:
//
//         _VTCompressionSessionEncodeFrame                     1
//         _VTCompressionSessionCreate                          1
//         _VTDecompressionSessionDecodeFrame                   1
//         _VTDecompressionSessionCreate                        1
//         _VTCompressionSessionSetOutputCallback               0
//         _VTDecompressionSessionSetOutputCallback             0
//
//     Zero for both setters, in the release and in the 26.2 SDK's headers alike.
//
//   - The one route the coordinator pointed at does not carry a frame on this release.
//     _kVTDecompressionSessionNotification_FrameDecodeCompleted IS exported by the 6.1.3 cache - it is in
//     the symbol table - but it is declared in NO C header of the 16.4 SDK, of the 26.2 SDK or of the
//     host, only in the three VideoToolbox.tbd export tables, so there is no declared contract for what it
//     carries. The key that would name the frame,
//     kVTDecompressionSessionFrameDecodeNotificationUserInfoKey, is not in the 6.1.3 symbol table AT ALL
//     (zero hits). So there is nothing on this release to read a decoded frame out of, and a notification
//     is in any case not a block: delivering through it would mean the port posting and the caller
//     observing, which is a different API with different lifetime and thread semantics from the block the
//     caller handed in.
//
// So the frame cannot be delivered to the block, and the status says so instead of the work being done and
// dropped. The codes are the release's own and mean what they say: kVTVideoEncoderNotAvailableNowErr for
// the encoder and kVTVideoDecoderNotAvailableNowErr for the decoder.
//
// The caller is not left without a way to encode or decode: it creates the session with a
// VTCompressionOutputCallback or a VTDecompressionOutputCallbackRecord and calls
// VTCompressionSessionEncodeFrame or VTDecompressionSessionDecodeFrame, which the release exports and
// which this port does not touch. These two entry points are the ones that cannot work here, and they say
// so.

OSStatus VTCompressionSessionEncodeFrameWithOutputHandler(
    VTCompressionSessionRef session, CVImageBufferRef imageBuffer, CMTime presentationTimeStamp,
    CMTime duration, CFDictionaryRef CM_NULLABLE frameProperties,
    VTEncodeInfoFlags * CM_NULLABLE infoFlagsOut, VTCompressionOutputHandler outputHandler)
{
    // Each argument named and discarded, so the reader sees that ignoring them is the decision and not an
    // oversight. There is no path that reads them: the frame is not encoded, so nothing is passed on.
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