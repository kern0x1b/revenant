#import "CharonVideoToolbox.h"

// The error domain VTFrameProcessor.h of SDK 26.2 declares as a NAME and never spells:
//
//     extern NSErrorDomain _Nonnull const VTFrameProcessorErrorDomain;
//
// An NSErrorDomain is an NSString, and this one has no spelling in any header, so writing
// @"VTFrameProcessorErrorDomain" from the name would be a guess. The string is Apple's own and it is
// MEASURED: the host's own /System/Library/Frameworks/VideoToolbox.framework exports the symbol, and
// tests/backports/host/videotoolbox-frameprocessor/frameprocessor.m dlsym's it on every run, builds an
// NSError in the port's own domain and compares .domain against Apple's string byte for byte.
// Measured 2026-10-03 on this machine:
//
//     VTFrameProcessorErrorDomain = "VTFrameProcessorErrorDomain" (class __NSCFConstantString)
//
// which is the constant's own name, and it is recorded as measured rather than assumed precisely
// because a name is not a value: MTLCommonCounterSetStageUtilization is "stageutilization" and no
// compiler says so.
//
// Its own codes are NOT here: VTFrameProcessorError is an NS_ERROR_ENUM, so its cases are the
// enumerated names in CharonVideoToolbox.h and there is no symbol for a case to be. The port's errors
// are built with [NSError errorWithDomain:VTFrameProcessorErrorDomain code:...] against those.

NSErrorDomain const VTFrameProcessorErrorDomain = @"VTFrameProcessorErrorDomain";