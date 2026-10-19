#import <AVFoundation/AVFoundation.h>

// The AVFoundation constants this object carries, one release's worth: an object may only hold API of
// one release, and which release that is was MEASURED with tools/symbol-first-release.lua - the first
// release whose AVFoundation EXPORTS the name - not read off a header's API_AVAILABLE.
// The two disagree for 1 of the 1 names here, which is why the header's own introduced version is not what this file is split by.
// Measured as first exported by: 10.0.1.
//
// Every value below was read on this machine and none was typed. tests/backports/host/avf-globals/run.sh
// is the differential: it compiles this object with each constant's DEFINITION renamed to a charon_host_
// spelling, links it beside a probe that reads Apple's own symbol under the bare name, and compares the
// two in one process - 1 of 1 here, and 62 of the 116 the port carries, agree with the host.
// 1 of the 1 were read a second time from the shared cache of the iOS release that exports them (tools/corpus/cache-value.lua), and that reading agrees on every one.
// facts/AVFoundation/Globals.md has the run, its four controls, the planted value that proves
// the check can fail and the clean control that proves the red is the mutation, the correction of an
// earlier wrong claim about this host, and the five AVCaptureWhiteBalanceTemperatureAndTintValues
// presets no oracle on this machine can answer.
//
// None of this is the port's minimum release own: it does not export these names, so an application
// that names one loads this string rather than a missing symbol, and where it hands the string to
// the release the release treats it as it treats any string it does not know.
NSString *const AVMediaTypeHaptic = @"hapt";
