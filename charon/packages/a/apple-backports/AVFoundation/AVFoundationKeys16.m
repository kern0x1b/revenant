#import <AVFoundation/AVFoundation.h>

// 13 of the notification names, user-info keys and option keys this slice carries: the names the 16.0 rung is the
// first held rung to export. The other 14 are in AVFoundationKeys134.m, which is the 13.4 object of the same slice.
//
// Every value was read out of the host's own AVFoundation at runtime, one dlsym of the exported
// symbol per name, and the differential in tests/backports/host/avf-notifications reads the same table
// out of two builds - Apple's framework on its own, and this file beside it in one binary with the
// names renamed - and diffs it, the text and the bytes both.
//
// 9 of the 13 answer their own symbol's name and 4 do not: AVMediaCharacteristicContainsHDRVideo
// answers "public.contains-hdr-video", the two AVPlayerInterstitialEventMonitor names drop the
// monitor's own prefix, and AVVideoAppleProRAWBitDepthKey answers "AppleProRAWBitDepthKey". The values
// are read at run time rather than composed from the symbol, which is why the port follows the host.
//
// The object is split by MEASUREMENT, not by the corpus's introduced: an object may not mix a name a
// band already exports with one it does not, or backports.lua's band() raises "an object carries API
// that arrived in one release". Searching the held caches - 4.3, 6.1.3, 7.0, 7.1, 7.1.1, 7.1.2 and 8.0
// (armv7), 8.1.3, 8.2 and 8.4.1 (armv7s), 9.3.6 (armv7), 10.0.1, 11.0, 12.0 and 13.4 (arm64), and 16.0
// (arm64e) - for each name's own exported symbol gives the FIRST HELD RUNG that exports it. "First held
// rung" is the honest phrase: a release between two held ones may export a name and this measurement
// cannot see it. _NSFileSize is planted as a control wherever a rung is claimed.
//
// See facts/AVFoundation/AVFoundationNotificationKeys.md.
NSString *const AVAssetDownloadTaskPrefersHDRKey = @"AVAssetDownloadTaskPrefersHDRKey";
NSString *const AVAssetDownloadTaskPrefersLosslessAudioKey = @"AVAssetDownloadTaskPrefersLosslessAudioKey";
NSString *const AVMediaCharacteristicContainsHDRVideo = @"public.contains-hdr-video";
NSString *const AVPlayerInterstitialEventMonitorCurrentEventDidChangeNotification = @"CurrentEventDidChangeNotification";
NSString *const AVPlayerInterstitialEventMonitorEventsDidChangeNotification = @"EventsDidChangeNotification";
NSString *const AVPlayerItemTimeJumpedOriginatingParticipantKey = @"AVPlayerItemTimeJumpedOriginatingParticipantKey";
NSString *const AVSampleBufferAudioRendererOutputConfigurationDidChangeNotification = @"AVSampleBufferAudioRendererOutputConfigurationDidChangeNotification";
NSString *const AVSampleBufferDisplayLayerOutputObscuredDueToInsufficientExternalProtectionDidChangeNotification = @"AVSampleBufferDisplayLayerOutputObscuredDueToInsufficientExternalProtectionDidChangeNotification";
NSString *const AVSampleBufferDisplayLayerRequiresFlushToResumeDecodingDidChangeNotification = @"AVSampleBufferDisplayLayerRequiresFlushToResumeDecodingDidChangeNotification";
NSString *const AVURLAssetHTTPUserAgentKey = @"AVURLAssetHTTPUserAgentKey";
NSString *const AVURLAssetPrimarySessionIdentifierKey = @"AVURLAssetPrimarySessionIdentifierKey";
NSString *const AVURLAssetURLRequestAttributionKey = @"AVURLAssetURLRequestAttributionKey";
NSString *const AVVideoAppleProRAWBitDepthKey = @"AppleProRAWBitDepthKey";
