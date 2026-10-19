#import "CharonAUAudioUnit.h"

// The C entry point the release calls when it wants audio for an audio unit. It is here rather than
// in AUAudioUnit9.m because a C function shared between backport files is the documented trap in
// charon/AGENTS.md: a file that exports an API symbol is left out of a band whose release already has
// it, and the call is Undefined symbols in later bands only - backports.lua's minimums() then takes
// this one as a helper, at the lowest minimum among the objects that name it. This file exports no
// API symbol: the one C function it defines is Charon-prefixed, and internal_symbol() hides that.

// The render callback the release's own AudioUnitRender machinery invokes. AURenderBlock is the
// port's block; this is the C shim that reaches it, and it does no allocation, no locking and no
// message send beyond the one call into the owner - which is what a render callback may do.
OSStatus CharonAURenderInput(void *inRefCon, AudioUnitRenderActionFlags *ioActionFlags,
                             const AudioTimeStamp *inTimeStamp, UInt32 inBusNumber,
                             UInt32 inNumberFrames, AudioBufferList *ioData)
{
    // inRefCon is the AUAudioUnit, held unretained and for as long as the AudioUnit lives, which is
    // the owner's own lifetime: -dealloc disposes the AudioUnit, and the AudioUnit is the only thing
    // that can call this.
    AUAudioUnit *owner = (__bridge AUAudioUnit *)inRefCon;
    return [owner charon_renderWithActionFlags:ioActionFlags
                                     timestamp:inTimeStamp
                                    frameCount:inNumberFrames
                                           bus:inBusNumber
                                           data:ioData];
}
