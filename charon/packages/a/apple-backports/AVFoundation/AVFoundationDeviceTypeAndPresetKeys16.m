#import <AVFoundation/AVFoundation.h>

// 15 of the AVFoundation constants this slice carries: the names the 16.0 rung is the first held rung to export.
// The other 19 are in AVFoundationDeviceTypeAndPresetKeys134.m, which is the 13.4 object of the same slice.
//
// The values were read out of the host's own AVFoundation with one dlsym of the exported symbol per
// name, as text and as bytes, and the differential in tests/backports/host/avf-notifications reads
// the same table out of two builds - Apple's framework alone, and this file beside it in one binary
// with the names renamed - and diffs it.
//
// 9 of the 15 answer their own symbol's name and 6 do not, and which is a measurement and not a rule:
// the AVFileTypeProfile names are a UTI suffix, the AVPlayerInterstitialEvent names are bare cue names,
// and AVVideoTransferFunction_Linear answers "Linear".
//
// The object is split by MEASUREMENT, not by the corpus's introduced: an object may not mix a name a
// band already exports with one it does not, or backports.lua's band() raises. Searching the held
// caches - 4.3, 6.1.3, 7.0, 7.1, 7.1.1, 7.1.2 and 8.0 (armv7), 8.1.3, 8.2 and 8.4.1 (armv7s), 9.3.6
// (armv7), 10.0.1, 11.0, 12.0 and 13.4 (arm64), and 16.0 (arm64e) - for each name's own exported
// symbol gives the first HELD RUNG that exports it. "First held rung" is the honest phrase: a release
// between two held ones may export a name and this measurement cannot see it, and _NSFileSize is
// planted as a control wherever a rung is claimed.
//
// See facts/AVFoundation/AVFoundationDeviceTypeAndPresetKeys.md.
NSString *const AVAssetExportPresetAppleProRes422LPCM = @"AVAssetExportPresetAppleProRes422LPCM";
NSString *const AVAssetExportPresetAppleProRes4444LPCM = @"AVAssetExportPresetAppleProRes4444LPCM";
NSString *const AVAssetPlaybackConfigurationOptionStereoMultiviewVideo = @"AVAssetPlaybackConfigurationOptionStereoMultiviewVideo";
NSString *const AVAssetPlaybackConfigurationOptionStereoVideo = @"AVAssetPlaybackConfigurationOptionStereoVideo";
NSString *const AVCaptureDeviceTypeBuiltInLiDARDepthCamera = @"AVCaptureDeviceTypeBuiltInLiDARDepthCamera";
NSString *const AVFileTypeProfileMPEG4AppleHLS = @"MPEG4AppleHLS";
NSString *const AVFileTypeProfileMPEG4CMAFCompliant = @"MPEG4CMAFCompliant";
NSString *const AVPlayerInterstitialEventJoinCue = @"EventJoinCue";
NSString *const AVPlayerInterstitialEventLeaveCue = @"EventLeaveCue";
NSString *const AVPlayerInterstitialEventNoCue = @"EventNoCue";
NSString *const AVSemanticSegmentationMatteTypeGlasses = @"AVSemanticSegmentationMatteTypeGlasses";
NSString *const AVVideoRangeHLG = @"AVVideoRangeHLG";
NSString *const AVVideoRangePQ = @"AVVideoRangePQ";
NSString *const AVVideoRangeSDR = @"AVVideoRangeSDR";
NSString *const AVVideoTransferFunction_Linear = @"Linear";
