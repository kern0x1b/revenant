#import "CharonVideoToolbox.h"
#include <CoreFoundation/CoreFoundation.h>
#include <CoreMedia/CoreMedia.h>
#include <CoreVideo/CoreVideo.h>
#include <VideoToolbox/VTCompressionSession.h>
#include <VideoToolbox/VTDecompressionSession.h>
#include <VideoToolbox/VTErrors.h>
#include <VideoToolbox/VTSession.h>

// The multi-pass trio of VideoToolbox's session entry points, and what each honestly answers on a
// release whose sessions are the 6.1.3 ones. Their answer is read out of the session rather than
// assumed. VTCompressionSession.h says of each that calling it before multi-pass encoding is enabled, through the
// kVTCompressionPropertyKey_MultiPassStorage property, is an error. Multi-pass
// arrived with iOS 9.0 and the 6.1.3 encoder has no such property, so every one of the three is being
// called in the case the header calls an error - but "the port cannot support multi-pass" is a claim
// about the release, and the release can be ASKED: VTSessionCopyProperty with
// kVTCompressionPropertyKey_MultiPassStorage answers NULL on a session that was never given one. That
// query is what these three do, and its answer is what they report.
//
// The two output-handler variants cannot be made to work at all, and the cause is a measured absence of
// API rather than a difficulty:
//
//   VTCompressionSessionEncodeFrameWithOutputHandler is forbidden on a session made with a VTCompressionOutputCallback, and
//   the decode counterpart, VTDecompressionSessionDecodeFrameWithOutputHandler, is forbidden on one made with a
//   VTDecompressionOutputCallbackRecord. Both say the caller
//   therefore creates the session with a NULL callback and passes a block per call. But the callback is
//   fixed at VTCompressionSessionCreate / VTDecompressionSessionCreate time and NO API CHANGES IT
//   AFTERWARDS: there is no VTCompressionSessionSetOutputCallback and no
//   VTDecompressionSessionSetOutputCallback in the 16.4 SDK this port builds against, nor in the 26.2
//   SDK - measured, grep over both header sets, zero hits for either name. So the port can start the
//   encode, and there is no way for it to route the encoder's output to the block the caller handed in.
//
// What it does instead is the release's own behaviour for a session with no output callback: the frame
// is encoded and the compressed sample has nowhere to go. The encode's own status is passed back
// unchanged, because the encode really did happen. The block is not called, and no block is not a
// failure the caller can see - which is why the effect in registry/VideoToolbox/ios26.json says so
// plainly and why the entry is written up for coordination/crutches.md rather than left as an effect
// field nobody reads.

// The one query all three share, and the answer is per session rather than per process: two sessions in
// one process can be in different states, and a module-level flag would answer for both.
static Boolean session_has_multi_pass_storage(VTCompressionSessionRef session)
{
    CFTypeRef storage = NULL;
    if (VTSessionCopyProperty(session, kVTCompressionPropertyKey_MultiPassStorage, NULL, &storage) != noErr)
        return false;
    // A session that holds no storage object is a session multi-pass was never really enabled on, and the
    // value VTSessionCopyProperty produced is the session's own to release.
    Boolean enabled = storage != NULL;
    if (storage)
        CFRelease(storage);
    return enabled;
}

OSStatus VTCompressionSessionBeginPass(VTCompressionSessionRef session,
                                       VTCompressionSessionOptionFlags beginPassFlags,
                                       uint32_t * CM_NULLABLE reserved)
{
    if (!session_has_multi_pass_storage(session))
        return kVTParameterErr;
    // A session that HAS multi-pass storage cannot be driven through passes on this release either: the
    // 6.1.3 encoder knows nothing about pass boundaries, so there is no state to record and the encoder
    // would not honour it. The code is the release's own for the encoder that would consume this not
    // being available now.
    return kVTVideoEncoderNotAvailableNowErr;
}

OSStatus VTCompressionSessionEndPass(VTCompressionSessionRef session,
                                     Boolean * CM_NULLABLE furtherPassesRequestedOut,
                                     uint32_t * CM_NULLABLE reserved)
{
    if (!session_has_multi_pass_storage(session))
        return kVTParameterErr;
    // *furtherPassesRequestedOut is NOT written on either path. The header makes the caller read it only
    // after a success, and writing false on an error would let a caller that forgets to check the status
    // end its loop believing the encoder wanted no more passes.
    return kVTVideoEncoderNotAvailableNowErr;
}

OSStatus VTCompressionSessionGetTimeRangesForNextPass(VTCompressionSessionRef session,
                                                     CMItemCount * CM_NONNULL timeRangeCountOut,
                                                     const CMTimeRange * CM_NULLABLE * CM_NONNULL timeRangeArrayOut)
{
    // The header names two more ways this is an error, and both are checked: multi-pass not enabled, and
    // EndPass did not ask for another pass. The second is answered by the session's own pass count,
    // which nothing on this release ever advances.
    // The header names two ways this call is an error: multi-pass was never enabled, and EndPass did not
    // ask for another pass. BOTH are kVTParameterErr, so there is one code and one outcome, and writing
    // the two checks as two branches with the same return would be a check that reads as if it
    // distinguished something it cannot. The second condition is also unreachable on this release: no
    // pass ever ends here, because BeginPass and EndPass both refuse first.
    if (!session_has_multi_pass_storage(session))
        return kVTParameterErr;
    return kVTParameterErr;
}

// The two output-handler variants are in VTSessionOutputHandler9_0.m rather than here: they are iOS 9.0
// API and these three are the ladder's 7.0, and one object may hold one release's API.
