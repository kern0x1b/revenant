#import <AVFoundation/AVFoundation.h>

// The AVFoundation constants this object carries, one release's worth: an object may only hold API of
// one release, and which release that is was MEASURED with tools/symbol-first-release.lua - the first
// release whose AVFoundation EXPORTS the name - not read off a header's API_AVAILABLE.
// Every name here measures the same, so this file is one object: no held cache exports any of them, so each row's own introduced places this object.
//
// Every value below was read on this machine and none was typed. tests/backports/host/avf-globals/run.sh
// is the differential: it compiles this object with each constant's DEFINITION renamed to a charon_host_
// spelling, links it beside a probe that reads Apple's own symbol under the bare name, and compares the
// two in one process - 54 of 54 here, and 62 of the 116 the port carries, agree with the host.
// No name here is in a cache this machine holds - the ladder ends at 18.0 and these are above it - so the host is the only oracle that reaches them, which is why the differential has to be right.
// facts/AVFoundation/Globals.md has the run, its four controls, the planted value that proves
// the check can fail and the clean control that proves the red is the mutation, the correction of an
// earlier wrong claim about this host, and the five AVCaptureWhiteBalanceTemperatureAndTintValues
// presets no oracle on this machine can answer.
//
// None of this is the port's minimum release own: it does not export these names, so an application
// that names one loads this string rather than a missing symbol, and where it hands the string to
// the release the release treats it as it treats any string it does not know.
NSString *const AVAssetExportPresetHEVC4320x2160 = @"AVAssetExportPresetHEVC4320x2160";
NSString *const AVAssetExportPresetMVHEVC4320x4320 = @"AVAssetExportPresetMVHEVC4320x4320";
NSString *const AVAssetExportPresetMVHEVC7680x7680 = @"AVAssetExportPresetMVHEVC7680x7680";
NSString *const AVAssetPlaybackConfigurationOptionNonRectilinearProjection = @"AVAssetPlaybackConfigurationOptionNonRectilinearProjection";
NSString *const AVCaptureAspectRatio16x9 = @"AVCaptureAspectRatio16x9";
NSString *const AVCaptureAspectRatio1x1 = @"AVCaptureAspectRatio1x1";
NSString *const AVCaptureAspectRatio3x4 = @"AVCaptureAspectRatio3x4";
NSString *const AVCaptureAspectRatio4x3 = @"AVCaptureAspectRatio4x3";
NSString *const AVCaptureAspectRatio9x16 = @"AVCaptureAspectRatio9x16";
NSString *const AVCaptureSceneMonitoringStatusNotEnoughLight = @"AVCaptureSceneMonitoringStatusNotEnoughLight";
NSString *const AVContentKeyRequestRandomDeviceIdentifierSeedKey = @"RandomDeviceIdentifierSeedKey";
NSString *const AVContentKeyRequestShouldRandomizeDeviceIdentifierKey = @"ShouldRandomizeDeviceIdentifierKey";
NSString *const AVFileTypeDICOM = @"org.nema.dicom";
NSString *const AVFileTypeQuickTimeAudio = @"com.apple.quicktime-audio";
NSString *const AVMediaCharacteristicIndicatesNonRectilinearProjection = @"public.indicates-non-rectilinear-projection";
NSString *const AVMediaCharacteristicMachineGenerated = @"public.machine-generated";
NSString *const AVMetadataIdentifierQuickTimeMetadataCameraISOSensitivity = @"mdta/org.smpte.rdd18.camera.isosensitivity";
NSString *const AVMetadataIdentifierQuickTimeMetadataCameraLensIrisFNumber = @"mdta/com.apple.quicktime.camera.lens_irisfnumber";
NSString *const AVMetadataIdentifierQuickTimeMetadataCameraShutterSpeedAngle = @"mdta/org.smpte.rdd18.camera.shutterspeed_angle";
NSString *const AVMetadataIdentifierQuickTimeMetadataCameraShutterSpeedTime = @"mdta/org.smpte.rdd18.camera.shutterspeed_time";
NSString *const AVMetadataIdentifierQuickTimeMetadataCameraWhiteBalance = @"mdta/org.smpte.rdd18.camera.whitebalance";
NSString *const AVMetadataIdentifierQuickTimeMetadataCinematicVideoIntent = @"mdta/com.apple.quicktime.cinematic-video-intent";
NSString *const AVMetadataIdentifierQuickTimeMetadataWhiteBalanceByCCTColorMatrices = @"mdta/com.apple.proresraw.whitebalance.bycct.colormatrices";
NSString *const AVMetadataIdentifierQuickTimeMetadataWhiteBalanceByCCTWhiteBalanceFactors = @"mdta/com.apple.proresraw.whitebalance.bycct.whitebalancefactors";
NSString *const AVMetadataQuickTimeMetadataKeyCameraFocalLength35mmEquivalent = @"com.apple.quicktime.camera.focal_length.35mm_equivalent";
NSString *const AVMetadataQuickTimeMetadataKeyCameraISOSensitivity = @"org.smpte.rdd18.camera.isosensitivity";
NSString *const AVMetadataQuickTimeMetadataKeyCameraLensIrisFNumber = @"com.apple.quicktime.camera.lens_irisfnumber";
NSString *const AVMetadataQuickTimeMetadataKeyCameraLensModel = @"com.apple.quicktime.camera.lens_model";
NSString *const AVMetadataQuickTimeMetadataKeyCameraShutterSpeedAngle = @"org.smpte.rdd18.camera.shutterspeed_angle";
NSString *const AVMetadataQuickTimeMetadataKeyCameraShutterSpeedTime = @"org.smpte.rdd18.camera.shutterspeed_time";
NSString *const AVMetadataQuickTimeMetadataKeyCameraWhiteBalance = @"org.smpte.rdd18.camera.whitebalance";
NSString *const AVMetadataQuickTimeMetadataKeyCinematicVideoIntent = @"com.apple.quicktime.cinematic-video-intent";
NSString *const AVMetadataQuickTimeMetadataKeyWhiteBalanceByCCTColorMatrices = @"com.apple.proresraw.whitebalance.bycct.colormatrices";
NSString *const AVMetadataQuickTimeMetadataKeyWhiteBalanceByCCTWhiteBalanceFactors = @"com.apple.proresraw.whitebalance.bycct.whitebalancefactors";
NSString *const AVOutputSettingsPresetHEVC4320x2160 = @"AVOutputSettingsPresetHEVC4320x2160";
NSString *const AVOutputSettingsPresetMVHEVC4320x4320 = @"AVOutputSettingsPresetMVHEVC4320x4320";
NSString *const AVOutputSettingsPresetMVHEVC7680x7680 = @"AVOutputSettingsPresetMVHEVC7680x7680";
NSString *const AVPlayerInterstitialEventMonitorCurrentEventSkippableStateDidChangeEventKey = @"CurrentEventSkippableStateDidChangeEventKey";
NSString *const AVPlayerInterstitialEventMonitorCurrentEventSkippableStateDidChangeNotification = @"CurrentEventSkippableStateDidChange";
NSString *const AVPlayerInterstitialEventMonitorCurrentEventSkippableStateDidChangeSkipControlLabelKey = @"CurrentEventSkippableStateDidChangeSkipControlLabelKey";
NSString *const AVPlayerInterstitialEventMonitorCurrentEventSkippableStateDidChangeStateKey = @"CurrentEventSkippableStateDidChangeStateKey";
NSString *const AVPlayerInterstitialEventMonitorCurrentEventSkippedEventKey = @"CurrentEventSkippedEventKey";
NSString *const AVPlayerInterstitialEventMonitorCurrentEventSkippedNotification = @"CurrentEventSkipped";
NSString *const AVPlayerInterstitialEventMonitorInterstitialEventDidFinishDidPlayEntireEventKey = @"InterstitialEventDidFinishDidPlayEntireEventKey";
NSString *const AVPlayerInterstitialEventMonitorInterstitialEventDidFinishEventKey = @"InterstitialEventDidFinishEventKey";
NSString *const AVPlayerInterstitialEventMonitorInterstitialEventDidFinishNotification = @"InterstitialEventDidFinish";
NSString *const AVPlayerInterstitialEventMonitorInterstitialEventDidFinishPlayoutTimeKey = @"InterstitialEventDidFinishPlayoutTimeKey";
NSString *const AVPlayerInterstitialEventMonitorInterstitialEventWasUnscheduledErrorKey = @"InterstitialEventWasUnscheduleErrorKey";
NSString *const AVPlayerInterstitialEventMonitorInterstitialEventWasUnscheduledEventKey = @"InterstitialEventWasUnscheduleEventKey";
NSString *const AVPlayerInterstitialEventMonitorInterstitialEventWasUnscheduledNotification = @"InterstitialEventWasUnscheduled";
NSString *const AVTrackAssociationTypeRenderMetadataSource = @"rndr";
NSString *const AVURLAssetShouldParseExternalSphericalTagsKey = @"AVURLAssetShouldParseExternalSphericalTagsKey";
NSString *const AVVideoCodecTypeAppleProResRAW = @"aprn";
NSString *const AVVideoCodecTypeAppleProResRAWHQ = @"aprh";
