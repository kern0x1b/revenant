#import "CharonVideoToolbox.h"
#include <CoreFoundation/CoreFoundation.h>
#include <CoreMedia/CoreMedia.h>
#include <VideoToolbox/VTDecompressionSession.h>
#include <VideoToolbox/VTCompressionSession.h>
#include <VideoToolbox/VTErrors.h>

// The four decode and encode variants of SDK 17.0, and what each one can honestly do on a release that
// exports none of them.
//
// The measurement that decides all four (tools/corpus/dump-cache.lua over
// $HOME/.charon/dyld/4.3/dyld_shared_cache_armv7, and v-audio's 6.1.3 armv7 dump, 2026-10-03):
//
//   _VTDecompressionSessionDecodeFrameWithMultiImageCapableOutputHandler   4.3=0  6.1.3=0
//   _VTDecompressionSessionSetMultiImageCallback                           4.3=0  6.1.3=0
//   _VTCompressionSessionEncodeMultiImageFrame                             4.3=0  6.1.3=0
//   _VTCompressionSessionEncodeMultiImageFrameWithOutputHandler            4.3=0  6.1.3=0
//   _VTDecompressionSessionDecodeFrame                                      4.3=1  6.1.3=1
//   _VTCompressionSessionEncodeFrame                                        4.3=1  6.1.3=1
//
// So the single-frame entry points ARE the release's and the four variants are the port's. What decides each
// one is not the missing symbol but WHAT THE CALLER'S ARGUMENT IS:
//
//   - the two decode variants take a CMTaggedBufferGroup through their callback - a group of several images
//     for one frame, which arrived with iOS 14 - and the release's own decode callback has no parameter to
//     receive one: the 16.4 SDK's VTDecompressionOutputCallback ends at CVImageBuffer imageBuffer. A
//     callback the release cannot call is a block the port would have to call itself, and a port that called
//     it would be inventing the multi-image decode it has no decoder for. So both refuse with the release's
//     own decoder code and do no work;
//   - the two encode variants take a CMTaggedBufferGroupRef as their SOURCE, and there is no release
//     function that reads one: the release's encode entry point takes a CVImageBuffer. Same answer, with
//     the encoder's own code.
//
// kVTVideoDecoderNotAvailableNowErr and kVTVideoEncoderNotAvailableNowErr are the release's own constants
// (VTErrors.h:42 and :45) and they are what the same argument earned for the 9.0 output-handler pair, which
// this branch already refuses in VTSessionOutputHandler9_0.m. A variant that accepted its argument and did
// nothing with it would be the silent fake the brief forbids; a variant that refuses says so in the status,
// before any work, and the caller sees it.

// VTDecompressionSessionSetMultiImageCallback, and this one does NOT refuse.
//
// The first version answered kVTVideoDecoderNotAvailableNowErr (-12913) on the reasoning that the release's
// decode callback ends at CVImageBuffer and so could never reach the callback it is given. MEASURED on this
// host, 2026-10-03, on an ORDINARY single-image H264 session with no key and no special decoder:
// **VTDecompressionSessionSetMultiImageCallback answers 0**. So a caller that did nothing unusual is told the
// installation worked, and a port that answered -12913 would refuse a call the release accepts - the worse
// direction of the two, because the caller is told no where the real thing says yes.
//
// WHAT THIS DOES NOT DO, and the difference is named rather than papered over. The second version of this
// function stored the callback and its reference value in a process-global table keyed by the session's
// ADDRESS. That table was wrong twice over and is gone: it is never emptied when a session dies, so it
// leaks; and an address is not an identity, so a later session allocated at the same address would be handed
// a callback it was never given - the same hazard a release-local allocator raises and the one a stored
// pointer into a dead object always does. A second reason it was wrong: nothing read it.
//
// So this accepts the callback, stores nothing, and answers noErr, and here is precisely what a caller gets
// The 26.2 header says of the installed callback that once it is installed, outputMultiImageCallback also applies when
// DecodeFrame operations fail and hand back a nonzero status.
// On the host that is true. **On the port a failing decode still reaches the session's single-image
// callback**, because the session is the RELEASE's session and the release's decode output has no
// multi-image parameter to carry the failure anywhere else. A caller that installed the callback to watch
// for failures will not see them, and that is the difference - stated here and in the registry row rather than
// hidden behind a table that would have looked like the installation worked.
OSStatus VTDecompressionSessionSetMultiImageCallback(
    VTDecompressionSessionRef CM_NONNULL decompressionSession,
    VTDecompressionOutputMultiImageCallback CM_NONNULL outputMultiImageCallback,
    void * CM_NULLABLE outputMultiImageRefcon)
{
    // Both arguments are checked because the header marks the session and the callback non-null, and a NULL
    // session is the one case where noErr would be a lie about something: there is no session to install on.
    if (!decompressionSession || !outputMultiImageCallback)
        return kVTParameterErr;
    (void)outputMultiImageRefcon;
    return noErr;
}

// VTDecompressionSessionDecodeFrameWithMultiImageCapableOutputHandler.
//
// MEASURED on this host with a REAL H264 sample, 2026-10-03 - a 221-byte avc1 frame at 64x48, encoded here
// and handed over by an H264 compression session, because a NULL sample buffer makes every variant answer
// the same -12902 as plain DecodeFrame and measures nothing:
//
//   decompression session                                    -> 0 with a session
//   DecodeFrameWithMultiImageCapableOutputHandler             -> -12902  handler calls=0 infoFlags=0x5a5a5a5a
//   DecodeFrame (the control, same session, same sample)      -> 0  single-image calls=1  infoFlags=0
//
// So the host REFUSES with kVTParameterErr (-12902), does not call the handler, and does not write
// infoFlagsOut - the word handed in came back as 0x5a5a5a5a. It is a refusal about the variant and not about
// the session or the sample: the control decode on the same session answers noErr and fires the callback.
// Its own header says that when the VTDecompressionSessionDecodeFrameWithMultiImageCapableOutputHandler call reports
// an error the block is not run, so refusing is the documented shape of the answer.
OSStatus VTDecompressionSessionDecodeFrameWithMultiImageCapableOutputHandler(
    VTDecompressionSessionRef CM_NONNULL session,
    CMSampleBufferRef CM_NONNULL sampleBuffer,
    VTDecodeFrameFlags decodeFlags,
    VTDecodeInfoFlags * CM_NULLABLE infoFlagsOut,
    VTDecompressionMultiImageCapableOutputHandler CM_NONNULL multiImageCapableOutputHandler)
{
    (void)session;
    (void)sampleBuffer;
    (void)decodeFlags;
    // infoFlagsOut is left ALONE rather than set to zero, because the host leaves it alone: a word written
    // here would be a value this port invented, and the measurement says the release does not write one.
    (void)multiImageCapableOutputHandler;
    return kVTParameterErr;
}

// VTCompressionSessionEncodeMultiImageFrame, and this one ACCEPTS.
//
// MEASURED on this host with a real group - built the documented way, CMTagCollectionCreate(NULL, 0) then
// CMTaggedBufferGroupCreate over one buffer, matches=1 - and a real session:
//
//   CMTaggedBufferGroupCreate(1 buffer) -> 0 with a group  [matches=1]
//   EncodeMultiImageFrame(real group)    -> 0  encode callbacks=2  infoFlags=0x1
//   encode callback: calls=2 status=-12902 flags=0 sample=(null)
//
// The host answers **noErr**, writes `kVTEncodeInfo_FrameDropped` (bit 0 of VTEncodeInfoFlags, so 0x1) into
// infoFlagsOut, and calls the session's output callback ONCE with status -12902 and no sample. The "2" in
// the callback count is CUMULATIVE across the probe's two compression sessions - the first session's own
// successful encode is calls=1 - so this frame's contribution is exactly one call.
//
// What this port cannot reproduce is the call. The session is the RELEASE's session and the caller's output
// callback is inside it, with no public route out: the release's own encode refuses to make the call on
// request, which is measured - `EncodeFrame(NULL image)` answers -12902 with ZERO callbacks and leaves
// infoFlagsOut untouched - so there is no release call whose effect is "call the caller's callback once with
// -12902". So this reproduces the two things the host does that a caller can read, noErr and the dropped
// frame, and NOT the third, and the registry row says so in those words.
OSStatus VTCompressionSessionEncodeMultiImageFrame(
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

// VTCompressionSessionEncodeMultiImageFrameWithOutputHandler.
//
// MEASURED on the same session and the same real group:
//
//   EncodeMultiImageFrameWithOutputHandler(real) -> -12902  encode callbacks=0
//
// No callback, and infoFlagsOut NOT written: the 0x1 in that probe line is the value the previous call left
// in the same variable, because the probe reused one word across the two calls - which is the shape of
// index-by-hand error that has bitten this family twice already, so it is named rather than quoted as a
// measurement. The host refuses with kVTParameterErr.
OSStatus VTCompressionSessionEncodeMultiImageFrameWithOutputHandler(
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
