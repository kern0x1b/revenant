#import <AVFoundation/AVFoundation.h>

// 19 of the AVFoundation constants this slice carries: the names the 13.4 rung is the first held rung to export.
// The other 15 are in AVFoundationDeviceTypeAndPresetKeys16.m, which is the 16.0 object of the same slice.
//
// The values were read out of the host's own AVFoundation with one dlsym of the exported symbol per
// name, as text and as bytes, and the differential in tests/backports/host/avf-notifications reads
// the same table out of two builds - Apple's framework alone, and this file beside it in one binary
// with the names renamed - and diffs it.
//
// 11 of the 19 answer their own symbol's name and 8 do not, and which is a measurement and not a rule:
// the AVVideoCodecTypeAppleProRes422* names are Apple's four-letter codes (apch, apcs, apco),
// AVVideoCodecTypeHEVCWithAlpha is "muxa", and the AVContentKey names are bare key names.
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
NSString *const AVAssetExportPresetHEVC1920x1080WithAlpha = @"AVAssetExportPresetHEVC1920x1080WithAlpha";
NSString *const AVAssetExportPresetHEVC3840x2160WithAlpha = @"AVAssetExportPresetHEVC3840x2160WithAlpha";
NSString *const AVAssetExportPresetHEVCHighestQualityWithAlpha = @"AVAssetExportPresetHEVCHighestQualityWithAlpha";
NSString *const AVCaptureDeviceTypeBuiltInDualWideCamera = @"AVCaptureDeviceTypeBuiltInDualWideCamera";
NSString *const AVCaptureDeviceTypeBuiltInTripleCamera = @"AVCaptureDeviceTypeBuiltInTripleCamera";
NSString *const AVCaptureDeviceTypeBuiltInUltraWideCamera = @"AVCaptureDeviceTypeBuiltInUltraWideCamera";
NSString *const AVContentKeyRequestRequiresValidationDataInSecureTokenKey = @"RequiresValidationDataInSecureTokenKey";
NSString *const AVContentKeySessionServerPlaybackContextOptionProtocolVersions = @"ProtocolVersionsKey";
NSString *const AVContentKeySessionServerPlaybackContextOptionServerChallenge = @"ServerChallenge";
NSString *const AVContentKeySystemAuthorizationToken = @"AuthorizationTokenSystem";
NSString *const AVOutputSettingsPresetHEVC1920x1080WithAlpha = @"AVOutputSettingsPresetHEVC1920x1080WithAlpha";
NSString *const AVOutputSettingsPresetHEVC3840x2160WithAlpha = @"AVOutputSettingsPresetHEVC3840x2160WithAlpha";
NSString *const AVSemanticSegmentationMatteTypeHair = @"AVSemanticSegmentationMatteTypeHair";
NSString *const AVSemanticSegmentationMatteTypeSkin = @"AVSemanticSegmentationMatteTypeSkin";
NSString *const AVSemanticSegmentationMatteTypeTeeth = @"AVSemanticSegmentationMatteTypeTeeth";
NSString *const AVVideoCodecTypeAppleProRes422HQ = @"apch";
NSString *const AVVideoCodecTypeAppleProRes422LT = @"apcs";
NSString *const AVVideoCodecTypeAppleProRes422Proxy = @"apco";
NSString *const AVVideoCodecTypeHEVCWithAlpha = @"muxa";
