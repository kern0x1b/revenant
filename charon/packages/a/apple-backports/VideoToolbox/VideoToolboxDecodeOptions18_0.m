#import "CharonVideoToolbox.h"
#include <CoreFoundation/CoreFoundation.h>
#include <CoreMedia/CoreMedia.h>
#include <VideoToolbox/VTDecompressionSession.h>
#include <VideoToolbox/VTErrors.h>

// The two decode variants of SDK 18.0, and what each one does now that the host has been measured with a
// real H264 sample.
//
// THE OPTIONS ARE IGNORED, and that is the host's answer rather than this port's preference. Measured on this
// Mac, 2026-10-03, on a real 221-byte avc1 sample at 64x48 with five dictionaries - and all five lines are
// IDENTICAL:
//
//   NULL options                 DecodeFrame=0 WithOptions=0 handlerCalls=2 infoFlags=0 ...AndOutputHandler=-12902
//   empty options                DecodeFrame=0 WithOptions=0 handlerCalls=2 infoFlags=0 ...AndOutputHandler=-12902
//   an unknown key               DecodeFrame=0 WithOptions=0 handlerCalls=2 infoFlags=0 ...AndOutputHandler=-12902
//   ContentAnalyzerRotation=90   DecodeFrame=0 WithOptions=0 handlerCalls=2 infoFlags=0 ...AndOutputHandler=-12902
//   ContentAnalyzerCropRectangle DecodeFrame=0 WithOptions=0 handlerCalls=2 infoFlags=0 ...AndOutputHandler=-12902
//
// `handlerCalls` is the session's SINGLE-image callback, and it rises by two per line - one from the control
// `DecodeFrame` and one from the options call - so the decode really happened both times; `infoFlags` was
// handed in as 0x5a5A5A5A and comes back 0, so the callee WROTE it. An unknown key is therefore not refused
// and not honoured: it is dropped. The two `kVTDecodeFrameOptionKey_` names are the only ones in any SDK (both
// 26.0) and this host acts on neither of them either - consistent with no release the port builds having a
// `kVTDecodeFrameOptionKey_` of any kind (4.3=0, 6.1.3=0) - so the release does not implement them, and the
// only honest thing to do with a dictionary of them is what the host does with it.
//
// The earlier reasoning on this family said the opposite - "there is no dictionary to ask, so a caller's
// options cannot be passed anywhere" - and it pointed at the wrong thing: the options CAN be passed and are
// dropped. That sentence is retracted in facts/VideoToolbox/DecodeEncodeVariants.md.
//
// The arity question is settled too, and in the direction that makes this a forward: the 16.4 SDK declares
// `VTDecompressionSessionDecodeFrame` with five parameters including `infoFlagsOut`
// (VTDecompressionSession.h:184-190, API_AVAILABLE(macosx(10.8), ios(8.0), tvos(10.2))), and on ARM an EXTRA
// argument is harmless while a MISSING one is not, so calling that form at 4.3 is safe. The annotation says
// when the symbol became public, not how many arguments the 4.3 code reads.

// The options are dropped, so the dictionary is not even looked at. Taking it as a parameter and ignoring it
// is the whole of the host's behaviour here; the parameter is still named, because the API has it.
OSStatus VTDecompressionSessionDecodeFrameWithOptions(
    VTDecompressionSessionRef CM_NONNULL session,
    CMSampleBufferRef CM_NONNULL sampleBuffer,
    VTDecodeFrameFlags decodeFlags,
    CFDictionaryRef CM_NULLABLE frameOptions,
    void * CM_NULLABLE sourceFrameRefCon,
    VTDecodeInfoFlags * CM_NULLABLE infoFlagsOut)
{
    (void)frameOptions;
    // The release's own decode, with the same flags, the same sourceFrameRefCon and the same infoFlags word -
    // all three forwarded, because the measurement shows the host writes infoFlagsOut and the port has no
    // other source for it. Nothing is added and nothing is dropped.
    return VTDecompressionSessionDecodeFrame(session, sampleBuffer, decodeFlags, sourceFrameRefCon, infoFlagsOut);
}

// VTDecompressionSessionDecodeFrameWithOptionsAndOutputHandler.
//
// MEASURED on the same real sample, all five dictionaries: **-12902 for every one, with no handler call and
// infoFlagsOut not written** (the 0x5a5a5a5a the probe handed in came back). The refusal is about the
// variant and not about the options - the five lines are identical - and not about the session, since the
// control decode on the same session answers noErr.
//
// The block is not called, which the header sanctions: when the
// VTDecompressionSessionDecodeFrameWithOptionsAndOutputHandler call reports an error, the block is never run.
// The block is also not retained: there is nowhere to retain it that the release would read, and the
// release's own handler form of the decode does not exist at any band the port builds
// (_VTDecompressionSessionDecodeFrameWithOutputHandler 4.3=0, 6.1.3=0).
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