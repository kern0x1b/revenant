#import <AVFoundation/AVFoundation.h>

// 2 constants, the two IsMontage names, which the 10.0.1 release already exports, and nothing else: a name this file does not define is a name the
// corpus's gate asks for and the link cannot find, so the list below is the whole of this file's
// claim and the registry names each one of them.
//
// Every value was read out of the host's own AVFoundation at runtime and the differential in
// tests/backports/host/avf-metadata reads the same table out of two builds - Apple's framework on
// its own, and this file beside it in one binary with the names renamed - and diffs them, text and
// bytes both.
//
// The object is split by MEASUREMENT, not by a version string: dyld.first_releases' own answer over
// the armv7/armv7s ladder and a direct dump of the arm64 caches of 9.3.6, 10.0.1, 11.0, 12.0 and 16.0
// (tools/corpus/dump-cache.lua) say which release first exports each name, and an object may not mix
// a name a band already exports with one it does not - backports.lua's band() raises on that, and a
// single-band 6.1.3 gate cannot see it because #present is 0 there. The table is in
// facts/AVFoundation/MetadataKeySpaces.md and the dumps that produced it are the evidence this claim rests on.
//
// See facts/AVFoundation/MetadataKeySpaces.md.

NSString *const AVMetadataIdentifierQuickTimeMetadataIsMontage = @"mdta/com.apple.quicktime.is-montage";
NSString *const AVMetadataQuickTimeMetadataKeyIsMontage = @"com.apple.quicktime.is-montage";
